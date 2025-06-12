#include "RelocationUtils.h"
#include "SIDwinderUtils.h"
#include "ConfigManager.h"
#include "cpu6510.h"
#include "SIDEmulator.h"
#include "SIDLoader.h"
#include "Disassembler.h"

#include <fstream>


namespace sidwinder {
    namespace util {

        RelocationResult relocateSID(
            CPU6510* cpu,
            SIDLoader* sid,
            const RelocationParams& params) {

            RelocationResult result;
            result.success = false;

            // Validate that both input and output are SID files
            const std::string inExt = getFileExtension(params.inputFile);
            if (inExt != ".sid") {
                result.message = "Input file must be a SID file (.sid): " + params.inputFile.string();
                Logger::error(result.message);
                return result;
            }

            const std::string outExt = getFileExtension(params.outputFile);
            if (outExt != ".sid") {
                result.message = "Output file must be a SID file (.sid): " + params.outputFile.string();
                Logger::error(result.message);
                return result;
            }

            // Create temp directory if it doesn't exist
            try {
                fs::create_directories(params.tempDir);
            }
            catch (const std::exception& e) {
                result.message = std::string("Failed to create temp directory: ") + e.what();
                Logger::error(result.message);
                return result;
            }

            // Load the input file
            if (!sid->loadSID(params.inputFile.string())) {
                result.message = "Failed to load file for relocation: " + params.inputFile.string();
                Logger::error(result.message);
                return result;
            }

            // Get original addresses and header
            result.originalLoad = sid->getLoadAddress();
            result.originalInit = sid->getInitAddress();
            result.originalPlay = sid->getPlayAddress();

            // Get the original SID header to preserve its flags and additional SID addresses
            const SIDHeader& originalHeader = sid->getHeader();
            u16 originalFlags = originalHeader.flags;
            u8 secondSIDAddress = originalHeader.secondSIDAddress;
            u8 thirdSIDAddress = originalHeader.thirdSIDAddress;
            u16 version = originalHeader.version;
            u32 speed = originalHeader.speed;

            // Calculate relocated addresses
            result.newLoad = params.relocationAddress;
            result.newInit = result.newLoad + (result.originalInit - result.originalLoad);
            result.newPlay = result.newLoad + (result.originalPlay - result.originalLoad);

            // Create a Disassembler
            Disassembler disassembler(*cpu, *sid);

            // Run emulation to analyze memory access patterns
            const int numFrames = util::ConfigManager::getInt("emulationFrames");
            if (!runSIDEmulation(cpu, sid, numFrames)) {
                result.message = "Failed to run SID emulation for memory analysis";
                Logger::error(result.message);
                return result;
            }

            // For SID output, we need to:
            // 1. Generate assembly with relocation
            // 2. Assemble to PRG
            // 3. Create a SID file with proper header

            // Setup temp files
            const std::string basename = params.inputFile.stem().string();
            const fs::path tempAsmFile = params.tempDir / (basename + "-relocated.asm");
            const fs::path tempPrgFile = params.tempDir / (basename + "-relocated.prg");

            // Generate ASM with relocated addresses
            disassembler.generateAsmFile(
                tempAsmFile.string(),
                result.newLoad,
                result.newInit,
                result.newPlay,
                false);

            // Assemble to PRG
            if (!assembleAsmToPrg(tempAsmFile, tempPrgFile, params.kickAssPath, params.tempDir)) {
                result.message = "Failed to assemble relocated code: " + tempAsmFile.string();
                Logger::error(result.message);
                return result;
            }

            // Create SID file from PRG
            const std::string title = originalHeader.name;
            const std::string author = originalHeader.author;
            const std::string copyright = originalHeader.copyright;

            if (!createSIDFromPRG(
                tempPrgFile,
                params.outputFile,
                result.newLoad,
                result.newInit,
                result.newPlay,
                title,
                author,
                copyright,
                originalFlags,
                secondSIDAddress,
                thirdSIDAddress,
                version,
                speed)) {

                // If SID creation fails, fall back to PRG
                Logger::warning("SID file generation failed. Saving as PRG instead.");

                try {
                    fs::copy_file(tempPrgFile, params.outputFile, fs::copy_options::overwrite_existing);

                    result.success = true;
                    result.message = "Relocation complete (saved as PRG).";
                }
                catch (const std::exception& e) {
                    result.message = std::string("Failed to copy output file: ") + e.what();
                    Logger::error(result.message);
                    return result;
                }
            }
            else {
                result.success = true;
                result.message = "Relocation to SID complete. ";
            }

            return result;
        }

        RelocationVerificationResult relocateAndVerifySID(
            CPU6510* cpu,
            SIDLoader* sid,
            const fs::path& inputFile,
            const fs::path& outputFile,
            u16 relocationAddress,
            const fs::path& tempDir,
            const std::string& kickAssPath) {  // Add parameter here too

            RelocationVerificationResult result;
            result.success = false;
            result.verified = false;
            result.outputsMatch = false;

            // Prepare paths for verification
            fs::path originalTrace = tempDir / (inputFile.stem().string() + "-original.trace");
            fs::path relocatedTrace = tempDir / (inputFile.stem().string() + "-relocated.trace");
            fs::path diffReport = tempDir / (inputFile.stem().string() + "-diff.txt");

            result.originalTrace = originalTrace.string();
            result.relocatedTrace = relocatedTrace.string();
            result.diffReport = diffReport.string();

            try {
                // Step 1: Relocate the SID file
                util::RelocationParams relocParams;
                relocParams.inputFile = inputFile;
                relocParams.outputFile = outputFile;
                relocParams.tempDir = tempDir;
                relocParams.relocationAddress = relocationAddress;
                relocParams.kickAssPath = kickAssPath;  // Use the passed KickAss path

                util::RelocationResult relocResult = util::relocateSID(cpu, sid, relocParams);

                if (!relocResult.success) {
                    result.message = "Relocation failed: " + relocResult.message;
                    return result;
                }

                result.success = true;

                // Step 2: Create trace of original SID
                if (!sid->loadSID(inputFile.string())) {
                    result.message = "Failed to load original SID file";
                    return result;
                }

                SIDEmulator originalEmulator(cpu, sid);
                SIDEmulator::EmulationOptions options;
                options.frames = DEFAULT_SID_EMULATION_FRAMES;
                options.traceEnabled = true;
                options.traceLogPath = originalTrace.string();
                cpu->reset();
                if (!originalEmulator.runEmulation(options)) {
                    result.message = "Failed to emulate original SID file";
                    return result;
                }

                // Step 3: Verify the relocated SID
                if (!sid->loadSID(outputFile.string())) {
                    result.message = "Failed to load relocated SID file";
                    return result;
                }
                SIDEmulator relocatedEmulator(cpu, sid);
                options.traceLogPath = relocatedTrace.string();
                cpu->reset();
                if (!relocatedEmulator.runEmulation(options)) {
                    result.message = "Emulation of relocated SID file failed";
                    return result;
                }

                result.verified = true;

                // Step 4: Compare trace files
                result.outputsMatch = TraceLogger::compareTraceLogs(
                    originalTrace.string(),
                    relocatedTrace.string(),
                    diffReport.string());

                if (result.outputsMatch) {
                    result.message = "SID file relocated OK with matching before/after trace outputs";
                }
                else {
                    result.message = "SID relocation verification failed - before/after trace outputs differ";
                }

                return result;
            }
            catch (const std::exception& e) {
                result.message = std::string("Exception during relocation/verification: ") + e.what();
                return result;
            }
        }

        bool assembleAsmToPrg(
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

        bool createSIDFromPRG(
            const fs::path& prgFile,
            const fs::path& sidFile,
            u16 loadAddr,
            u16 initAddr,
            u16 playAddr,
            const std::string& title,
            const std::string& author,
            const std::string& copyright,
            u16 flags,
            u8 secondSIDAddress,
            u8 thirdSIDAddress,
            u16 version,
            u32 speed) {

            // Read the PRG file
            std::ifstream prg(prgFile, std::ios::binary | std::ios::ate);
            if (!prg) {
                Logger::error("Failed to open PRG file: " + prgFile.string());
                return false;
            }

            // Get file size
            const auto filePos = prg.tellg();
            const size_t fileSize = static_cast<size_t>(filePos);
            prg.seekg(0, std::ios::beg);

            if (fileSize < 2) {
                Logger::error("PRG file too small: " + prgFile.string());
                return false;
            }

            // PRG files start with a 2-byte load address, verify it matches our expected loadAddr
            u8 lo, hi;
            prg.read(reinterpret_cast<char*>(&lo), 1);
            prg.read(reinterpret_cast<char*>(&hi), 1);

            // The load address from the PRG file
            const u16 prgLoadAddr = (hi << 8) | lo;

            // If the specified load address doesn't match the one in the PRG, log a warning
            if (prgLoadAddr != loadAddr) {
                Logger::warning("PRG file load address ($" + wordToHex(prgLoadAddr) +
                    ") doesn't match specified address ($" + wordToHex(loadAddr) + ")");
                // We'll use the load address from the PRG if it doesn't match
                loadAddr = prgLoadAddr;
            }

            // Create a SID header
            SIDHeader header;

            // Fill in the header fields (initially in little-endian format)
            std::memcpy(header.magicID, "PSID", 4);  // Magic ID for SID format
            header.version = version;        // Use original version number
            header.dataOffset = (version == 1) ? 0x76 : 0x7C;  // Adjust based on version
            header.loadAddress = 0;          // 0 means load address is in the data
            header.initAddress = initAddr;   // Init address
            header.playAddress = playAddr;   // Play address
            header.songs = 1;                // 1 song
            header.startSong = 1;            // Start song 1
            header.speed = speed;

            // Fill in metadata fields with null-termination
            std::memset(header.name, 0, sizeof(header.name));
            std::memset(header.author, 0, sizeof(header.author));
            std::memset(header.copyright, 0, sizeof(header.copyright));

            // Copy metadata if provided, ensuring null-termination
            if (!title.empty()) {
                std::strncpy(header.name, title.c_str(), sizeof(header.name) - 1);
            }
            if (!author.empty()) {
                std::strncpy(header.author, author.c_str(), sizeof(header.author) - 1);
            }
            if (!copyright.empty()) {
                std::strncpy(header.copyright, copyright.c_str(), sizeof(header.copyright) - 1);
            }

            // Set flags and SID chip addresses
            header.flags = flags;                // Use provided flags instead of default 0
            header.startPage = 0;                // Not used in this context
            header.pageLength = 0;               // Not used in this context

            // Only set secondSIDAddress if version >= 3
            if (version >= 3) {
                header.secondSIDAddress = secondSIDAddress;
            }
            else {
                header.secondSIDAddress = 0;
                // Log if we're losing information
                if (secondSIDAddress != 0) {
                    Logger::warning("Second SID address information ($" +
                        wordToHex(secondSIDAddress << 4) +
                        ") lost due to SID version " +
                        std::to_string(version) + " (requires v3+)");
                }
            }

            // Only set thirdSIDAddress if version >= 4
            if (version >= 4) {
                header.thirdSIDAddress = thirdSIDAddress;
            }
            else {
                header.thirdSIDAddress = 0;
                // Log if we're losing information
                if (thirdSIDAddress != 0) {
                    Logger::warning("Third SID address information ($" +
                        wordToHex(thirdSIDAddress << 4) +
                        ") lost due to SID version " +
                        std::to_string(version) + " (requires v4)");
                }
            }

            // Fix endianness (SID files are big-endian)
            // We need to reverse the byte order for all multi-byte fields
            header.version = util::swapEndian(header.version);
            header.dataOffset = util::swapEndian(header.dataOffset);
            header.loadAddress = util::swapEndian(header.loadAddress);
            header.initAddress = util::swapEndian(header.initAddress);
            header.playAddress = util::swapEndian(header.playAddress);
            header.songs = util::swapEndian(header.songs);
            header.startSong = util::swapEndian(header.startSong);
            header.flags = util::swapEndian(header.flags);
            header.speed = util::swapEndian(header.speed);

            // Open the output SID file
            std::ofstream sid_file(sidFile, std::ios::binary);
            if (!sid_file) {
                Logger::error("Failed to create SID file: " + sidFile.string());
                return false;
            }

            // Write the header
            sid_file.write(reinterpret_cast<const char*>(&header), sizeof(header));

            // Write the load address (little-endian) at the beginning of the data
            sid_file.write(reinterpret_cast<const char*>(&lo), 1);
            sid_file.write(reinterpret_cast<const char*>(&hi), 1);

            // Write the actual PRG data, skipping the 2-byte load address that was already in the PRG
            const size_t dataSize = fileSize - 2;
            std::vector<char> buffer(dataSize);
            prg.read(buffer.data(), dataSize);
            sid_file.write(buffer.data(), dataSize);

            sid_file.close();

            return true;
        }

        /**
         * @brief Run SID emulation to analyze memory patterns
         *
         * Initializes the SID and executes the play routine for a specified number of frames,
         * allowing memory access patterns to be analyzed for relocation or tracing.
         *
         * @param cpu Pointer to CPU instance
         * @param sid Pointer to SID loader instance
         * @param frames Number of frames to emulate
         * @return True if emulation completed successfully
         */
        bool runSIDEmulation(
            CPU6510* cpu,
            SIDLoader* sid,
            int frames) {

            SIDEmulator emulator(cpu, sid);
            SIDEmulator::EmulationOptions options;
            options.frames = frames;
            options.traceEnabled = false;

            return emulator.runEmulation(options);
        }

    }
}