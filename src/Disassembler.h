// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#pragma once

#include "SIDwinderUtils.h"

#include <functional>
#include <memory>
#include <string>

/**
 * @file Disassembler.h
 * @brief High-level disassembler for SID files
 *
 * Provides the main interface for disassembling SID music files into
 * readable and analyzable assembly language.
 */

 // Forward declarations
class CPU6510;
class SIDLoader;

namespace sidwinder {

    // Forward declarations
    class MemoryAnalyzer;
    class LabelGenerator;
    class CodeFormatter;
    class DisassemblyWriter;

    /**
     * @class Disassembler
     * @brief High-level class for disassembling SID files
     *
     * Coordinates the entire disassembly process, from memory analysis
     * to label generation and output formatting.
     */
    class Disassembler {
    public:
        /**
         * @brief Constructor
         * @param cpu Reference to the CPU
         * @param sid Reference to the SID loader
         */
        Disassembler(const CPU6510& cpu, const SIDLoader& sid);

        /**
         * @brief Destructor
         */
        ~Disassembler();

        /**
         * @brief Generate an assembly file from the loaded SID
         * @param outputPath Path to write the assembly file
         * @param sidLoad New SID load address
         * @param sidInit New SID init address (relative to load)
         * @param sidPlay New SID play address (relative to load)
         *
         * Performs the entire disassembly process and writes the result
         * to the specified output file.
         */
        void generateAsmFile(
            const std::string& outputPath,
            u16 sidLoad,
            u16 sidInit,
            u16 sidPlay,
            bool removeCIAWrites = false);

    private:
        const CPU6510& cpu_;  // Reference to CPU
        const SIDLoader& sid_;  // Reference to SID loader

        // Components of the disassembly process
        std::unique_ptr<MemoryAnalyzer> analyzer_;
        std::unique_ptr<LabelGenerator> labelGenerator_;
        std::unique_ptr<CodeFormatter> formatter_;
        std::unique_ptr<DisassemblyWriter> writer_;

        /**
         * @brief Initialize the disassembler components
         *
         * Sets up all the necessary components for the disassembly process.
         */
        void initialize();
    };

} // namespace sidwinder