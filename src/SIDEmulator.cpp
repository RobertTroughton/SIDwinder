#include "SIDEmulator.h"
#include "cpu6510.h"
#include "SIDLoader.h"
#include "SIDwinderUtils.h"
#include "MemoryConstants.h"
#include "ConfigManager.h"

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
                // Record the write in our tracker if tracking is enabled
                if (enableTracking) {
                    writeTracker_.recordWrite(addr, value);
                }

                // Record the write in our pattern finder if pattern detection is enabled
                if (options.patternDetectionEnabled) {
                    patternFinder_.recordWrite(addr, value);
                }
                });
            };

        // Create a backup of memory
        sid_->backupMemory();

        // Initialize the SID
        const u16 initAddr = sid_->getInitAddress();
        const u16 playAddr = sid_->getPlayAddress();

        u32 extraAddr = 0;
        if (playAddr == initAddr + 3)
            extraAddr = initAddr + 6;
        if (playAddr == initAddr + 6)
            extraAddr = initAddr + 3;
        if (cpu_->readMemory(extraAddr) != 0x4C)
            extraAddr = 0;

        // Execute the init routine once
        cpu_->resetRegistersAndFlags();
        updateSIDCallback(false);
        cpu_->executeFunction(initAddr);

        // Run a short playback period to identify initial memory patterns
        // This helps with memory copies performed during initialization
        const int numEmulationFrames = util::ConfigManager::getInt("emulationFrames", DEFAULT_SID_EMULATION_FRAMES);
        for (int frame = 0; frame < numEmulationFrames; ++frame) {
            for (int call = 0; call < options.callsPerFrame; ++call) {
                cpu_->resetRegistersAndFlags();
                if (!cpu_->executeFunction(playAddr)) {
                    return false;
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

        if (extraAddr != 0)
        {
            cpu_->resetRegistersAndFlags();
            cpu_->executeFunction(extraAddr);
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

        if (extraAddr != 0)
        {
            cpu_->resetRegistersAndFlags();
            cpu_->executeFunction(extraAddr);
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

    bool SIDEmulator::generateHelpfulDataFile(const std::string& filename) const {
        util::TextFileBuilder builder;

        builder.section("SIDwinder Generated Helpful Data")
            .line()
            .line("// Modified memory addresses");

        std::set<u16> writtenAddresses;
        auto accessFlags = cpu_->getMemoryAccess();
        for (u32 addr = 0; addr < 65536; ++addr) {
            if (accessFlags[addr] & static_cast<u8>(MemoryAccessFlag::Write)) {
                writtenAddresses.insert(addr);
            }
        }

        std::ostringstream listBuilder;
        listBuilder << ".var SIDModifiedMemory = List()";
        int numItems = 0;
        for (u16 addr : writtenAddresses) {
            if (!MemoryConstants::isSID(addr)) {
                listBuilder << ".add($" << util::wordToHex(addr) << ")";
                numItems++;
            }
        }
        builder.line(listBuilder.str());

        builder.line(".var SIDModifiedMemoryCount = SIDModifiedMemory.size()  // " +
            std::to_string(writtenAddresses.size()) + " total");

        if (writeTracker_.hasConsistentPattern()) {
            builder.section("SID Register Reordering Available")
                .line("#define SID_REGISTER_REORDER_AVAILABLE")
                .line(writeTracker_.getWriteOrderString());
        }
        else {
            builder.section("No SID Register Pattern Detected")
                .line(".var SIDRegisterCount = 0")
                .line(".var SIDRegisterOrder = List()");
        }

        if (patternFinder_.getPatternPeriod() > 0) {
            builder.section("SID Pattern Detected")
                .line("#define SID_PATTERN_DETECTED")
                .line(".var SIDInitFrames = " + std::to_string(patternFinder_.getInitFramesCount()))
                .line(".var SIDPatternPeriod = " + std::to_string(patternFinder_.getPatternPeriod()));
        }
        else {
            builder.section("No SID Pattern Detected")
                .line(".var SIDInitFrames = 0")
                .line(".var SIDPatternPeriod = 0");
        }

        return builder.saveToFile(filename);
    }

} // namespace sidwinder