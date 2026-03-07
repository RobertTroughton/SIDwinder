#include "RelocationUtils.h"
#include "SIDwinderUtils.h"
#include "ConfigManager.h"
#include "cpu6510.h"
#include "SIDEmulator.h"
#include "SIDFileFormat.h"
#include "SIDLoader.h"
#include "Disassembler.h"


namespace sidwinder {
    namespace util {

        // In RelocationUtils.cpp, update relocateSID to pass the current metadata

        RelocationResult relocateSID(
            CPU6510* cpu,
            SIDLoader* sid,
            const RelocationParams& params) {
            RelocationResult result;
            result.success = false;
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
            try {
                fs::create_directories(params.tempDir);
            }
            catch (const std::exception& e) {
                result.message = std::string("Failed to create temp directory: ") + e.what();
                Logger::error(result.message);
                return result;
            }
            if (!sid->loadSID(params.inputFile.string())) {
                result.message = "Failed to load file for relocation: " + params.inputFile.string();
                Logger::error(result.message);
                return result;
            }
            result.originalLoad = sid->getLoadAddress();
            result.originalInit = sid->getInitAddress();
            result.originalPlay = sid->getPlayAddress();
            const SIDHeader& originalHeader = sid->getHeader();
            u16 originalFlags = originalHeader.flags;
            u8 secondSIDAddress = originalHeader.secondSIDAddress;
            u8 thirdSIDAddress = originalHeader.thirdSIDAddress;
            u16 version = originalHeader.version;
            u32 speed = originalHeader.speed;
            result.newLoad = params.relocationAddress;
            result.newInit = result.newLoad + (result.originalInit - result.originalLoad);
            result.newPlay = result.newLoad + (result.originalPlay - result.originalLoad);
            Disassembler disassembler(*cpu, *sid);
            const int numFrames = util::ConfigManager::getInt("emulationFrames");
            if (!runSIDEmulation(cpu, sid, numFrames)) {
                result.message = "Failed to run SID emulation for memory analysis";
                Logger::error(result.message);
                return result;
            }
            const std::string basename = params.inputFile.stem().string();
            const fs::path tempAsmFile = params.tempDir / (basename + "-relocated.asm");
            const fs::path tempPrgFile = params.tempDir / (basename + "-relocated.prg");
            disassembler.generateAsmFile(
                tempAsmFile.string(),
                result.newLoad,
                result.newInit,
                result.newPlay,
                false);
            if (!assembleAsmToPrg(tempAsmFile, tempPrgFile, params.kickAssPath, params.tempDir)) {
                result.message = "Failed to assemble relocated code: " + tempAsmFile.string();
                Logger::error(result.message);
                return result;
            }

            // Get the current metadata from the SIDLoader (which may have been overridden)
            const SIDHeader& currentHeader = sid->getHeader();
            const std::string title = std::string(currentHeader.name);
            const std::string author = std::string(currentHeader.author);
            const std::string copyright = std::string(currentHeader.copyright);

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

            // Read entire PRG file
            auto prgData = util::readBinaryFile(prgFile);
            if (!prgData) {
                return false; // Error already logged
            }

            if (prgData->size() < 2) {
                Logger::error("PRG file too small: " + prgFile.string());
                return false;
            }

            // Extract load address from PRG
            const u16 prgLoadAddr = (*prgData)[0] | ((*prgData)[1] << 8);

            if (prgLoadAddr != loadAddr) {
                Logger::warning("PRG file load address ($" + util::wordToHex(prgLoadAddr) +
                    ") doesn't match specified address ($" + util::wordToHex(loadAddr) + ")");
                loadAddr = prgLoadAddr;
            }

            // Create and initialize SID header
            SIDHeader header;
            std::memset(&header, 0, sizeof(header));

            // Basic header fields
            std::memcpy(header.magicID, "PSID", 4);
            header.version = version;
            header.dataOffset = (version == 1) ? 0x76 : 0x7C;
            header.loadAddress = 0;          // Embedded in data
            header.initAddress = initAddr;
            header.playAddress = playAddr;
            header.songs = 1;
            header.startSong = 1;
            header.speed = speed;
            header.flags = flags;
            header.startPage = 0;
            header.pageLength = 0;

            // Copy metadata strings safely
            std::memset(header.name, 0, sizeof(header.name));
            std::memset(header.author, 0, sizeof(header.author));
            std::memset(header.copyright, 0, sizeof(header.copyright));

            if (!title.empty()) {
                std::strncpy(header.name, title.c_str(), sizeof(header.name) - 1);
            }
            if (!author.empty()) {
                std::strncpy(header.author, author.c_str(), sizeof(header.author) - 1);
            }
            if (!copyright.empty()) {
                std::strncpy(header.copyright, copyright.c_str(), sizeof(header.copyright) - 1);
            }

            header.secondSIDAddress = secondSIDAddress;
            header.thirdSIDAddress = thirdSIDAddress;

            // Fix endianness for SID format
            util::fixSIDHeaderEndianness(header);

            // Build complete SID file in memory
            std::vector<u8> sidData;
            sidData.reserve(sizeof(header) + prgData->size());

            // Add header
            const u8* headerBytes = reinterpret_cast<const u8*>(&header);
            sidData.insert(sidData.end(), headerBytes, headerBytes + sizeof(header));

            // Add PRG data (including the load address bytes)
            sidData.insert(sidData.end(), prgData->begin(), prgData->end());

            // Write complete SID file
            bool success = util::writeBinaryFile(sidFile, sidData);

            return success;
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