#pragma once

#include "Common.h"

#include <array>
#include <functional>
#include <limits>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <map>
#include <unordered_map>
#include <vector>

// Forward declaration of implementation class
class CPU6510Impl;

// Addressing modes
enum class AddressingMode {
    Implied,
    Immediate,
    ZeroPage,
    ZeroPageX,
    ZeroPageY,
    Absolute,
    AbsoluteX,
    AbsoluteY,
    Indirect,
    IndirectX,
    IndirectY,
    Relative,
    Accumulator
};

// Memory access flags (using enum class for type safety)
enum class MemoryAccessFlag : u8 {
    Execute = 1 << 0,
    Read = 1 << 1,
    Write = 1 << 2,
    JumpTarget = 1 << 3,
    OpCode = 1 << 4,
};

// Overload bitwise operators for MemoryAccessFlag
inline MemoryAccessFlag operator|(MemoryAccessFlag a, MemoryAccessFlag b) {
    return static_cast<MemoryAccessFlag>(static_cast<u8>(a) | static_cast<u8>(b));
}

inline MemoryAccessFlag& operator|=(MemoryAccessFlag& a, MemoryAccessFlag b) {
    a = a | b;
    return a;
}

inline bool operator&(MemoryAccessFlag a, MemoryAccessFlag b) {
    return (static_cast<u8>(a) & static_cast<u8>(b)) != 0;
}

// Processor Status Flags as an enum class
enum class StatusFlag : u8 {
    Carry = 0x01,      // Carry Bit
    Zero = 0x02,       // Zero
    Interrupt = 0x04,  // Disable Interrupts
    Decimal = 0x08,    // Decimal Mode (ignored on C64)
    Break = 0x10,      // Break
    Unused = 0x20,     // Unused (always set to 1 internally)
    Overflow = 0x40,   // Overflow
    Negative = 0x80    // Negative
};

// Overload bitwise operators for StatusFlag
inline u8 operator|(StatusFlag a, StatusFlag b) {
    return static_cast<u8>(a) | static_cast<u8>(b);
}

inline u8 operator|(u8 a, StatusFlag b) {
    return a | static_cast<u8>(b);
}

inline u8& operator|=(u8& a, StatusFlag b) {
    a = a | static_cast<u8>(b);
    return a;
}

inline u8 operator&(u8 a, StatusFlag b) {
    return a & static_cast<u8>(b);
}

inline u8& operator&=(u8& a, StatusFlag b) {
    a = a & static_cast<u8>(b);
    return a;
}

inline u8 operator~(StatusFlag a) {
    return ~static_cast<u8>(a);
}

// Instructions as an enum class
enum class Instruction {
    // Standard instructions
    ADC, AND, ASL, BCC, BCS, BEQ, BIT, BMI,
    BNE, BPL, BRK, BVC, BVS, CLC, CLD, CLI,
    CLV, CMP, CPX, CPY, DEC, DEX, DEY, EOR,
    INC, INX, INY, JMP, JSR, LDA, LDX, LDY,
    LSR, NOP, ORA, PHA, PHP, PLA, PLP, ROL,
    ROR, RTI, RTS, SBC, SEC, SED, SEI, STA,
    STX, STY, TAX, TAY, TSX, TXA, TXS, TYA,

    // Illegal instructions
    AHX, ANC, ALR, ARR, AXS, DCP, ISC, KIL,
    LAS, LAX, RLA, RRA, SAX, SLO, SRE, TAS,
    SHA, SHX, SHY, XAA
};

// Source information for register values
struct RegisterSourceInfo {
    enum class SourceType { Unknown, Immediate, Memory };

    SourceType type = SourceType::Unknown;
    u16 address = 0;
    u8 value = 0;
    u8 index = 0;
};

// Index range tracking
struct IndexRange {
    int min = std::numeric_limits<int>::max();
    int max = std::numeric_limits<int>::min();

    void update(int offset) {
        min = std::min(min, offset);
        max = std::max(max, offset);
    }

    std::pair<int, int> getRange() const {
        if (min > max) return { 0, 0 };  // No valid data
        return { min, max };
    }
};

// Opcode information
struct OpcodeInfo {
    Instruction instruction;
    std::string_view mnemonic;
    AddressingMode mode;
    u8 cycles;
    bool illegal;
};

/**
 * @struct MemoryDataFlow
 * @brief Tracks data flow between memory locations
 *
 * Used to analyze how data moves through memory, especially for tracking
 * pointer chains used in indirect addressing.
 */
struct MemoryDataFlow {
    std::map<u16, std::vector<u16>> memoryWriteSources;
};

class CPU6510 {
public:
    // Constructor and basic operations
    CPU6510();
    ~CPU6510();

    // Disable copy/move to handle the pImpl properly
    CPU6510(const CPU6510&) = delete;
    CPU6510& operator=(const CPU6510&) = delete;
    CPU6510(CPU6510&&) = delete;
    CPU6510& operator=(CPU6510&&) = delete;

    void reset();
    void resetRegistersAndFlags();
    void step();

    // Execution control
    bool executeFunction(u16 address);
    void jumpTo(u16 address);

    // Memory operations
    u8 readMemory(u16 addr);
    void writeByte(u16 addr, u8 value);
    void writeMemory(u16 addr, u8 value);
    void copyMemoryBlock(u16 start, std::span<const u8> data);

    // Data loading
    void loadData(const std::string& filename, u16 loadAddress);

    // Program counter management
    void setPC(u16 address);
    u16 getPC() const;

    // Stack pointer management
    void setSP(u8 sp);
    u8 getSP() const;

    // Cycle counting
    u64 getCycles() const;
    void setCycles(u64 newCycles);
    void resetCycles();

    // Instruction information
    std::string_view getMnemonic(u8 opcode) const;
    u8 getInstructionSize(u8 opcode) const;
    AddressingMode getAddressingMode(u8 opcode) const;
    bool isIllegalInstruction(u8 opcode) const;

    // Memory access tracking
    void dumpMemoryAccess(const std::string& filename);
    std::pair<u8, u8> getIndexRange(u16 pc) const;

    // Memory access
    std::span<const u8> getMemory() const;
    std::span<const u8> getMemoryAccess() const;

    // Accessors
    u16 getLastWriteTo(u16 addr) const;
    const std::vector<u16>& getLastWriteToAddr() const;
    RegisterSourceInfo getRegSourceA() const;
    RegisterSourceInfo getRegSourceX() const;
    RegisterSourceInfo getRegSourceY() const;
    RegisterSourceInfo getWriteSourceInfo(u16 addr) const;

    /**
   * @brief Get the memory data flow tracking information
   * @return Reference to the memory data flow tracking
   */
    const MemoryDataFlow& getMemoryDataFlow() const;
    
    // Callbacks
    using IndirectReadCallback = std::function<void(u16 pc, u8 zpAddr, u16 targetAddr)>;
    using MemoryWriteCallback = std::function<void(u16 addr, u8 value)>;

    void setOnIndirectReadCallback(IndirectReadCallback callback);
    void setOnWriteMemoryCallback(MemoryWriteCallback callback);
    void setOnCIAWriteCallback(MemoryWriteCallback callback);
    void setOnSIDWriteCallback(MemoryWriteCallback callback);
    void setOnVICWriteCallback(MemoryWriteCallback callback);

private:
    // Implementation pointer
    std::unique_ptr<CPU6510Impl> pImpl_;
};