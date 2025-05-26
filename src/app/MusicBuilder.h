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
            // Player options
            bool includePlayer = true;     ///< Whether to include player code
            std::string playerName = "SimpleRaster";  ///< Player name
            u16 playerAddress = 0x4000;    ///< Player load address

            // Compression options
            bool compress = true;          ///< Whether to compress the output
            std::string compressorType = "exomizer";  ///< Compression tool
            std::string exomizerPath = "Exomizer.exe";  ///< Path to Exomizer

            // Assembly options
            std::string kickAssPath = "java -jar KickAss.jar -silentMode";  ///< Path to KickAss

            // SID options
            int playCallsPerFrame = 1;     ///< Number of SID play calls per frame
            u16 sidLoadAddr = 0x1000;      ///< SID load address
            u16 sidInitAddr = 0x1000;      ///< SID init address
            u16 sidPlayAddr = 0x1003;      ///< SID play address

            // User definitions
            std::map<std::string, std::string> userDefinitions;  ///< User-defined constants
            
            // File options
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

    private:
        const CPU6510* cpu_;  ///< Pointer to CPU
        const SIDLoader* sid_;  ///< Pointer to SID loader
        std::unique_ptr<SIDEmulator> emulator_; ///< For analyzing SID properties

        /**
         * @enum InputType
         * @brief Type of input file
         */
        enum class InputType {
            SID,  ///< SID file
            PRG,  ///< PRG file
            ASM,  ///< Assembly file
            BIN   ///< Binary file
        };

        void addUserDefinitions(std::ofstream& file, const BuildOptions& options);

        /**
         * @brief Create a linker file for KickAss assembler
         * @param linkerFile Output linker file path
         * @param musicFile Music file path
         * @param playerAsmFile Player assembly file path
         * @param options Build options
         * @param isPrgInput Whether music file is PRG/SID
         * @return True if creation was successful
         */
        bool createLinkerFile(
            const fs::path& linkerFile,
            const fs::path& musicFile,
            const fs::path& playerAsmFile,
            const BuildOptions& options);

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

        /**
         * @brief Compress a PRG file
         * @param inputPrg Input PRG file
         * @param outputPrg Output compressed PRG file
         * @param loadAddress Load address for compressed file
         * @param options Build options
         * @return True if compression was successful
         */
        bool compressPrg(
            const fs::path& inputPrg,
            const fs::path& outputPrg,
            u16 loadAddress,
            const BuildOptions& options);
    };

} // namespace sidwinder