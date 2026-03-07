// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#pragma once

#include "cpu6510.h"
#include "CodeFormatter.h"
#include "LabelGenerator.h"
#include "MemoryAnalyzer.h"
#include "SIDwinderUtils.h"
#include "RelocationStructs.h"

#include <fstream>
#include <map>
#include <string>
#include <vector>

/**
 * @file DisassemblyWriter.h
 * @brief Writes formatted disassembly to output files
 *
 * This module handles the high-level writing of disassembled code to
 * assembly files, managing the overall structure and organization of
 * the output.
 */

 // Forward declarations
class SIDLoader;
class CPU6510;

namespace sidwinder {

    /**
     * @struct RelocationInfo
     * @brief Information about a relocated byte
     *
     * Used to track address relocations during the disassembly process.
     */
    struct RelocationInfo {
        u16 targetAddr;                  // Target address being referenced
        enum class Type { Low, High } type; // Whether this is a low or high byte
    };

    /**
     * @class DisassemblyWriter
     * @brief Writes disassembled code to an output file
     *
     * Coordinates the entire process of writing a disassembly to an
     * assembly language file, including header comments, constants,
     * and the structured output of code and data sections.
     */
    class DisassemblyWriter {
    public:
        /**
         * @brief Constructor
         * @param cpu Reference to the CPU
         * @param sid Reference to the SID loader
         * @param analyzer Reference to the memory analyzer
         * @param labelGenerator Reference to the label generator
         * @param formatter Reference to the code formatter
         */
        DisassemblyWriter(
            const CPU6510& cpu,
            const SIDLoader& sid,
            const MemoryAnalyzer& analyzer,
            const LabelGenerator& labelGenerator,
            const CodeFormatter& formatter);

        /**
         * @brief Generate an assembly file
         * @param filename Output filename
         * @param sidLoad New SID load address
         * @param sidInit New SID init address
         * @param sidPlay New SID play address
         *
         * Creates a complete assembly language file for the disassembled SID.
         */
        void generateAsmFile(
            const std::string& filename,
            u16 sidLoad,
            u16 sidInit,
            u16 sidPlay,
            bool removeCIAWrites = false);

        /**
         * @brief Add an indirect memory access
         * @param pc Program counter
         * @param zpAddr Zero page address
         * @param targetAddr Target address
         *
         * Tracks indirect memory accesses for later analysis.
         */
        void addIndirectAccess(u16 pc, u8 zpAddr, u16 targetAddr);

        /**
         * @brief Process all recorded indirect accesses to identify relocation bytes
         *
         * Analyzes indirect access patterns to identify address references.
         */
        void processIndirectAccesses();

        void onMemoryFlow(u16 pc, char reg, u16 sourceAddr, u8 value, bool isIndexed);

        void updateSelfModifyingPattern(u16 instrAddr, int offset, u16 sourceAddr, u8 value) {
            auto& patterns = selfModifyingPatterns_[instrAddr];

            // Find or create a pattern for this modification
            SelfModifyingPattern* currentPattern = nullptr;

            // Look for an existing incomplete pattern
            for (auto& pattern : patterns) {
                // If we have a low byte but no high byte, and this is offset 2
                if (pattern.hasLowByte && !pattern.hasHighByte && offset == 2) {
                    currentPattern = &pattern;
                    break;
                }
                // If we have a high byte but no low byte, and this is offset 1
                else if (!pattern.hasLowByte && pattern.hasHighByte && offset == 1) {
                    currentPattern = &pattern;
                    break;
                }
            }

            // If we didn't find a suitable pattern, create a new one
            if (!currentPattern) {
                patterns.push_back(SelfModifyingPattern{});
                currentPattern = &patterns.back();
            }

            // Update the pattern
            if (offset == 1) {
                currentPattern->lowByteSource = sourceAddr;
                currentPattern->lowByte = value;
                currentPattern->hasLowByte = true;
            }
            else if (offset == 2) {
                currentPattern->highByteSource = sourceAddr;
                currentPattern->highByte = value;
                currentPattern->hasHighByte = true;
            }
        }

        void analyzeWritesForSelfModification();

    private:
        const CPU6510& cpu_;                      // Reference to CPU
        const SIDLoader& sid_;                    // Reference to SID loader
        const MemoryAnalyzer& analyzer_;          // Reference to memory analyzer
        const LabelGenerator& labelGenerator_;    // Reference to label generator
        const CodeFormatter& formatter_;          // Reference to code formatter

        RelocationTable relocTable_;              // Map of bytes that need relocation

        /**
         * @brief Struct for tracking indirect memory accesses
         *
         * Records detailed information about indirect memory access patterns
         * to identify address references and pointer tables.
         */
        struct IndirectAccessInfo {
            u16 instructionAddress = 0;   // Address of the instruction
            u8 zpAddr = 0;                // Zero page pointer address (low byte)
            u16 sourceLowAddress = 0;     // Source of the low byte value
            u16 sourceHighAddress = 0;    // Source of the high byte value
            std::vector<u16> targetAddresses; // ALL target addresses for this ZP pointer
        };
        std::vector<IndirectAccessInfo> indirectAccesses_;  // List of indirect accesses

        // Track data flow from memory reads
        struct MemoryFlowInfo {
            u16 sourceAddr;
            u8 value;
            bool isIndexed;
        };

        // Current register states (what memory location each register was loaded from)
        std::map<char, MemoryFlowInfo> registerSources_;

        // Track self-modifying code patterns
        struct SelfModifyingPattern {
            u16 lowByteSource = 0;
            u16 highByteSource = 0;
            u8 lowByte = 0;
            u8 highByte = 0;
            bool hasLowByte = false;
            bool hasHighByte = false;
        };
        std::map<u16, std::vector<SelfModifyingPattern>> selfModifyingPatterns_;

        /**
         * @brief Output hardware constants to the assembly file
         * @param file Output stream
         *
         * Writes hardware-related constant definitions.
         */
        void outputHardwareConstants(std::ofstream& file);

        /**
         * @brief Output zero page definitions to the assembly file
         * @param file Output stream
         *
         * Writes zero page variable definitions.
         */
        void emitZPDefines(std::ofstream& file);

        /**
         * @brief Disassemble to the output file
         * @param file Output stream
         *
         * Performs the actual disassembly writing to the file.
         */
        void disassembleToFile(std::ofstream& file, bool removeCIAWrites);

        void processRelocationChain(const MemoryDataFlow& dataFlow, RelocationTable& relocTable, u16 addr, u16 targetAddr, RelocationEntry::Type relocType);

        struct WriteRecord {
            u16 addr;
            u8 value;
            RegisterSourceInfo sourceInfo;
        };
        std::vector<WriteRecord> allWrites_;

        friend class Disassembler;
    };

} // namespace sidwinder