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

#include <fstream>
#include <cctype>

namespace sidwinder {

    MusicBuilder::MusicBuilder(CPU6510* cpu, SIDLoader* sid)
        : cpu_(cpu), sid_(sid) {
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

        // Determine input file type
        std::string ext = util::getFileExtension(inputFile);
        bool bIsSID = (ext == ".sid");
        bool bIsASM = (ext == ".asm");
        bool bIsPRG = (ext == ".prg");

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
            return SIDLoader::extractPrgFromSid(inputFile, outputFile);
        }
        else {
            util::Logger::error("Unsupported input file type");
            return false;
        }
    }

    bool MusicBuilder::runAssembler(
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

} // namespace sidwinder