// sid_audio.cpp - reSID-based audio playback engine for SIDwinder
// Provides cycle-accurate SID emulation via reSID library
// with a lightweight 6510 CPU for running SID play routines.
//
// Compile together with reSID sources via Emscripten.

#include <emscripten/emscripten.h>
#include <cstdint>
#include <cstring>
#include <cmath>
#include "resid/sid.h"

extern "C" {

// ---- Constants ----
static const double PAL_CLOCK  = 985248.0;
static const double NTSC_CLOCK = 1022730.0;
static const int PAL_CYCLES_PER_FRAME  = 19656;
static const int NTSC_CYCLES_PER_FRAME = 17095;
static const int MAX_SID_CHIPS = 3;

// ---- CPU flags ----
#define FLAG_C 0x01
#define FLAG_Z 0x02
#define FLAG_I 0x04
#define FLAG_D 0x08
#define FLAG_B 0x10
#define FLAG_U 0x20
#define FLAG_V 0x40
#define FLAG_N 0x80

// ---- Debug counters ----
static int dbg_sid_writes = 0;    // SID register writes per play call
static int dbg_play_cycles = 0;   // CPU cycles used by play routine
static uint16_t dbg_last_write_addr = 0;

// ---- Playback state ----
static struct {
    // 6510 CPU registers
    uint16_t pc;
    uint8_t  sp, a, x, y, st;
    uint8_t  memory[65536];

    // reSID instances
    reSID::SID sid[MAX_SID_CHIPS];
    int        sidCount;
    uint16_t   sidAddress[MAX_SID_CHIPS];

    // SID file metadata
    uint16_t loadAddress;
    uint16_t initAddress;
    uint16_t playAddress;
    uint16_t songs;
    uint16_t startSong;
    uint32_t speed;        // bit per subtune: 0=VBI, 1=CIA
    char     name[33];
    char     author[33];
    char     copyright[33];
    uint16_t flags;        // v2+ flags field
    uint8_t  secondSIDAddr;
    uint8_t  thirdSIDAddr;

    // Playback config
    double   clockFreq;
    double   sampleRate;
    int      cyclesPerFrame;
    int      currentSubtune;
    bool     isNTSC;
    bool     loaded;

    // Frame-level playback
    int      remainingCycles;  // cycles left in current frame
    bool     playRoutineActive;
    uint64_t totalCycles;      // total cycles since play started
    int      chipModel;        // 6581 or 8580
} S;

// ---- Memory access with SID register interception ----

static inline uint8_t mem_read(uint16_t addr) {
    // Primary SID reads
    if (addr >= 0xD400 && addr <= 0xD41F) {
        return S.sid[0].read(addr & 0x1F);
    }
    // Multi-SID reads
    for (int i = 1; i < S.sidCount; i++) {
        if (addr >= S.sidAddress[i] && addr < S.sidAddress[i] + 0x20) {
            return S.sid[i].read(addr & 0x1F);
        }
    }
    return S.memory[addr];
}

static inline void mem_write(uint16_t addr, uint8_t val) {
    S.memory[addr] = val;

    // Primary SID at $D400
    if (addr >= 0xD400 && addr <= 0xD41F) {
        S.sid[0].write(addr & 0x1F, val);
        dbg_sid_writes++;
        dbg_last_write_addr = addr;
        return;
    }
    // Multi-SID chips
    for (int i = 1; i < S.sidCount; i++) {
        if (addr >= S.sidAddress[i] && addr < S.sidAddress[i] + 0x20) {
            S.sid[i].write(addr & 0x1F, val);
            return;
        }
    }
    // SID mirror range ($D420-$D7FF) - mirror to chip 0 if no multi-SID mapped
    if (addr >= 0xD420 && addr < 0xD800) {
        S.memory[0xD400 | (addr & 0x1F)] = val;
        S.sid[0].write(addr & 0x1F, val);
    }
}

// ---- Stack helpers ----
static inline void push8(uint8_t val) {
    S.memory[0x100 + S.sp] = val;
    S.sp--;
}
static inline uint8_t pull8() {
    S.sp++;
    return S.memory[0x100 + S.sp];
}
static inline void push16(uint16_t val) {
    push8((val >> 8) & 0xFF);
    push8(val & 0xFF);
}
static inline uint16_t pull16() {
    uint8_t lo = pull8();
    uint8_t hi = pull8();
    return (hi << 8) | lo;
}

// ---- Flag helpers ----
static inline void set_nz(uint8_t val) {
    S.st = (S.st & ~(FLAG_N | FLAG_Z)) | (val & 0x80) | (val == 0 ? FLAG_Z : 0);
}

// ---- Addressing modes (return effective address) ----
static inline uint16_t am_imm()  { return S.pc++; }
static inline uint16_t am_zp()   { return S.memory[S.pc++]; }
static inline uint16_t am_zpx()  { return (S.memory[S.pc++] + S.x) & 0xFF; }
static inline uint16_t am_zpy()  { return (S.memory[S.pc++] + S.y) & 0xFF; }
static inline uint16_t am_abs()  { uint16_t a = S.memory[S.pc] | (S.memory[S.pc+1] << 8); S.pc += 2; return a; }
static inline uint16_t am_abx()  { uint16_t a = (S.memory[S.pc] | (S.memory[S.pc+1] << 8)) + S.x; S.pc += 2; return a; }
static inline uint16_t am_aby()  { uint16_t a = (S.memory[S.pc] | (S.memory[S.pc+1] << 8)) + S.y; S.pc += 2; return a; }
static inline uint16_t am_izx()  { uint8_t zp = (S.memory[S.pc++] + S.x) & 0xFF; return S.memory[zp] | (S.memory[(zp+1) & 0xFF] << 8); }
static inline uint16_t am_izy()  { uint8_t zp = S.memory[S.pc++]; return (S.memory[zp] | (S.memory[(zp+1) & 0xFF] << 8)) + S.y; }

// ---- 6510 CPU step: execute one instruction, return cycle count ----
static int cpu_step() {
    uint8_t op = S.memory[S.pc++];
    uint16_t addr;
    uint8_t val, tmp;
    uint16_t tmp16;
    int cyc;

    switch (op) {
    // ---- LDA ----
    case 0xA9: val=mem_read(am_imm());  set_nz(S.a=val); return 2;
    case 0xA5: val=mem_read(am_zp());   set_nz(S.a=val); return 3;
    case 0xB5: val=mem_read(am_zpx());  set_nz(S.a=val); return 4;
    case 0xAD: val=mem_read(am_abs());  set_nz(S.a=val); return 4;
    case 0xBD: addr=am_abx(); val=mem_read(addr); set_nz(S.a=val); return 4;
    case 0xB9: addr=am_aby(); val=mem_read(addr); set_nz(S.a=val); return 4;
    case 0xA1: val=mem_read(am_izx());  set_nz(S.a=val); return 6;
    case 0xB1: addr=am_izy(); val=mem_read(addr); set_nz(S.a=val); return 5;

    // ---- LDX ----
    case 0xA2: val=mem_read(am_imm());  set_nz(S.x=val); return 2;
    case 0xA6: val=mem_read(am_zp());   set_nz(S.x=val); return 3;
    case 0xB6: val=mem_read(am_zpy());  set_nz(S.x=val); return 4;
    case 0xAE: val=mem_read(am_abs());  set_nz(S.x=val); return 4;
    case 0xBE: addr=am_aby(); val=mem_read(addr); set_nz(S.x=val); return 4;

    // ---- LDY ----
    case 0xA0: val=mem_read(am_imm());  set_nz(S.y=val); return 2;
    case 0xA4: val=mem_read(am_zp());   set_nz(S.y=val); return 3;
    case 0xB4: val=mem_read(am_zpx());  set_nz(S.y=val); return 4;
    case 0xAC: val=mem_read(am_abs());  set_nz(S.y=val); return 4;
    case 0xBC: addr=am_abx(); val=mem_read(addr); set_nz(S.y=val); return 4;

    // ---- STA ----
    case 0x85: mem_write(am_zp(),  S.a); return 3;
    case 0x95: mem_write(am_zpx(), S.a); return 4;
    case 0x8D: mem_write(am_abs(), S.a); return 4;
    case 0x9D: mem_write(am_abx(), S.a); return 5;
    case 0x99: mem_write(am_aby(), S.a); return 5;
    case 0x81: mem_write(am_izx(), S.a); return 6;
    case 0x91: mem_write(am_izy(), S.a); return 6;

    // ---- STX ----
    case 0x86: mem_write(am_zp(),  S.x); return 3;
    case 0x96: mem_write(am_zpy(), S.x); return 4;
    case 0x8E: mem_write(am_abs(), S.x); return 4;

    // ---- STY ----
    case 0x84: mem_write(am_zp(),  S.y); return 3;
    case 0x94: mem_write(am_zpx(), S.y); return 4;
    case 0x8C: mem_write(am_abs(), S.y); return 4;

    // ---- Transfer ----
    case 0xAA: set_nz(S.x = S.a); return 2;  // TAX
    case 0xA8: set_nz(S.y = S.a); return 2;  // TAY
    case 0x8A: set_nz(S.a = S.x); return 2;  // TXA
    case 0x98: set_nz(S.a = S.y); return 2;  // TYA
    case 0xBA: set_nz(S.x = S.sp); return 2; // TSX
    case 0x9A: S.sp = S.x; return 2;          // TXS

    // ---- AND ----
    case 0x29: S.a &= mem_read(am_imm());  set_nz(S.a); return 2;
    case 0x25: S.a &= mem_read(am_zp());   set_nz(S.a); return 3;
    case 0x35: S.a &= mem_read(am_zpx());  set_nz(S.a); return 4;
    case 0x2D: S.a &= mem_read(am_abs());  set_nz(S.a); return 4;
    case 0x3D: S.a &= mem_read(am_abx());  set_nz(S.a); return 4;
    case 0x39: S.a &= mem_read(am_aby());  set_nz(S.a); return 4;
    case 0x21: S.a &= mem_read(am_izx());  set_nz(S.a); return 6;
    case 0x31: S.a &= mem_read(am_izy());  set_nz(S.a); return 5;

    // ---- ORA ----
    case 0x09: S.a |= mem_read(am_imm());  set_nz(S.a); return 2;
    case 0x05: S.a |= mem_read(am_zp());   set_nz(S.a); return 3;
    case 0x15: S.a |= mem_read(am_zpx());  set_nz(S.a); return 4;
    case 0x0D: S.a |= mem_read(am_abs());  set_nz(S.a); return 4;
    case 0x1D: S.a |= mem_read(am_abx());  set_nz(S.a); return 4;
    case 0x19: S.a |= mem_read(am_aby());  set_nz(S.a); return 4;
    case 0x01: S.a |= mem_read(am_izx());  set_nz(S.a); return 6;
    case 0x11: S.a |= mem_read(am_izy());  set_nz(S.a); return 5;

    // ---- EOR ----
    case 0x49: S.a ^= mem_read(am_imm());  set_nz(S.a); return 2;
    case 0x45: S.a ^= mem_read(am_zp());   set_nz(S.a); return 3;
    case 0x55: S.a ^= mem_read(am_zpx());  set_nz(S.a); return 4;
    case 0x4D: S.a ^= mem_read(am_abs());  set_nz(S.a); return 4;
    case 0x5D: S.a ^= mem_read(am_abx());  set_nz(S.a); return 4;
    case 0x59: S.a ^= mem_read(am_aby());  set_nz(S.a); return 4;
    case 0x41: S.a ^= mem_read(am_izx());  set_nz(S.a); return 6;
    case 0x51: S.a ^= mem_read(am_izy());  set_nz(S.a); return 5;

    // ---- ADC ----
    #define DO_ADC(v) do { \
        val = (v); \
        tmp16 = (uint16_t)S.a + val + (S.st & FLAG_C); \
        S.st = (S.st & ~(FLAG_C|FLAG_Z|FLAG_N|FLAG_V)) | \
               (tmp16 > 0xFF ? FLAG_C : 0) | \
               ((~(S.a ^ val) & (S.a ^ tmp16) & 0x80) ? FLAG_V : 0); \
        S.a = tmp16 & 0xFF; \
        set_nz(S.a); \
    } while(0)
    case 0x69: DO_ADC(mem_read(am_imm()));  return 2;
    case 0x65: DO_ADC(mem_read(am_zp()));   return 3;
    case 0x75: DO_ADC(mem_read(am_zpx()));  return 4;
    case 0x6D: DO_ADC(mem_read(am_abs()));  return 4;
    case 0x7D: DO_ADC(mem_read(am_abx()));  return 4;
    case 0x79: DO_ADC(mem_read(am_aby()));  return 4;
    case 0x61: DO_ADC(mem_read(am_izx()));  return 6;
    case 0x71: DO_ADC(mem_read(am_izy()));  return 5;

    // ---- SBC ----
    #define DO_SBC(v) do { \
        val = (v); \
        tmp16 = (uint16_t)S.a - val - !(S.st & FLAG_C); \
        S.st = (S.st & ~(FLAG_C|FLAG_Z|FLAG_N|FLAG_V)) | \
               (tmp16 < 0x100 ? FLAG_C : 0) | \
               (((S.a ^ val) & (S.a ^ tmp16) & 0x80) ? FLAG_V : 0); \
        S.a = tmp16 & 0xFF; \
        set_nz(S.a); \
    } while(0)
    case 0xE9: DO_SBC(mem_read(am_imm()));  return 2;
    case 0xEB: DO_SBC(mem_read(am_imm()));  return 2; // illegal SBC #imm
    case 0xE5: DO_SBC(mem_read(am_zp()));   return 3;
    case 0xF5: DO_SBC(mem_read(am_zpx()));  return 4;
    case 0xED: DO_SBC(mem_read(am_abs()));  return 4;
    case 0xFD: DO_SBC(mem_read(am_abx()));  return 4;
    case 0xF9: DO_SBC(mem_read(am_aby()));  return 4;
    case 0xE1: DO_SBC(mem_read(am_izx()));  return 6;
    case 0xF1: DO_SBC(mem_read(am_izy()));  return 5;

    // ---- CMP ----
    #define DO_CMP(r, v) do { \
        val = (v); \
        tmp16 = (uint16_t)(r) - val; \
        S.st = (S.st & ~(FLAG_C|FLAG_Z|FLAG_N)) | \
               (tmp16 < 0x100 ? FLAG_C : 0); \
        set_nz(tmp16 & 0xFF); \
    } while(0)
    case 0xC9: DO_CMP(S.a, mem_read(am_imm()));  return 2;
    case 0xC5: DO_CMP(S.a, mem_read(am_zp()));   return 3;
    case 0xD5: DO_CMP(S.a, mem_read(am_zpx()));  return 4;
    case 0xCD: DO_CMP(S.a, mem_read(am_abs()));  return 4;
    case 0xDD: DO_CMP(S.a, mem_read(am_abx()));  return 4;
    case 0xD9: DO_CMP(S.a, mem_read(am_aby()));  return 4;
    case 0xC1: DO_CMP(S.a, mem_read(am_izx()));  return 6;
    case 0xD1: DO_CMP(S.a, mem_read(am_izy()));  return 5;

    // ---- CPX ----
    case 0xE0: DO_CMP(S.x, mem_read(am_imm()));  return 2;
    case 0xE4: DO_CMP(S.x, mem_read(am_zp()));   return 3;
    case 0xEC: DO_CMP(S.x, mem_read(am_abs()));  return 4;

    // ---- CPY ----
    case 0xC0: DO_CMP(S.y, mem_read(am_imm()));  return 2;
    case 0xC4: DO_CMP(S.y, mem_read(am_zp()));   return 3;
    case 0xCC: DO_CMP(S.y, mem_read(am_abs()));  return 4;

    // ---- BIT ----
    case 0x24: val=mem_read(am_zp());  S.st=(S.st&~(FLAG_N|FLAG_V|FLAG_Z))|(val&0xC0)|((S.a&val)?0:FLAG_Z); return 3;
    case 0x2C: val=mem_read(am_abs()); S.st=(S.st&~(FLAG_N|FLAG_V|FLAG_Z))|(val&0xC0)|((S.a&val)?0:FLAG_Z); return 4;

    // ---- INC/DEC memory ----
    #define DO_RMW(am, op, cyc) addr=am(); val=mem_read(addr); val op; mem_write(addr,val); set_nz(val); return cyc
    case 0xE6: DO_RMW(am_zp,  ++, 5);
    case 0xF6: DO_RMW(am_zpx, ++, 6);
    case 0xEE: DO_RMW(am_abs, ++, 6);
    case 0xFE: DO_RMW(am_abx, ++, 7);
    case 0xC6: DO_RMW(am_zp,  --, 5);
    case 0xD6: DO_RMW(am_zpx, --, 6);
    case 0xCE: DO_RMW(am_abs, --, 6);
    case 0xDE: DO_RMW(am_abx, --, 7);

    // ---- INX/INY/DEX/DEY ----
    case 0xE8: set_nz(++S.x); return 2;
    case 0xC8: set_nz(++S.y); return 2;
    case 0xCA: set_nz(--S.x); return 2;
    case 0x88: set_nz(--S.y); return 2;

    // ---- ASL ----
    #define DO_ASL(v) tmp = (v); S.st = (S.st & ~FLAG_C) | (tmp >> 7); tmp <<= 1; set_nz(tmp)
    case 0x0A: DO_ASL(S.a); S.a=tmp; return 2;
    case 0x06: addr=am_zp();  DO_ASL(mem_read(addr)); mem_write(addr,tmp); return 5;
    case 0x16: addr=am_zpx(); DO_ASL(mem_read(addr)); mem_write(addr,tmp); return 6;
    case 0x0E: addr=am_abs(); DO_ASL(mem_read(addr)); mem_write(addr,tmp); return 6;
    case 0x1E: addr=am_abx(); DO_ASL(mem_read(addr)); mem_write(addr,tmp); return 7;

    // ---- LSR ----
    #define DO_LSR(v) tmp = (v); S.st = (S.st & ~FLAG_C) | (tmp & 1); tmp >>= 1; set_nz(tmp)
    case 0x4A: DO_LSR(S.a); S.a=tmp; return 2;
    case 0x46: addr=am_zp();  DO_LSR(mem_read(addr)); mem_write(addr,tmp); return 5;
    case 0x56: addr=am_zpx(); DO_LSR(mem_read(addr)); mem_write(addr,tmp); return 6;
    case 0x4E: addr=am_abs(); DO_LSR(mem_read(addr)); mem_write(addr,tmp); return 6;
    case 0x5E: addr=am_abx(); DO_LSR(mem_read(addr)); mem_write(addr,tmp); return 7;

    // ---- ROL ----
    #define DO_ROL(v) do { \
        tmp = (v); uint8_t c = S.st & FLAG_C; \
        S.st = (S.st & ~FLAG_C) | (tmp >> 7); \
        tmp = (tmp << 1) | c; set_nz(tmp); \
    } while(0)
    case 0x2A: DO_ROL(S.a); S.a=tmp; return 2;
    case 0x26: addr=am_zp();  DO_ROL(mem_read(addr)); mem_write(addr,tmp); return 5;
    case 0x36: addr=am_zpx(); DO_ROL(mem_read(addr)); mem_write(addr,tmp); return 6;
    case 0x2E: addr=am_abs(); DO_ROL(mem_read(addr)); mem_write(addr,tmp); return 6;
    case 0x3E: addr=am_abx(); DO_ROL(mem_read(addr)); mem_write(addr,tmp); return 7;

    // ---- ROR ----
    #define DO_ROR(v) do { \
        tmp = (v); uint8_t c = (S.st & FLAG_C) << 7; \
        S.st = (S.st & ~FLAG_C) | (tmp & 1); \
        tmp = (tmp >> 1) | c; set_nz(tmp); \
    } while(0)
    case 0x6A: DO_ROR(S.a); S.a=tmp; return 2;
    case 0x66: addr=am_zp();  DO_ROR(mem_read(addr)); mem_write(addr,tmp); return 5;
    case 0x76: addr=am_zpx(); DO_ROR(mem_read(addr)); mem_write(addr,tmp); return 6;
    case 0x6E: addr=am_abs(); DO_ROR(mem_read(addr)); mem_write(addr,tmp); return 6;
    case 0x7E: addr=am_abx(); DO_ROR(mem_read(addr)); mem_write(addr,tmp); return 7;

    // ---- Branches ----
    #define BRANCH(cond) do { \
        int8_t off = (int8_t)S.memory[S.pc++]; \
        if (cond) { S.pc = (uint16_t)(S.pc + off); return 3; } \
        return 2; \
    } while(0)
    case 0x10: BRANCH(!(S.st & FLAG_N));  // BPL
    case 0x30: BRANCH(S.st & FLAG_N);     // BMI
    case 0x50: BRANCH(!(S.st & FLAG_V));  // BVC
    case 0x70: BRANCH(S.st & FLAG_V);     // BVS
    case 0x90: BRANCH(!(S.st & FLAG_C));  // BCC
    case 0xB0: BRANCH(S.st & FLAG_C);     // BCS
    case 0xD0: BRANCH(!(S.st & FLAG_Z));  // BNE
    case 0xF0: BRANCH(S.st & FLAG_Z);     // BEQ

    // ---- JMP ----
    case 0x4C: S.pc = am_abs(); return 3;
    case 0x6C: { // JMP indirect (with 6502 page-crossing bug)
        uint16_t ptr = am_abs();
        uint16_t lo = S.memory[ptr];
        uint16_t hi = S.memory[(ptr & 0xFF00) | ((ptr + 1) & 0xFF)];
        S.pc = (hi << 8) | lo;
        return 5;
    }

    // ---- JSR / RTS / RTI ----
    case 0x20: addr = am_abs(); push16(S.pc - 1); S.pc = addr; return 6;
    case 0x60: S.pc = pull16() + 1; return 6;
    case 0x40: S.st = pull8() | FLAG_U; S.pc = pull16(); return 6;

    // ---- Stack ----
    case 0x48: push8(S.a); return 3;                         // PHA
    case 0x08: push8(S.st | FLAG_B | FLAG_U); return 3;     // PHP
    case 0x68: set_nz(S.a = pull8()); return 4;             // PLA
    case 0x28: S.st = pull8() | FLAG_U; return 4;           // PLP

    // ---- Flag instructions ----
    case 0x18: S.st &= ~FLAG_C; return 2;  // CLC
    case 0x38: S.st |= FLAG_C;  return 2;  // SEC
    case 0x58: S.st &= ~FLAG_I; return 2;  // CLI
    case 0x78: S.st |= FLAG_I;  return 2;  // SEI
    case 0xD8: S.st &= ~FLAG_D; return 2;  // CLD
    case 0xF8: S.st |= FLAG_D;  return 2;  // SED
    case 0xB8: S.st &= ~FLAG_V; return 2;  // CLV

    // ---- BRK ----
    case 0x00:
        S.pc++;
        push16(S.pc);
        push8(S.st | FLAG_B | FLAG_U);
        S.st |= FLAG_I;
        S.pc = S.memory[0xFFFE] | (S.memory[0xFFFF] << 8);
        return 7;

    // ---- NOP ----
    case 0xEA: return 2;

    // ==== Illegal opcodes commonly used by SID music ====

    // LAX - LDA + LDX
    case 0xA7: val=mem_read(am_zp());   S.a=S.x=val; set_nz(val); return 3;
    case 0xB7: val=mem_read(am_zpy());  S.a=S.x=val; set_nz(val); return 4;
    case 0xAF: val=mem_read(am_abs());  S.a=S.x=val; set_nz(val); return 4;
    case 0xBF: val=mem_read(am_aby());  S.a=S.x=val; set_nz(val); return 4;
    case 0xA3: val=mem_read(am_izx());  S.a=S.x=val; set_nz(val); return 6;
    case 0xB3: val=mem_read(am_izy());  S.a=S.x=val; set_nz(val); return 5;

    // SAX - store A & X
    case 0x87: mem_write(am_zp(),  S.a & S.x); return 3;
    case 0x97: mem_write(am_zpy(), S.a & S.x); return 4;
    case 0x8F: mem_write(am_abs(), S.a & S.x); return 4;
    case 0x83: mem_write(am_izx(), S.a & S.x); return 6;

    // DCP - DEC + CMP
    #define DO_DCP(am, cyc) addr=am(); val=mem_read(addr)-1; mem_write(addr,val); DO_CMP(S.a,val); return cyc
    case 0xC7: DO_DCP(am_zp,  5);
    case 0xD7: DO_DCP(am_zpx, 6);
    case 0xCF: DO_DCP(am_abs, 6);
    case 0xDF: DO_DCP(am_abx, 7);
    case 0xDB: DO_DCP(am_aby, 7);
    case 0xC3: DO_DCP(am_izx, 8);
    case 0xD3: DO_DCP(am_izy, 8);

    // ISC (ISB) - INC + SBC
    #define DO_ISC(am, cyc) addr=am(); val=mem_read(addr)+1; mem_write(addr,val); DO_SBC(val); return cyc
    case 0xE7: DO_ISC(am_zp,  5);
    case 0xF7: DO_ISC(am_zpx, 6);
    case 0xEF: DO_ISC(am_abs, 6);
    case 0xFF: DO_ISC(am_abx, 7);
    case 0xFB: DO_ISC(am_aby, 7);
    case 0xE3: DO_ISC(am_izx, 8);
    case 0xF3: DO_ISC(am_izy, 8);

    // SLO - ASL + ORA
    #define DO_SLO(am, cyc) addr=am(); val=mem_read(addr); S.st=(S.st&~FLAG_C)|(val>>7); val<<=1; mem_write(addr,val); S.a|=val; set_nz(S.a); return cyc
    case 0x07: DO_SLO(am_zp,  5);
    case 0x17: DO_SLO(am_zpx, 6);
    case 0x0F: DO_SLO(am_abs, 6);
    case 0x1F: DO_SLO(am_abx, 7);
    case 0x1B: DO_SLO(am_aby, 7);
    case 0x03: DO_SLO(am_izx, 8);
    case 0x13: DO_SLO(am_izy, 8);

    // RLA - ROL + AND
    #define DO_RLA(am, cyc) do { \
        addr=am(); val=mem_read(addr); uint8_t c=S.st&FLAG_C; \
        S.st=(S.st&~FLAG_C)|(val>>7); val=(val<<1)|c; \
        mem_write(addr,val); S.a&=val; set_nz(S.a); return cyc; \
    } while(0)
    case 0x27: DO_RLA(am_zp,  5);
    case 0x37: DO_RLA(am_zpx, 6);
    case 0x2F: DO_RLA(am_abs, 6);
    case 0x3F: DO_RLA(am_abx, 7);
    case 0x3B: DO_RLA(am_aby, 7);
    case 0x23: DO_RLA(am_izx, 8);
    case 0x33: DO_RLA(am_izy, 8);

    // SRE - LSR + EOR
    #define DO_SRE(am, cyc) addr=am(); val=mem_read(addr); S.st=(S.st&~FLAG_C)|(val&1); val>>=1; mem_write(addr,val); S.a^=val; set_nz(S.a); return cyc
    case 0x47: DO_SRE(am_zp,  5);
    case 0x57: DO_SRE(am_zpx, 6);
    case 0x4F: DO_SRE(am_abs, 6);
    case 0x5F: DO_SRE(am_abx, 7);
    case 0x5B: DO_SRE(am_aby, 7);
    case 0x43: DO_SRE(am_izx, 8);
    case 0x53: DO_SRE(am_izy, 8);

    // RRA - ROR + ADC
    #define DO_RRA(am, cyc) do { \
        addr=am(); val=mem_read(addr); uint8_t c=(S.st&FLAG_C)<<7; \
        S.st=(S.st&~FLAG_C)|(val&1); val=(val>>1)|c; \
        mem_write(addr,val); DO_ADC(val); return cyc; \
    } while(0)
    case 0x67: DO_RRA(am_zp,  5);
    case 0x77: DO_RRA(am_zpx, 6);
    case 0x6F: DO_RRA(am_abs, 6);
    case 0x7F: DO_RRA(am_abx, 7);
    case 0x7B: DO_RRA(am_aby, 7);
    case 0x63: DO_RRA(am_izx, 8);
    case 0x73: DO_RRA(am_izy, 8);

    // ANC - AND + set C from N
    case 0x0B: case 0x2B:
        S.a &= mem_read(am_imm());
        set_nz(S.a);
        S.st = (S.st & ~FLAG_C) | ((S.a >> 7) & FLAG_C);
        return 2;

    // ALR - AND + LSR
    case 0x4B:
        S.a &= mem_read(am_imm());
        S.st = (S.st & ~FLAG_C) | (S.a & 1);
        S.a >>= 1;
        set_nz(S.a);
        return 2;

    // ARR - AND + ROR (simplified)
    case 0x6B:
        S.a &= mem_read(am_imm());
        S.a = (S.a >> 1) | ((S.st & FLAG_C) << 7);
        set_nz(S.a);
        S.st = (S.st & ~(FLAG_C|FLAG_V)) |
               ((S.a >> 6) & FLAG_C) |
               (((S.a >> 6) ^ (S.a >> 5)) & 1) << 6;
        return 2;

    // AXS (SBX) - (A & X) - imm -> X
    case 0xCB:
        val = mem_read(am_imm());
        tmp16 = (uint16_t)(S.a & S.x) - val;
        S.st = (S.st & ~FLAG_C) | (tmp16 < 0x100 ? FLAG_C : 0);
        S.x = tmp16 & 0xFF;
        set_nz(S.x);
        return 2;

    // Illegal NOPs (various sizes)
    case 0x1A: case 0x3A: case 0x5A: case 0x7A: case 0xDA: case 0xFA:
        return 2; // 1-byte NOPs
    case 0x80: case 0x82: case 0x89: case 0xC2: case 0xE2:
        S.pc++; return 2; // 2-byte NOPs
    case 0x04: case 0x44: case 0x64:
        S.pc++; return 3; // 2-byte ZP NOPs
    case 0x14: case 0x34: case 0x54: case 0x74: case 0xD4: case 0xF4:
        S.pc++; return 4; // 2-byte ZPX NOPs
    case 0x0C:
        S.pc += 2; return 4; // 3-byte ABS NOP
    case 0x1C: case 0x3C: case 0x5C: case 0x7C: case 0xDC: case 0xFC:
        S.pc += 2; return 4; // 3-byte ABX NOPs

    // KIL opcodes - halt CPU (treat as NOP for safety)
    case 0x02: case 0x12: case 0x22: case 0x32: case 0x42: case 0x52:
    case 0x62: case 0x72: case 0x92: case 0xB2: case 0xD2: case 0xF2:
        return 2;

    // Remaining rarely-used illegals - treat as NOP
    default:
        return 2;
    }
}

// ---- CPU init ----
static void cpu_init(uint16_t pc) {
    S.pc = pc;
    S.sp = 0xFF;
    S.a = S.x = S.y = 0;
    S.st = FLAG_U | FLAG_I;
}

// ---- Run subroutine until RTS (with cycle limit) ----
static void cpu_jsr(uint16_t addr, uint32_t maxCycles) {
    // Set up like the C64 kernal does: push a sentinel return address
    push16(0xFFFF);  // Will RTS to $0000
    S.pc = addr;
    uint32_t cyclesRun = 0;
    uint8_t initialSP = S.sp + 2;  // SP before our push

    while (cyclesRun < maxCycles) {
        int cyc = cpu_step();
        cyclesRun += cyc;
        S.totalCycles += cyc;

        // Detect RTS back to our sentinel
        if (S.sp >= initialSP) break;
        // Also break on BRK to kernal
        if (S.pc == 0 || S.pc == 0xFFFF) break;
    }
}

// ---- SID file header (PSID/RSID v1-v4) ----
#pragma pack(push, 1)
struct SIDFileHeader {
    char     magicID[4];
    uint8_t  versionHi, versionLo;
    uint8_t  dataOffsetHi, dataOffsetLo;
    uint8_t  loadAddrHi, loadAddrLo;
    uint8_t  initAddrHi, initAddrLo;
    uint8_t  playAddrHi, playAddrLo;
    uint8_t  songsHi, songsLo;
    uint8_t  startSongHi, startSongLo;
    uint8_t  speedB3, speedB2, speedB1, speedB0;
    char     name[32];
    char     author[32];
    char     copyright[32];
    // v2+ fields follow at offset 0x76
};
#pragma pack(pop)

static uint16_t be16(uint8_t hi, uint8_t lo) { return (hi << 8) | lo; }

// ====================================================================
// WASM-exported functions
// ====================================================================

EMSCRIPTEN_KEEPALIVE
void audio_init(double sampleRate) {
    // Zero POD fields without touching reSID::SID objects (which have constructors)
    S.pc = 0; S.sp = 0; S.a = 0; S.x = 0; S.y = 0; S.st = 0;
    memset(S.memory, 0, sizeof(S.memory));
    S.sidCount = 1;
    for (int i = 0; i < MAX_SID_CHIPS; i++) {
        S.sidAddress[i] = 0;
        S.sid[i].reset();
    }
    S.sidAddress[0] = 0xD400;
    S.loadAddress = 0; S.initAddress = 0; S.playAddress = 0;
    S.songs = 0; S.startSong = 0; S.speed = 0;
    S.name[0] = 0; S.author[0] = 0; S.copyright[0] = 0;
    S.flags = 0; S.secondSIDAddr = 0; S.thirdSIDAddr = 0;
    S.clockFreq = PAL_CLOCK;
    S.sampleRate = sampleRate > 0 ? sampleRate : 48000.0;
    S.cyclesPerFrame = PAL_CYCLES_PER_FRAME;
    S.currentSubtune = 0;
    S.isNTSC = false;
    S.loaded = false;
    S.remainingCycles = 0;
    S.playRoutineActive = false;
    S.totalCycles = 0;
    S.chipModel = 6581;
}

EMSCRIPTEN_KEEPALIVE
int audio_load_sid(const uint8_t* data, int length) {
    if (length < 0x7C) return -1;  // Too small

    const SIDFileHeader* hdr = (const SIDFileHeader*)data;

    // Validate magic
    if (memcmp(hdr->magicID, "PSID", 4) != 0 &&
        memcmp(hdr->magicID, "RSID", 4) != 0) {
        return -2;
    }

    uint16_t version    = be16(hdr->versionHi, hdr->versionLo);
    uint16_t dataOffset = be16(hdr->dataOffsetHi, hdr->dataOffsetLo);
    S.loadAddress  = be16(hdr->loadAddrHi, hdr->loadAddrLo);
    S.initAddress  = be16(hdr->initAddrHi, hdr->initAddrLo);
    S.playAddress  = be16(hdr->playAddrHi, hdr->playAddrLo);
    S.songs        = be16(hdr->songsHi, hdr->songsLo);
    S.startSong    = be16(hdr->startSongHi, hdr->startSongLo);
    S.speed        = ((uint32_t)hdr->speedB3 << 24) | ((uint32_t)hdr->speedB2 << 16) |
                     ((uint32_t)hdr->speedB1 << 8)  | hdr->speedB0;

    // Copy strings
    memcpy(S.name, hdr->name, 32); S.name[32] = 0;
    memcpy(S.author, hdr->author, 32); S.author[32] = 0;
    memcpy(S.copyright, hdr->copyright, 32); S.copyright[32] = 0;

    // If loadAddress is 0, first two bytes of data are the load address (little-endian)
    const uint8_t* musicData = data + dataOffset;
    int musicLen = length - dataOffset;
    if (S.loadAddress == 0 && musicLen >= 2) {
        S.loadAddress = musicData[0] | (musicData[1] << 8);
        musicData += 2;
        musicLen -= 2;
    }
    if (S.initAddress == 0) S.initAddress = S.loadAddress;

    // v2+ fields
    S.flags = 0;
    S.secondSIDAddr = 0;
    S.thirdSIDAddr = 0;
    if (version >= 2 && length >= 0x7C) {
        S.flags = (data[0x76] << 8) | data[0x77];
        if (version >= 3 && length > 0x7A) S.secondSIDAddr = data[0x7A];
        if (version >= 4 && length > 0x7B) S.thirdSIDAddr  = data[0x7B];
    }

    // Detect PAL/NTSC from flags
    S.isNTSC = (S.flags & 0x0C) == 0x08;
    S.clockFreq = S.isNTSC ? NTSC_CLOCK : PAL_CLOCK;
    S.cyclesPerFrame = S.isNTSC ? NTSC_CYCLES_PER_FRAME : PAL_CYCLES_PER_FRAME;

    // Detect chip model from flags
    uint8_t sidModelBits = (S.flags >> 4) & 0x03;
    S.chipModel = (sidModelBits >= 2) ? 8580 : 6581;

    // Set up multi-SID
    S.sidCount = 1;
    S.sidAddress[0] = 0xD400;
    if (S.secondSIDAddr >= 0x42 && (S.secondSIDAddr < 0x80 || S.secondSIDAddr >= 0xE0)) {
        S.sidAddress[S.sidCount++] = 0xD000 + S.secondSIDAddr * 16;
    }
    if (S.thirdSIDAddr >= 0x42 && (S.thirdSIDAddr < 0x80 || S.thirdSIDAddr >= 0xE0)) {
        S.sidAddress[S.sidCount++] = 0xD000 + S.thirdSIDAddr * 16;
    }

    // Initialize CPU memory
    memset(S.memory, 0, 65536);
    S.memory[0x01] = 0x37;  // Default processor port

    // Load music data into memory
    if (musicLen > 0 && S.loadAddress + musicLen <= 65536) {
        memcpy(&S.memory[S.loadAddress], musicData, musicLen);
    }

    // Set up I/O area defaults
    S.memory[0xDC04] = 0x24;  // CIA1 Timer A default
    S.memory[0xDC05] = 0x40;

    // ---- Minimal C64 Kernal environment for SID compatibility ----
    // Many SID tunes JSR to Kernal ROM routines or JMP to IRQ exit points.
    // Without stubs, those addresses contain 0x00 (BRK) which causes infinite
    // BRK loops that eat all CPU cycles and prevent the init/play routines
    // from completing.  Only place stubs where memory is still zero (i.e. not
    // overwritten by the SID's own code/data).

    // Kernal IRQ exit at $EA31  (PLA/TAY/PLA/TAX/PLA/RTI)
    // Play routines that are IRQ handlers typically JMP $EA31 to exit.
    if (S.memory[0xEA31] == 0) {
        static const uint8_t ea31[] = {0x68,0xA8,0x68,0xAA,0x68,0x40};
        memcpy(&S.memory[0xEA31], ea31, sizeof(ea31));
    }

    // $EA81 - another common Kernal IRQ exit (just RTI)
    if (S.memory[0xEA81] == 0) {
        S.memory[0xEA81] = 0x40; // RTI
    }

    // Kernal jump table ($FF81-$FFF3, every 3 bytes) → RTS
    // SID init routines sometimes call SCINIT ($FF81), IOINIT ($FF84), etc.
    for (int addr = 0xFF81; addr <= 0xFFF3; addr += 3) {
        if (S.memory[addr] == 0) {
            S.memory[addr] = 0x60; // RTS
        }
    }

    // RTI at $FF48 (standard Kernal IRQ entry point)
    if (S.memory[0xFF48] == 0) {
        S.memory[0xFF48] = 0x40; // RTI
    }

    // Hardware IRQ vector ($FFFE/$FFFF) → $FF48 (RTI)
    if (S.memory[0xFFFE] == 0 && S.memory[0xFFFF] == 0) {
        S.memory[0xFFFE] = 0x48;
        S.memory[0xFFFF] = 0xFF;
    }

    // Hardware NMI vector ($FFFA/$FFFB) → $FF48 (RTI)
    if (S.memory[0xFFFA] == 0 && S.memory[0xFFFB] == 0) {
        S.memory[0xFFFA] = 0x48;
        S.memory[0xFFFB] = 0xFF;
    }

    // Software IRQ vector ($0314/$0315) → $EA31 (Kernal IRQ exit)
    if (S.memory[0x0314] == 0 && S.memory[0x0315] == 0) {
        S.memory[0x0314] = 0x31;
        S.memory[0x0315] = 0xEA;
    }

    // Software NMI vector ($0318/$0319) → $EA81 (RTI)
    if (S.memory[0x0318] == 0 && S.memory[0x0319] == 0) {
        S.memory[0x0318] = 0x81;
        S.memory[0x0319] = 0xEA;
    }

    // Initialize reSID chips
    reSID::chip_model model = (S.chipModel == 8580) ? reSID::MOS8580 : reSID::MOS6581;
    for (int i = 0; i < S.sidCount; i++) {
        S.sid[i].reset();
        S.sid[i].set_chip_model(model);
        S.sid[i].set_sampling_parameters(S.clockFreq, reSID::SAMPLE_FAST, S.sampleRate);
    }

    // Handle per-chip model if different (v2+ flags)
    if (version >= 2) {
        uint8_t model2bits = (S.flags >> 6) & 0x03;
        if (S.sidCount > 1 && model2bits >= 2) {
            S.sid[1].set_chip_model(reSID::MOS8580);
            S.sid[1].set_sampling_parameters(S.clockFreq, reSID::SAMPLE_FAST, S.sampleRate);
        }
    }

    S.loaded = true;
    S.totalCycles = 0;
    return 0;
}

EMSCRIPTEN_KEEPALIVE
void audio_set_subtune(int subtune) {
    if (!S.loaded) return;
    S.currentSubtune = subtune;

    // Reset SID chips
    for (int i = 0; i < S.sidCount; i++) {
        S.sid[i].reset();
    }

    // Reset memory I/O
    S.memory[0x01] = 0x37;

    // Init CPU and call init routine with subtune in A
    cpu_init(S.initAddress);
    S.a = subtune;
    S.totalCycles = 0;

    // Run init routine (with generous cycle limit)
    cpu_jsr(S.initAddress, 1000000);

    // Detect CIA timer-based playback
    if (S.speed & (1 << (subtune & 31))) {
        // CIA timer mode - check if init routine set CIA timer
        uint16_t timerVal = S.memory[0xDC04] | (S.memory[0xDC05] << 8);
        if (timerVal > 0) {
            S.cyclesPerFrame = timerVal;
        }
    }

    // Detect play address from vectors if not specified
    if (S.playAddress == 0) {
        if ((S.memory[0x01] & 3) < 2) {
            S.playAddress = S.memory[0xFFFE] | (S.memory[0xFFFF] << 8);
        } else {
            S.playAddress = S.memory[0x0314] | (S.memory[0x0315] << 8);
        }
    }

    S.remainingCycles = 0;
}

EMSCRIPTEN_KEEPALIVE
int audio_generate(int16_t* buffer, int numSamples) {
    if (!S.loaded || numSamples <= 0) return 0;

    // Temporary buffer for multi-SID mixing
    int16_t mixBuf[8192];
    int totalGenerated = 0;

    int loopGuard = 0;
    const int maxLoops = numSamples + 256;  // Safety limit

    while (totalGenerated < numSamples && loopGuard++ < maxLoops) {
        // If we've exhausted the current frame, call the play routine
        if (S.remainingCycles <= 0) {
            if (S.playAddress == 0) break;  // No play routine
            dbg_sid_writes = 0;
            uint16_t pc_before = S.pc;
            uint8_t sp_before = S.sp;
            cpu_jsr(S.playAddress, (uint32_t)S.cyclesPerFrame);
            dbg_play_cycles = S.cyclesPerFrame; // approximate
            S.remainingCycles += S.cyclesPerFrame;
        }

        // Clock reSID and generate samples from chip 0
        int remaining = numSamples - totalGenerated;
        reSID::cycle_count delta = S.remainingCycles;
        int generated = S.sid[0].clock(delta, buffer + totalGenerated, remaining);
        int cyclesConsumed = S.remainingCycles - delta;

        // Generate and mix additional SID chips
        for (int chip = 1; chip < S.sidCount; chip++) {
            reSID::cycle_count delta2 = cyclesConsumed;
            int gen2 = S.sid[chip].clock(delta2, mixBuf, generated);
            for (int s = 0; s < gen2; s++) {
                int mixed = (int)buffer[totalGenerated + s] + mixBuf[s];
                if (mixed > 32767) mixed = 32767;
                if (mixed < -32768) mixed = -32768;
                buffer[totalGenerated + s] = (int16_t)mixed;
            }
        }

        S.remainingCycles = delta;  // reSID updates delta with remaining cycles
        totalGenerated += generated;
        S.totalCycles += cyclesConsumed;

        // If clock() generated 0 samples and consumed 0 cycles, force progress
        if (generated == 0 && cyclesConsumed == 0) {
            S.remainingCycles = 0;  // Force next frame
        }
    }

    return totalGenerated;
}

EMSCRIPTEN_KEEPALIVE
void audio_set_model(int model) {
    S.chipModel = model;
    reSID::chip_model m = (model == 8580) ? reSID::MOS8580 : reSID::MOS6581;
    for (int i = 0; i < S.sidCount; i++) {
        S.sid[i].set_chip_model(m);
    }
}

EMSCRIPTEN_KEEPALIVE
void audio_set_sampling_method(int method) {
    reSID::sampling_method m;
    switch (method) {
        case 1:  m = reSID::SAMPLE_INTERPOLATE; break;
        case 2:  m = reSID::SAMPLE_RESAMPLE; break;
        default: m = reSID::SAMPLE_FAST; break;
    }
    for (int i = 0; i < S.sidCount; i++) {
        S.sid[i].set_sampling_parameters(S.clockFreq, m, S.sampleRate);
    }
}

// ---- Metadata accessors ----

EMSCRIPTEN_KEEPALIVE
const char* audio_get_title() { return S.name; }

EMSCRIPTEN_KEEPALIVE
const char* audio_get_author() { return S.author; }

EMSCRIPTEN_KEEPALIVE
const char* audio_get_copyright() { return S.copyright; }

EMSCRIPTEN_KEEPALIVE
int audio_get_subtune_count() { return S.songs; }

EMSCRIPTEN_KEEPALIVE
int audio_get_default_subtune() { return S.startSong; }

EMSCRIPTEN_KEEPALIVE
int audio_get_sid_model() { return S.chipModel; }

EMSCRIPTEN_KEEPALIVE
int audio_get_sid_count() { return S.sidCount; }

EMSCRIPTEN_KEEPALIVE
double audio_get_play_time() {
    return (double)S.totalCycles / S.clockFreq;
}

EMSCRIPTEN_KEEPALIVE
int audio_get_is_ntsc() { return S.isNTSC ? 1 : 0; }

EMSCRIPTEN_KEEPALIVE
int audio_get_play_address() { return S.playAddress; }

EMSCRIPTEN_KEEPALIVE
int audio_get_volume() { return S.memory[0xD418] & 0x0F; }

EMSCRIPTEN_KEEPALIVE
int audio_read_memory(int addr) { return S.memory[addr & 0xFFFF]; }

EMSCRIPTEN_KEEPALIVE
int audio_get_dbg_sid_writes() { return dbg_sid_writes; }

EMSCRIPTEN_KEEPALIVE
int audio_get_dbg_play_pc() { return S.pc; }

EMSCRIPTEN_KEEPALIVE
int audio_get_dbg_play_sp() { return S.sp; }

EMSCRIPTEN_KEEPALIVE
void audio_cleanup() {
    for (int i = 0; i < MAX_SID_CHIPS; i++) {
        S.sid[i].reset();
    }
    S.loaded = false;
}

} // extern "C"
