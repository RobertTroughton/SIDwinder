#pragma once
#include "PlayerOptions.h"
#include "../Common.h"
#include <filesystem>
#include <memory>
#include <string>

namespace fs = std::filesystem;

class CPU6510;
class SIDLoader;

namespace sidwinder {
    class SIDEmulator;

    class PlayerBuilder {
    public:
        PlayerBuilder(CPU6510* cpu, SIDLoader* sid);
        ~PlayerBuilder(); // Destructor must be declared

        // Build music with player
        bool buildMusicWithPlayer(
            const std::string& basename,
            const fs::path& inputFile,
            const fs::path& outputFile,
            const PlayerOptions& options);

        // Generate helpful data for player assembly
        bool generateHelpfulData(
            const fs::path& helpfulDataFile,
            const fs::path& helpfulDataBlockFile,
            const PlayerOptions& options);

    private:
        CPU6510* cpu_;
        SIDLoader* sid_;
        std::unique_ptr<SIDEmulator> emulator_;

        // Create the linker file that combines player and music
        bool createLinkerFile(
            const fs::path& linkerFile,
            const fs::path& musicFile,
            const fs::path& playerAsmFile,
            const PlayerOptions& options);

        // Add user definitions to assembly file
        void addUserDefinitions(
            std::ofstream& file,
            const PlayerOptions& options);

        // Run KickAss assembler
        bool runAssembler(
            const fs::path& sourceFile,
            const fs::path& outputFile,
            const std::string& kickAssPath,
            const fs::path& tempDir);

        // Compress the final PRG
        bool compressPrg(
            const fs::path& inputPrg,
            const fs::path& outputPrg,
            u16 loadAddress,
            const PlayerOptions& options);
    };
}