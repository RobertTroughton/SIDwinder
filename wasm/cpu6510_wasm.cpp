// cpu6510_wasm.cpp - Fixed version
// Compile with: emcc cpu6510_wasm.cpp -O3 -s WASM=1 -s EXPORTED_FUNCTIONS='["_malloc","_free"]' -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap"]' -s MODULARIZE=1 -s EXPORT_NAME='CPU6510Module' -o cpu6510.js

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
        cpu.recordWrites = false;

        memset(cpu.memory, 0, sizeof(cpu.memory));
        memset(cpu.memoryAccess, 0, sizeof(cpu.memoryAccess));
        memset(cpu.sidWrites, 0, sizeof(cpu.sidWrites));
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

    // Read memory
    EMSCRIPTEN_KEEPALIVE
        uint8_t cpu_read_memory(uint16_t address) {
        cpu.memoryAccess[address] |= MEM_READ;
        return cpu.memory[address];
    }

    // Write memory
    EMSCRIPTEN_KEEPALIVE
        void cpu_write_memory(uint16_t address, uint8_t value) {
        cpu.memory[address] = value;
        cpu.memoryAccess[address] |= MEM_WRITE;
        cpu.lastWritePC[address] = cpu.pc;

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

    // Stack operations
    void push(uint8_t value) {
        cpu.memory[0x0100 + cpu.sp] = value;
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
            cpu.a = cpu.memory[cpu.memory[pc++]];
            set_zn_flags(cpu.a);
            cpu.cycles += 3;
            break;

        case 0xAD: // LDA absolute
        {
            uint16_t addr = read_word(pc);
            cpu.a = cpu_read_memory(addr);
            set_zn_flags(cpu.a);
            cpu.cycles += 4;
        }
        break;

        case 0xBD: // LDA absolute,X
        {
            uint16_t addr = read_word(pc) + cpu.x;
            cpu.a = cpu_read_memory(addr);
            set_zn_flags(cpu.a);
            cpu.cycles += 4;
        }
        break;

        case 0xB9: // LDA absolute,Y
        {
            uint16_t addr = read_word(pc) + cpu.y;
            cpu.a = cpu_read_memory(addr);
            set_zn_flags(cpu.a);
            cpu.cycles += 4;
        }
        break;

        // STA
        case 0x85: // STA zero page
            cpu_write_memory(cpu.memory[pc++], cpu.a);
            cpu.cycles += 3;
            break;

        case 0x8D: // STA absolute
        {
            uint16_t addr = read_word(pc);
            cpu_write_memory(addr, cpu.a);
            cpu.cycles += 4;
        }
        break;

        case 0x9D: // STA absolute,X
        {
            uint16_t addr = read_word(pc) + cpu.x;
            cpu_write_memory(addr, cpu.a);
            cpu.cycles += 5;
        }
        break;

        case 0x99: // STA absolute,Y
        {
            uint16_t addr = read_word(pc) + cpu.y;
            cpu_write_memory(addr, cpu.a);
            cpu.cycles += 5;
        }
        break;

        // STX
        case 0x86: // STX zero page
            cpu_write_memory(cpu.memory[pc++], cpu.x);
            cpu.cycles += 3;
            break;

        case 0x8E: // STX absolute
        {
            uint16_t addr = read_word(pc);
            cpu_write_memory(addr, cpu.x);
            cpu.cycles += 4;
        }
        break;

        // STY
        case 0x84: // STY zero page
            cpu_write_memory(cpu.memory[pc++], cpu.y);
            cpu.cycles += 3;
            break;

        case 0x8C: // STY absolute
        {
            uint16_t addr = read_word(pc);
            cpu_write_memory(addr, cpu.y);
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
            cpu.x = cpu.memory[cpu.memory[pc++]];
            set_zn_flags(cpu.x);
            cpu.cycles += 3;
            break;

        case 0xAE: // LDX absolute
        {
            uint16_t addr = read_word(pc);
            cpu.x = cpu_read_memory(addr);
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
            cpu.y = cpu.memory[cpu.memory[pc++]];
            set_zn_flags(cpu.y);
            cpu.cycles += 3;
            break;

        case 0xAC: // LDY absolute
        {
            uint16_t addr = read_word(pc);
            cpu.y = cpu_read_memory(addr);
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
            uint8_t value = cpu.memory[cpu.memory[pc++]];
            uint8_t result = cpu.a - value;
            set_flag(FLAG_CARRY, cpu.a >= value);
            set_zn_flags(result);
            cpu.cycles += 3;
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

        // Logical
        case 0x29: // AND immediate
            cpu.a &= cpu.memory[pc++];
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
            break;

        case 0x09: // ORA immediate
            cpu.a |= cpu.memory[pc++];
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
            break;

        case 0x49: // EOR immediate
            cpu.a ^= cpu.memory[pc++];
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
            break;

            // INC/DEC
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

        case 0xE6: // INC zero page
        {
            uint8_t zp = cpu.memory[pc++];
            cpu.memory[zp]++;
            set_zn_flags(cpu.memory[zp]);
            cpu.cycles += 5;
        }
        break;

        case 0xC6: // DEC zero page
        {
            uint8_t zp = cpu.memory[pc++];
            cpu.memory[zp]--;
            set_zn_flags(cpu.memory[zp]);
            cpu.cycles += 5;
        }
        break;

        // Shifts
        case 0x0A: // ASL A
            set_flag(FLAG_CARRY, cpu.a & 0x80);
            cpu.a <<= 1;
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
            break;

        case 0x4A: // LSR A
            set_flag(FLAG_CARRY, cpu.a & 0x01);
            cpu.a >>= 1;
            set_zn_flags(cpu.a);
            cpu.cycles += 2;
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

        default:
            // For unimplemented opcodes, try to guess the size
            // This is a simplified approach - a full implementation would have all opcodes
            if ((opcode & 0x1F) == 0x19 || (opcode & 0x1F) == 0x1D) {
                // Absolute,Y addressing
                pc += 2;
                cpu.cycles += 4;
            }
            else if ((opcode & 0x0F) == 0x0D) {
                // Absolute addressing
                pc += 2;
                cpu.cycles += 4;
            }
            else if ((opcode & 0x0F) == 0x09 || (opcode & 0x0F) == 0x05) {
                // Immediate or zero page
                pc += 1;
                cpu.cycles += 2;
            }
            else {
                // Unknown - just advance
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

    // Enable/disable write sequence recording
    EMSCRIPTEN_KEEPALIVE
        void cpu_set_record_writes(bool record) {
        cpu.recordWrites = record;
        if (record) {
            cpu.writeSequence.clear();
        }
    }

    // Get write sequence
    EMSCRIPTEN_KEEPALIVE
        uint32_t cpu_get_write_sequence_length() {
        return cpu.writeSequence.size();
    }

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