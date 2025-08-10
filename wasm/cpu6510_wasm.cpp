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
        cpu.totalSidWrites = 0;
        cpu.totalZpWrites = 0;
        cpu.recordWrites = false;

        memset(cpu.memory, 0, sizeof(cpu.memory));
        memset(cpu.memoryAccess, 0, sizeof(cpu.memoryAccess));
        memset(cpu.sidWrites, 0, sizeof(cpu.sidWrites));
        memset(cpu.zpWrites, 0, sizeof(cpu.zpWrites));
        memset(cpu.lastWritePC, 0, sizeof(cpu.lastWritePC));

        cpu.writeSequence.clear();
    }

    // Load data into memory
    EMSCRIPTEN_KEEPALIVE
        void cpu_load_memory(uint16_t address, uint8_t* data, uint16_t size) {
        if (address + size <= 65536) {
            memcpy(&cpu.memory[address], data, size);
        }
    }

    // Read memory (for internal use and tracking)
    EMSCRIPTEN_KEEPALIVE
        uint8_t cpu_read_memory(uint16_t address) {
        cpu.memoryAccess[address] |= MEM_READ;
        return cpu.memory[address];
    }

    // Write memory with full tracking
    EMSCRIPTEN_KEEPALIVE
        void cpu_write_memory(uint16_t address, uint8_t value) {
        cpu.memory[address] = value;
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
    }

    // Internal memory write (used by instructions)
    void write_memory_internal(uint16_t address, uint8_t value) {
        cpu.memory[address] = value;
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

    // Execute one instruction
    EMSCRIPTEN_KEEPALIVE
        void cpu_step() {
        uint16_t pc = cpu.pc;
        uint8_t opcode = cpu.memory[pc++];
        cpu.memoryAccess[cpu.pc] |= MEM_EXECUTE | MEM_OPCODE;

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
            cpu.memoryAccess[zp] |= MEM_READ;
            set_zn_flags(cpu.a);
            cpu.cycles += 3;
        }
        break;

        case 0xAD: // LDA absolute
        {
            uint16_t addr = read_word(pc);
            cpu.a = cpu.memory[addr];
            cpu.memoryAccess[addr] |= MEM_READ;
            set_zn_flags(cpu.a);
            cpu.cycles += 4;
        }
        break;

        case 0xBD: // LDA absolute,X
        {
            uint16_t addr = read_word(pc) + cpu.x;
            cpu.a = cpu.memory[addr];
            cpu.memoryAccess[addr] |= MEM_READ;
            set_zn_flags(cpu.a);
            cpu.cycles += 4;
        }
        break;

        case 0xB9: // LDA absolute,Y
        {
            uint16_t addr = read_word(pc) + cpu.y;
            cpu.a = cpu.memory[addr];
            cpu.memoryAccess[addr] |= MEM_READ;
            set_zn_flags(cpu.a);
            cpu.cycles += 4;
        }
        break;

        case 0xB5: // LDA zero page,X
        {
            uint8_t zp = (cpu.memory[pc++] + cpu.x) & 0xFF;
            cpu.a = cpu.memory[zp];
            cpu.memoryAccess[zp] |= MEM_READ;
            set_zn_flags(cpu.a);
            cpu.cycles += 4;
        }
        break;

        case 0xA1: // LDA (indirect,X)
        {
            uint8_t zp = (cpu.memory[pc++] + cpu.x) & 0xFF;
            uint16_t addr = cpu.memory[zp] | (cpu.memory[(zp + 1) & 0xFF] << 8);
            cpu.a = cpu.memory[addr];
            cpu.memoryAccess[addr] |= MEM_READ;
            set_zn_flags(cpu.a);
            cpu.cycles += 6;
        }
        break;

        case 0xB1: // LDA (indirect),Y
        {
            uint8_t zp = cpu.memory[pc++];
            uint16_t addr = (cpu.memory[zp] | (cpu.memory[(zp + 1) & 0xFF] << 8)) + cpu.y;
            cpu.a = cpu.memory[addr];
            cpu.memoryAccess[addr] |= MEM_READ;
            set_zn_flags(cpu.a);
            cpu.cycles += 5;
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
            cpu.memoryAccess[zp] |= MEM_READ;
            set_zn_flags(cpu.x);
            cpu.cycles += 3;
        }
        break;

        case 0xAE: // LDX absolute
        {
            uint16_t addr = read_word(pc);
            cpu.x = cpu.memory[addr];
            cpu.memoryAccess[addr] |= MEM_READ;
            set_zn_flags(cpu.x);
            cpu.cycles += 4;
        }
        break;

        case 0xB6: // LDX zero page,Y
        {
            uint8_t zp = (cpu.memory[pc++] + cpu.y) & 0xFF;
            cpu.x = cpu.memory[zp];
            cpu.memoryAccess[zp] |= MEM_READ;
            set_zn_flags(cpu.x);
            cpu.cycles += 4;
        }
        break;

        case 0xBE: // LDX absolute,Y
        {
            uint16_t addr = read_word(pc) + cpu.y;
            cpu.x = cpu.memory[addr];
            cpu.memoryAccess[addr] |= MEM_READ;
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
            cpu.memoryAccess[zp] |= MEM_READ;
            set_zn_flags(cpu.y);
            cpu.cycles += 3;
        }
        break;

        case 0xAC: // LDY absolute
        {
            uint16_t addr = read_word(pc);
            cpu.y = cpu.memory[addr];
            cpu.memoryAccess[addr] |= MEM_READ;
            set_zn_flags(cpu.y);
            cpu.cycles += 4;
        }
        break;

        case 0xB4: // LDY zero page,X
        {
            uint8_t zp = (cpu.memory[pc++] + cpu.x) & 0xFF;
            cpu.y = cpu.memory[zp];
            cpu.memoryAccess[zp] |= MEM_READ;
            set_zn_flags(cpu.y);
            cpu.cycles += 4;
        }
        break;

        case 0xBC: // LDY absolute,X
        {
            uint16_t addr = read_word(pc) + cpu.x;
            cpu.y = cpu.memory[addr];
            cpu.memoryAccess[addr] |= MEM_READ;
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
            cpu.memoryAccess[addr] |= MEM_JUMP_TARGET;
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
            cpu.memoryAccess[addr] |= MEM_JUMP_TARGET;
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
            cpu.memoryAccess[addr] |= MEM_JUMP_TARGET;
            cpu.cycles += 5;
        }
        break;

        // Branches
        case 0xF0: // BEQ
        {
            int8_t offset = (int8_t)cpu.memory[pc++];
            if (test_flag(FLAG_ZERO)) {
                pc += offset;
                cpu.cycles += 3;
            }
            else {
                cpu.cycles += 2;
            }
        }
        break;

        case 0xD0: // BNE
        {
            int8_t offset = (int8_t)cpu.memory[pc++];
            if (!test_flag(FLAG_ZERO)) {
                pc += offset;
                cpu.cycles += 3;
            }
            else {
                cpu.cycles += 2;
            }
        }
        break;

        case 0xB0: // BCS
        {
            int8_t offset = (int8_t)cpu.memory[pc++];
            if (test_flag(FLAG_CARRY)) {
                pc += offset;
                cpu.cycles += 3;
            }
            else {
                cpu.cycles += 2;
            }
        }
        break;

        case 0x90: // BCC
        {
            int8_t offset = (int8_t)cpu.memory[pc++];
            if (!test_flag(FLAG_CARRY)) {
                pc += offset;
                cpu.cycles += 3;
            }
            else {
                cpu.cycles += 2;
            }
        }
        break;

        case 0x30: // BMI
        {
            int8_t offset = (int8_t)cpu.memory[pc++];
            if (test_flag(FLAG_NEGATIVE)) {
                pc += offset;
                cpu.cycles += 3;
            }
            else {
                cpu.cycles += 2;
            }
        }
        break;

        case 0x10: // BPL
        {
            int8_t offset = (int8_t)cpu.memory[pc++];
            if (!test_flag(FLAG_NEGATIVE)) {
                pc += offset;
                cpu.cycles += 3;
            }
            else {
                cpu.cycles += 2;
            }
        }
        break;

        case 0x50: // BVC
        {
            int8_t offset = (int8_t)cpu.memory[pc++];
            if (!test_flag(FLAG_OVERFLOW)) {
                pc += offset;
                cpu.cycles += 3;
            }
            else {
                cpu.cycles += 2;
            }
        }
        break;

        case 0x70: // BVS
        {
            int8_t offset = (int8_t)cpu.memory[pc++];
            if (test_flag(FLAG_OVERFLOW)) {
                pc += offset;
                cpu.cycles += 3;
            }
            else {
                cpu.cycles += 2;
            }
        }
        break;

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

} // extern "C"