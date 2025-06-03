// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#include "CommandProcessor.h"
#include "../SIDwinderUtils.h"
#include "../ConfigManager.h"
#include "../cpu6510.h"
#include "../SIDEmulator.h"
#include "../SIDLoader.h"
#include "../Disassembler.h"
#include "../RelocationUtils.h"
#include "MusicBuilder.h"

#include <algorithm>
#include <fstream>
#include <cctype>

namespace sidwinder {

    CommandProcessor::CommandProcessor() {
        // Initialize CPU
        cpu_ = std::make_unique<CPU6510>();
        cpu_->reset();

        // Initialize SID Loader
        sid_ = std::make_unique<SIDLoader>();
        sid_->setCPU(cpu_.get());
    }

    CommandProcessor::~CommandProcessor() {
        // Ensure trace logger is closed properly
        traceLogger_.reset();
    }

    bool CommandProcessor::processFile(const ProcessingOptions& options) {
        try {
            // Create temp directory if it doesn't exist
            fs::create_directories(options.tempDir);

            // Set up tracing if enabled
            if (options.enableTracing && !options.traceLogPath.empty()) {
                traceLogger_ = std::make_unique<TraceLogger>(options.traceLogPath, options.traceFormat);

                // Set up callback for SID writes
                cpu_->setOnSIDWriteCallback([this](u16 addr, u8 value) {
                    traceLogger_->logSIDWrite(addr, value);
                    });

                // Set up callback for CIA writes
                cpu_->setOnCIAWriteCallback([this](u16 addr, u8 value) {
                    traceLogger_->logCIAWrite(addr, value);
                    });
            }

            // Load the input file
            if (!loadInputFile(options)) {
                return false;
            }

            // Apply any metadata overrides
            applySIDMetadataOverrides(options);

            // For -player command, we need to run emulation to analyze register patterns
            if (options.includePlayer && getFileExtension(options.outputFile) == ".prg" && options.analyzeRegisterOrder) {
                // Create SID emulator
                SIDEmulator emulator(cpu_.get(), sid_.get());
                SIDEmulator::EmulationOptions emulationOptions;
                emulationOptions.frames = options.frames > 0 ?
                    options.frames : util::Configuration::getInt("emulationFrames", DEFAULT_SID_EMULATION_FRAMES);

                // Enable register tracking specifically for player generation
                emulationOptions.registerTrackingEnabled = true;

                // Enable pattern detection
                emulationOptions.patternDetectionEnabled = true;

                // Track CIA timer writes
                u8 CIATimerLo = 0;
                u8 CIATimerHi = 0;
                cpu_->setOnCIAWriteCallback([&](u16 addr, u8 value) {
                    if (addr == 0xDC04) CIATimerLo = value;
                    if (addr == 0xDC05) CIATimerHi = value;
                    });

                // Run emulation to analyze SID patterns
                if (!emulator.runEmulation(emulationOptions)) {
                    util::Logger::warning("SID pattern analysis failed - continuing without pattern info");
                }

                // Calculate play calls per frame
                int playCallsPerFrame = calculatePlayCallsPerFrame(CIATimerLo, CIATimerHi);
                sid_->setNumPlayCallsPerFrame(playCallsPerFrame);
            }

            // Determine if we need emulation based on the command type
            bool needsEmulation = false;

            // If output is ASM (disassembly) or SID with relocation, we need emulation
            if (getFileExtension(options.outputFile) == ".asm" ||
                (getFileExtension(options.outputFile) == ".sid" && options.hasRelocation)) {
                needsEmulation = true;
            }

            // If trace is enabled, we need emulation
            if (options.enableTracing) {
                needsEmulation = true;
            }

            // If we're just linking a player with SID, we don't need emulation
            if (options.includePlayer && getFileExtension(options.outputFile) == ".prg") {
                needsEmulation = false;
                util::Logger::debug("Skipping emulation for LinkPlayer command - not needed");
            }

            // Analyze the music (only if needed)
            if (needsEmulation) {
                if (!analyzeMusic(options)) {
                    return false;
                }
            }
            else {
                // For LinkPlayer, we still need the Disassembler but without running emulation
                disassembler_ = std::make_unique<Disassembler>(*cpu_, *sid_);
            }

            // Generate the output file
            if (!generateOutput(options)) {
                return false;
            }
            return true;
        }
        catch (const std::exception& e) {
            util::Logger::error(std::string("Error processing file: ") + e.what());
            return false;
        }
    }

    bool CommandProcessor::loadInputFile(const ProcessingOptions& options) {
        // Base name for temporary files
        std::string basename = options.inputFile.stem().string();

        // Setup temporary file paths
        fs::path tempExtractedPrg = options.tempDir / (basename + "-original.prg");

        std::string ext = getFileExtension(options.inputFile);
        if (ext != ".sid")
        {
            util::Logger::error("Unsupported file type: " + options.inputFile.string() + " - only SID files accepted.");
            return false;
        }
        if (!loadSidFile(options, tempExtractedPrg)) {
            util::Logger::error("Failed to load file: " + options.inputFile.string());
            return false;
        }

        return true;
    }


    bool CommandProcessor::loadSidFile(const ProcessingOptions& options, const fs::path& tempExtractedPrg) {
        bool loaded = sid_->loadSID(options.inputFile.string());

        if (loaded) {
            // Apply overrides if specified
            if (options.hasOverrideInit) {
                sid_->setInitAddress(options.overrideInitAddress);
            }

            if (options.hasOverridePlay) {
                sid_->setPlayAddress(options.overridePlayAddress);
            }

            if (options.hasOverrideLoad) {
                sid_->setLoadAddress(options.overrideLoadAddress);
            }

            // Extract PRG data from SID to temp file
            // Create a temporary MusicBuilder to use its extractPrgFromSid method
            MusicBuilder builder(cpu_.get(), sid_.get());
            builder.extractPrgFromSid(options.inputFile, tempExtractedPrg);
        }

        return loaded;
    }

    void CommandProcessor::applySIDMetadataOverrides(const ProcessingOptions& options) {
        // Apply overrides from command line
        if (!options.overrideTitle.empty()) {
            sid_->setTitle(options.overrideTitle);
        }

        if (!options.overrideAuthor.empty()) {
            sid_->setAuthor(options.overrideAuthor);
        }

        if (!options.overrideCopyright.empty()) {
            sid_->setCopyright(options.overrideCopyright);
        }
    }

    bool CommandProcessor::analyzeMusic(const ProcessingOptions& options) {
        // Backup memory before emulation
        sid_->backupMemory();

        // Track CIA timer writes
        u8 CIATimerLo = 0;
        u8 CIATimerHi = 0;
        cpu_->setOnCIAWriteCallback([&](u16 addr, u8 value) {
            if (addr == 0xDC04) CIATimerLo = value;
            if (addr == 0xDC05) CIATimerHi = value;
            });

        // Set up Disassembler if needed
        disassembler_ = std::make_unique<Disassembler>(*cpu_, *sid_);

        // Set up emulation options
        SIDEmulator emulator(cpu_.get(), sid_.get());
        SIDEmulator::EmulationOptions emulationOptions;

        // Use frames count from options (from command line or config)
        emulationOptions.frames = options.frames > 0 ?
            options.frames : util::Configuration::getInt("emulationFrames", DEFAULT_SID_EMULATION_FRAMES);

        emulationOptions.traceEnabled = options.enableTracing;
        emulationOptions.traceFormat = options.traceFormat;
        emulationOptions.traceLogPath = options.traceLogPath;

        // Don't enable register tracking by default
        emulationOptions.registerTrackingEnabled = false;

        // Run the emulation
        if (!emulator.runEmulation(emulationOptions)) {
            util::Logger::error("SID emulation failed");
            return false;
        }

        // Calculate play calls per frame
        int playCallsPerFrame = calculatePlayCallsPerFrame(CIATimerLo, CIATimerHi);
        sid_->setNumPlayCallsPerFrame(playCallsPerFrame);

        // Get SID info
        const u16 sidLoad = sid_->getLoadAddress();
        const u16 sidInit = sid_->getInitAddress();
        const u16 sidPlay = sid_->getPlayAddress();

        // Get cycle statistics
        auto [avgCycles, maxCycles] = emulator.getCycleStats();
        util::Logger::debug("Maximum cycles per frame: " + std::to_string(maxCycles));

        return true;
    }


    int CommandProcessor::calculatePlayCallsPerFrame(u8 CIATimerLo, u8 CIATimerHi) {
        const uint32_t speedBits = sid_->getHeader().speed;
        int count = 0;

        // Count bits in speed field
        for (int i = 0; i < 32; ++i) {
            if (speedBits & (1u << i)) {
                ++count;
            }
        }

        // Default to calls per frame from config, or 1 if not set
        int defaultCalls = util::ConfigManager::getInt("defaultPlayCallsPerFrame", 1);
        int numPlayCallsPerFrame = std::clamp(count == 0 ? defaultCalls : count, 1, 16);

        // Check for CIA timer
        if ((CIATimerLo != 0) || (CIATimerHi != 0)) {
            const u16 timerValue = CIATimerLo | (CIATimerHi << 8);

            // Get cycles per frame based on clock standard
            const double NumCyclesPerFrame = util::ConfigManager::getCyclesPerFrame();
            const double freq = NumCyclesPerFrame / std::max(1, static_cast<int>(timerValue));
            const int numCalls = static_cast<int>(freq + 0.5);
            numPlayCallsPerFrame = std::clamp(numCalls, 1, 16);
        }

        return numPlayCallsPerFrame;
    }

    bool CommandProcessor::generateOutput(const ProcessingOptions& options) {

        // Determine new addresses for relocation
        u16 newSidLoad;
        u16 newSidInit;
        u16 newSidPlay;

        const u16 sidLoad = sid_->getLoadAddress();
        const u16 sidInit = sid_->getInitAddress();
        const u16 sidPlay = sid_->getPlayAddress();

        if (options.hasRelocation) {
            newSidLoad = options.relocationAddress;
            // Calculate offset for init and play addresses
            newSidInit = newSidLoad + (sidInit - sidLoad);
            newSidPlay = newSidLoad + (sidPlay - sidLoad);
        }
        else {
            // Use original addresses if not relocating
            newSidLoad = sidLoad;
            newSidInit = sidInit;
            newSidPlay = sidPlay;
        }

        // Generate the appropriate output format
        std::string ext = getFileExtension(options.outputFile);
        if (ext == ".prg") {
            return generatePRGOutput(options);
        }
        else if (ext == ".sid") {
            return generateSIDOutput(options);
        }
        else if (ext == ".asm") {
            return generateASMOutput(options);
        }
        util::Logger::error("Unsupported output format");
        return false;
    }

    bool CommandProcessor::generatePRGOutput(const ProcessingOptions& options) {
        // Base name for files
        std::string basename = options.inputFile.stem().string();

        // Setup temporary file paths
        fs::path tempDir = options.tempDir;
        fs::path tempExtractedPrg = tempDir / (basename + "-original.prg");

        std::string inputExt = getFileExtension(options.inputFile);
        bool bIsSID = (inputExt == ".sid");
        bool bIsASM = (inputExt == ".asm");
        bool bIsPRG = (inputExt == ".prg");

        // For LinkPlayer with SID input, go directly to MusicBuilder without disassembly
        if (options.includePlayer && bIsSID) {
            MusicBuilder builder(cpu_.get(), sid_.get());
            MusicBuilder::BuildOptions buildOptions;
            buildOptions.includePlayer = true;
            buildOptions.playerName = options.playerName;
            buildOptions.playerAddress = options.playerAddress;
            buildOptions.compress = options.compress;
            buildOptions.compressorType = options.compressorType;
            buildOptions.exomizerPath = options.exomizerPath;
            buildOptions.kickAssPath = options.kickAssPath;
            buildOptions.tempDir = tempDir;
            buildOptions.playCallsPerFrame = sid_->getNumPlayCallsPerFrame();
            buildOptions.userDefinitions = options.userDefinitions;

            // These aren't used for SID input - KickAss will get them from the SID file
            buildOptions.sidLoadAddr = sid_->getLoadAddress();
            buildOptions.sidInitAddr = sid_->getInitAddress();
            buildOptions.sidPlayAddr = sid_->getPlayAddress();

            return builder.buildMusic(basename, options.inputFile, options.outputFile, buildOptions);
        }

        // The rest of the method handles relocation and other special cases
        bool bRelocation = options.hasRelocation;
        u16 newSidLoad = options.relocationAddress;

        // If the input file is a SID and we haven't extracted it yet, do so now
        if ((!bRelocation) && (bIsSID) && (!fs::exists(tempExtractedPrg))) {
            MusicBuilder builder(cpu_.get(), sid_.get());
            builder.extractPrgFromSid(options.inputFile, tempExtractedPrg);
        }

        // Determine if we need to use the disassembler for relocation
        if (bRelocation) {
            sid_->restoreMemory();

            // For relocation, generate assembly file
            fs::path tempAsmFile = tempDir / (basename + ".asm");
            const u16 sidLoad = sid_->getLoadAddress();
            const u16 newSidInit = newSidLoad + (sid_->getInitAddress() - sidLoad);
            const u16 newSidPlay = newSidLoad + (sid_->getPlayAddress() - sidLoad);

            disassembler_->generateAsmFile(tempAsmFile.string(), newSidLoad, newSidInit, newSidPlay, true);

            // Run assembler to build with player
            MusicBuilder builder(cpu_.get(), sid_.get());
            MusicBuilder::BuildOptions buildOptions;
            buildOptions.includePlayer = options.includePlayer;
            buildOptions.playerName = options.playerName;
            buildOptions.playerAddress = options.playerAddress;
            buildOptions.compress = options.compress;
            buildOptions.compressorType = options.compressorType;
            buildOptions.exomizerPath = options.exomizerPath;
            buildOptions.kickAssPath = options.kickAssPath;
            buildOptions.tempDir = tempDir;
            buildOptions.sidLoadAddr = newSidLoad;
            buildOptions.sidInitAddr = newSidInit;
            buildOptions.sidPlayAddr = newSidPlay;
            buildOptions.playCallsPerFrame = sid_->getNumPlayCallsPerFrame();
            buildOptions.userDefinitions = options.userDefinitions;

            return builder.buildMusic(basename, tempAsmFile, options.outputFile, buildOptions);
        }
        else if (bIsSID) {
            // No relocation, and input is a SID file - handled earlier for LinkPlayer
            // This branch handles SID input when not using a player
            MusicBuilder builder(cpu_.get(), sid_.get());
            MusicBuilder::BuildOptions buildOptions;
            buildOptions.includePlayer = options.includePlayer;
            buildOptions.playerName = options.playerName;
            buildOptions.playerAddress = options.playerAddress;
            buildOptions.compress = options.compress;
            buildOptions.compressorType = options.compressorType;
            buildOptions.exomizerPath = options.exomizerPath;
            buildOptions.kickAssPath = options.kickAssPath;
            buildOptions.tempDir = tempDir;
            buildOptions.playCallsPerFrame = sid_->getNumPlayCallsPerFrame();
            buildOptions.userDefinitions = options.userDefinitions;

            return builder.buildMusic(basename, options.inputFile, options.outputFile, buildOptions);
        }
        else {
            // No relocation, input is PRG or ASM
            MusicBuilder builder(cpu_.get(), sid_.get());
            MusicBuilder::BuildOptions buildOptions;
            buildOptions.includePlayer = options.includePlayer;
            buildOptions.playerName = options.playerName;
            buildOptions.playerAddress = options.playerAddress;
            buildOptions.compress = options.compress;
            buildOptions.compressorType = options.compressorType;
            buildOptions.exomizerPath = options.exomizerPath;
            buildOptions.kickAssPath = options.kickAssPath;
            buildOptions.tempDir = tempDir;
            buildOptions.playCallsPerFrame = sid_->getNumPlayCallsPerFrame();
            buildOptions.userDefinitions = options.userDefinitions;

            // Use the original file directly - either ASM or the extracted PRG
            fs::path inputToUse = bIsASM ? options.inputFile : tempExtractedPrg;

            return builder.buildMusic(basename, inputToUse, options.outputFile, buildOptions);
        }
    }

    bool CommandProcessor::generateSIDOutput(const ProcessingOptions& options) {
        // Check if relocation is requested
        if (options.hasRelocation) {
            // Setup parameters for relocation
            util::RelocationParams params;
            params.inputFile = options.inputFile;
            params.outputFile = options.outputFile;
            params.tempDir = options.tempDir;
            params.relocationAddress = options.relocationAddress;
            params.kickAssPath = options.kickAssPath;

            // Perform the relocation
            util::RelocationResult result = util::relocateSID(cpu_.get(), sid_.get(), params);

            // Return success/failure
            return result.success;
        }
        else {
            // No relocation requested - just create a SID file

            // Different handling based on input type
            std::string ext = getFileExtension(options.inputFile);

            if (ext == ".sid") {
                // Input is already a SID - just copy it (or extract/modify if needed)
                try {
                    fs::copy_file(options.inputFile, options.outputFile, fs::copy_options::overwrite_existing);
                    return true;
                }
                catch (const std::exception& e) {
                    util::Logger::error(std::string("Failed to copy SID file: ") + e.what());
                    return false;
                }
            }
            else if (ext == ".prg") {
                // Input is PRG - need to create a SID file

                // We need load, init, and play addresses
                u16 loadAddr = options.hasOverrideLoad ?
                    options.overrideLoadAddress : util::ConfigManager::getDefaultSidLoadAddress();
                u16 initAddr = options.hasOverrideInit ?
                    options.overrideInitAddress : util::ConfigManager::getDefaultSidInitAddress();
                u16 playAddr = options.hasOverridePlay ?
                    options.overridePlayAddress : util::ConfigManager::getDefaultSidPlayAddress();

                // Get default flags and SID addresses
                const SIDHeader& originalHeader = sid_->getHeader();
                u16 flags = originalHeader.flags;
                u8 secondSIDAddress = originalHeader.secondSIDAddress;
                u8 thirdSIDAddress = originalHeader.thirdSIDAddress;
                u16 version = originalHeader.version;
                u32 speed = originalHeader.speed;

                // Create SID from PRG
                bool success = util::createSIDFromPRG(
                    options.inputFile,
                    options.outputFile,
                    loadAddr,
                    initAddr,
                    playAddr,
                    options.overrideTitle,
                    options.overrideAuthor,
                    options.overrideCopyright,
                    flags,
                    secondSIDAddress,
                    thirdSIDAddress,
                    version,
                    speed);

                if (!success) {
                    try {
                        fs::copy_file(options.inputFile, options.outputFile, fs::copy_options::overwrite_existing);
                        return true;
                    }
                    catch (const std::exception& e) {
                        util::Logger::error(std::string("Failed to copy PRG file: ") + e.what());
                        return false;
                    }
                }

                return success;
            }
            else {
                util::Logger::error("Unsupported input file type for SID output");
                return false;
            }
        }
    }

    bool CommandProcessor::generateASMOutput(const ProcessingOptions& options) {
        // Base name for files
        std::string basename = options.inputFile.stem().string();

        // Setup temporary file paths
        fs::path tempDir = options.tempDir;

        // Restore original memory for clean disassembly
        sid_->restoreMemory();

        // Determine if we're relocating
        u16 outputSidLoad = options.hasRelocation ?
            options.relocationAddress : sid_->getLoadAddress();

        // Generate disassembly with adjusted addresses as needed
        const u16 sidLoad = sid_->getLoadAddress();
        const u16 newSidInit = outputSidLoad + (sid_->getInitAddress() - sidLoad);
        const u16 newSidPlay = outputSidLoad + (sid_->getPlayAddress() - sidLoad);

        disassembler_->generateAsmFile(options.outputFile.string(), outputSidLoad, newSidInit, newSidPlay, true);

        return true;
    }

} // namespace sidwinder