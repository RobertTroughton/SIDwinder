#pragma once

#include "cpu6510.h"

// Forward declaration of implementation class
class CPU6510Impl;

/**
 * @brief Addressing modes handler for the CPU6510
 *
 * Handles all addressing mode calculations for instruction execution.
 */
class AddressingModes {
public:
    /**
     * @brief Constructor
     *
     * @param cpu Reference to the CPU implementation
     */
    explicit AddressingModes(CPU6510Impl& cpu);

    /**
     * @brief Calculate the target address for a given addressing mode
     *
     * @param mode The addressing mode to use
     * @return The calculated target address
     */
    u16 getAddress(AddressingMode mode);

private:
    // Reference to CPU implementation
    CPU6510Impl& cpu_;

    // Helper method to record index register usage
    void recordIndexOffset(u16 pc, u8 offset);
};