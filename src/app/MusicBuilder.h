// MusicBuilder.h
#pragma once

#include "../Common.h"
#include "../SIDFileFormat.h"
#include "../SIDEmulator.h"
#include <filesystem>
#include <memory>
#include <string>
#include <map>

namespace fs = std::filesystem;

class CPU6510;
class SIDLoader;

namespace sidwinder {

    /**
     * @class MusicBuilder
     * @brief Unified builder for SID music files
     *
     * Handles building PRG files from SID music, with or without player code.
     */
    class MusicBuilder {
    public:
        /**
         * @struct BuildOptions
         * @brief Options for building music
         */

        struct BuildOptions {
            std::string kickAssPath = "java -jar KickAss.jar -silentMode";  ///< Path to KickAss
            fs::path tempDir = "temp";     ///< Temporary directory
        };

        /**
         * @brief Constructor
         * @param cpu Pointer to CPU6510 instance
         * @param sid Pointer to SIDLoader instance
         */
        MusicBuilder(const CPU6510* cpu, const SIDLoader* sid);

        /**
         * @brief Build music file
         * @param basename Base name for generated files
         * @param inputFile Input file path
         * @param outputFile Output file path
         * @param options Build options
         * @return True if build was successful
         */
        bool buildMusic(
            const std::string& basename,
            const fs::path& inputFile,
            const fs::path& outputFile,
            const BuildOptions& options);

        /**
         * @brief Extract PRG data from a SID file
         * @param sidFile Path to the SID file
         * @param outputPrg Path to save the extracted PRG
         * @return True if extraction was successful
         */
        bool extractPrgFromSid(
            const fs::path& sidFile,
            const fs::path& outputPrg);

        /**
         * @brief Run the KickAss assembler
         * @param sourceFile Source file to assemble
         * @param outputFile Output file path
         * @param kickAssPath Path to KickAss
         * @return True if assembly was successful
         */
        bool runAssembler(
            const fs::path& sourceFile,
            const fs::path& outputFile,
            const std::string& kickAssPath,
            const fs::path& tempDir);

    private:
        const CPU6510* cpu_;  ///< Pointer to CPU
        const SIDLoader* sid_;  ///< Pointer to SID loader

    };

} // namespace sidwinder