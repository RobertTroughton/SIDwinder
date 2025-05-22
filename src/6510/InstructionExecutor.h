#pragma once

#include "cpu6510.h"

// Forward declaration of implementation class
class CPU6510Impl;

/**
 * @brief Instruction executor for the CPU6510
 *
 * Handles execution of all CPU instructions.
 */
class InstructionExecutor {
public:
    /**
     * @brief Constructor
     *
     * @param cpu Reference to the CPU implementation
     */
    explicit InstructionExecutor(CPU6510Impl& cpu);

    /**
     * @brief Execute an instruction
     *
     * Main entry point for instruction execution.
     *
     * @param instr The instruction to execute
     * @param mode The addressing mode to use
     */
    void execute(Instruction instr, AddressingMode mode);

private:
    // Reference to CPU implementation
    CPU6510Impl& cpu_;

    // Instruction execution dispatch
    void executeInstruction(Instruction instr, AddressingMode mode);

    // Instruction type handlers
    void executeLoad(Instruction instr, AddressingMode mode);
    void executeStore(Instruction instr, AddressingMode mode);
    void executeArithmetic(Instruction instr, AddressingMode mode);
    void executeLogical(Instruction instr, AddressingMode mode);
    void executeBranch(Instruction instr, AddressingMode mode);
    void executeJump(Instruction instr, AddressingMode mode);
    void executeStack(Instruction instr, AddressingMode mode);
    void executeRegister(Instruction instr, AddressingMode mode);
    void executeFlag(Instruction instr, AddressingMode mode);
    void executeShift(Instruction instr, AddressingMode mode);
    void executeCompare(Instruction instr, AddressingMode mode);
    void executeIllegal(Instruction instr, AddressingMode mode);
};