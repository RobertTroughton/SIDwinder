#include "SIDEmulator.h"
#include "cpu6510.h"
#include "SIDLoader.h"
#include "SIDwinderUtils.h"
#include "MemoryConstants.h"

#include <set>

namespace sidwinder {

    SIDEmulator::SIDEmulator(CPU6510* cpu, SIDLoader* sid)
        : cpu_(cpu), sid_(sid) {
    }

    bool SIDEmulator::runEmulation(const EmulationOptions& options) {
        if (!cpu_ || !sid_) {
            util::Logger::error("Invalid CPU or SID loader for emulation");
            return false;
        }

        // Temporarily disable register tracking for init
        bool temporaryTrackingEnabled = false;

        // Clear the write tracker if tracking is enabled
        if (options.registerTrackingEnabled) {
            writeTracker_.reset();
        }

        // Clear the pattern finder if pattern detection is enabled
        if (options.patternDetectionEnabled) {
            patternFinder_.reset();
        }

        // Set up trace logger if enabled
        if (options.traceEnabled && !options.traceLogPath.empty()) {
            traceLogger_ = std::make_unique<TraceLogger>(options.traceLogPath, options.traceFormat);
        }
        else {
            traceLogger_.reset();
        }

        // Set up callbacks based on enabled features
        auto updateSIDCallback = [this, &temporaryTrackingEnabled, &options](bool enableTracking) {
            cpu_->setOnSIDWriteCallback([this, enableTracking, &options](u16 addr, u8 value) {
                // Call the trace logger if enabled
                if (traceLogger_) {
                    traceLogger_->logSIDWrite(addr, value);
                }

                // Record the write in our tracker if tracking is enabled
                if (enableTracking) {
                    writeTracker_.recordWrite(addr, value);
                }

                // Record the write in our pattern finder if pattern detection is enabled
                if (options.patternDetectionEnabled) {
                    patternFinder_.recordWrite(addr, value);
                }

                // Record for shadow register detection if enabled
                if (options.shadowRegisterDetectionEnabled) {
                    shadowRegisterFinder_.recordSIDWrite(addr, value);
                }
                });
            };

        // Create a backup of memory
        sid_->backupMemory();

        // Initialize the SID
        const u16 initAddr = sid_->getInitAddress();
        const u16 playAddr = sid_->getPlayAddress();

        // Execute the init routine once
        cpu_->resetRegistersAndFlags();
        updateSIDCallback(false);
        cpu_->executeFunction(initAddr);

        // Run a short playback period to identify initial memory patterns
        // This helps with memory copies performed during initialization
        const int numEmulationFrames = util::Configuration::getInt("emulationFrames", DEFAULT_SID_EMULATION_FRAMES);
        for (int frame = 0; frame < numEmulationFrames; ++frame) {
            for (int call = 0; call < options.callsPerFrame; ++call) {
                cpu_->resetRegistersAndFlags();
                if (!cpu_->executeFunction(playAddr)) {
                    return false;
                }
                if (options.shadowRegisterDetectionEnabled) {
                    shadowRegisterFinder_.checkMemoryForShadowRegisters(cpu_->getMemory());
                }
                if (options.traceEnabled && traceLogger_) {
                    traceLogger_->logFrameMarker();
                }

                if (options.registerTrackingEnabled) {
                    writeTracker_.endFrame();
                }

                if (options.patternDetectionEnabled) {
                    patternFinder_.endFrame();
                }
            }
        }

        // Re-run the init routine to reset the player state
        cpu_->resetRegistersAndFlags();
        updateSIDCallback(false);
        cpu_->executeFunction(initAddr);

        // Mark end of initialization in trace log
        if (options.traceEnabled && traceLogger_) {
            traceLogger_->logFrameMarker();
        }

        // Reset counters
        totalCycles_ = 0;
        maxCyclesPerFrame_ = 0;
        framesExecuted_ = 0;

        // Now enable register tracking and pattern detection if requested
        if (options.registerTrackingEnabled || options.patternDetectionEnabled) {
            cpu_->executeFunction(playAddr);    //; do "play" for the first frame .. because some SIDs output differently on the first frame
            temporaryTrackingEnabled = true;
            updateSIDCallback(true);
        }

        // Get initial cycle count
        u64 lastCycles = cpu_->getCycles();

        // Call play routine for the specified number of frames
        bool bGood = true;
        for (int frame = 0; frame < options.frames; ++frame) {
            // Execute play routine (multiple times per frame if requested)
            for (int call = 0; call < options.callsPerFrame; ++call) {
                cpu_->resetRegistersAndFlags();
                bGood = cpu_->executeFunction(playAddr);
                if (!bGood) {
                    break;
                }
            }

            if (!bGood) {
                break;
            }

            // Calculate cycles used in this frame
            const u64 curCycles = cpu_->getCycles();
            const u64 frameCycles = curCycles - lastCycles;

            // Update statistics
            maxCyclesPerFrame_ = std::max(maxCyclesPerFrame_, frameCycles);
            totalCycles_ += frameCycles;
            lastCycles = curCycles;

            // Mark end of frame in trace log, write tracker, and pattern finder
            if (options.traceEnabled && traceLogger_) {
                traceLogger_->logFrameMarker();
            }

            if (options.registerTrackingEnabled) {
                writeTracker_.endFrame();
            }

            if (options.patternDetectionEnabled) {
                patternFinder_.endFrame();
            }

            framesExecuted_++;
        }

        // Analyze register write patterns if tracking was enabled
        if (temporaryTrackingEnabled) {
            writeTracker_.analyzePattern();
        }

        // Analyze pattern if pattern detection was enabled
        if (options.patternDetectionEnabled) {
            patternFinder_.analyzePattern();
        }

        // Restore original memory
        sid_->restoreMemory();

        return true;
    }

    std::pair<u64, u64> SIDEmulator::getCycleStats() const {
        const u64 avgCycles = framesExecuted_ > 0 ? totalCycles_ / framesExecuted_ : 0;
        return { avgCycles, maxCyclesPerFrame_ };
    }

    // Modified to include pattern information
    bool SIDEmulator::generateHelpfulDataFile(const std::string& filename) const {
        std::ofstream file(filename);
        if (!file) {
            util::Logger::error("Failed to create helpful data file: " + filename);
            return false;
        }

        // File header
        file << "// Generated by SIDwinder\n";
        file << "// Helpful data for double-buffering, register reordering, and pattern detection\n\n";

        // Part 1: Memory addresses that change
        std::set<u16> writtenAddresses;
        auto accessFlags = cpu_->getMemoryAccess();

        // Find all addresses with write access
        for (u32 addr = 0; addr < 65536; ++addr) {
            if (accessFlags[addr] & static_cast<u8>(MemoryAccessFlag::Write)) {
                writtenAddresses.insert(addr);
            }
        }

        // Generate the KickAss list syntax
        file << "// Addresses changed during SID execution\n";
        file << ".var SIDModifiedMemory = List()";

        // Add addresses to the list - limit to 8 per line for readability
        int numItems = 0;
        for (u16 addr : writtenAddresses) {
            if (!MemoryConstants::isSID(addr)) {
                file << ".add($" << util::wordToHex(addr) << ")";
                numItems++;
            }
        }

        file << "\n.var SIDModifiedMemoryCount = SIDModifiedMemory.size()  // " << std::to_string(numItems) << "\n\n";

        // Part 2: SID Register order information
        if (writeTracker_.hasConsistentPattern()) {
            file << "// SID Register write order\n";
            file << "#define SID_REGISTER_REORDER_AVAILABLE\n";
            file << writeTracker_.getWriteOrderString() << "\n";
        }
        else {
            file << "// No consistent SID register write order detected\n";
            file << ".var SIDRegisterCount = 0\n";
            file << ".var SIDRegisterOrder = List()\n\n";
        }

        // Part 3: SID Register write pattern information
        if (patternFinder_.getPatternPeriod() > 0) {
            file << "// SID Register write pattern information\n";
            file << "#define SID_PATTERN_DETECTED\n";
            file << ".var SIDInitFrames = " << patternFinder_.getInitFramesCount() << "\n";
            file << ".var SIDPatternPeriod = " << patternFinder_.getPatternPeriod() << "\n\n";
        }
        else {
            file << "// No clear SID register write pattern detected\n";
            file << ".var SIDInitFrames = 0\n";
            file << ".var SIDPatternPeriod = 0\n\n";
        }

        // Part 4: Shadow Register information
        file << shadowRegisterFinder_.generateHelpfulDataSection();

        return true;
    }

} // namespace sidwinder