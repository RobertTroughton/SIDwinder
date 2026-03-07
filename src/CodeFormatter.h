// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#pragma once

#include "LabelGenerator.h"
#include "SIDwinderUtils.h"
#include "RelocationStructs.h"

#include <memory>
#include <span>
#include <string>
#include <vector>

/**
 * @file CodeFormatter.h
 * @brief Formats disassembled instructions and data into readable assembly
 *
 * This module handles the formatting of instructions and data into properly
 * formatted assembly language, including instruction mnemonics, operands,
 * and special formatting for hardware registers.
 */

 // Forward declarations
class CPU6510;

namespace sidwinder {

    /**
     * @class CodeFormatter
     * @brief Formats disassembled instructions and data
     *
     * Converts raw machine code and memory data into readable assembly language
     * format with proper syntax, labels, and addressing modes.
     */
    class CodeFormatter {
    public:
        /**
         * @brief Constructor
         * @param cpu Reference to the CPU
         * @param labelGenerator Reference to the label generator
         * @param memory Span of memory data
         */
        CodeFormatter(
            const CPU6510& cpu,
            const LabelGenerator& labelGenerator,
            std::span<const u8> memory);

        /**
         * @brief Format a disassembled instruction
         * @param pc Program counter (will be updated to point after instruction)
         * @return Formatted instruction string
         *
         * Converts a machine code instruction at PC into assembly language.
         * Updates PC to point to the next instruction.
         */
        std::string formatInstruction(u16& pc) const;

        /**
         * @brief Format data bytes
         * @param file Output stream
         * @param pc Program counter (will be updated)
         * @param originalMemory Original memory data
         * @param originalBase Base address of original memory
         * @param endAddress End address
         * @param relocationBytes Map of relocation bytes
         * @param memoryTags Memory type tags
         *
         * Outputs data bytes in assembly format (.byte directives).
         * Handles relocation entries and unused bytes.
         */
        void formatDataBytes(
            std::ostream& file,
            u16& pc,
            std::span<const u8> originalMemory,
            u16 originalBase,
            u16 endAddress,
            const std::map<u16, RelocationEntry>& relocationBytes,
            std::span<const MemoryType> memoryTags) const;

        /**
         * @brief Check if a store instruction is a CIA timer patch
         * @param opcode Instruction opcode
         * @param mode Addressing mode
         * @param operand Operand address
         * @param mnemonic Instruction mnemonic
         * @return True if this is a CIA timer patch
         *
         * Detects writes to CIA timer registers that should be handled specially.
         */
        bool isCIAStorePatch(
            u8 opcode,
            int mode,
            u16 operand,
            std::string_view mnemonic) const;

        /**
         * @brief Format an instruction operand
         * @param pc Program counter
         * @param mode Addressing mode
         * @return Formatted operand string
         *
         * Handles different addressing modes and formats operands appropriately.
         */
        std::string formatOperand(u16 pc, int mode) const;

        /**
         * @brief Format an indexed address with minimum offset
         * @param baseAddr Base address
         * @param minOffset Minimum offset
         * @param indexReg Index register ('X' or 'Y')
         * @return Formatted address string
         *
         * Formats addresses with index registers, accounting for offsets.
         */
        std::string formatIndexedAddressWithMinOffset(
            u16 baseAddr,
            u8 minOffset,
            char indexReg) const;

        void setCIAWriteRemoval(bool removeCIAWrites) const;

    private:
        const CPU6510& cpu_;                      // Reference to CPU
        const LabelGenerator& labelGenerator_;    // Reference to label generator
        std::span<const u8> memory_;              // Memory data
        mutable bool removeCIAWrites_;            // Whether to remove CIA writes
    };

} // namespace sidwinder