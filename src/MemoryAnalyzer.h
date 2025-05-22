// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#pragma once

#include "SIDwinderUtils.h"

#include <memory>
#include <span>
#include <vector>

/**
 * @file MemoryAnalyzer.h
 * @brief Analysis of CPU memory patterns for disassembly
 *
 * Provides utilities to classify memory regions as code, data, or special regions
 * based on their access patterns during emulation.
 */

namespace sidwinder {

    /**
     * @brief Types of memory regions
     *
     * Bitflags that can be combined to represent different attributes of memory.
     */
    enum class MemoryType : u8 {
        Unknown = 0,        // Memory whose purpose hasn't been determined
        Code = 1 << 0,      // Memory containing executable code
        Data = 1 << 1,      // Memory containing data
        LabelTarget = 1 << 2, // Memory that is the target of a jump or call
        Accessed = 1 << 3   // Memory that has been accessed during execution
    };

    // Operator overloads for MemoryType
    inline MemoryType operator|(MemoryType a, MemoryType b) {
        return static_cast<MemoryType>(static_cast<u8>(a) | static_cast<u8>(b));
    }

    inline bool operator&(MemoryType a, MemoryType b) {
        return (static_cast<u8>(a) & static_cast<u8>(b)) != 0;
    }

    inline MemoryType& operator|=(MemoryType& a, MemoryType b) {
        a = static_cast<MemoryType>(static_cast<u8>(a) | static_cast<u8>(b));
        return a;
    }

    /**
     * @class MemoryAnalyzer
     * @brief Analyzes CPU memory to identify code, data, and label targets
     *
     * This class processes memory access information collected during CPU emulation
     * to classify memory regions and identify important structures like jump targets,
     * code blocks, and data regions for disassembly.
     */
    class MemoryAnalyzer {
    public:
        /**
         * @brief Constructor
         * @param memory CPU memory
         * @param memoryAccess Memory access tracking data
         * @param startAddress Start address of the region to analyze
         * @param endAddress End address of the region to analyze
         */
        MemoryAnalyzer(
            std::span<const u8> memory,
            std::span<const u8> memoryAccess,
            u16 startAddress,
            u16 endAddress);

        /**
         * @brief Analyze execution patterns
         *
         * Marks memory regions that have been executed as Code,
         * and jump targets as LabelTarget.
         */
        void analyzeExecution();

        /**
         * @brief Analyze memory access patterns
         *
         * Identifies accessed memory regions and marks them accordingly.
         * Also identifies potential label targets where data has been read.
         */
        void analyzeAccesses();

        /**
         * @brief Analyze data regions
         *
         * Identifies memory regions that are not code and marks them as Data.
         * This completes the classification of all memory in the analyzed range.
         */
        void analyzeData();

        /**
         * @brief Find the start of an instruction that covers a specific address
         * @param addr Address to find the covering instruction for
         * @return Start address of the instruction
         *
         * Used when identifying labels for instructions that span multiple bytes.
         */
        u16 findInstructionStartCovering(u16 addr) const;

        /**
         * @brief Get the memory type for a specific address
         * @param addr Address to check
         * @return Memory type flags for that address
         */
        MemoryType getMemoryType(u16 addr) const;

        /**
         * @brief Get the memory type map
         * @return Span of memory types for all addresses
         */
        std::span<const MemoryType> getMemoryTypes() const;

        /**
         * @brief Find all data ranges in the analyzed memory
         * @return Vector of pairs representing start and end addresses of data blocks
         */
        std::vector<std::pair<u16, u16>> findDataRanges() const;

        /**
         * @brief Find all code ranges in the analyzed memory
         * @return Vector of pairs representing start and end addresses of code blocks
         */
        std::vector<std::pair<u16, u16>> findCodeRanges() const;

        /**
         * @brief Find all addresses that should have labels
         * @return Vector of addresses that should have labels
         *
         * These include jump targets, subroutine entry points, and data references.
         */
        std::vector<u16> findLabelTargets() const;

    private:
        std::span<const u8> memory_;        // Reference to CPU memory
        std::span<const u8> memoryAccess_;  // Reference to access pattern data
        u16 startAddress_;                  // Start address of region to analyze
        u16 endAddress_;                    // End address of region to analyze
        std::vector<MemoryType> memoryTypes_; // Classification of each memory byte
    };

} // namespace sidwinder