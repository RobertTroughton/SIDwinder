// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
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
        setupCommandLine();
    }

    int SIDwinderApp::run() {
        // Find and initialize configuration
        fs::path configFile = "SIDwinder.cfg";
        if (!fs::exists(configFile)) {
            configFile = fs::path(cmdParser_.getProgramName()).parent_path() / "SIDwinder.cfg";
        }
        util::ConfigManager::initialize(configFile);

        // Parse command line
        command_ = cmdParser_.parse();

        // Initialize logging
        initializeLogging();

        // Execute the command
        return executeCommand();
    }

    void SIDwinderApp::setupCommandLine() {
        cmdParser_.addFlagDefinition("player", "Link SID music with a player (convert .sid to playable .prg)", "Commands");
        cmdParser_.addFlagDefinition("relocate", "Relocate a SID file to a new address (use -relocate=<address>)", "Commands");
        cmdParser_.addFlagDefinition("disassemble", "Disassemble a SID file to assembly code", "Commands");
        cmdParser_.addFlagDefinition("trace", "Trace SID register writes during emulation", "Commands");
        cmdParser_.addOptionDefinition("log", "file", "Log file path", "General", util::ConfigManager::getString("logFile", "SIDwinder.log"));
        cmdParser_.addOptionDefinition("kickass", "path", "Path to KickAss.jar", "General", util::ConfigManager::getKickAssPath());
        cmdParser_.addOptionDefinition("exomizer", "path", "Path to Exomizer", "General", util::ConfigManager::getExomizerPath());
        cmdParser_.addOptionDefinition("define", "key=value", "Add user definition (can be used multiple times)", "Assembly");

        cmdParser_.addOptionDefinition("sidname", "name", "Override SID title/name", "SID Metadata");
        cmdParser_.addOptionDefinition("sidauthor", "author", "Override SID author", "SID Metadata");
        cmdParser_.addOptionDefinition("sidcopyright", "text", "Override SID copyright", "SID Metadata");

        cmdParser_.addFlagDefinition("verbose", "Enable verbose logging", "General");
        cmdParser_.addFlagDefinition("help", "Display this help message", "General");
        cmdParser_.addFlagDefinition("force", "Force overwrite of output file", "General");
        cmdParser_.addOptionDefinition("playeraddr", "address", "Player load address", "Player", "$4000");
        cmdParser_.addFlagDefinition("nocompress", "Disable compression for PRG output", "Player");
        cmdParser_.addFlagDefinition("noverify", "Skip verification after relocation", "Relocation");
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
        cmdParser_.addExample(
            "SIDwinder -player -sidname=\"My Cool Tune\" -sidauthor=\"DJ Awesome\" music.sid player.prg",
            "Creates player with overridden SID metadata");
        cmdParser_.addExample(
            "SIDwinder -relocate=$3000 -sidcopyright=\"(C) 2025 Me\" music.sid relocated.sid",
            "Relocates SID with updated copyright information");
    }

    void SIDwinderApp::initializeLogging() {
        std::string logFilePath = command_.getParameter("logfile",
            util::ConfigManager::getString("logFile", "SIDwinder.log"));
        logFile_ = fs::path(logFilePath);
        verbose_ = command_.hasFlag("verbose");

        int configLogLevel = util::ConfigManager::getInt("logLevel", 3);
        auto logLevel = verbose_ ?
            util::Logger::Level::Debug :
            static_cast<util::Logger::Level>(std::min(std::max(configLogLevel - 1, 0), 3));

        util::Logger::initialize(logFile_);
        util::Logger::setLogLevel(logLevel);
    }

    int SIDwinderApp::executeCommand() {
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
            std::cout << "Unknown command or no command specified" << std::endl << std::endl;
            return showHelp();
        }
    }

    CommandProcessor::ProcessingOptions SIDwinderApp::createProcessingOptions() {
        CommandProcessor::ProcessingOptions options;
        options.inputFile = fs::path(command_.getInputFile());
        options.outputFile = fs::path(command_.getOutputFile());
        options.tempDir = fs::path("temp");
        try {
            fs::create_directories(options.tempDir);
        }
        catch (const std::exception& e) {
            util::Logger::error(std::string("Failed to create temp directory: ") + e.what());
        }
        options.userDefinitions = command_.getDefinitions();
        options.kickAssPath = command_.getParameter("kickass", util::ConfigManager::getKickAssPath());

        if (command_.hasParameter("sidname")) {
            options.overrideTitle = command_.getParameter("sidname");
        }
        if (command_.hasParameter("sidauthor")) {
            options.overrideAuthor = command_.getParameter("sidauthor");
        }
        if (command_.hasParameter("sidcopyright")) {
            options.overrideCopyright = command_.getParameter("sidcopyright");
        }
        if (command_.hasParameter("sidloadaddr")) {
            options.overrideLoadAddress = command_.getHexParameter("sidloadaddr", 0);
            options.hasOverrideLoad = true;
        }
        if (command_.hasParameter("sidinitaddr")) {
            options.overrideInitAddress = command_.getHexParameter("sidinitaddr", 0);
            options.hasOverrideInit = true;
        }
        if (command_.hasParameter("sidplayaddr")) {
            options.overridePlayAddress = command_.getHexParameter("sidplayaddr", 0);
            options.hasOverridePlay = true;
        }

        if (command_.getType() == CommandClass::Type::Player) {
            options.includePlayer = true;
            options.playerName = command_.getParameter("playerName", util::ConfigManager::getPlayerName());
            options.playerAddress = command_.getHexParameter("playeraddr", util::ConfigManager::getPlayerAddress());
            options.compress = !command_.hasFlag("nocompress");
            options.exomizerPath = command_.getParameter("exomizer", util::ConfigManager::getExomizerPath());
            options.compressorType = util::ConfigManager::getCompressorType();
        }
        if (command_.getType() == CommandClass::Type::Relocate) {
            options.relocationAddress = command_.getHexParameter("relocateaddr", 0);
            options.hasRelocation = true;
        }
        if (command_.getType() == CommandClass::Type::Trace) {
            options.enableTracing = true;
            options.traceLogPath = command_.getParameter("tracelog", "trace.bin");
            std::string traceFormat = command_.getParameter("traceformat", "binary");
            options.traceFormat = (traceFormat == "text") ? TraceFormat::Text : TraceFormat::Binary;
        }
        options.frames = command_.getIntParameter("frames",
            util::ConfigManager::getInt("emulationFrames", DEFAULT_SID_EMULATION_FRAMES));
        return options;
    }

    int SIDwinderApp::showHelp() {
        cmdParser_.printUsage(SIDwinder_VERSION);
        return 0;
    }

    int SIDwinderApp::processPlayer() {
        fs::path inputFile = fs::path(command_.getInputFile());
        fs::path outputFile = fs::path(command_.getOutputFile());

        // Validate input
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

        // Check file types
        std::string inExt = util::getFileExtension(inputFile);
        if (inExt != ".sid") {
            std::cout << "Error: Player command requires a .sid input file, got: " << inExt << std::endl;
            return 1;
        }

        std::string outExt = util::getFileExtension(outputFile);
        if (outExt != ".prg") {
            std::cout << "Error: Player command requires a .prg output file, got: " << outExt << std::endl;
            return 1;
        }

        // Create processing options
        CommandProcessor::ProcessingOptions options = createProcessingOptions();

        // Process the file
        CommandProcessor processor;
        bool success = processor.processFile(options);

        if (success) {
            std::cout << "SUCCESS: " << outputFile << " successfully generated" << std::endl;
        }

        return success ? 0 : 1;
    }

    int SIDwinderApp::processRelocation() {
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

        // Create CPU and SID loader for relocation
        auto cpu = std::make_unique<CPU6510>();
        cpu->reset();
        auto sid = std::make_unique<SIDLoader>();
        sid->setCPU(cpu.get());

        u16 relocAddress = command_.getHexParameter("relocateaddr", 0);
        bool skipVerify = command_.hasFlag("noverify");

        if (skipVerify) {
            // Simple relocation without verification
            util::RelocationParams params;
            params.inputFile = inputFile;
            params.outputFile = outputFile;
            params.tempDir = fs::path("temp");
            params.relocationAddress = relocAddress;
            params.kickAssPath = command_.getParameter("kickass", util::ConfigManager::getKickAssPath());
            params.verbose = command_.hasFlag("verbose");

            try {
                fs::create_directories(params.tempDir);
            }
            catch (const std::exception& e) {
                util::Logger::error(std::string("Failed to create temp directory: ") + e.what());
                return 1;
            }

            util::RelocationResult result = util::relocateSID(cpu.get(), sid.get(), params);

            if (result.success) {
                std::cout << "SUCCESS: Relocated " << inputFile << " to $" << util::wordToHex(relocAddress) << std::endl;
                return 0;
            }
            else {
                util::Logger::error("Failed to relocate " + inputFile.string() + ": " + result.message);
                return 1;
            }
        }
        else {
            // Relocation with verification
            fs::path tempDir = fs::path("temp");
            try {
                fs::create_directories(tempDir);
            }
            catch (const std::exception& e) {
                util::Logger::error(std::string("Failed to create temp directory: ") + e.what());
                return 1;
            }

            util::RelocationVerificationResult result = util::relocateAndVerifySID(
                cpu.get(), sid.get(), inputFile, outputFile, relocAddress, tempDir,
                command_.getParameter("kickass", util::ConfigManager::getKickAssPath()));

            bool bTotalSuccess = result.success && result.verified && result.outputsMatch;
            std::cout << (bTotalSuccess ? "SUCCESS" : "FAILURE") << ": " << inputFile << " " << result.message << std::endl;

            return bTotalSuccess ? 0 : 1;
        }
    }

    int SIDwinderApp::processDisassembly() {
        fs::path inputFile = fs::path(command_.getInputFile());
        fs::path outputFile = fs::path(command_.getOutputFile());

        // Validate input
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

        // Check file types
        std::string inExt = util::getFileExtension(inputFile);
        if (inExt != ".sid") {
            std::cout << "Error: Disassemble command requires a .sid input file, got: " << inExt << std::endl;
            return 1;
        }

        std::string outExt = util::getFileExtension(outputFile);
        if (outExt != ".asm") {
            std::cout << "Error: Disassemble command requires an .asm output file, got: " << outExt << std::endl;
            return 1;
        }

        // Create processing options
        CommandProcessor::ProcessingOptions options = createProcessingOptions();

        // Process the file
        CommandProcessor processor;
        bool success = processor.processFile(options);

        if (success) {
            std::cout << "SUCCESS: Disassembled " << inputFile << " to " << outputFile << std::endl;
        }
        else {
            util::Logger::error("Failed to disassemble " + inputFile.string());
        }

        return success ? 0 : 1;
    }

    int SIDwinderApp::processTrace() {
        fs::path inputFile = fs::path(command_.getInputFile());

        // Validate input
        if (inputFile.empty()) {
            std::cout << "Error: No input file specified for trace command" << std::endl;
            return 1;
        }
        if (!fs::exists(inputFile)) {
            std::cout << "Error: Input file not found: " << inputFile.string() << std::endl;
            return 1;
        }

        // Check file type
        std::string inExt = util::getFileExtension(inputFile);
        if (inExt != ".sid") {
            std::cout << "Error: Trace command requires a .sid input file, got: " << inExt << std::endl;
            return 1;
        }

        // Create processing options
        CommandProcessor::ProcessingOptions options = createProcessingOptions();
        options.inputFile = inputFile;
        options.outputFile = fs::path(); // No output file for trace

        // Process the file
        CommandProcessor processor;
        bool success = processor.processFile(options);

        if (success) {
            std::cout << "SUCCESS: Trace log written to " << options.traceLogPath << std::endl;
        }
        else {
            util::Logger::error("Error occurred during SID emulation on " + inputFile.string());
        }

        return success ? 0 : 1;
    }

} // namespace sidwinder