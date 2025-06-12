// SIDEmulator.h
#pragma once

#include "Common.h"
#include "app/TraceLogger.h"
#include "SIDPatternFinder.h"
#include "SIDWriteTracker.h"

#include <functional>
#include <memory>

class CPU6510;
class SIDLoader;

namespace sidwinder {

    /**
     * @class SIDEmulator
     * @brief Unified SID emulation functionality
     *
     * Provides a consistent interface for SID emulation across the application,
     * eliminating duplicated code and providing a single point of control.
     */
    class SIDEmulator {
    public:
        /**
         * @struct EmulationOptions
         * @brief Configuration options for SID emulation
         */
        struct EmulationOptions {
            int frames = DEFAULT_SID_EMULATION_FRAMES;   ///< Number of frames to emulate
            bool traceEnabled = false;                   ///< Whether to generate trace logs
            TraceFormat traceFormat = TraceFormat::Binary; ///< Format for trace logs
            std::string traceLogPath;                    ///< Path for trace log (if enabled)
            int callsPerFrame = 1;                       ///< Calls to play routine per frame
            bool registerTrackingEnabled = false;        ///< Whether to track register write order
            bool patternDetectionEnabled = false;        ///< Whether to detect repeating patterns
            bool shadowRegisterDetectionEnabled = false;  ///< Whether to detect shadow registers
        };

        /**
         * @brief Constructor
         * @param cpu Pointer to CPU instance
         * @param sid Pointer to SID loader
         */
        SIDEmulator(CPU6510* cpu, SIDLoader* sid);

        /**
         * @brief Run SID emulation
         * @param options Emulation options
         * @return True if emulation completed successfully
         */
        bool runEmulation(const EmulationOptions& options);

        /**
         * @brief Get cycle count per frame statistics
         * @return Pair of average and maximum cycles per frame
         */
        std::pair<u64, u64> getCycleStats() const;

        /**
         * @brief Get the register write tracker
         * @return Reference to the write tracker
         */
        const SIDWriteTracker& getWriteTracker() const { return writeTracker_; }

        /**
         * @brief Get the pattern finder
         * @return Reference to the pattern finder
         */
        const SIDPatternFinder& getPatternFinder() const { return patternFinder_; }

        /**
         * @brief Generate a helpful data file with addresses that change and register order
         * @param filename Output filename
         * @return True if file was successfully created
         */
        bool generateHelpfulDataFile(const std::string& filename) const;

    private:
        CPU6510* cpu_;                 ///< CPU instance
        SIDLoader* sid_;               ///< SID loader
        std::unique_ptr<TraceLogger> traceLogger_; ///< Trace logger (if enabled)
        u64 totalCycles_ = 0;          ///< Total cycles used
        u64 maxCyclesPerFrame_ = 0;    ///< Maximum cycles used in a frame
        int framesExecuted_ = 0;       ///< Number of frames executed

        SIDWriteTracker writeTracker_; ///< Tracks SID register write order
        SIDPatternFinder patternFinder_; ///< Detects repeating SID patterns

    };

} // namespace sidwinder