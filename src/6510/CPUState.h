#pragma once

#include "cpu6510.h"

// Forward declaration of implementation class
class CPU6510Impl;

/**
 * @brief CPU state management for the CPU6510
 *
 * Handles CPU registers, flags, and status management.
 */
class CPUState {
public:
    /**
     * @brief Constructor
     *
     * @param cpu Reference to the CPU implementation
     */
    explicit CPUState(CPU6510Impl& cpu);

    /**
     * @brief Reset the CPU state
     */
    void reset();

    /**
     * @brief Get the current program counter
     *
     * @return The program counter value
     */
    u16 getPC() const;

    /**
     * @brief Set the program counter
     *
     * @param value New program counter value
     */
    void setPC(u16 value);

    /**
     * @brief Increment the program counter
     */
    void incrementPC();

    /**
     * @brief Get the current stack pointer
     *
     * @return The stack pointer value
     */
    u8 getSP() const;

    /**
     * @brief Set the stack pointer
     *
     * @param value New stack pointer value
     */
    void setSP(u8 value);

    /**
     * @brief Increment the stack pointer
     */
    void incrementSP();

    /**
     * @brief Decrement the stack pointer
     */
    void decrementSP();

    /**
     * @brief Get the A register value
     *
     * @return The accumulator value
     */
    u8 getA() const;

    /**
     * @brief Set the A register value
     *
     * @param value New accumulator value
     */
    void setA(u8 value);

    /**
     * @brief Get the X register value
     *
     * @return The X index register value
     */
    u8 getX() const;

    /**
     * @brief Set the X register value
     *
     * @param value New X index register value
     */
    void setX(u8 value);

    /**
     * @brief Get the Y register value
     *
     * @return The Y index register value
     */
    u8 getY() const;

    /**
     * @brief Set the Y register value
     *
     * @param value New Y index register value
     */
    void setY(u8 value);

    /**
     * @brief Get the status register value
     *
     * @return The status register value
     */
    u8 getStatus() const;

    /**
     * @brief Set the status register value
     *
     * @param value New status register value
     */
    void setStatus(u8 value);

    /**
     * @brief Set a specific status flag
     *
     * @param flag The flag to set/clear
     * @param value True to set, false to clear
     */
    void setFlag(StatusFlag flag, bool value);

    /**
     * @brief Test if a status flag is set
     *
     * @param flag The flag to test
     * @return True if the flag is set, false otherwise
     */
    bool testFlag(StatusFlag flag) const;

    /**
     * @brief Set Zero and Negative flags based on a value
     *
     * @param value The value to check
     */
    void setZN(u8 value);

    /**
     * @brief Get the CPU cycle count
     *
     * @return The current cycle count
     */
    u64 getCycles() const;

    /**
     * @brief Set the CPU cycle count
     *
     * @param newCycles New cycle count value
     */
    void setCycles(u64 newCycles);

    /**
     * @brief Add cycles to the cycle count
     *
     * @param cycles Number of cycles to add
     */
    void addCycles(u64 cycles);

    /**
     * @brief Reset the CPU cycle counter
     */
    void resetCycles();

    /**
     * @brief Get the source information for the A register
     *
     * @return Register source information for the accumulator
     */
    RegisterSourceInfo getRegSourceA() const;

    /**
     * @brief Set the source information for the A register
     *
     * @param info Register source information
     */
    void setRegSourceA(const RegisterSourceInfo& info);

    /**
     * @brief Get the source information for the X register
     *
     * @return Register source information for the X register
     */
    RegisterSourceInfo getRegSourceX() const;

    /**
     * @brief Set the source information for the X register
     *
     * @param info Register source information
     */
    void setRegSourceX(const RegisterSourceInfo& info);

    /**
     * @brief Get the source information for the Y register
     *
     * @return Register source information for the Y register
     */
    RegisterSourceInfo getRegSourceY() const;

    /**
     * @brief Set the source information for the Y register
     *
     * @param info Register source information
     */
    void setRegSourceY(const RegisterSourceInfo& info);

private:
    // Reference to CPU implementation
    CPU6510Impl& cpu_;

    // CPU registers
    u16 pc_ = 0;      // Program Counter
    u8 sp_ = 0;       // Stack Pointer
    u8 regA_ = 0;     // Accumulator
    u8 regX_ = 0;     // X Index Register
    u8 regY_ = 0;     // Y Index Register
    u8 statusReg_ = 0; // Processor Status Register

    // Cycle count
    u64 cycles_ = 0;

    // Register source tracking
    RegisterSourceInfo regSourceA_;
    RegisterSourceInfo regSourceX_;
    RegisterSourceInfo regSourceY_;
};