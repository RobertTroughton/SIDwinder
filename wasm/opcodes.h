// opcodes.h - 6510 CPU Opcode definitions
#pragma once

#include <cstdint>

// Addressing modes
enum AddressingMode {
    MODE_IMPLIED,
    MODE_IMMEDIATE,
    MODE_ZERO_PAGE,
    MODE_ZERO_PAGE_X,
    MODE_ZERO_PAGE_Y,
    MODE_ABSOLUTE,
    MODE_ABSOLUTE_X,
    MODE_ABSOLUTE_Y,
    MODE_INDIRECT,
    MODE_INDIRECT_X,
    MODE_INDIRECT_Y,
    MODE_RELATIVE,
    MODE_ACCUMULATOR
};

// Opcode information structure
struct OpcodeInfo {
    const char* mnemonic;
    uint8_t mode;
    uint8_t size;
    uint8_t cycles;
    bool illegal;
};

// Complete 6510 opcode table
static const OpcodeInfo opcodeTable[256] = {
    // 0x00-0x0F
    {"brk", MODE_IMPLIED, 1, 7, false},      // 0x00
    {"ora", MODE_INDIRECT_X, 2, 6, false},   // 0x01
    {"kil", MODE_IMPLIED, 1, 0, true},       // 0x02
    {"slo", MODE_INDIRECT_X, 2, 8, true},    // 0x03
    {"nop", MODE_ZERO_PAGE, 2, 3, true},     // 0x04
    {"ora", MODE_ZERO_PAGE, 2, 3, false},    // 0x05
    {"asl", MODE_ZERO_PAGE, 2, 5, false},    // 0x06
    {"slo", MODE_ZERO_PAGE, 2, 5, true},     // 0x07
    {"php", MODE_IMPLIED, 1, 3, false},      // 0x08
    {"ora", MODE_IMMEDIATE, 2, 2, false},    // 0x09
    {"asl", MODE_ACCUMULATOR, 1, 2, false},  // 0x0A
    {"anc", MODE_IMMEDIATE, 2, 2, true},     // 0x0B
    {"nop", MODE_ABSOLUTE, 3, 4, true},      // 0x0C
    {"ora", MODE_ABSOLUTE, 3, 4, false},     // 0x0D
    {"asl", MODE_ABSOLUTE, 3, 6, false},     // 0x0E
    {"slo", MODE_ABSOLUTE, 3, 6, true},      // 0x0F

    // 0x10-0x1F
    {"bpl", MODE_RELATIVE, 2, 2, false},     // 0x10
    {"ora", MODE_INDIRECT_Y, 2, 5, false},   // 0x11
    {"kil", MODE_IMPLIED, 1, 0, true},       // 0x12
    {"slo", MODE_INDIRECT_Y, 2, 8, true},    // 0x13
    {"nop", MODE_ZERO_PAGE_X, 2, 4, true},   // 0x14
    {"ora", MODE_ZERO_PAGE_X, 2, 4, false},  // 0x15
    {"asl", MODE_ZERO_PAGE_X, 2, 6, false},  // 0x16
    {"slo", MODE_ZERO_PAGE_X, 2, 6, true},   // 0x17
    {"clc", MODE_IMPLIED, 1, 2, false},      // 0x18
    {"ora", MODE_ABSOLUTE_Y, 3, 4, false},   // 0x19
    {"nop", MODE_IMPLIED, 1, 2, true},       // 0x1A
    {"slo", MODE_ABSOLUTE_Y, 3, 7, true},    // 0x1B
    {"nop", MODE_ABSOLUTE_X, 3, 4, true},    // 0x1C
    {"ora", MODE_ABSOLUTE_X, 3, 4, false},   // 0x1D
    {"asl", MODE_ABSOLUTE_X, 3, 7, false},   // 0x1E
    {"slo", MODE_ABSOLUTE_X, 3, 7, true},    // 0x1F

    // 0x20-0x2F
    {"jsr", MODE_ABSOLUTE, 3, 6, false},     // 0x20
    {"and", MODE_INDIRECT_X, 2, 6, false},   // 0x21
    {"kil", MODE_IMPLIED, 1, 0, true},       // 0x22
    {"rla", MODE_INDIRECT_X, 2, 8, true},    // 0x23
    {"bit", MODE_ZERO_PAGE, 2, 3, false},    // 0x24
    {"and", MODE_ZERO_PAGE, 2, 3, false},    // 0x25
    {"rol", MODE_ZERO_PAGE, 2, 5, false},    // 0x26
    {"rla", MODE_ZERO_PAGE, 2, 5, true},     // 0x27
    {"plp", MODE_IMPLIED, 1, 4, false},      // 0x28
    {"and", MODE_IMMEDIATE, 2, 2, false},    // 0x29
    {"rol", MODE_ACCUMULATOR, 1, 2, false},  // 0x2A
    {"anc", MODE_IMMEDIATE, 2, 2, true},     // 0x2B
    {"bit", MODE_ABSOLUTE, 3, 4, false},     // 0x2C
    {"and", MODE_ABSOLUTE, 3, 4, false},     // 0x2D
    {"rol", MODE_ABSOLUTE, 3, 6, false},     // 0x2E
    {"rla", MODE_ABSOLUTE, 3, 6, true},      // 0x2F

    // 0x30-0x3F
    {"bmi", MODE_RELATIVE, 2, 2, false},     // 0x30
    {"and", MODE_INDIRECT_Y, 2, 5, false},   // 0x31
    {"kil", MODE_IMPLIED, 1, 0, true},       // 0x32
    {"rla", MODE_INDIRECT_Y, 2, 8, true},    // 0x33
    {"nop", MODE_ZERO_PAGE_X, 2, 4, true},   // 0x34
    {"and", MODE_ZERO_PAGE_X, 2, 4, false},  // 0x35
    {"rol", MODE_ZERO_PAGE_X, 2, 6, false},  // 0x36
    {"rla", MODE_ZERO_PAGE_X, 2, 6, true},   // 0x37
    {"sec", MODE_IMPLIED, 1, 2, false},      // 0x38
    {"and", MODE_ABSOLUTE_Y, 3, 4, false},   // 0x39
    {"nop", MODE_IMPLIED, 1, 2, true},       // 0x3A
    {"rla", MODE_ABSOLUTE_Y, 3, 7, true},    // 0x3B
    {"nop", MODE_ABSOLUTE_X, 3, 4, true},    // 0x3C
    {"and", MODE_ABSOLUTE_X, 3, 4, false},   // 0x3D
    {"rol", MODE_ABSOLUTE_X, 3, 7, false},   // 0x3E
    {"rla", MODE_ABSOLUTE_X, 3, 7, true},    // 0x3F

    // 0x40-0x4F
    {"rti", MODE_IMPLIED, 1, 6, false},      // 0x40
    {"eor", MODE_INDIRECT_X, 2, 6, false},   // 0x41
    {"kil", MODE_IMPLIED, 1, 0, true},       // 0x42
    {"sre", MODE_INDIRECT_X, 2, 8, true},    // 0x43
    {"nop", MODE_ZERO_PAGE, 2, 3, true},     // 0x44
    {"eor", MODE_ZERO_PAGE, 2, 3, false},    // 0x45
    {"lsr", MODE_ZERO_PAGE, 2, 5, false},    // 0x46
    {"sre", MODE_ZERO_PAGE, 2, 5, true},     // 0x47
    {"pha", MODE_IMPLIED, 1, 3, false},      // 0x48
    {"eor", MODE_IMMEDIATE, 2, 2, false},    // 0x49
    {"lsr", MODE_ACCUMULATOR, 1, 2, false},  // 0x4A
    {"alr", MODE_IMMEDIATE, 2, 2, true},     // 0x4B
    {"jmp", MODE_ABSOLUTE, 3, 3, false},     // 0x4C
    {"eor", MODE_ABSOLUTE, 3, 4, false},     // 0x4D
    {"lsr", MODE_ABSOLUTE, 3, 6, false},     // 0x4E
    {"sre", MODE_ABSOLUTE, 3, 6, true},      // 0x4F

    // 0x50-0x5F
    {"bvc", MODE_RELATIVE, 2, 2, false},     // 0x50
    {"eor", MODE_INDIRECT_Y, 2, 5, false},   // 0x51
    {"kil", MODE_IMPLIED, 1, 0, true},       // 0x52
    {"sre", MODE_INDIRECT_Y, 2, 8, true},    // 0x53
    {"nop", MODE_ZERO_PAGE_X, 2, 4, true},   // 0x54
    {"eor", MODE_ZERO_PAGE_X, 2, 4, false},  // 0x55
    {"lsr", MODE_ZERO_PAGE_X, 2, 6, false},  // 0x56
    {"sre", MODE_ZERO_PAGE_X, 2, 6, true},   // 0x57
    {"cli", MODE_IMPLIED, 1, 2, false},      // 0x58
    {"eor", MODE_ABSOLUTE_Y, 3, 4, false},   // 0x59
    {"nop", MODE_IMPLIED, 1, 2, true},       // 0x5A
    {"sre", MODE_ABSOLUTE_Y, 3, 7, true},    // 0x5B
    {"nop", MODE_ABSOLUTE_X, 3, 4, true},    // 0x5C
    {"eor", MODE_ABSOLUTE_X, 3, 4, false},   // 0x5D
    {"lsr", MODE_ABSOLUTE_X, 3, 7, false},   // 0x5E
    {"sre", MODE_ABSOLUTE_X, 3, 7, true},    // 0x5F

    // 0x60-0x6F
    {"rts", MODE_IMPLIED, 1, 6, false},      // 0x60
    {"adc", MODE_INDIRECT_X, 2, 6, false},   // 0x61
    {"kil", MODE_IMPLIED, 1, 0, true},       // 0x62
    {"rra", MODE_INDIRECT_X, 2, 8, true},    // 0x63
    {"nop", MODE_ZERO_PAGE, 2, 3, true},     // 0x64
    {"adc", MODE_ZERO_PAGE, 2, 3, false},    // 0x65
    {"ror", MODE_ZERO_PAGE, 2, 5, false},    // 0x66
    {"rra", MODE_ZERO_PAGE, 2, 5, true},     // 0x67
    {"pla", MODE_IMPLIED, 1, 4, false},      // 0x68
    {"adc", MODE_IMMEDIATE, 2, 2, false},    // 0x69
    {"ror", MODE_ACCUMULATOR, 1, 2, false},  // 0x6A
    {"arr", MODE_IMMEDIATE, 2, 2, true},     // 0x6B
    {"jmp", MODE_INDIRECT, 3, 5, false},     // 0x6C
    {"adc", MODE_ABSOLUTE, 3, 4, false},     // 0x6D
    {"ror", MODE_ABSOLUTE, 3, 6, false},     // 0x6E
    {"rra", MODE_ABSOLUTE, 3, 6, true},      // 0x6F

    // 0x70-0x7F
    {"bvs", MODE_RELATIVE, 2, 2, false},     // 0x70
    {"adc", MODE_INDIRECT_Y, 2, 5, false},   // 0x71
    {"kil", MODE_IMPLIED, 1, 0, true},       // 0x72
    {"rra", MODE_INDIRECT_Y, 2, 8, true},    // 0x73
    {"nop", MODE_ZERO_PAGE_X, 2, 4, true},   // 0x74
    {"adc", MODE_ZERO_PAGE_X, 2, 4, false},  // 0x75
    {"ror", MODE_ZERO_PAGE_X, 2, 6, false},  // 0x76
    {"rra", MODE_ZERO_PAGE_X, 2, 6, true},   // 0x77
    {"sei", MODE_IMPLIED, 1, 2, false},      // 0x78
    {"adc", MODE_ABSOLUTE_Y, 3, 4, false},   // 0x79
    {"nop", MODE_IMPLIED, 1, 2, true},       // 0x7A
    {"rra", MODE_ABSOLUTE_Y, 3, 7, true},    // 0x7B
    {"nop", MODE_ABSOLUTE_X, 3, 4, true},    // 0x7C
    {"adc", MODE_ABSOLUTE_X, 3, 4, false},   // 0x7D
    {"ror", MODE_ABSOLUTE_X, 3, 7, false},   // 0x7E
    {"rra", MODE_ABSOLUTE_X, 3, 7, true},    // 0x7F

    // 0x80-0x8F
    {"nop", MODE_IMMEDIATE, 2, 2, true},     // 0x80
    {"sta", MODE_INDIRECT_X, 2, 6, false},   // 0x81
    {"nop", MODE_IMMEDIATE, 2, 2, true},     // 0x82
    {"sax", MODE_INDIRECT_X, 2, 6, true},    // 0x83
    {"sty", MODE_ZERO_PAGE, 2, 3, false},    // 0x84
    {"sta", MODE_ZERO_PAGE, 2, 3, false},    // 0x85
    {"stx", MODE_ZERO_PAGE, 2, 3, false},    // 0x86
    {"sax", MODE_ZERO_PAGE, 2, 3, true},     // 0x87
    {"dey", MODE_IMPLIED, 1, 2, false},      // 0x88
    {"nop", MODE_IMMEDIATE, 2, 2, true},     // 0x89
    {"txa", MODE_IMPLIED, 1, 2, false},      // 0x8A
    {"xaa", MODE_IMMEDIATE, 2, 2, true},     // 0x8B
    {"sty", MODE_ABSOLUTE, 3, 4, false},     // 0x8C
    {"sta", MODE_ABSOLUTE, 3, 4, false},     // 0x8D
    {"stx", MODE_ABSOLUTE, 3, 4, false},     // 0x8E
    {"sax", MODE_ABSOLUTE, 3, 4, true},      // 0x8F

    // 0x90-0x9F
    {"bcc", MODE_RELATIVE, 2, 2, false},     // 0x90
    {"sta", MODE_INDIRECT_Y, 2, 6, false},   // 0x91
    {"kil", MODE_IMPLIED, 1, 0, true},       // 0x92
    {"ahx", MODE_INDIRECT_Y, 2, 6, true},    // 0x93
    {"sty", MODE_ZERO_PAGE_X, 2, 4, false},  // 0x94
    {"sta", MODE_ZERO_PAGE_X, 2, 4, false},  // 0x95
    {"stx", MODE_ZERO_PAGE_Y, 2, 4, false},  // 0x96
    {"sax", MODE_ZERO_PAGE_Y, 2, 4, true},   // 0x97
    {"tya", MODE_IMPLIED, 1, 2, false},      // 0x98
    {"sta", MODE_ABSOLUTE_Y, 3, 5, false},   // 0x99
    {"txs", MODE_IMPLIED, 1, 2, false},      // 0x9A
    {"tas", MODE_ABSOLUTE_Y, 3, 5, true},    // 0x9B
    {"shy", MODE_ABSOLUTE_X, 3, 5, true},    // 0x9C
    {"sta", MODE_ABSOLUTE_X, 3, 5, false},   // 0x9D
    {"shx", MODE_ABSOLUTE_Y, 3, 5, true},    // 0x9E
    {"ahx", MODE_ABSOLUTE_Y, 3, 5, true},    // 0x9F

    // 0xA0-0xAF
    {"ldy", MODE_IMMEDIATE, 2, 2, false},    // 0xA0
    {"lda", MODE_INDIRECT_X, 2, 6, false},   // 0xA1
    {"ldx", MODE_IMMEDIATE, 2, 2, false},    // 0xA2
    {"lax", MODE_INDIRECT_X, 2, 6, true},    // 0xA3
    {"ldy", MODE_ZERO_PAGE, 2, 3, false},    // 0xA4
    {"lda", MODE_ZERO_PAGE, 2, 3, false},    // 0xA5
    {"ldx", MODE_ZERO_PAGE, 2, 3, false},    // 0xA6
    {"lax", MODE_ZERO_PAGE, 2, 3, true},     // 0xA7
    {"tay", MODE_IMPLIED, 1, 2, false},      // 0xA8
    {"lda", MODE_IMMEDIATE, 2, 2, false},    // 0xA9
    {"tax", MODE_IMPLIED, 1, 2, false},      // 0xAA
    {"lax", MODE_IMMEDIATE, 2, 2, true},     // 0xAB
    {"ldy", MODE_ABSOLUTE, 3, 4, false},     // 0xAC
    {"lda", MODE_ABSOLUTE, 3, 4, false},     // 0xAD
    {"ldx", MODE_ABSOLUTE, 3, 4, false},     // 0xAE
    {"lax", MODE_ABSOLUTE, 3, 4, true},      // 0xAF

    // 0xB0-0xBF
    {"bcs", MODE_RELATIVE, 2, 2, false},     // 0xB0
    {"lda", MODE_INDIRECT_Y, 2, 5, false},   // 0xB1
    {"kil", MODE_IMPLIED, 1, 0, true},       // 0xB2
    {"lax", MODE_INDIRECT_Y, 2, 5, true},    // 0xB3
    {"ldy", MODE_ZERO_PAGE_X, 2, 4, false},  // 0xB4
    {"lda", MODE_ZERO_PAGE_X, 2, 4, false},  // 0xB5
    {"ldx", MODE_ZERO_PAGE_Y, 2, 4, false},  // 0xB6
    {"lax", MODE_ZERO_PAGE_Y, 2, 4, true},   // 0xB7
    {"clv", MODE_IMPLIED, 1, 2, false},      // 0xB8
    {"lda", MODE_ABSOLUTE_Y, 3, 4, false},   // 0xB9
    {"tsx", MODE_IMPLIED, 1, 2, false},      // 0xBA
    {"las", MODE_ABSOLUTE_Y, 3, 4, true},    // 0xBB
    {"ldy", MODE_ABSOLUTE_X, 3, 4, false},   // 0xBC
    {"lda", MODE_ABSOLUTE_X, 3, 4, false},   // 0xBD
    {"ldx", MODE_ABSOLUTE_Y, 3, 4, false},   // 0xBE
    {"lax", MODE_ABSOLUTE_Y, 3, 4, true},    // 0xBF

    // 0xC0-0xCF
    {"cpy", MODE_IMMEDIATE, 2, 2, false},    // 0xC0
    {"cmp", MODE_INDIRECT_X, 2, 6, false},   // 0xC1
    {"nop", MODE_IMMEDIATE, 2, 2, true},     // 0xC2
    {"dcp", MODE_INDIRECT_X, 2, 8, true},    // 0xC3
    {"cpy", MODE_ZERO_PAGE, 2, 3, false},    // 0xC4
    {"cmp", MODE_ZERO_PAGE, 2, 3, false},    // 0xC5
    {"dec", MODE_ZERO_PAGE, 2, 5, false},    // 0xC6
    {"dcp", MODE_ZERO_PAGE, 2, 5, true},     // 0xC7
    {"iny", MODE_IMPLIED, 1, 2, false},      // 0xC8
    {"cmp", MODE_IMMEDIATE, 2, 2, false},    // 0xC9
    {"dex", MODE_IMPLIED, 1, 2, false},      // 0xCA
    {"axs", MODE_IMMEDIATE, 2, 2, true},     // 0xCB
    {"cpy", MODE_ABSOLUTE, 3, 4, false},     // 0xCC
    {"cmp", MODE_ABSOLUTE, 3, 4, false},     // 0xCD
    {"dec", MODE_ABSOLUTE, 3, 6, false},     // 0xCE
    {"dcp", MODE_ABSOLUTE, 3, 6, true},      // 0xCF

    // 0xD0-0xDF
    {"bne", MODE_RELATIVE, 2, 2, false},     // 0xD0
    {"cmp", MODE_INDIRECT_Y, 2, 5, false},   // 0xD1
    {"kil", MODE_IMPLIED, 1, 0, true},       // 0xD2
    {"dcp", MODE_INDIRECT_Y, 2, 8, true},    // 0xD3
    {"nop", MODE_ZERO_PAGE_X, 2, 4, true},   // 0xD4
    {"cmp", MODE_ZERO_PAGE_X, 2, 4, false},  // 0xD5
    {"dec", MODE_ZERO_PAGE_X, 2, 6, false},  // 0xD6
    {"dcp", MODE_ZERO_PAGE_X, 2, 6, true},   // 0xD7
    {"cld", MODE_IMPLIED, 1, 2, false},      // 0xD8
    {"cmp", MODE_ABSOLUTE_Y, 3, 4, false},   // 0xD9
    {"nop", MODE_IMPLIED, 1, 2, true},       // 0xDA
    {"dcp", MODE_ABSOLUTE_Y, 3, 7, true},    // 0xDB
    {"nop", MODE_ABSOLUTE_X, 3, 4, true},    // 0xDC
    {"cmp", MODE_ABSOLUTE_X, 3, 4, false},   // 0xDD
    {"dec", MODE_ABSOLUTE_X, 3, 7, false},   // 0xDE
    {"dcp", MODE_ABSOLUTE_X, 3, 7, true},    // 0xDF

    // 0xE0-0xEF
    {"cpx", MODE_IMMEDIATE, 2, 2, false},    // 0xE0
    {"sbc", MODE_INDIRECT_X, 2, 6, false},   // 0xE1
    {"nop", MODE_IMMEDIATE, 2, 2, true},     // 0xE2
    {"isc", MODE_INDIRECT_X, 2, 8, true},    // 0xE3
    {"cpx", MODE_ZERO_PAGE, 2, 3, false},    // 0xE4
    {"sbc", MODE_ZERO_PAGE, 2, 3, false},    // 0xE5
    {"inc", MODE_ZERO_PAGE, 2, 5, false},    // 0xE6
    {"isc", MODE_ZERO_PAGE, 2, 5, true},     // 0xE7
    {"inx", MODE_IMPLIED, 1, 2, false},      // 0xE8
    {"sbc", MODE_IMMEDIATE, 2, 2, false},    // 0xE9
    {"nop", MODE_IMPLIED, 1, 2, false},      // 0xEA
    {"sbc", MODE_IMMEDIATE, 2, 2, true},     // 0xEB
    {"cpx", MODE_ABSOLUTE, 3, 4, false},     // 0xEC
    {"sbc", MODE_ABSOLUTE, 3, 4, false},     // 0xED
    {"inc", MODE_ABSOLUTE, 3, 6, false},     // 0xEE
    {"isc", MODE_ABSOLUTE, 3, 6, true},      // 0xEF

    // 0xF0-0xFF
    {"beq", MODE_RELATIVE, 2, 2, false},     // 0xF0
    {"sbc", MODE_INDIRECT_Y, 2, 5, false},   // 0xF1
    {"kil", MODE_IMPLIED, 1, 0, true},       // 0xF2
    {"isc", MODE_INDIRECT_Y, 2, 8, true},    // 0xF3
    {"nop", MODE_ZERO_PAGE_X, 2, 4, true},   // 0xF4
    {"sbc", MODE_ZERO_PAGE_X, 2, 4, false},  // 0xF5
    {"inc", MODE_ZERO_PAGE_X, 2, 6, false},  // 0xF6
    {"isc", MODE_ZERO_PAGE_X, 2, 6, true},   // 0xF7
    {"sed", MODE_IMPLIED, 1, 2, false},      // 0xF8
    {"sbc", MODE_ABSOLUTE_Y, 3, 4, false},   // 0xF9
    {"nop", MODE_IMPLIED, 1, 2, true},       // 0xFA
    {"isc", MODE_ABSOLUTE_Y, 3, 7, true},    // 0xFB
    {"nop", MODE_ABSOLUTE_X, 3, 4, true},    // 0xFC
    {"sbc", MODE_ABSOLUTE_X, 3, 4, false},   // 0xFD
    {"inc", MODE_ABSOLUTE_X, 3, 7, false},   // 0xFE
    {"isc", MODE_ABSOLUTE_X, 3, 7, true}     // 0xFF
};

