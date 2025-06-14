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
#include "../MemoryConstants.h"
#include "../SIDplayers/PlayerManager.h"
#include "../SIDplayers/PlayerOptions.h"
#include "MusicBuilder.h"

namespace sidwinder {

    CommandProcessor::CommandProcessor() {
        // Initialize CPU
        cpu_ = std::make_unique<CPU6510>();
        cpu_->reset();

        // Initialize SID Loader
        sid_ = std::make_unique<SIDLoader>();
        sid_->setCPU(cpu_.get());

        // Initialize builders
        musicBuilder_ = std::make_unique<MusicBuilder>(cpu_.get(), sid_.get());
        playerManager_ = std::make_unique<PlayerManager>(cpu_.get(), sid_.get());
    }

    CommandProcessor::~CommandProcessor() {
        // Ensure trace logger is closed properly
        traceLogger_.reset();
    }

    bool CommandProcessor::processFile(const ProcessingOptions& options) {
        try {
            fs::create_directories(options.tempDir);
            if (options.enableTracing && !options.traceLogPath.empty()) {
                traceLogger_ = std::make_unique<TraceLogger>(options.traceLogPath, options.traceFormat);
            }
            if (!loadInputFile(options)) {
                return false;
            }

            // Apply metadata overrides right after loading - this ensures they're used everywhere
            applySIDMetadataOverrides(options);

            bool needsEmulation = false;
            if (util::isValidASMFile(options.outputFile) ||
                (util::isValidSIDFile(options.outputFile) && options.hasRelocation)) {
                needsEmulation = true;
            }
            if (options.enableTracing) {
                needsEmulation = true;
            }
            if (needsEmulation) {
                if (!analyzeMusic(options)) {
                    return false;
                }
            }
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
        // Verify input file exists
        if (!fs::exists(options.inputFile)) {
            util::Logger::error("Input file not found: " + options.inputFile.string());
            return false;
        }

        // Only accept SID files
        if (!util::isValidSIDFile(options.inputFile)) {
            util::Logger::error("Unsupported file type: " + options.inputFile.string() + " - only SID files accepted.");
            return false;
        }

        // Load the SID file
        if (!sid_->loadSID(options.inputFile.string())) {
            util::Logger::error("Failed to load SID file: " + options.inputFile.string());
            return false;
        }

        // Apply address overrides if specified
        if (options.hasOverrideInit) {
            sid_->setInitAddress(options.overrideInitAddress);
        }
        if (options.hasOverridePlay) {
            sid_->setPlayAddress(options.overridePlayAddress);
        }
        if (options.hasOverrideLoad) {
            sid_->setLoadAddress(options.overrideLoadAddress);
        }

        return true;
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

        // Set up emulation options
        SIDEmulator emulator(cpu_.get(), sid_.get());
        SIDEmulator::EmulationOptions emulationOptions;

        // Use frames count from options (from command line or config)
        emulationOptions.frames = options.frames > 0 ?
            options.frames : util::ConfigManager::getInt("emulationFrames", DEFAULT_SID_EMULATION_FRAMES);

        emulationOptions.traceEnabled = options.enableTracing;
        emulationOptions.traceFormat = options.traceFormat;
        emulationOptions.traceLogPath = options.traceLogPath;

        // Run the emulation
        if (!emulator.runEmulation(emulationOptions)) {
            util::Logger::error("SID emulation failed");
            return false;
        }

        // Create disassembler after emulation
        disassembler_ = std::make_unique<Disassembler>(*cpu_, *sid_);

        return true;
    }

    bool CommandProcessor::generateOutput(const ProcessingOptions& options) {
        // Generate the appropriate output format
        std::string ext = util::getFileExtension(options.outputFile);

        if (ext == ".prg") {
            return generatePRGOutput(options);
        }
        else if (ext == ".sid") {
            return generateSIDOutput(options);
        }
        else if (ext == ".asm") {
            return generateASMOutput(options);
        }

        util::Logger::error("Unsupported output format: " + ext);
        return false;
    }

    bool CommandProcessor::generatePRGOutput(const ProcessingOptions& options) {
        // If including player, delegate to PlayerManager
        if (options.includePlayer) {
            // Convert options to PlayerOptions
            PlayerOptions playerOpts;
            playerOpts.playerName = options.playerName;
            playerOpts.playerAddress = options.playerAddress;
            playerOpts.compress = options.compress;
            playerOpts.compressorType = options.compressorType;
            playerOpts.exomizerPath = options.exomizerPath;
            playerOpts.kickAssPath = options.kickAssPath;
            playerOpts.tempDir = options.tempDir;
            playerOpts.userDefinitions = options.userDefinitions;

            // Set SID addresses
            playerOpts.sidLoadAddr = sid_->getLoadAddress();
            playerOpts.sidInitAddr = sid_->getInitAddress();
            playerOpts.sidPlayAddr = sid_->getPlayAddress();

            // Calculate play calls per frame
            const uint32_t speedBits = sid_->getHeader().speed;
            int count = 0;
            for (int i = 0; i < 32; ++i) {
                if (speedBits & (1u << i)) {
                    ++count;
                }
            }
            playerOpts.playCallsPerFrame = std::clamp(count == 0 ? 1 : count, 1, 16);

            // Analyze music if needed
            playerManager_->analyzeMusicForPlayer(playerOpts);

            return playerManager_->processWithPlayer(options.inputFile, options.outputFile, playerOpts);
        }

        // For non-player PRG output
        std::string basename = options.inputFile.stem().string();

        // Handle relocation
        if (options.hasRelocation) {
            // Need to disassemble and reassemble at new address
            if (!disassembler_) {
                // Run analysis if not already done
                if (!analyzeMusic(options)) {
                    return false;
                }
            }

            sid_->restoreMemory();

            // Generate relocated assembly
            fs::path tempAsmFile = options.tempDir / (basename + "-relocated.asm");
            const u16 sidLoad = sid_->getLoadAddress();
            const u16 newSidLoad = options.relocationAddress;
            const u16 newSidInit = newSidLoad + (sid_->getInitAddress() - sidLoad);
            const u16 newSidPlay = newSidLoad + (sid_->getPlayAddress() - sidLoad);

            disassembler_->generateAsmFile(tempAsmFile.string(), newSidLoad, newSidInit, newSidPlay, true);

            // Build the relocated PRG
            MusicBuilder::BuildOptions buildOpts;
            buildOpts.kickAssPath = options.kickAssPath;
            buildOpts.tempDir = options.tempDir;

            return musicBuilder_->buildMusic(basename, tempAsmFile, options.outputFile, buildOpts);
        }
        else {
            // Simple extraction from SID to PRG
            return SIDLoader::extractPrgFromSid(options.inputFile, options.outputFile);
        }
    }

    bool CommandProcessor::generateSIDOutput(const ProcessingOptions& options) {
        if (options.hasRelocation) {
            util::RelocationParams params;
            params.inputFile = options.inputFile;
            params.outputFile = options.outputFile;
            params.tempDir = options.tempDir;
            params.relocationAddress = options.relocationAddress;
            params.kickAssPath = options.kickAssPath;
            util::RelocationResult result = util::relocateSID(cpu_.get(), sid_.get(), params);
            return result.success;
        }
        else {
            if (!options.overrideTitle.empty() || !options.overrideAuthor.empty() || !options.overrideCopyright.empty()) {
                auto sidData = util::readBinaryFile(options.inputFile);
                if (!sidData) {
                    util::Logger::error("Failed to read input SID file");
                    return false;
                }

                SIDHeader header;
                std::memcpy(&header, sidData->data(), sizeof(header));

                if (!options.overrideTitle.empty()) {
                    std::memset(header.name, 0, sizeof(header.name));
                    std::strncpy(header.name, options.overrideTitle.c_str(), sizeof(header.name) - 1);
                }
                if (!options.overrideAuthor.empty()) {
                    std::memset(header.author, 0, sizeof(header.author));
                    std::strncpy(header.author, options.overrideAuthor.c_str(), sizeof(header.author) - 1);
                }
                if (!options.overrideCopyright.empty()) {
                    std::memset(header.copyright, 0, sizeof(header.copyright));
                    std::strncpy(header.copyright, options.overrideCopyright.c_str(), sizeof(header.copyright) - 1);
                }

                std::vector<u8> newSidData;
                newSidData.resize(sizeof(header));
                std::memcpy(newSidData.data(), &header, sizeof(header));
                newSidData.insert(newSidData.end(), sidData->begin() + sizeof(header), sidData->end());

                return util::writeBinaryFile(options.outputFile, newSidData);
            }
            else {
                try {
                    fs::copy_file(options.inputFile, options.outputFile, fs::copy_options::overwrite_existing);
                    return true;
                }
                catch (const std::exception& e) {
                    util::Logger::error(std::string("Failed to copy SID file: ") + e.what());
                    return false;
                }
            }
        }
    }

    bool CommandProcessor::generateASMOutput(const ProcessingOptions& options) {
        // Ensure we have analyzed the music
        if (!disassembler_) {
            if (!analyzeMusic(options)) {
                return false;
            }
        }

        // Restore original memory for clean disassembly
        sid_->restoreMemory();

        // Determine output addresses
        u16 outputSidLoad = options.hasRelocation ?
            options.relocationAddress : sid_->getLoadAddress();

        const u16 sidLoad = sid_->getLoadAddress();
        const u16 newSidInit = outputSidLoad + (sid_->getInitAddress() - sidLoad);
        const u16 newSidPlay = outputSidLoad + (sid_->getPlayAddress() - sidLoad);

        // Generate disassembly
        disassembler_->generateAsmFile(options.outputFile.string(), outputSidLoad, newSidInit, newSidPlay, true);

        return true;
    }

} // namespace sidwinder