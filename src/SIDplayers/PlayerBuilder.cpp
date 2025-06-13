// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#include "PlayerBuilder.h"
#include "../SIDwinderUtils.h"
#include "../ConfigManager.h"
#include "../cpu6510.h"
#include "../SIDLoader.h"
#include "../SIDEmulator.h"

#include <fstream>
#include <cctype>

namespace sidwinder {

    PlayerBuilder::PlayerBuilder(const CPU6510* cpu, const SIDLoader* sid)
        : cpu_(cpu), sid_(sid) {
        // Create an emulator for analysis
        emulator_ = std::make_unique<SIDEmulator>(const_cast<CPU6510*>(cpu), const_cast<SIDLoader*>(sid));
    }

    PlayerBuilder::~PlayerBuilder() = default; // Destructor implementation

    bool PlayerBuilder::buildMusicWithPlayer(
        const std::string& basename,
        const fs::path& inputFile,
        const fs::path& outputFile,
        const PlayerOptions& options) {

        // Create temp directory if it doesn't exist
        try {
            fs::create_directories(options.tempDir);
        }
        catch (const std::exception& e) {
            util::Logger::error(std::string("Failed to create temp directory: ") + e.what());
            return false;
        }

        // Setup temporary file paths
        fs::path tempDir = options.tempDir;
        fs::path tempPlayerPrgFile = tempDir / (basename + "-player.prg");
        fs::path tempLinkerFile = tempDir / (basename + "-linker.asm");

        // Set default player name if none specified
        std::string playerToUse = options.playerName;
        if (playerToUse == "default") {
            playerToUse = util::ConfigManager::getPlayerName();
        }

        // Get player assembly file path
        fs::path playerAsmFile = options.playerDirectory / playerToUse / (playerToUse + ".asm");

        // Create the player directory if it doesn't exist
        fs::create_directories(playerAsmFile.parent_path());

        // Generate helpful data for double-buffering
        fs::path helpfulDataFile = tempDir / (basename + "-HelpfulData.asm");
        generateHelpfulData(helpfulDataFile, options);

        // Create linker file
        if (!createLinkerFile(tempLinkerFile, inputFile, playerAsmFile, options)) {
            return false;
        }

        // Run assembler to build player+music
        if (!runAssembler(tempLinkerFile, tempPlayerPrgFile, options.kickAssPath, options.tempDir)) {
            return false;
        }

        // Apply compression if requested
        if (options.compress) {
            if (!compressPrg(tempPlayerPrgFile, outputFile, options.playerAddress, options)) {
                // Fallback to uncompressed if compression fails
                try {
                    fs::copy_file(tempPlayerPrgFile, outputFile,
                        fs::copy_options::overwrite_existing);
                    return true;
                }
                catch (const std::exception& e) {
                    util::Logger::error(std::string("Failed to copy uncompressed PRG: ") + e.what());
                    return false;
                }
            }
            return true;
        }
        else {
            // Copy uncompressed file to output
            try {
                fs::copy_file(tempPlayerPrgFile, outputFile,
                    fs::copy_options::overwrite_existing);
                return true;
            }
            catch (const std::exception& e) {
                util::Logger::error(std::string("Failed to copy uncompressed PRG: ") + e.what());
                return false;
            }
        }
    }

    bool PlayerBuilder::generateHelpfulData(
        const fs::path& helpfulDataFile,
        const PlayerOptions& options) {

        if (!emulator_) return false;

        // Configure emulation options
        SIDEmulator::EmulationOptions emulOptions;
        emulOptions.frames = 100; // Just need a short run to identify key patterns
        emulOptions.registerTrackingEnabled = true; // Track register write order
        emulOptions.patternDetectionEnabled = true;
        emulOptions.shadowRegisterDetectionEnabled = true; // Enable shadow register detection

        // Run the emulation
        if (emulator_->runEmulation(emulOptions)) {
            // Generate the helpful data file
            return emulator_->generateHelpfulDataFile(helpfulDataFile.string());
        }

        return false;
    }

    bool PlayerBuilder::createLinkerFile(
        const fs::path& linkerFile,
        const fs::path& musicFile,
        const fs::path& playerAsmFile,
        const PlayerOptions& options) {

        std::string ext = util::getFileExtension(musicFile);
        bool bIsSID = (ext == ".sid");
        bool bIsASM = (ext == ".asm");

        if ((!bIsSID) && (!bIsASM)) {
            util::Logger::error(std::string("Only SID and ASM files can be linked - '" + musicFile.string() + "' rejected."));
            return false;
        }

        std::ofstream file(linkerFile);
        if (!file) {
            util::Logger::error("Failed to create linker file: " + linkerFile.string());
            return false;
        }

        // Write the linker file header
        file << "//; ------------------------------------------\n";
        file << "//; SIDwinder Player Linker\n";
        file << "//; ------------------------------------------\n";
        file << "\n";

        if (bIsSID) {
            // For SID files, use LoadSid directly
            file << ".var music_prg = LoadSid(\"" << musicFile.string() << "\")\n";
            file << "* = music_prg.location \"SID\"\n";
            file << ".fill music_prg.size, music_prg.getData(i)\n";
            file << "\n";
            file << ".var SIDInit = music_prg.init\n";
            file << ".var SIDPlay = music_prg.play\n";
        }
        else {
            // For ASM files, we need explicit addresses
            u16 sidInit = options.sidInitAddr;
            u16 sidPlay = options.sidPlayAddr;
            file << ".var SIDInit = $" << util::wordToHex(sidInit) << "\n";
            file << ".var SIDPlay = $" << util::wordToHex(sidPlay) << "\n";
        }

        // Define player variables
        file << ".var NumCallsPerFrame = " << options.playCallsPerFrame << "\n";
        file << ".var PlayerADDR = $" << util::wordToHex(options.playerAddress) << "\n";
        file << "\n";

        // Add helpful data include if available
        std::string basename = musicFile.stem().string();
        fs::path helpfulDataFile = options.tempDir / (basename + "-HelpfulData.asm");
        bool hasHelpfulDataFile = fs::exists(helpfulDataFile);

        if (hasHelpfulDataFile) {
            file << "// Include helpful data for double-buffering and register reordering\n";
            file << ".import source \"" << helpfulDataFile.string() << "\"\n";
        }
        else {
            file << "// No helpful data available\n";
            file << ".var SIDModifiedMemoryCount = 0\n";
            file << ".var SIDModifiedMemory = List()\n";
            file << ".var SIDRegisterCount = 0\n";
            file << ".var SIDRegisterOrder = List()\n";
        }
        file << "\n";

        // Add SID metadata if available
        if (sid_) {
            const auto& header = sid_->getHeader();

            // Clean up strings for embedding in the linker file
            auto cleanString = [](const std::string& str) {
                std::string result;
                for (unsigned char c : str) {
                    // Keep alphanumeric and basic punctuation, replace others with _
                    if (std::isalnum(c) || c == ' ' || c == '-' || c == '_' || c == '!') {
                        result.push_back(c);
                    }
                    else {
                        result.push_back('_');
                    }
                }
                return result;
                };

            // Add SID metadata
            file << "// SID Metadata\n";
            file << ".var SIDName = \"" << cleanString(std::string(header.name)) << "\"\n";
            file << ".var SIDAuthor = \"" << cleanString(std::string(header.author)) << "\"\n";
            file << ".var SIDCopyright = \"" << cleanString(std::string(header.copyright)) << "\"\n\n";
            file << "\n";
        }

        addUserDefinitions(file, options);

        // Add player code
        file << "* = PlayerADDR\n";
        file << ".import source \"" << playerAsmFile.string() << "\"\n";
        file << "\n";

        if (bIsASM) {
            // For ASM input, import the source directly
            u16 sidLoad = options.sidLoadAddr;
            file << "* = $" << util::wordToHex(sidLoad) << "\n";
            file << ".import source \"" << musicFile.string() << "\"\n";
            file << "\n";
        }

        file.close();
        return true;
    }

    void PlayerBuilder::addUserDefinitions(std::ofstream& file, const PlayerOptions& options) {
        // Add user definitions if any
        if (!options.userDefinitions.empty()) {
            file << "// User Definitions\n";
            for (const auto& [key, value] : options.userDefinitions) {
                // Determine if it's a number or string
                bool isNumber = true;
                bool isHex = false;

                // Check for hex prefix
                if (value.length() > 1 && value[0] == '$') {
                    isHex = true;
                    // Validate hex
                    for (size_t i = 1; i < value.length(); i++) {
                        if (!std::isxdigit(value[i])) {
                            isNumber = false;
                            break;
                        }
                    }
                }
                else if (value.length() > 2 && value.substr(0, 2) == "0x") {
                    isHex = true;
                    // Validate hex
                    for (size_t i = 2; i < value.length(); i++) {
                        if (!std::isxdigit(value[i])) {
                            isNumber = false;
                            break;
                        }
                    }
                }
                else {
                    // Check if it's a decimal number
                    for (char c : value) {
                        if (!std::isdigit(c) && c != '-' && c != '+') {
                            isNumber = false;
                            break;
                        }
                    }
                }

                // Output a #define so we can check whether or not this var exists!
                file << "#define USERDEFINES_" << key << "\n";

                // Output the definition
                if (isNumber) {
                    file << ".var " << key << " = " << value << "\n";
                }
                else {
                    // It's a string - escape any quotes
                    std::string escaped = value;
                    size_t pos = 0;
                    while ((pos = escaped.find('"', pos)) != std::string::npos) {
                        escaped.insert(pos, "\\");
                        pos += 2;
                    }
                    file << ".var " << key << " = \"" << escaped << "\"\n";
                }
            }
            file << "\n";
        }
    }

    bool PlayerBuilder::runAssembler(
        const fs::path& sourceFile,
        const fs::path& outputFile,
        const std::string& kickAssPath,
        const fs::path& tempDir) {

        // Create log file path in temp directory
        fs::path logFile = tempDir / (sourceFile.stem().string() + "_kickass.log");

        // Build the command line with output redirection
        const std::string kickCommand = kickAssPath + " " +
            "\"" + sourceFile.string() + "\" -o \"" +
            outputFile.string() + "\" > \"" +
            logFile.string() + "\" 2>&1";

        const int result = std::system(kickCommand.c_str());

        if (result != 0) {
            util::Logger::error("FAILURE: " + sourceFile.string() + " - please see output log for details: " + logFile.string());
            return false;
        }

        return true;
    }

    bool PlayerBuilder::compressPrg(
        const fs::path& inputPrg,
        const fs::path& outputPrg,
        u16 loadAddress,
        const PlayerOptions& options) {

        // Build compression command based on compressor type
        std::string compressCommand;

        if (options.compressorType == "exomizer") {
            // Get additional options from configuration if available
            std::string exomizerOptions = util::ConfigManager::getString("exomizerOptions", "-x 3 -q");

            compressCommand = options.exomizerPath + " sfx " + std::to_string(loadAddress) +
                " " + exomizerOptions + " \"" + inputPrg.string() + "\" -o \"" + outputPrg.string() + "\"";
        }
        else if (options.compressorType == "pucrunch") {
            // Get pucrunch path and options from configuration
            std::string pucrunchPath = util::ConfigManager::getString("pucrunchPath", "pucrunch");
            std::string pucrunchOptions = util::ConfigManager::getString("pucrunchOptions", "-x");

            compressCommand = pucrunchPath + " " + pucrunchOptions + " " + std::to_string(loadAddress) +
                " \"" + inputPrg.string() + "\" \"" + outputPrg.string() + "\"";
        }
        else {
            util::Logger::error("Unsupported compressor type: " + options.compressorType);
            return false;
        }

        // Execute the compression command
        const int result = std::system(compressCommand.c_str());

        if (result != 0) {
            util::Logger::error("Compression failed: " + compressCommand);
            return false;
        }
        return true;
    }

} // namespace sidwinder