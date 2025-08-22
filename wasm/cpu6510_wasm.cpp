// cpu6510_wasm.cpp - Fixed version with proper zero page tracking
// Compile with: emcc cpu6510_wasm.cpp -O3 -s WASM=1 -s EXPORTED_FUNCTIONS='["_malloc","_free"]' -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","getValue","setValue"]' -s MODULARIZE=1 -s EXPORT_NAME='CPU6510Module' -o cpu6510.js

#include <emscripten/emscripten.h>
#include <cstdint>
#include <cstring>
#include <vector>
#include <algorithm>
#include "opcodes.h"

extern "C" {

    // Memory access tracking flags
    enum MemoryAccessFlag {
        MEM_EXECUTE = 1 << 0,
        MEM_READ = 1 << 1,
        MEM_WRITE = 1 << 2,
        MEM_JUMP_TARGET = 1 << 3,
        MEM_OPCODE = 1 << 4
    };

    // CPU Status flags
    enum StatusFlag {
        FLAG_CARRY = 0x01,
        FLAG_ZERO = 0x02,
        FLAG_INTERRUPT = 0x04,
        FLAG_DECIMAL = 0x08,
        FLAG_BREAK = 0x10,
        FLAG_UNUSED = 0x20,
        FLAG_OVERFLOW = 0x40,
        FLAG_NEGATIVE = 0x80
    };

    // Global CPU state
    struct CPU6510State {
        uint16_t pc;
        uint8_t sp;
        uint8_t a;
        uint8_t x;
        uint8_t y;
        uint8_t status;
        uint64_t cycles;

        uint8_t ciaTimerLo;
        uint8_t ciaTimerHi;
        bool ciaTimerWritten;

        uint8_t memory[65536];
        uint8_t memoryAccess[65536];

        // SID write tracking
        uint32_t sidWrites[32];  // Count writes to each SID register
        uint32_t totalSidWrites;

        // Zero page write tracking
        uint32_t zpWrites[256];   // Count writes to each zero page location
        uint32_t totalZpWrites;

        // Memory write tracking
        uint16_t lastWritePC[65536];  // Track PC that last wrote to each address

        // For pattern detection
        std::vector<uint16_t> writeSequence;
        bool recordWrites;

        // Flag to enable/disable tracking (so we can load without tracking)
        bool trackingEnabled;
    } cpu;

    // Helper function to read 16-bit address from memory
    uint16_t read_word(uint16_t& pc) {
        uint8_t lo = cpu.memory[pc++];
        uint8_t hi = cpu.memory[pc++];
        return lo | (hi << 8);
    }

    // Initialize CPU
    EMSCRIPTEN_KEEPALIVE
        void cpu_init() {
        cpu.pc = 0;
        cpu.sp = 0xFD;
        cpu.a = 0;
        cpu.x = 0;
        cpu.y = 0;
        cpu.status = FLAG_INTERRUPT | FLAG_UNUSED;
        cpu.cycles = 0;

        cpu.ciaTimerLo = 0;
        cpu.ciaTimerHi = 0;
        cpu.ciaTimerWritten = false;

        cpu.totalSidWrites = 0;
        cpu.totalZpWrites = 0;
        cpu.recordWrites = false;
        cpu.trackingEnabled = false;

        memset(cpu.memory, 0, sizeof(cpu.memory));
        memset(cpu.memoryAccess, 0, sizeof(cpu.memoryAccess));
        memset(cpu.sidWrites, 0, sizeof(cpu.sidWrites));
        memset(cpu.zpWrites, 0, sizeof(cpu.zpWrites));
        memset(cpu.lastWritePC, 0, sizeof(cpu.lastWritePC));

        cpu.writeSequence.clear();
    }

    // Enable or disable tracking
    EMSCRIPTEN_KEEPALIVE
        void cpu_set_tracking(bool enabled) {
        cpu.trackingEnabled = enabled;
    }

    // Load data into memory WITHOUT tracking
    EMSCRIPTEN_KEEPALIVE
        void cpu_load_memory(uint16_t address, uint8_t* data, uint16_t size) {
        if (address + size <= 65536) {
            memcpy(&cpu.memory[address], data, size);
            // Note: No tracking here - this is just loading the initial data
        }
    }

    // Read memory (for internal use and tracking)
    EMSCRIPTEN_KEEPALIVE
        uint8_t cpu_read_memory(uint16_t address) {
        if (cpu.trackingEnabled) {
            cpu.memoryAccess[address] |= MEM_READ;
        }
        return cpu.memory[address];
    }

    // Write memory - only used for initial loading, not tracked
    EMSCRIPTEN_KEEPALIVE
        void cpu_write_memory(uint16_t address, uint8_t value) {
        cpu.memory[address] = value;
        // Don't track this - it's only for initial setup
    }

    // Internal memory write (used by instructions) - THIS is what we track
    void write_memory_internal(uint16_t address, uint8_t value) {
        cpu.memory[address] = value;

        // Only track if tracking is enabled
        if (cpu.trackingEnabled) {
            cpu.memoryAccess[address] |= MEM_WRITE;
            cpu.lastWritePC[address] = cpu.pc;

            // Track zero page writes
            if (address < 256) {
                cpu.zpWrites[address]++;
                cpu.totalZpWrites++;
            }

            // Track SID writes
            if (address >= 0xD400 && address <= 0xD41F) {
                uint8_t reg = address & 0x1F;
                cpu.sidWrites[reg]++;
                cpu.totalSidWrites++;

                if (cpu.recordWrites) {
                    cpu.writeSequence.push_back(address);
                }
            }

			// Track CIA timer writes
            if (address == 0xDC04) {
                cpu.ciaTimerLo = value;
                cpu.ciaTimerWritten = true;
            }
            else if (address == 0xDC05) {
                cpu.ciaTimerHi = value;
                cpu.ciaTimerWritten = true;
            }
        }
    }

    // Stack operations
    void push(uint8_t value) {
        write_memory_internal(0x0100 + cpu.sp, value);
        cpu.sp--;
    }

    uint8_t pop() {
        cpu.sp++;
        return cpu.memory[0x0100 + cpu.sp];
    }

    // Set processor flags
    void set_flag(uint8_t flag, bool value) {
        if (value) {
            cpu.status |= flag;
        }
        else {
            cpu.status &= ~flag;
        }
    }

    bool test_flag(uint8_t flag) {
        return (cpu.status & flag) != 0;
    }

    void set_zn_flags(uint8_t value) {
        set_flag(FLAG_ZERO, value == 0);
        set_flag(FLAG_NEGATIVE, (value & 0x80) != 0);
    }

    // === Addressing & micro-helpers =============================================
    inline uint8_t rd(uint16_t addr) {
        if (cpu.trackingEnabled) cpu.memoryAccess[addr] |= MEM_READ;
        return cpu.memory[addr];
    }
    inline bool page_crossed(uint16_t a, uint16_t b) { return (a & 0xFF00) != (b & 0xFF00); }

    struct EA { uint16_t addr; bool cross; };

    inline EA ea_abs(uint16_t& pc) { uint16_t base = read_word(pc); return { base, false }; }
    inline EA ea_absx(uint16_t& pc) { uint16_t base = read_word(pc); uint16_t a = base + cpu.x; return { a, page_crossed(base,a) }; }
    inline EA ea_absy(uint16_t& pc) { uint16_t base = read_word(pc); uint16_t a = base + cpu.y; return { a, page_crossed(base,a) }; }
    inline EA ea_zp(uint16_t& pc) { uint8_t z = cpu.memory[pc++]; return { z, false }; }
    inline EA ea_zpx(uint16_t& pc) { uint8_t z = (cpu.memory[pc++] + cpu.x) & 0xFF; return { z, false }; }
    inline EA ea_zpy(uint16_t& pc) { uint8_t z = (cpu.memory[pc++] + cpu.y) & 0xFF; return { z, false }; }
    inline EA ea_indx(uint16_t& pc) { uint8_t z = (cpu.memory[pc++] + cpu.x) & 0xFF; uint16_t a = rd(z) | (rd((z + 1) & 0xFF) << 8); return { a, false }; }
    inline EA ea_indy(uint16_t& pc) { uint8_t z = cpu.memory[pc++]; uint16_t b = rd(z) | (rd((z + 1) & 0xFF) << 8); uint16_t a = b + cpu.y; return { a, page_crossed(b,a) }; }

    inline void add(uint8_t c) { cpu.cycles += c; }
    inline void add_read(uint8_t base, bool cross) { cpu.cycles += base + (cross ? 1 : 0); }

    inline void do_cmp(uint8_t reg, uint8_t v) {
        uint8_t r = reg - v;
        set_flag(FLAG_CARRY, reg >= v);
        set_zn_flags(r);
    }
    inline void do_adc(uint8_t v) { // binary mode (matches your current core)
        uint16_t r = uint16_t(cpu.a) + v + (test_flag(FLAG_CARRY) ? 1 : 0);
        set_flag(FLAG_CARRY, r > 0xFF);
        set_flag(FLAG_OVERFLOW, ((cpu.a ^ r) & (v ^ r) & 0x80) != 0);
        cpu.a = uint8_t(r);
        set_zn_flags(cpu.a);
    }
    inline void do_sbc(uint8_t v) { // binary mode (matches your current core)
        uint16_t r = uint16_t(cpu.a) - v - (test_flag(FLAG_CARRY) ? 0 : 1);
        set_flag(FLAG_CARRY, r < 0x100);
        set_flag(FLAG_OVERFLOW, ((cpu.a ^ r) & (~v ^ r) & 0x80) != 0);
        cpu.a = uint8_t(r);
        set_zn_flags(cpu.a);
    }

    // RMW helpers (memory)
    inline void do_asl_mem(uint16_t a) { uint8_t v = rd(a); set_flag(FLAG_CARRY, v & 0x80); v <<= 1; write_memory_internal(a, v); set_zn_flags(v); }
    inline void do_lsr_mem(uint16_t a) { uint8_t v = rd(a); set_flag(FLAG_CARRY, v & 0x01); v >>= 1; write_memory_internal(a, v); set_zn_flags(v); }
    inline void do_rol_mem(uint16_t a) { uint8_t v = rd(a); bool c = test_flag(FLAG_CARRY); set_flag(FLAG_CARRY, v & 0x80); v = (v << 1) | (c ? 1 : 0); write_memory_internal(a, v); set_zn_flags(v); }
    inline void do_ror_mem(uint16_t a) { uint8_t v = rd(a); bool c = test_flag(FLAG_CARRY); set_flag(FLAG_CARRY, v & 0x01); v = (v >> 1) | (c ? 0x80 : 0); write_memory_internal(a, v); set_zn_flags(v); }

    // Unofficial convenience
    inline void do_lax(uint8_t v) { cpu.a = v; cpu.x = v; set_zn_flags(v); }

    // Branch helper (+1 taken, +1 if taken crosses page)
    inline void branch_if(bool cond, uint16_t& pc) {
        int8_t off = (int8_t)cpu.memory[pc++];
        if (!cond) { add(2); return; }
        uint16_t old = pc; pc = uint16_t(pc + off);
        add(3);
        if (page_crossed(old, pc)) add(1);
    }
    // =============================================================================

    // Execute one instruction
    EMSCRIPTEN_KEEPALIVE
        void cpu_step() {
        uint16_t pc = cpu.pc;
        uint8_t opcode = cpu.memory[pc++];

        if (cpu.trackingEnabled) {
            cpu.memoryAccess[cpu.pc] |= MEM_EXECUTE | MEM_OPCODE;
        }

        // Simplified instruction execution - implement core instructions
        switch (opcode) {
            // LDA
        case 0xA9: // LDA immediate
            cpu.a = cpu.memory[pc++];
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
            break;

        case 0xA5: // LDA zero page
        {
            uint8_t zp = cpu.memory[pc++];
            cpu.a = cpu.memory[zp];
            if (cpu.trackingEnabled) {
                cpu.memoryAccess[zp] |= MEM_READ;
            }
            set_zn_flags(cpu.a);
            cpu.cycles += 3;
        }
        break;

        case 0xAD: // LDA absolute
        {
            uint16_t addr = read_word(pc);
            cpu.a = cpu.memory[addr];
            if (cpu.trackingEnabled) {
                cpu.memoryAccess[addr] |= MEM_READ;
            }
            set_zn_flags(cpu.a);
            cpu.cycles += 4;
        }
        break;

        case 0xBD: /* LDA abs,X */ { auto e = ea_absx(pc); cpu.a = rd(e.addr); set_zn_flags(cpu.a); add_read(4, e.cross); } break;
        case 0xB9: /* LDA abs,Y */ { auto e = ea_absy(pc); cpu.a = rd(e.addr); set_zn_flags(cpu.a); add_read(4, e.cross); } break;
        case 0xB1: /* LDA (ind),Y */ { auto e = ea_indy(pc); cpu.a = rd(e.addr); set_zn_flags(cpu.a); add_read(5, e.cross); } break;
        case 0xBE: /* LDX abs,Y */ { auto e = ea_absy(pc); cpu.x = rd(e.addr); set_zn_flags(cpu.x); add_read(4, e.cross); } break;
        case 0xBC: /* LDY abs,X */ { auto e = ea_absx(pc); cpu.y = rd(e.addr); set_zn_flags(cpu.y); add_read(4, e.cross); } break;


        case 0xB5: // LDA zero page,X
        {
            uint8_t zp = (cpu.memory[pc++] + cpu.x) & 0xFF;
            cpu.a = cpu.memory[zp];
            if (cpu.trackingEnabled) {
                cpu.memoryAccess[zp] |= MEM_READ;
            }
            set_zn_flags(cpu.a);
            cpu.cycles += 4;
        }
        break;

        case 0xA1: // LDA (indirect,X)
        {
            uint8_t zp = (cpu.memory[pc++] + cpu.x) & 0xFF;
            uint16_t addr = cpu.memory[zp] | (cpu.memory[(zp + 1) & 0xFF] << 8);
            cpu.a = cpu.memory[addr];
            if (cpu.trackingEnabled) {
                cpu.memoryAccess[addr] |= MEM_READ;
            }
            set_zn_flags(cpu.a);
            cpu.cycles += 6;
        }
        break;

        // STA
        case 0x85: // STA zero page
        {
            uint8_t zp = cpu.memory[pc++];
            write_memory_internal(zp, cpu.a);
            cpu.cycles += 3;
        }
        break;

        case 0x8D: // STA absolute
        {
            uint16_t addr = read_word(pc);
            write_memory_internal(addr, cpu.a);
            cpu.cycles += 4;
        }
        break;

        case 0x9D: // STA absolute,X
        {
            uint16_t addr = read_word(pc) + cpu.x;
            write_memory_internal(addr, cpu.a);
            cpu.cycles += 5;
        }
        break;

        case 0x99: // STA absolute,Y
        {
            uint16_t addr = read_word(pc) + cpu.y;
            write_memory_internal(addr, cpu.a);
            cpu.cycles += 5;
        }
        break;

        case 0x95: // STA zero page,X
        {
            uint8_t zp = (cpu.memory[pc++] + cpu.x) & 0xFF;
            write_memory_internal(zp, cpu.a);
            cpu.cycles += 4;
        }
        break;

        case 0x81: // STA (indirect,X)
        {
            uint8_t zp = (cpu.memory[pc++] + cpu.x) & 0xFF;
            uint16_t addr = cpu.memory[zp] | (cpu.memory[(zp + 1) & 0xFF] << 8);
            write_memory_internal(addr, cpu.a);
            cpu.cycles += 6;
        }
        break;

        case 0x91: // STA (indirect),Y
        {
            uint8_t zp = cpu.memory[pc++];
            uint16_t addr = (cpu.memory[zp] | (cpu.memory[(zp + 1) & 0xFF] << 8)) + cpu.y;
            write_memory_internal(addr, cpu.a);
            cpu.cycles += 6;
        }
        break;

        // STX
        case 0x86: // STX zero page
        {
            uint8_t zp = cpu.memory[pc++];
            write_memory_internal(zp, cpu.x);
            cpu.cycles += 3;
        }
        break;

        case 0x8E: // STX absolute
        {
            uint16_t addr = read_word(pc);
            write_memory_internal(addr, cpu.x);
            cpu.cycles += 4;
        }
        break;

        case 0x96: // STX zero page,Y
        {
            uint8_t zp = (cpu.memory[pc++] + cpu.y) & 0xFF;
            write_memory_internal(zp, cpu.x);
            cpu.cycles += 4;
        }
        break;

        // STY
        case 0x84: // STY zero page
        {
            uint8_t zp = cpu.memory[pc++];
            write_memory_internal(zp, cpu.y);
            cpu.cycles += 3;
        }
        break;

        case 0x8C: // STY absolute
        {
            uint16_t addr = read_word(pc);
            write_memory_internal(addr, cpu.y);
            cpu.cycles += 4;
        }
        break;

        case 0x94: // STY zero page,X
        {
            uint8_t zp = (cpu.memory[pc++] + cpu.x) & 0xFF;
            write_memory_internal(zp, cpu.y);
            cpu.cycles += 4;
        }
        break;

        // LDX
        case 0xA2: // LDX immediate
            cpu.x = cpu.memory[pc++];
            set_zn_flags(cpu.x);
            cpu.cycles += 2;
            break;

        case 0xA6: // LDX zero page
        {
            uint8_t zp = cpu.memory[pc++];
            cpu.x = cpu.memory[zp];
            if (cpu.trackingEnabled) {
                cpu.memoryAccess[zp] |= MEM_READ;
            }
            set_zn_flags(cpu.x);
            cpu.cycles += 3;
        }
        break;

        case 0xAE: // LDX absolute
        {
            uint16_t addr = read_word(pc);
            cpu.x = cpu.memory[addr];
            if (cpu.trackingEnabled) {
                cpu.memoryAccess[addr] |= MEM_READ;
            }
            set_zn_flags(cpu.x);
            cpu.cycles += 4;
        }
        break;

        case 0xB6: // LDX zero page,Y
        {
            uint8_t zp = (cpu.memory[pc++] + cpu.y) & 0xFF;
            cpu.x = cpu.memory[zp];
            if (cpu.trackingEnabled) {
                cpu.memoryAccess[zp] |= MEM_READ;
            }
            set_zn_flags(cpu.x);
            cpu.cycles += 4;
        }
        break;

        // LDY
        case 0xA0: // LDY immediate
            cpu.y = cpu.memory[pc++];
            set_zn_flags(cpu.y);
            cpu.cycles += 2;
            break;

        case 0xA4: // LDY zero page
        {
            uint8_t zp = cpu.memory[pc++];
            cpu.y = cpu.memory[zp];
            if (cpu.trackingEnabled) {
                cpu.memoryAccess[zp] |= MEM_READ;
            }
            set_zn_flags(cpu.y);
            cpu.cycles += 3;
        }
        break;

        case 0xAC: // LDY absolute
        {
            uint16_t addr = read_word(pc);
            cpu.y = cpu.memory[addr];
            if (cpu.trackingEnabled) {
                cpu.memoryAccess[addr] |= MEM_READ;
            }
            set_zn_flags(cpu.y);
            cpu.cycles += 4;
        }
        break;

        case 0xB4: // LDY zero page,X
        {
            uint8_t zp = (cpu.memory[pc++] + cpu.x) & 0xFF;
            cpu.y = cpu.memory[zp];
            if (cpu.trackingEnabled) {
                cpu.memoryAccess[zp] |= MEM_READ;
            }
            set_zn_flags(cpu.y);
            cpu.cycles += 4;
        }
        break;

        // Transfer instructions
        case 0xAA: // TAX
            cpu.x = cpu.a;
            set_zn_flags(cpu.x);
            cpu.cycles += 2;
            break;

        case 0xA8: // TAY
            cpu.y = cpu.a;
            set_zn_flags(cpu.y);
            cpu.cycles += 2;
            break;

        case 0x8A: // TXA
            cpu.a = cpu.x;
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
            break;

        case 0x98: // TYA
            cpu.a = cpu.y;
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
            break;

        case 0xBA: // TSX
            cpu.x = cpu.sp;
            set_zn_flags(cpu.x);
            cpu.cycles += 2;
            break;

        case 0x9A: // TXS
            cpu.sp = cpu.x;
            cpu.cycles += 2;
            break;

            // INC/DEC memory
        case 0xE6: // INC zero page
        {
            uint8_t zp = cpu.memory[pc++];
            uint8_t val = cpu.memory[zp] + 1;
            write_memory_internal(zp, val);
            set_zn_flags(val);
            cpu.cycles += 5;
        }
        break;

        case 0xEE: // INC absolute
        {
            uint16_t addr = read_word(pc);
            uint8_t val = cpu.memory[addr] + 1;
            write_memory_internal(addr, val);
            set_zn_flags(val);
            cpu.cycles += 6;
        }
        break;

        case 0xF6: // INC zero page,X
        {
            uint8_t zp = (cpu.memory[pc++] + cpu.x) & 0xFF;
            uint8_t val = cpu.memory[zp] + 1;
            write_memory_internal(zp, val);
            set_zn_flags(val);
            cpu.cycles += 6;
        }
        break;

        case 0xFE: // INC absolute,X
        {
            uint16_t addr = read_word(pc) + cpu.x;
            uint8_t val = cpu.memory[addr] + 1;
            write_memory_internal(addr, val);
            set_zn_flags(val);
            cpu.cycles += 7;
        }
        break;

        case 0xC6: // DEC zero page
        {
            uint8_t zp = cpu.memory[pc++];
            uint8_t val = cpu.memory[zp] - 1;
            write_memory_internal(zp, val);
            set_zn_flags(val);
            cpu.cycles += 5;
        }
        break;

        case 0xCE: // DEC absolute
        {
            uint16_t addr = read_word(pc);
            uint8_t val = cpu.memory[addr] - 1;
            write_memory_internal(addr, val);
            set_zn_flags(val);
            cpu.cycles += 6;
        }
        break;

        case 0xD6: // DEC zero page,X
        {
            uint8_t zp = (cpu.memory[pc++] + cpu.x) & 0xFF;
            uint8_t val = cpu.memory[zp] - 1;
            write_memory_internal(zp, val);
            set_zn_flags(val);
            cpu.cycles += 6;
        }
        break;

        case 0xDE: // DEC absolute,X
        {
            uint16_t addr = read_word(pc) + cpu.x;
            uint8_t val = cpu.memory[addr] - 1;
            write_memory_internal(addr, val);
            set_zn_flags(val);
            cpu.cycles += 7;
        }
        break;

        // JSR
        case 0x20: // JSR absolute
        {
            uint16_t addr = read_word(pc);
            push((pc - 1) >> 8);
            push((pc - 1) & 0xFF);
            pc = addr;
            if (cpu.trackingEnabled) {
                cpu.memoryAccess[addr] |= MEM_JUMP_TARGET;
            }
            cpu.cycles += 6;
        }
        break;

        // RTS
        case 0x60: // RTS
        {
            uint16_t addr = pop() | (pop() << 8);
            pc = addr + 1;
            cpu.cycles += 6;
        }
        break;

        // JMP
        case 0x4C: // JMP absolute
        {
            uint16_t addr = read_word(pc);
            pc = addr;
            if (cpu.trackingEnabled) {
                cpu.memoryAccess[addr] |= MEM_JUMP_TARGET;
            }
            cpu.cycles += 3;
        }
        break;

        case 0x6C: // JMP indirect
        {
            uint16_t ptr = read_word(pc);
            // Handle 6502 page boundary bug
            uint16_t addr;
            if ((ptr & 0xFF) == 0xFF) {
                addr = cpu.memory[ptr] | (cpu.memory[ptr & 0xFF00] << 8);
            }
            else {
                addr = cpu.memory[ptr] | (cpu.memory[ptr + 1] << 8);
            }
            pc = addr;
            if (cpu.trackingEnabled) {
                cpu.memoryAccess[addr] |= MEM_JUMP_TARGET;
            }
            cpu.cycles += 5;
        }
        break;

        case 0xF0: /* BEQ */ { branch_if(test_flag(FLAG_ZERO), pc); } break;
        case 0xD0: /* BNE */ { branch_if(!test_flag(FLAG_ZERO), pc); } break;
        case 0xB0: /* BCS */ { branch_if(test_flag(FLAG_CARRY), pc); } break;
        case 0x90: /* BCC */ { branch_if(!test_flag(FLAG_CARRY), pc); } break;
        case 0x30: /* BMI */ { branch_if(test_flag(FLAG_NEGATIVE), pc); } break;
        case 0x10: /* BPL */ { branch_if(!test_flag(FLAG_NEGATIVE), pc); } break;
        case 0x50: /* BVC */ { branch_if(!test_flag(FLAG_OVERFLOW), pc); } break;
        case 0x70: /* BVS */ { branch_if(test_flag(FLAG_OVERFLOW), pc); } break;


        // INC/DEC registers
        case 0xE8: // INX
            cpu.x++;
            set_zn_flags(cpu.x);
            cpu.cycles += 2;
            break;

        case 0xC8: // INY
            cpu.y++;
            set_zn_flags(cpu.y);
            cpu.cycles += 2;
            break;

        case 0xCA: // DEX
            cpu.x--;
            set_zn_flags(cpu.x);
            cpu.cycles += 2;
            break;

        case 0x88: // DEY
            cpu.y--;
            set_zn_flags(cpu.y);
            cpu.cycles += 2;
            break;

            // CMP
        case 0xC9: // CMP immediate
        {
            uint8_t value = cpu.memory[pc++];
            uint8_t result = cpu.a - value;
            set_flag(FLAG_CARRY, cpu.a >= value);
            set_zn_flags(result);
            cpu.cycles += 2;
        }
        break;

        case 0xC5: // CMP zero page
        {
            uint8_t zp = cpu.memory[pc++];
            uint8_t value = cpu.memory[zp];
            uint8_t result = cpu.a - value;
            set_flag(FLAG_CARRY, cpu.a >= value);
            set_zn_flags(result);
            cpu.cycles += 3;
        }
        break;

        case 0xCD: // CMP absolute
        {
            uint16_t addr = read_word(pc);
            uint8_t value = cpu.memory[addr];
            uint8_t result = cpu.a - value;
            set_flag(FLAG_CARRY, cpu.a >= value);
            set_zn_flags(result);
            cpu.cycles += 4;
        }
        break;

        // CPX
        case 0xE0: // CPX immediate
        {
            uint8_t value = cpu.memory[pc++];
            uint8_t result = cpu.x - value;
            set_flag(FLAG_CARRY, cpu.x >= value);
            set_zn_flags(result);
            cpu.cycles += 2;
        }
        break;

        case 0xE4: // CPX zero page
        {
            uint8_t zp = cpu.memory[pc++];
            uint8_t value = cpu.memory[zp];
            uint8_t result = cpu.x - value;
            set_flag(FLAG_CARRY, cpu.x >= value);
            set_zn_flags(result);
            cpu.cycles += 3;
        }
        break;

        // CPY
        case 0xC0: // CPY immediate
        {
            uint8_t value = cpu.memory[pc++];
            uint8_t result = cpu.y - value;
            set_flag(FLAG_CARRY, cpu.y >= value);
            set_zn_flags(result);
            cpu.cycles += 2;
        }
        break;

        case 0xC4: // CPY zero page
        {
            uint8_t zp = cpu.memory[pc++];
            uint8_t value = cpu.memory[zp];
            uint8_t result = cpu.y - value;
            set_flag(FLAG_CARRY, cpu.y >= value);
            set_zn_flags(result);
            cpu.cycles += 3;
        }
        break;

        // Logical operations
        case 0x29: // AND immediate
            cpu.a &= cpu.memory[pc++];
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
            break;

        case 0x25: // AND zero page
        {
            uint8_t zp = cpu.memory[pc++];
            cpu.a &= cpu.memory[zp];
            set_zn_flags(cpu.a);
            cpu.cycles += 3;
        }
        break;

        case 0x09: // ORA immediate
            cpu.a |= cpu.memory[pc++];
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
            break;

        case 0x05: // ORA zero page
        {
            uint8_t zp = cpu.memory[pc++];
            cpu.a |= cpu.memory[zp];
            set_zn_flags(cpu.a);
            cpu.cycles += 3;
        }
        break;

        case 0x49: // EOR immediate
            cpu.a ^= cpu.memory[pc++];
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
            break;

        case 0x45: // EOR zero page
        {
            uint8_t zp = cpu.memory[pc++];
            cpu.a ^= cpu.memory[zp];
            set_zn_flags(cpu.a);
            cpu.cycles += 3;
        }
        break;

        // BIT
        case 0x24: // BIT zero page
        {
            uint8_t zp = cpu.memory[pc++];
            uint8_t value = cpu.memory[zp];
            set_flag(FLAG_ZERO, (cpu.a & value) == 0);
            set_flag(FLAG_NEGATIVE, value & 0x80);
            set_flag(FLAG_OVERFLOW, value & 0x40);
            cpu.cycles += 3;
        }
        break;

        case 0x2C: // BIT absolute
        {
            uint16_t addr = read_word(pc);
            uint8_t value = cpu.memory[addr];
            set_flag(FLAG_ZERO, (cpu.a & value) == 0);
            set_flag(FLAG_NEGATIVE, value & 0x80);
            set_flag(FLAG_OVERFLOW, value & 0x40);
            cpu.cycles += 4;
        }
        break;

        // Arithmetic
        case 0x69: // ADC immediate
        {
            uint8_t value = cpu.memory[pc++];
            uint16_t result = cpu.a + value + (test_flag(FLAG_CARRY) ? 1 : 0);
            set_flag(FLAG_CARRY, result > 0xFF);
            set_flag(FLAG_OVERFLOW, ((cpu.a ^ result) & (value ^ result) & 0x80) != 0);
            cpu.a = result & 0xFF;
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
        }
        break;

        case 0x65: // ADC zero page
        {
            uint8_t zp = cpu.memory[pc++];
            uint8_t value = cpu.memory[zp];
            uint16_t result = cpu.a + value + (test_flag(FLAG_CARRY) ? 1 : 0);
            set_flag(FLAG_CARRY, result > 0xFF);
            set_flag(FLAG_OVERFLOW, ((cpu.a ^ result) & (value ^ result) & 0x80) != 0);
            cpu.a = result & 0xFF;
            set_zn_flags(cpu.a);
            cpu.cycles += 3;
        }
        break;

        case 0xE9: // SBC immediate
        {
            uint8_t value = cpu.memory[pc++];
            uint16_t result = cpu.a - value - (test_flag(FLAG_CARRY) ? 0 : 1);
            set_flag(FLAG_CARRY, result < 0x100);
            set_flag(FLAG_OVERFLOW, ((cpu.a ^ result) & (~value ^ result) & 0x80) != 0);
            cpu.a = result & 0xFF;
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
        }
        break;

        case 0xE5: // SBC zero page
        {
            uint8_t zp = cpu.memory[pc++];
            uint8_t value = cpu.memory[zp];
            uint16_t result = cpu.a - value - (test_flag(FLAG_CARRY) ? 0 : 1);
            set_flag(FLAG_CARRY, result < 0x100);
            set_flag(FLAG_OVERFLOW, ((cpu.a ^ result) & (~value ^ result) & 0x80) != 0);
            cpu.a = result & 0xFF;
            set_zn_flags(cpu.a);
            cpu.cycles += 3;
        }
        break;

        // Shifts
        case 0x0A: // ASL A
            set_flag(FLAG_CARRY, cpu.a & 0x80);
            cpu.a <<= 1;
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
            break;

        case 0x06: // ASL zero page
        {
            uint8_t zp = cpu.memory[pc++];
            uint8_t value = cpu.memory[zp];
            set_flag(FLAG_CARRY, value & 0x80);
            value <<= 1;
            write_memory_internal(zp, value);
            set_zn_flags(value);
            cpu.cycles += 5;
        }
        break;

        case 0x4A: // LSR A
            set_flag(FLAG_CARRY, cpu.a & 0x01);
            cpu.a >>= 1;
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
            break;

        case 0x46: // LSR zero page
        {
            uint8_t zp = cpu.memory[pc++];
            uint8_t value = cpu.memory[zp];
            set_flag(FLAG_CARRY, value & 0x01);
            value >>= 1;
            write_memory_internal(zp, value);
            set_zn_flags(value);
            cpu.cycles += 5;
        }
        break;

        case 0x2A: // ROL A
        {
            bool old_carry = test_flag(FLAG_CARRY);
            set_flag(FLAG_CARRY, cpu.a & 0x80);
            cpu.a = (cpu.a << 1) | (old_carry ? 1 : 0);
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
        }
        break;

        case 0x26: // ROL zero page
        {
            uint8_t zp = cpu.memory[pc++];
            uint8_t value = cpu.memory[zp];
            bool old_carry = test_flag(FLAG_CARRY);
            set_flag(FLAG_CARRY, value & 0x80);
            value = (value << 1) | (old_carry ? 1 : 0);
            write_memory_internal(zp, value);
            set_zn_flags(value);
            cpu.cycles += 5;
        }
        break;

        case 0x6A: // ROR A
        {
            bool old_carry = test_flag(FLAG_CARRY);
            set_flag(FLAG_CARRY, cpu.a & 0x01);
            cpu.a = (cpu.a >> 1) | (old_carry ? 0x80 : 0);
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
        }
        break;

        case 0x66: // ROR zero page
        {
            uint8_t zp = cpu.memory[pc++];
            uint8_t value = cpu.memory[zp];
            bool old_carry = test_flag(FLAG_CARRY);
            set_flag(FLAG_CARRY, value & 0x01);
            value = (value >> 1) | (old_carry ? 0x80 : 0);
            write_memory_internal(zp, value);
            set_zn_flags(value);
            cpu.cycles += 5;
        }
        break;

        // Flags
        case 0x18: // CLC
            set_flag(FLAG_CARRY, false);
            cpu.cycles += 2;
            break;

        case 0x38: // SEC
            set_flag(FLAG_CARRY, true);
            cpu.cycles += 2;
            break;

        case 0xD8: // CLD
            set_flag(FLAG_DECIMAL, false);
            cpu.cycles += 2;
            break;

        case 0xF8: // SED
            set_flag(FLAG_DECIMAL, true);
            cpu.cycles += 2;
            break;

        case 0x78: // SEI
            set_flag(FLAG_INTERRUPT, true);
            cpu.cycles += 2;
            break;

        case 0x58: // CLI
            set_flag(FLAG_INTERRUPT, false);
            cpu.cycles += 2;
            break;

        case 0xB8: // CLV
            set_flag(FLAG_OVERFLOW, false);
            cpu.cycles += 2;
            break;

            // Stack
        case 0x48: // PHA
            push(cpu.a);
            cpu.cycles += 3;
            break;

        case 0x68: // PLA
            cpu.a = pop();
            set_zn_flags(cpu.a);
            cpu.cycles += 4;
            break;

        case 0x08: // PHP
            push(cpu.status | FLAG_BREAK | FLAG_UNUSED);
            cpu.cycles += 3;
            break;

        case 0x28: // PLP
            cpu.status = pop();
            cpu.cycles += 4;
            break;

            // NOP
        case 0xEA: // NOP
            cpu.cycles += 2;
            break;

            // BRK
        case 0x00: // BRK
            pc++;
            push(pc >> 8);
            push(pc & 0xFF);
            push(cpu.status | FLAG_BREAK);
            set_flag(FLAG_INTERRUPT, true);
            pc = cpu.memory[0xFFFE] | (cpu.memory[0xFFFF] << 8);
            cpu.cycles += 7;
            break;

            // RTI
        case 0x40: // RTI
            cpu.status = pop();
            pc = pop() | (pop() << 8);
            cpu.cycles += 6;
            break;

        //; AND
        case 0x2D: { auto e = ea_abs(pc);  cpu.a &= rd(e.addr); set_zn_flags(cpu.a); add(4); } break;
        case 0x3D: { auto e = ea_absx(pc); cpu.a &= rd(e.addr); set_zn_flags(cpu.a); add_read(4, e.cross); } break;
        case 0x39: { auto e = ea_absy(pc); cpu.a &= rd(e.addr); set_zn_flags(cpu.a); add_read(4, e.cross); } break;
        case 0x35: { auto e = ea_zpx(pc);  cpu.a &= rd(e.addr); set_zn_flags(cpu.a); add(4); } break;
        case 0x21: { auto e = ea_indx(pc); cpu.a &= rd(e.addr); set_zn_flags(cpu.a); add(6); } break;
        case 0x31: { auto e = ea_indy(pc); cpu.a &= rd(e.addr); set_zn_flags(cpu.a); add_read(5, e.cross); } break;

        //; ORA
        case 0x0D: { auto e = ea_abs(pc);  cpu.a |= rd(e.addr); set_zn_flags(cpu.a); add(4); } break;
        case 0x1D: { auto e = ea_absx(pc); cpu.a |= rd(e.addr); set_zn_flags(cpu.a); add_read(4, e.cross); } break;
        case 0x19: { auto e = ea_absy(pc); cpu.a |= rd(e.addr); set_zn_flags(cpu.a); add_read(4, e.cross); } break;
        case 0x15: { auto e = ea_zpx(pc);  cpu.a |= rd(e.addr); set_zn_flags(cpu.a); add(4); } break;
        case 0x01: { auto e = ea_indx(pc); cpu.a |= rd(e.addr); set_zn_flags(cpu.a); add(6); } break;
        case 0x11: { auto e = ea_indy(pc); cpu.a |= rd(e.addr); set_zn_flags(cpu.a); add_read(5, e.cross); } break;

        //; EOR
        case 0x4D: { auto e = ea_abs(pc);  cpu.a ^= rd(e.addr); set_zn_flags(cpu.a); add(4); } break;
        case 0x5D: { auto e = ea_absx(pc); cpu.a ^= rd(e.addr); set_zn_flags(cpu.a); add_read(4, e.cross); } break;
        case 0x59: { auto e = ea_absy(pc); cpu.a ^= rd(e.addr); set_zn_flags(cpu.a); add_read(4, e.cross); } break;
        case 0x55: { auto e = ea_zpx(pc);  cpu.a ^= rd(e.addr); set_zn_flags(cpu.a); add(4); } break;
        case 0x41: { auto e = ea_indx(pc); cpu.a ^= rd(e.addr); set_zn_flags(cpu.a); add(6); } break;
        case 0x51: { auto e = ea_indy(pc); cpu.a ^= rd(e.addr); set_zn_flags(cpu.a); add_read(5, e.cross); } break;

		//; ADC
        case 0x6D: { auto e = ea_abs(pc);  do_adc(rd(e.addr)); add(4); } break;
        case 0x7D: { auto e = ea_absx(pc); do_adc(rd(e.addr)); add_read(4, e.cross); } break;
        case 0x79: { auto e = ea_absy(pc); do_adc(rd(e.addr)); add_read(4, e.cross); } break;
        case 0x75: { auto e = ea_zpx(pc);  do_adc(rd(e.addr)); add(4); } break;
        case 0x61: { auto e = ea_indx(pc); do_adc(rd(e.addr)); add(6); } break;
        case 0x71: { auto e = ea_indy(pc); do_adc(rd(e.addr)); add_read(5, e.cross); } break;

        //; SBC
        case 0xED: { auto e = ea_abs(pc);  do_sbc(rd(e.addr)); add(4); } break;
        case 0xFD: { auto e = ea_absx(pc); do_sbc(rd(e.addr)); add_read(4, e.cross); } break;
        case 0xF9: { auto e = ea_absy(pc); do_sbc(rd(e.addr)); add_read(4, e.cross); } break;
        case 0xF5: { auto e = ea_zpx(pc);  do_sbc(rd(e.addr)); add(4); } break;
        case 0xE1: { auto e = ea_indx(pc); do_sbc(rd(e.addr)); add(6); } break;
        case 0xF1: { auto e = ea_indy(pc); do_sbc(rd(e.addr)); add_read(5, e.cross); } break;

        // CMP
        case 0xD5: { auto e = ea_zpx(pc);  do_cmp(cpu.a, rd(e.addr)); add(4); } break; // zp,X
        case 0xDD: { auto e = ea_absx(pc); do_cmp(cpu.a, rd(e.addr)); add_read(4, e.cross); } break; // abs,X
        case 0xD9: { auto e = ea_absy(pc); do_cmp(cpu.a, rd(e.addr)); add_read(4, e.cross); } break; // abs,Y
        case 0xC1: { auto e = ea_indx(pc); do_cmp(cpu.a, rd(e.addr)); add(6); } break; // (ind,X)
        case 0xD1: { auto e = ea_indy(pc); do_cmp(cpu.a, rd(e.addr)); add_read(5, e.cross); } break; // (ind),Y
        case 0xEC: { auto e = ea_abs(pc); do_cmp(cpu.x, rd(e.addr)); add(4); } break;
        case 0xCC: { auto e = ea_abs(pc); do_cmp(cpu.y, rd(e.addr)); add(4); } break;

        // ASL
        case 0x0E: { auto e = ea_abs(pc);  do_asl_mem(e.addr); add(6); } break;
        case 0x1E: { auto e = ea_absx(pc); do_asl_mem(e.addr); add(7); } break;
        case 0x16: { auto e = ea_zpx(pc);  do_asl_mem(e.addr); add(6); } break;

        // LSR
        case 0x4E: { auto e = ea_abs(pc);  do_lsr_mem(e.addr); add(6); } break;
        case 0x5E: { auto e = ea_absx(pc); do_lsr_mem(e.addr); add(7); } break;
        case 0x56: { auto e = ea_zpx(pc);  do_lsr_mem(e.addr); add(6); } break;

        // ROL
        case 0x2E: { auto e = ea_abs(pc);  do_rol_mem(e.addr); add(6); } break;
        case 0x3E: { auto e = ea_absx(pc); do_rol_mem(e.addr); add(7); } break;
        case 0x36: { auto e = ea_zpx(pc);  do_rol_mem(e.addr); add(6); } break;

        // ROR
        case 0x6E: { auto e = ea_abs(pc);  do_ror_mem(e.addr); add(6); } break;
        case 0x7E: { auto e = ea_absx(pc); do_ror_mem(e.addr); add(7); } break;
        case 0x76: { auto e = ea_zpx(pc);  do_ror_mem(e.addr); add(6); } break;

            // LAX (A,X) loads
        case 0xA7: { auto e = ea_zp(pc);  do_lax(rd(e.addr)); add(3); } break;
        case 0xB7: { auto e = ea_zpy(pc); do_lax(rd(e.addr)); add(4); } break;
        case 0xAF: { auto e = ea_abs(pc); do_lax(rd(e.addr)); add(4); } break;
        case 0xBF: { auto e = ea_absy(pc); do_lax(rd(e.addr)); add_read(4, e.cross); } break;
        case 0xA3: { auto e = ea_indx(pc); do_lax(rd(e.addr)); add(6); } break;
        case 0xB3: { auto e = ea_indy(pc); do_lax(rd(e.addr)); add_read(5, e.cross); } break;

            // SAX (store A&X)
        case 0x87: { auto e = ea_zp(pc);  write_memory_internal(e.addr, cpu.a & cpu.x); add(3); } break;
        case 0x97: { auto e = ea_zpy(pc); write_memory_internal(e.addr, cpu.a & cpu.x); add(4); } break;
        case 0x8F: { auto e = ea_abs(pc); write_memory_internal(e.addr, cpu.a & cpu.x); add(4); } break;
        case 0x83: { auto e = ea_indx(pc); write_memory_internal(e.addr, cpu.a & cpu.x); add(6); } break;

            // DCP (DEC + CMP)
        case 0xC7: { auto e = ea_zp(pc);  uint8_t v = rd(e.addr) - 1; write_memory_internal(e.addr, v); do_cmp(cpu.a, v); add(5); } break;
        case 0xD7: { auto e = ea_zpx(pc); uint8_t v = rd(e.addr) - 1; write_memory_internal(e.addr, v); do_cmp(cpu.a, v); add(6); } break;
        case 0xCF: { auto e = ea_abs(pc); uint8_t v = rd(e.addr) - 1; write_memory_internal(e.addr, v); do_cmp(cpu.a, v); add(6); } break;
        case 0xDF: { auto e = ea_absx(pc); uint8_t v = rd(e.addr) - 1; write_memory_internal(e.addr, v); do_cmp(cpu.a, v); add(7); } break;
        case 0xDB: { auto e = ea_absy(pc); uint8_t v = rd(e.addr) - 1; write_memory_internal(e.addr, v); do_cmp(cpu.a, v); add(7); } break;
        case 0xC3: { auto e = ea_indx(pc); uint8_t v = rd(e.addr) - 1; write_memory_internal(e.addr, v); do_cmp(cpu.a, v); add(8); } break;
        case 0xD3: { auto e = ea_indy(pc); uint8_t v = rd(e.addr) - 1; write_memory_internal(e.addr, v); do_cmp(cpu.a, v); add(8); } break;

            // ISC/ISB (INC + SBC)
        case 0xE7: { auto e = ea_zp(pc);  uint8_t v = rd(e.addr) + 1; write_memory_internal(e.addr, v); do_sbc(v); add(5); } break;
        case 0xF7: { auto e = ea_zpx(pc); uint8_t v = rd(e.addr) + 1; write_memory_internal(e.addr, v); do_sbc(v); add(6); } break;
        case 0xEF: { auto e = ea_abs(pc); uint8_t v = rd(e.addr) + 1; write_memory_internal(e.addr, v); do_sbc(v); add(6); } break;
        case 0xFF: { auto e = ea_absx(pc); uint8_t v = rd(e.addr) + 1; write_memory_internal(e.addr, v); do_sbc(v); add(7); } break;
        case 0xFB: { auto e = ea_absy(pc); uint8_t v = rd(e.addr) + 1; write_memory_internal(e.addr, v); do_sbc(v); add(7); } break;
        case 0xE3: { auto e = ea_indx(pc); uint8_t v = rd(e.addr) + 1; write_memory_internal(e.addr, v); do_sbc(v); add(8); } break;
        case 0xF3: { auto e = ea_indy(pc); uint8_t v = rd(e.addr) + 1; write_memory_internal(e.addr, v); do_sbc(v); add(8); } break;

        // SLO (ASL + ORA)
        case 0x07: { auto e = ea_zp(pc);  uint8_t v = rd(e.addr); set_flag(FLAG_CARRY, v & 0x80); v <<= 1; write_memory_internal(e.addr, v); cpu.a |= v; set_zn_flags(cpu.a); add(5); } break;
            // ... similarly: 0x17,0x0F,0x1F,0x1B,0x03,0x13

        // RLA (ROL + AND)
        case 0x27: { auto e = ea_zp(pc);  uint8_t v = rd(e.addr); bool c = test_flag(FLAG_CARRY); set_flag(FLAG_CARRY, v & 0x80); v = (v << 1) | (c ? 1 : 0); write_memory_internal(e.addr, v); cpu.a &= v; set_zn_flags(cpu.a); add(5); } break;
            // ... similarly: 0x37,0x2F,0x3F,0x3B,0x23,0x33

        // SRE (LSR + EOR)
        case 0x47: { auto e = ea_zp(pc);  uint8_t v = rd(e.addr); set_flag(FLAG_CARRY, v & 1); v >>= 1; write_memory_internal(e.addr, v); cpu.a ^= v; set_zn_flags(cpu.a); add(5); } break;
            // ... similarly: 0x57,0x4F,0x5F,0x5B,0x43,0x53

        // RRA (ROR + ADC)
        case 0x67: { auto e = ea_zp(pc);  uint8_t v = rd(e.addr); bool c = test_flag(FLAG_CARRY); set_flag(FLAG_CARRY, v & 1); v = (v >> 1) | (c ? 0x80 : 0); write_memory_internal(e.addr, v); do_adc(v); add(5); } break;
            // ... similarly: 0x77,0x6F,0x7F,0x7B,0x63,0x73

        // ANC (AND #imm; C = bit7)
        case 0x0B: case 0x2B: { uint8_t v = cpu.memory[pc++]; cpu.a &= v; set_zn_flags(cpu.a); set_flag(FLAG_CARRY, cpu.a & 0x80); add(2); } break;
        
        // ALR (AND #imm then LSR A)
        case 0x4B: { uint8_t v = cpu.memory[pc++]; cpu.a &= v; set_flag(FLAG_CARRY, cpu.a & 1); cpu.a >>= 1; set_zn_flags(cpu.a); add(2); } break;
        
        // ARR (AND #imm then ROR A) – simplified flags
        case 0x6B: { uint8_t v = cpu.memory[pc++]; uint8_t t = cpu.a & v; bool c = test_flag(FLAG_CARRY); cpu.a = (t >> 1) | (c ? 0x80 : 0); set_zn_flags(cpu.a); set_flag(FLAG_CARRY, (cpu.a & 0x40) != 0); set_flag(FLAG_OVERFLOW, ((cpu.a ^ (cpu.a << 1)) & 0x40) != 0); add(2); } break;

        // AXS/SBX (X=(A&X)-imm)
        case 0xCB: { uint8_t i = cpu.memory[pc++]; uint8_t t = (cpu.a & cpu.x); uint16_t r = uint16_t(t) - i; set_flag(FLAG_CARRY, r < 0x100); cpu.x = uint8_t(r); set_zn_flags(cpu.x); add(2); } break;

        // KIL/JAM (halt): keep CPU on this opcode
        case 0x02: case 0x12: case 0x22: case 0x32: case 0x42: case 0x52:
        case 0x62: case 0x72: case 0x92: case 0xB2: case 0xD2: case 0xF2:
        { pc--; add(2); } break;

        default:
            // For unimplemented opcodes, try to guess the size from the opcode table
            if (opcodeTable[opcode].size > 0) {
                pc += opcodeTable[opcode].size - 1;
                cpu.cycles += opcodeTable[opcode].cycles;
            }
            else {
                // Unknown opcode - just advance
                cpu.cycles += 2;
            }
            break;
        }

        cpu.pc = pc;
    }

    // Execute a function (until RTS)
    EMSCRIPTEN_KEEPALIVE
        int cpu_execute_function(uint16_t address, uint32_t maxCycles) {
        // Save return address
        uint16_t returnAddr = cpu.pc - 1;
        push(returnAddr >> 8);
        push(returnAddr & 0xFF);

        cpu.pc = address;
        uint64_t startCycles = cpu.cycles;
        uint8_t startSP = cpu.sp + 2;  // Account for return address we just pushed

        while ((cpu.cycles - startCycles) < maxCycles) {
            uint8_t opcode = cpu.memory[cpu.pc];

            cpu_step();

            // Check if we hit RTS and stack is back to expected level
            if (opcode == 0x60 && cpu.sp == startSP) {
                return 1;  // Success
            }

            // Safety check for infinite loops
            if (cpu.pc < 2) {
                return 0;  // Error - jumped to invalid address
            }
        }

        return 0;  // Hit cycle limit
    }

    // Get CPU state
    EMSCRIPTEN_KEEPALIVE
        uint16_t cpu_get_pc() { return cpu.pc; }

    EMSCRIPTEN_KEEPALIVE
        void cpu_set_pc(uint16_t pc) { cpu.pc = pc; }

    EMSCRIPTEN_KEEPALIVE
        uint8_t cpu_get_sp() { return cpu.sp; }

    EMSCRIPTEN_KEEPALIVE
        uint8_t cpu_get_a() { return cpu.a; }

    EMSCRIPTEN_KEEPALIVE
        uint8_t cpu_get_x() { return cpu.x; }

    EMSCRIPTEN_KEEPALIVE
        uint8_t cpu_get_y() { return cpu.y; }

    EMSCRIPTEN_KEEPALIVE
        uint8_t cpu_get_cia_timer_lo() {
        return cpu.ciaTimerLo;
    }

    EMSCRIPTEN_KEEPALIVE
        uint8_t cpu_get_cia_timer_hi() {
        return cpu.ciaTimerHi;
    }

    EMSCRIPTEN_KEEPALIVE
        bool cpu_get_cia_timer_written() {
        return cpu.ciaTimerWritten;
    }

    EMSCRIPTEN_KEEPALIVE
        uint64_t cpu_get_cycles() { return cpu.cycles; }

    // Get memory access info
    EMSCRIPTEN_KEEPALIVE
        uint8_t cpu_get_memory_access(uint16_t address) {
        return cpu.memoryAccess[address];
    }

    // Get SID write statistics
    EMSCRIPTEN_KEEPALIVE
        uint32_t cpu_get_sid_writes(uint8_t reg) {
        if (reg < 32) {
            return cpu.sidWrites[reg];
        }
        return 0;
    }

    EMSCRIPTEN_KEEPALIVE
        uint32_t cpu_get_total_sid_writes() {
        return cpu.totalSidWrites;
    }

    // Get zero page write statistics
    EMSCRIPTEN_KEEPALIVE
        uint32_t cpu_get_zp_writes(uint8_t addr) {
        return cpu.zpWrites[addr];
    }

    EMSCRIPTEN_KEEPALIVE
        uint32_t cpu_get_total_zp_writes() {
        return cpu.totalZpWrites;
    }

    // Enable/disable write sequence recording
    EMSCRIPTEN_KEEPALIVE
        void cpu_set_record_writes(bool record) {
        cpu.recordWrites = record;
        if (record) {
            cpu.writeSequence.clear();
        }
    }

    // Get write sequence length
    EMSCRIPTEN_KEEPALIVE
        uint32_t cpu_get_write_sequence_length() {
        return cpu.writeSequence.size();
    }

    // Get write sequence item
    EMSCRIPTEN_KEEPALIVE
        uint16_t cpu_get_write_sequence_item(uint32_t index) {
        if (index < cpu.writeSequence.size()) {
            return cpu.writeSequence[index];
        }
        return 0;
    }

    // Analyze memory for code vs data
    EMSCRIPTEN_KEEPALIVE
        void cpu_analyze_memory(uint16_t startAddr, uint16_t endAddr, uint32_t* codeBytes, uint32_t* dataBytes) {
        *codeBytes = 0;
        *dataBytes = 0;

        for (uint32_t addr = startAddr; addr <= endAddr && addr < 65536; addr++) {
            if (cpu.memoryAccess[addr] & MEM_EXECUTE) {
                (*codeBytes)++;
            }
            else {
                (*dataBytes)++;
            }
        }
    }

    // Get last PC that wrote to an address
    EMSCRIPTEN_KEEPALIVE
        uint16_t cpu_get_last_write_pc(uint16_t address) {
        return cpu.lastWritePC[address];
    }

    // Memory allocation helpers for JavaScript
    EMSCRIPTEN_KEEPALIVE
        uint8_t* allocate_memory(size_t size) {
        return (uint8_t*)malloc(size);
    }

    EMSCRIPTEN_KEEPALIVE
        void free_memory(uint8_t* ptr) {
        free(ptr);
    }

    // Add this function to set the accumulator
    EMSCRIPTEN_KEEPALIVE
        void cpu_set_accumulator(uint8_t value) {
        cpu.a = value;
    }

} // extern "C"