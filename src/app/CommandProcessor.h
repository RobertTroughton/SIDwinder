// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#pragma once

#include "../Common.h"
#include "TraceLogger.h"
#include <memory>
#include <string>
#include <map>

class CPU6510;
class SIDLoader;

namespace sidwinder {
    class Disassembler;
    class MusicBuilder;
    class PlayerManager;

    /**
     * @class CommandProcessor
     * @brief Main processor for SID file operations
     *
     * Handles loading, analysis, and processing of SID files, delegating to
     * specialized components for specific tasks.
     */
    class CommandProcessor {
    public:
        /**
         * @struct ProcessingOptions
         * @brief Options for processing SID files
         */
        struct ProcessingOptions {
            // File options
            fs::path inputFile;               ///< Input file path
            fs::path outputFile;              ///< Output file path
            fs::path tempDir = "temp";        ///< Temporary directory

            // SID options
            u16 relocationAddress = 0;        ///< Relocation address
            bool hasRelocation = false;       ///< Whether to relocate

            // Override addresses
            u16 overrideInitAddress = 0;      ///< Override init address
            u16 overridePlayAddress = 0;      ///< Override play address
            u16 overrideLoadAddress = 0;      ///< Override load address
            bool hasOverrideInit = false;     ///< Whether init address is overridden
            bool hasOverridePlay = false;     ///< Whether play address is overridden
            bool hasOverrideLoad = false;     ///< Whether load address is overridden

            // Metadata overrides
            std::string overrideTitle;        ///< Override SID title
            std::string overrideAuthor;       ///< Override SID author
            std::string overrideCopyright;    ///< Override SID copyright

            // Assembly options
            std::string kickAssPath = "java -jar KickAss.jar -silentMode"; ///< Path to KickAss

            // Trace options
            std::string traceLogPath;              ///< Trace log file path
            bool enableTracing = false;            ///< Whether to enable tracing
            TraceFormat traceFormat = TraceFormat::Binary;  ///< Trace format
            int frames = DEFAULT_SID_EMULATION_FRAMES;    ///< Number of frames to emulate

            // Player options (passed to PlayerManager if needed)
            bool includePlayer = false;
            std::string playerName = "SimpleRaster";
            u16 playerAddress = 0x4000;
            bool compress = true;
            std::string compressorType = "exomizer";
            std::string exomizerPath = "Exomizer.exe";
            std::map<std::string, std::string> userDefinitions;
        };

        /**
         * @brief Constructor
         */
        CommandProcessor();

        /**
         * @brief Destructor
         */
        ~CommandProcessor();

        /**
         * @brief Process a file according to options
         * @param options Processing options
         * @return True if processing succeeded
         */
        bool processFile(const ProcessingOptions& options);

    private:
        std::unique_ptr<CPU6510> cpu_;             ///< CPU instance
        std::unique_ptr<SIDLoader> sid_;           ///< SID loader instance
        std::unique_ptr<TraceLogger> traceLogger_; ///< Trace logger
        std::unique_ptr<Disassembler> disassembler_; ///< Disassembler
        std::unique_ptr<MusicBuilder> musicBuilder_; ///< Music builder
        std::unique_ptr<PlayerManager> playerManager_; ///< Player manager

        /**
         * @brief Load an input file
         * @param options Processing options
         * @return True if loading succeeded
         */
        bool loadInputFile(const ProcessingOptions& options);

        /**
         * @brief Analyze music properties
         * @param options Processing options
         * @return True if analysis succeeded
         */
        bool analyzeMusic(const ProcessingOptions& options);

        /**
         * @brief Generate output file
         * @param options Processing options
         * @return True if output generation succeeded
         */
        bool generateOutput(const ProcessingOptions& options);

        /**
         * @brief Generate PRG output
         * @param options Processing options
         * @return True if PRG generation succeeded
         */
        bool generatePRGOutput(const ProcessingOptions& options);

        /**
         * @brief Generate SID output
         * @param options Processing options
         * @return True if SID generation succeeded
         */
        bool generateSIDOutput(const ProcessingOptions& options);

        /**
         * @brief Generate ASM output
         * @param options Processing options
         * @return True if ASM generation succeeded
         */
        bool generateASMOutput(const ProcessingOptions& options);

        /**
         * @brief Apply SID metadata overrides
         * @param options Processing options
         */
        void applySIDMetadataOverrides(const ProcessingOptions& options);
    };

} // namespace sidwinder