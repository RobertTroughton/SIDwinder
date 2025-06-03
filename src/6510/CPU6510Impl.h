#pragma once

#include "cpu6510.h"
#include "InstructionExecutor.h"
#include "MemorySubsystem.h"
#include "AddressingModes.h"
#include "CPUState.h"

struct MemoryDataFlow;  // Forward declaration

/**
 * @brief Implementation class for CPU6510
 *
 * This class contains the actual implementation of the CPU6510, delegating
 * specific functionality to specialized classes.
 */
class CPU6510Impl {
public:
    // Constructor and basic operations
    CPU6510Impl();
    ~CPU6510Impl() = default;

    void reset();
    void resetRegistersAndFlags();
    void step();

    // Execution control
    bool executeFunction(u32 address);
    void jumpTo(u32 address);

    // Memory operations
    u8 readMemory(u32 addr);
    void writeByte(u32 addr, u8 value);
    void writeMemory(u32 addr, u8 value);
    void copyMemoryBlock(u32 start, std::span<const u8> data);

    // Data loading
    void loadData(const std::string& filename, u32 loadAddress);

    // Program counter management
    void setPC(u32 address);
    u32 getPC() const;

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
    std::pair<u8, u8> getIndexRange(u32 pc) const;

    // Memory access
    std::span<const u8> getMemory() const;
    std::span<const u8> getMemoryAccess() const;

    // Accessors
    u32 getLastWriteTo(u32 addr) const;
    const std::vector<u32>& getLastWriteToAddr() const;
    RegisterSourceInfo getRegSourceA() const;
    RegisterSourceInfo getRegSourceX() const;
    RegisterSourceInfo getRegSourceY() const;
    RegisterSourceInfo getWriteSourceInfo(u32 addr) const;

    /**
     * @brief Get the memory data flow tracking information
     * @return Reference to the memory data flow tracking
     */
    const MemoryDataFlow& getMemoryDataFlow() const;

    // Callbacks
    using IndirectReadCallback = CPU6510::IndirectReadCallback;
    using MemoryWriteCallback = CPU6510::MemoryWriteCallback;
    using MemoryFlowCallback = CPU6510::MemoryFlowCallback;

    void setOnIndirectReadCallback(IndirectReadCallback callback);
    void setOnWriteMemoryCallback(MemoryWriteCallback callback);
    void setOnCIAWriteCallback(MemoryWriteCallback callback);
    void setOnSIDWriteCallback(MemoryWriteCallback callback);
    void setOnVICWriteCallback(MemoryWriteCallback callback);
    void setOnMemoryFlowCallback(MemoryFlowCallback callback);

private:
    // CPU state components
    CPUState cpuState_;

    // Memory and tracking
    MemorySubsystem memory_;

    // Instruction execution
    InstructionExecutor instructionExecutor_;

    // Addressing modes
    AddressingModes addressingModes_;

    // Original PC tracking for current instruction
    u32 originalPc_ = 0;

    // Index range tracking
    std::unordered_map<u32, IndexRange> pcIndexRanges_;

    // Callbacks
    IndirectReadCallback onIndirectReadCallback_;
    MemoryWriteCallback onWriteMemoryCallback_;
    MemoryWriteCallback onCIAWriteCallback_;
    MemoryWriteCallback onSIDWriteCallback_;
    MemoryWriteCallback onVICWriteCallback_;
    MemoryFlowCallback onMemoryFlowCallback_;

    // Record the index offset used for a memory access
    void recordIndexOffset(u32 pc, u8 offset);

    // Stack operations
    void push(u8 value);
    u8 pop();
    u16 readWord(u32 addr);
    u16 readWordZeroPage(u8 addr);

    // Fetch operations
    u8 fetchOpcode(u32 addr);
    u8 fetchOperand(u32 addr);
    u8 readByAddressingMode(u32 addr, AddressingMode mode);

    // Make the opcodeTable accessible to all components
    static const std::array<OpcodeInfo, 256> opcodeTable_;

    // Grant access to internal components
    friend class InstructionExecutor;
    friend class MemorySubsystem;
    friend class AddressingModes;
    friend class CPUState;
};