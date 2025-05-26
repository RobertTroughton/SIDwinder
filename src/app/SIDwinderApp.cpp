// SIDwinderApp.cpp
#include "SIDwinderApp.h"
#include "CommandProcessor.h"
#include "RelocationUtils.h"
#include "../SIDwinderUtils.h"
#include "../ConfigManager.h"
#include "../cpu6510.h"
#include "../SIDLoader.h"
#include "../SIDEmulator.h"
#include <iostream>
#include <filesystem>

namespace sidwinder {

    SIDwinderApp::SIDwinderApp(int argc, char** argv)
        : cmdParser_(argc, argv),
        command_(CommandClass::Type::Unknown) {

        // Setup command line options
        setupCommandLine();
    }

    int SIDwinderApp::run() {
        // Look for configuration file in current directory and executable directory
        fs::path configFile = "SIDwinder.cfg";
        if (!fs::exists(configFile)) {
            // Try executable directory
            configFile = fs::path(cmdParser_.getProgramName()).parent_path() / "SIDwinder.cfg";
        }

        // Initialize configuration system
        util::ConfigManager::initialize(configFile);

        // Initialize logging
        initializeLogging();

        // Parse command line into command object
        command_ = cmdParser_.parse();

        // Execute the command
        return executeCommand();
    }

    void SIDwinderApp::setupCommandLine() {
        // Command type flags - updated with new simplified syntax
        cmdParser_.addFlagDefinition("player", "Link SID music with a player (convert .sid to playable .prg)", "Commands");
        cmdParser_.addFlagDefinition("relocate", "Relocate a SID file to a new address (use -relocate=<address>)", "Commands");
        cmdParser_.addFlagDefinition("disassemble", "Disassemble a SID file to assembly code", "Commands");
        cmdParser_.addFlagDefinition("trace", "Trace SID register writes during emulation", "Commands");

        // Remove old options and add new ones
        std::string defaultPlayerName = util::ConfigManager::getPlayerName();

        // General options
        cmdParser_.addOptionDefinition("log", "file", "Log file path", "General", util::ConfigManager::getString("logFile", "SIDwinder.log"));

        cmdParser_.addOptionDefinition("kickass", "path", "Path to KickAss.jar", "General", util::ConfigManager::getKickAssPath());

        cmdParser_.addOptionDefinition("exomizer", "path", "Path to Exomizer", "General", util::ConfigManager::getExomizerPath());

        cmdParser_.addOptionDefinition("define", "key=value", "Add user definition (can be used multiple times)", "Assembly");

        // Flags
        cmdParser_.addFlagDefinition("verbose", "Enable verbose logging", "General");
        cmdParser_.addFlagDefinition("help", "Display this help message", "General");
        cmdParser_.addFlagDefinition("force", "Force overwrite of output file", "General");
        cmdParser_.addFlagDefinition("nocompress", "Disable compression for PRG output", "General");
        cmdParser_.addFlagDefinition("noverify", "Skip verification after relocation", "Relocation");

        // Add example usages
        cmdParser_.addExample(
            "SIDwinder -player music.sid music.prg",
            "Links music.sid with the default player to create an executable music.prg");

        cmdParser_.addExample(
            "SIDwinder -player=SimpleBitmap music.sid player.prg",
            "Links music.sid with SimpleBitmap player");

        cmdParser_.addExample(
            "SIDwinder -relocate=$2000 music.sid relocated.sid",
            "Relocates music.sid to $2000 and saves as relocated.sid");

        cmdParser_.addExample(
            "SIDwinder -disassemble music.sid music.asm",
            "Disassembles music.sid to assembly code in music.asm");

        cmdParser_.addExample(
            "SIDwinder -trace music.sid",
            "Traces SID register writes to trace.bin in binary format");

        cmdParser_.addExample(
            "SIDwinder -trace=music.log music.sid",
            "Traces SID register writes to music.log in text format");

        cmdParser_.addExample(
            "SIDwinder -player -define BackgroundColor=$02 -define PlayerName=Dave music.sid game.prg",
            "Creates player with custom definitions accessible in the player code");

        cmdParser_.addExample(
            "SIDwinder -player=RaistlinBarsWithLogo -define LogoFile=\"Logos/MCH.kla\" music.sid game.prg",
            "Example with different logo for the player");
    }

    void SIDwinderApp::initializeLogging() {
        // Get log file path from command parameters or config
        std::string logFilePath = command_.getParameter("logfile",
            util::ConfigManager::getString("logFile", "SIDwinder.log"));
        logFile_ = fs::path(logFilePath);

        // Set log level based on verbose flag or config
        verbose_ = command_.hasFlag("verbose");

        // Convert integer log level from config to Logger::Level
        int configLogLevel = util::ConfigManager::getInt("logLevel", 3); // Default to Info
        auto logLevel = verbose_ ?
            util::Logger::Level::Debug :
            static_cast<util::Logger::Level>(std::min(std::max(configLogLevel - 1, 0), 3));

        // Initialize logger
        util::Logger::initialize(logFile_);
        util::Logger::setLogLevel(logLevel);

        util::Logger::info(SIDwinder_VERSION " started");
    }

    int SIDwinderApp::executeCommand() {
        // Execute based on command type
        switch (command_.getType()) {
        case CommandClass::Type::Help:
            return showHelp();
        case CommandClass::Type::Player:
            return processPlayer();
        case CommandClass::Type::Relocate:
            return processRelocation();
        case CommandClass::Type::Disassemble:
            return processDisassembly();
        case CommandClass::Type::Trace:
            return processTrace();
        default:
            // Show help when no valid command is specified
            std::cout << "Unknown command or no command specified" << std::endl << std::endl;
            return showHelp();
        }
    }

    CommandProcessor::ProcessingOptions SIDwinderApp::createProcessingOptions() {
        CommandProcessor::ProcessingOptions options;

        // Get input and output files
        options.inputFile = fs::path(command_.getInputFile());
        options.outputFile = fs::path(command_.getOutputFile());

        // Create temp directory
        options.tempDir = fs::path("temp");
        try {
            fs::create_directories(options.tempDir);
        }
        catch (const std::exception& e) {
            util::Logger::error(std::string("Failed to create temp directory: ") + e.what());
        }

        // Get user definitions
        options.userDefinitions = command_.getDefinitions();

        // Player options for Player command (formerly LinkPlayer)
        if (command_.getType() == CommandClass::Type::Player) {
            options.includePlayer = true;
            options.playerName = command_.getParameter("playerName", util::ConfigManager::getPlayerName());
            options.playerAddress = command_.getHexParameter("playeraddr", util::ConfigManager::getPlayerAddress());
            options.analyzeRegisterOrder = true; // Enable register order analysis for player
        }
        else {
            options.includePlayer = false;
        }

        // Build options
        options.kickAssPath = command_.getParameter("kickass", util::ConfigManager::getKickAssPath());
        options.exomizerPath = command_.getParameter("exomizer", util::ConfigManager::getExomizerPath());
        options.compressorType = util::ConfigManager::getCompressorType();
        options.compress = !command_.hasFlag("nocompress");

        // Parse relocation address for Relocate command
        if (command_.getType() == CommandClass::Type::Relocate) {
            options.relocationAddress = command_.getHexParameter("relocateaddr", 0);
            options.hasRelocation = true;
            util::Logger::debug("Relocation address set to $" + util::wordToHex(options.relocationAddress));
        }

        // Trace options
        options.traceLogPath = command_.getParameter("tracelog", "");
        options.enableTracing = !options.traceLogPath.empty() || (command_.getType() == CommandClass::Type::Trace);
        std::string traceFormat = command_.getParameter("traceformat", "binary");
        options.traceFormat = (traceFormat == "text") ?
            TraceFormat::Text : TraceFormat::Binary;

        // Get frames to emulate from command line or config
        options.frames = command_.getIntParameter("frames",
            util::ConfigManager::getInt("emulationFrames", DEFAULT_SID_EMULATION_FRAMES));

        return options;
    }

    int SIDwinderApp::showHelp() {
        cmdParser_.printUsage(SIDwinder_VERSION);
        return 0;
    }

    int SIDwinderApp::processPlayer() {
        // Validate input file
        fs::path inputFile = fs::path(command_.getInputFile());
        fs::path outputFile = fs::path(command_.getOutputFile());

        if (inputFile.empty()) {
            std::cout << "Error: No input file specified for player command" << std::endl;
            return 1;
        }

        if (outputFile.empty()) {
            std::cout << "Error: No output file specified for player command" << std::endl;
            return 1;
        }

        if (!fs::exists(inputFile)) {
            std::cout << "Error: Input file not found: " << inputFile.string() << std::endl;
            return 1;
        }

        // Strictly enforce .sid input and .prg output
        std::string inExt = getFileExtension(inputFile);
        if (inExt != ".sid") {
            std::cout << "Error: Player command requires a .sid input file, got: " << inExt << std::endl;
            return 1;
        }

        std::string outExt = getFileExtension(outputFile);
        if (outExt != ".prg") {
            std::cout << "Error: Player command requires a .prg output file, got: " << outExt << std::endl;
            return 1;
        }

        // Create processing options
        CommandProcessor::ProcessingOptions options = createProcessingOptions();

        // Set Player specific options
        options.includePlayer = true;
        options.playerName = command_.getParameter("playerName", util::ConfigManager::getPlayerName());
        options.playerAddress = command_.getHexParameter("playeraddr", util::ConfigManager::getPlayerAddress());

        // Create and run command processor
        CommandProcessor processor;
        bool success = processor.processFile(options);
        if (success)
        {
            std::cout << "SUCCESS: " << outputFile << " successfully generated" << std::endl;
        }

        return success ? 0 : 1;
    }

    int SIDwinderApp::processRelocation() {
        // Validate input file
        fs::path inputFile = fs::path(command_.getInputFile());
        fs::path outputFile = fs::path(command_.getOutputFile());

        if (inputFile.empty()) {
            std::cout << "Error: No input file specified for relocate command" << std::endl;
            return 1;
        }

        if (outputFile.empty()) {
            std::cout << "Error: No output file specified for relocate command" << std::endl;
            return 1;
        }

        // [Existing validation code remains the same]

        // Create CPU and SID Loader
        auto cpu = std::make_unique<CPU6510>();
        cpu->reset();

        auto sid = std::make_unique<SIDLoader>();
        sid->setCPU(cpu.get());

        // Get relocation address
        u16 relocAddress = command_.getHexParameter("relocateaddr", 0);

        // Determine if verification should be skipped (can add a flag for this)
        bool skipVerify = command_.hasFlag("noverify");

        if (skipVerify) {
            // Original relocation code without verification
            util::RelocationParams params;
            params.inputFile = inputFile;
            params.outputFile = outputFile;
            params.tempDir = fs::path("temp");
            params.relocationAddress = relocAddress;
            params.kickAssPath = command_.getParameter("kickass", util::ConfigManager::getKickAssPath());
            params.verbose = command_.hasFlag("verbose");

            // Ensure temp directory exists
            try {
                fs::create_directories(params.tempDir);
            }
            catch (const std::exception& e) {
                util::Logger::error(std::string("Failed to create temp directory: ") + e.what());
                return 1;
            }

            // Relocate the SID file
            util::RelocationResult result = util::relocateSID(cpu.get(), sid.get(), params);

            if (result.success) {
                util::Logger::info("Successfully relocated " + inputFile.string() + " to " + outputFile.string() +
                    " (Load: $" + util::wordToHex(result.newLoad) +
                    ", Init: $" + util::wordToHex(result.newInit) +
                    ", Play: $" + util::wordToHex(result.newPlay) + ")", true);
                return 0;
            }
            else {
                util::Logger::error("Failed to relocate " + inputFile.string() + ": " + result.message);
                return 1;
            }
        }
        else {
            // Use relocate and verify method
            fs::path tempDir = fs::path("temp");
            try {
                fs::create_directories(tempDir);
            }
            catch (const std::exception& e) {
                util::Logger::error(std::string("Failed to create temp directory: ") + e.what());
                return 1;
            }

            // Perform relocation with verification
            util::RelocationVerificationResult result = util::relocateAndVerifySID(
                cpu.get(), sid.get(), inputFile, outputFile, relocAddress, tempDir,
                command_.getParameter("kickass", util::ConfigManager::getKickAssPath()));

            // Display results to user
            if (result.success) {
                if (result.verified) {
                    if (result.outputsMatch) {
                        std::cout << "SUCCESS: " << inputFile << " successfully relocated and verified" << std::endl;
                    }
                    else {
                        std::cout << "FAILURE: " << inputFile << " relocation verification failed. Difference report saved to: " << result.diffReport << std::endl;
                    }
                }
                else {
                    std::cout << "SUCCESS: " << inputFile << " relocation completed (but verification not completed) - " << result.message << std::endl;
                }
                return result.outputsMatch ? 0 : 1;
            }
            else {
                std::cout << "FAILURE: " << inputFile << " relocation failed - " << result.message << std::endl;
                return 1;
            }
        }
    }

    int SIDwinderApp::processDisassembly() {
        // Validate input file
        fs::path inputFile = fs::path(command_.getInputFile());
        fs::path outputFile = fs::path(command_.getOutputFile());

        if (inputFile.empty()) {
            std::cout << "Error: No input file specified for disassemble command" << std::endl;
            return 1;
        }

        if (outputFile.empty()) {
            std::cout << "Error: No output file specified for disassemble command" << std::endl;
            return 1;
        }

        if (!fs::exists(inputFile)) {
            std::cout << "Error: Input file not found: " << inputFile.string() << std::endl;
            return 1;
        }

        // Strictly enforce .sid input and .asm output
        std::string inExt = getFileExtension(inputFile);
        if (inExt != ".sid") {
            std::cout << "Error: Disassemble command requires a .sid input file, got: " << inExt << std::endl;
            return 1;
        }

        std::string outExt = getFileExtension(outputFile);
        if (outExt != ".asm") {
            std::cout << "Error: Disassemble command requires an .asm output file, got: " << outExt << std::endl;
            return 1;
        }

        // Create processing options
        CommandProcessor::ProcessingOptions options = createProcessingOptions();

        // Create and run command processor
        CommandProcessor processor;
        bool success = processor.processFile(options);

        if (success) {
            util::Logger::info("Successfully disassembled " + inputFile.string() + " to " + outputFile.string(), true);
        }
        else {
            util::Logger::error("Failed to disassemble " + inputFile.string());
        }

        return success ? 0 : 1;
    }

    int SIDwinderApp::processTrace() {
        // Validate input file
        fs::path inputFile = fs::path(command_.getInputFile());

        if (inputFile.empty()) {
            std::cout << "Error: No input file specified for trace command" << std::endl;
            return 1;
        }

        if (!fs::exists(inputFile)) {
            std::cout << "Error: Input file not found: " << inputFile.string() << std::endl;
            return 1;
        }

        // Strictly enforce .sid extension for input
        std::string inExt = getFileExtension(inputFile);
        if (inExt != ".sid") {
            std::cout << "Error: Trace command requires a .sid input file, got: " << inExt << std::endl;
            return 1;
        }

        // Get trace log path from the command
        std::string traceLogPath = command_.getParameter("tracelog", "trace.bin");

        // Determine trace format
        std::string traceFormatStr = command_.getParameter("traceformat", "binary");
        TraceFormat traceFormat = (traceFormatStr == "text") ? TraceFormat::Text : TraceFormat::Binary;

        util::Logger::info("Tracing SID register writes for " + inputFile.string() +
            " to " + traceLogPath + " in " + traceFormatStr + " format");

        // Create CPU and SID Loader
        auto cpu = std::make_unique<CPU6510>();
        cpu->reset();

        auto sid = std::make_unique<SIDLoader>();
        sid->setCPU(cpu.get());

        // Load the SID file
        if (!sid->loadSID(inputFile.string())) {
            std::cout << "Error: Failed to load SID file: " << inputFile.string() << std::endl;
            return 1;
        }

        // Create trace logger
        auto traceLogger = std::make_unique<TraceLogger>(traceLogPath, traceFormat);

        // Set up callback for SID writes
        cpu->setOnSIDWriteCallback([&traceLogger](u16 addr, u8 value) {
            traceLogger->logSIDWrite(addr, value);
            });

        // Create emulator
        SIDEmulator emulator(cpu.get(), sid.get());
        SIDEmulator::EmulationOptions options;

        // Get frames count from command line or config
        options.frames = command_.getIntParameter("frames",
            util::ConfigManager::getInt("emulationFrames", DEFAULT_SID_EMULATION_FRAMES));

        options.traceEnabled = true;
        options.traceFormat = traceFormat;
        options.traceLogPath = traceLogPath;

        // Run the emulation
        bool success = emulator.runEmulation(options);

        if (success) {
            util::Logger::info("Successfully traced SID register writes to: " + traceLogPath, true);
            return 0;
        }
        else {
            util::Logger::error("Error occurred during SID emulation on " + inputFile.string());
            return 1;
        }
    }

} // namespace sidwinder