// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#include "MusicBuilder.h"
#include "../SIDwinderUtils.h"
#include "../ConfigManager.h"
#include "../cpu6510.h"
#include "../SIDLoader.h"

#include <algorithm>
#include <fstream>
#include <cctype>

namespace sidwinder {

    MusicBuilder::MusicBuilder(const CPU6510* cpu, const SIDLoader* sid)
        : cpu_(cpu), sid_(sid) {
        // Create an emulator for analysis
        emulator_ = std::make_unique<SIDEmulator>(const_cast<CPU6510*>(cpu), const_cast<SIDLoader*>(sid));
    }

    bool MusicBuilder::buildMusic(
        const std::string& basename,
        const fs::path& inputFile,
        const fs::path& outputFile,
        const BuildOptions& options) {

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
        fs::path tempPrgFile = tempDir / (basename + ".prg");
        fs::path tempPlayerPrgFile = tempDir / (basename + "-player.prg");
        fs::path tempLinkerFile = tempDir / (basename + "-linker.asm");

        // Determine input file type
        std::string ext = getFileExtension(inputFile);
        bool bIsSID = (ext == ".sid");
        bool bIsASM = (ext == ".asm");
        bool bIsPRG = (ext == ".prg");

        // Handle based on whether to include player or not
        if (!options.playerName.empty()) {
            // Set default player name if none specified
            std::string playerToUse = options.playerName;
            if (playerToUse == "default") {
                playerToUse = util::ConfigManager::getPlayerName();
            }

            // Get player assembly file path - check configuration for player directory
            std::string playerDir = util::ConfigManager::getString("playerDirectory", "SIDPlayers");
            fs::path playerAsmFile = fs::path(playerDir) / playerToUse / (playerToUse + ".asm");

            // Create the player directory if it doesn't exist
            try {
                fs::create_directories(playerAsmFile.parent_path());
            }
            catch (const std::exception& e) {
                util::Logger::warning(std::string("Failed to create player directory: ") + e.what());
                // Continue anyway, the assembler will fail if the file doesn't exist
            }

            // Generate helpful data for double-buffering
            fs::path helpfulDataFile = tempDir / (basename + "-HelpfulData.asm");

            // Only run analysis if the file doesn't exist
            if (emulator_) {
                util::Logger::info("Analyzing SID for helpful data generation...");

                // Configure emulation options
                SIDEmulator::EmulationOptions options;
                options.frames = 100; // Just need a short run to identify key patterns
                options.registerTrackingEnabled = true; // Track register write order
                options.patternDetectionEnabled = true;
                options.shadowRegisterDetectionEnabled = true; // Enable shadow register detection

                // Run the emulation
                if (emulator_->runEmulation(options)) {
                    // Generate the helpful data file
                    emulator_->generateHelpfulDataFile(helpfulDataFile.string());
                }
                else {
                    util::Logger::warning("SID analysis failed, helpful data not generated");
                }
            }

            // Create linker file - this now correctly handles SID files with LoadSid
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
                    util::Logger::warning(std::string("Compression failed on ") + tempPlayerPrgFile.string());
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
        else {
            // Pure music without player

            // If input is ASM, just assemble it
            if (bIsASM) {
                // Run assembler to build pure music
                if (!runAssembler(inputFile, outputFile, options.kickAssPath, options.tempDir)) {
                    return false;
                }
                return true;
            }
            else if (bIsPRG) {
                // For PRG input, just copy the file
                try {
                    fs::copy_file(inputFile, outputFile, fs::copy_options::overwrite_existing);
                    return true;
                }
                catch (const std::exception& e) {
                    util::Logger::error(std::string("Failed to copy PRG file: ") + e.what());
                    return false;
                }
            }
            else if (bIsSID) {
                // For SID input, extract the PRG data
                return extractPrgFromSid(inputFile, outputFile);
            }
            else {
                util::Logger::error("Unsupported input file type for pure music output");
                return false;
            }
        }

        return true;
    }

    void MusicBuilder::addUserDefinitions(std::ofstream& file, const BuildOptions& options)
    {
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

    bool MusicBuilder::createLinkerFile(
        const fs::path& linkerFile,
        const fs::path& musicFile,
        const fs::path& playerAsmFile,
        const BuildOptions& options) {

        std::string ext = getFileExtension(musicFile);

        bool bIsSID = (ext == ".sid");
        bool bIsASM = (ext == ".asm");

        if ((!bIsSID) && (!bIsASM))
        {
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

        if (bIsSID)
        {
            // For SID files, use LoadSid directly
            file << ".var music_prg = LoadSid(\"" << musicFile.string() << "\")\n";
            file << "* = music_prg.location \"SID\"\n";
            file << ".fill music_prg.size, music_prg.getData(i)\n";
            file << "\n";
            file << ".var SIDInit = music_prg.init\n";
            file << ".var SIDPlay = music_prg.play\n";
        }
        else
        {
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

        if (bIsASM)
        {
            // For ASM input, import the source directly
            u16 sidLoad = options.sidLoadAddr;
            file << "* = $" << util::wordToHex(sidLoad) << "\n";
            file << ".import source \"" << musicFile.string() << "\"\n";
            file << "\n";
        }

        file.close();

        util::Logger::debug("Created player linker file: " + linkerFile.string());

        return true;
    }

    bool MusicBuilder::runAssembler(
        const fs::path& sourceFile,
        const fs::path& outputFile,
        const std::string& kickAssPath,
        const fs::path& tempDir) {

        // Create log file path in temp directory
        fs::path logFile = tempDir / (sourceFile.stem().string() + "_kickass.log");

        // Build the command line with output redirection
        // Using 2>&1 to redirect both stdout and stderr to the same file
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

    bool MusicBuilder::compressPrg(
        const fs::path& inputPrg,
        const fs::path& outputPrg,
        u16 loadAddress,
        const BuildOptions& options) {

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
        util::Logger::debug("Compressing with command: " + compressCommand);
        const int result = std::system(compressCommand.c_str());

        if (result != 0) {
            util::Logger::error("Compression failed: " + compressCommand);
            return false;
        }

        util::Logger::info("Compressed PRG created: " + outputPrg.string());
        return true;
    }

    bool MusicBuilder::extractPrgFromSid(const fs::path& sidFile, const fs::path& outputPrg) {
        // Read the SID file
        std::ifstream input(sidFile, std::ios::binary);
        if (!input) {
            util::Logger::error("Failed to open SID file for extraction: " + sidFile.string());
            return false;
        }

        // Read header to determine data offset
        SIDHeader header;
        input.read(reinterpret_cast<char*>(&header), sizeof(header));

        // Fix endianness (SID files are big-endian)
        u16 dataOffset = (header.dataOffset >> 8) | (header.dataOffset << 8);
        u16 loadAddress = (header.loadAddress >> 8) | (header.loadAddress << 8);

        // Handle embedded load address if present
        if (loadAddress == 0) {
            // If load address is 0, it's embedded in the file
            if (input.seekg(dataOffset, std::ios::beg)) {
                u8 lo, hi;
                input.read(reinterpret_cast<char*>(&lo), 1);
                input.read(reinterpret_cast<char*>(&hi), 1);
                loadAddress = (hi << 8) | lo;
                dataOffset += 2; // Skip these two bytes in subsequent copy
            }
            else {
                util::Logger::error("Error seeking to data in SID file");
                return false;
            }
        }

        // Log what we're doing
        util::Logger::debug("Extracting PRG from SID: " + sidFile.string() +
            " (load address: $" + util::wordToHex(loadAddress) +
            ", data offset: $" + util::wordToHex(dataOffset) + ")");

        // Create PRG file (first 2 bytes are load address in little-endian)
        std::ofstream output(outputPrg, std::ios::binary);
        if (!output) {
            util::Logger::error("Failed to create PRG file: " + outputPrg.string());
            return false;
        }

        // Write load address (little-endian)
        const u8 lo = loadAddress & 0xFF;
        const u8 hi = (loadAddress >> 8) & 0xFF;
        output.write(reinterpret_cast<const char*>(&lo), 1);
        output.write(reinterpret_cast<const char*>(&hi), 1);

        // Position to start of data
        if (!input.seekg(dataOffset, std::ios::beg)) {
            util::Logger::error("Error seeking to data in SID file");
            return false;
        }

        // Copy the data
        char buffer[4096];
        while (input) {
            input.read(buffer, sizeof(buffer));
            std::streamsize bytesRead = input.gcount();
            if (bytesRead > 0) {
                output.write(buffer, bytesRead);
            }
            else {
                break;
            }
        }

        util::Logger::debug("Extracted PRG data to: " + outputPrg.string());
        return true;
    }

} // namespace sidwinder