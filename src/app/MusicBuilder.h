#pragma once
#include "../Common.h"
#include "../SIDFileFormat.h"
#include <filesystem>
#include <memory>
#include <string>

namespace fs = std::filesystem;

class CPU6510;
class SIDLoader;

namespace sidwinder {
    class MusicBuilder {
    public:
        struct BuildOptions {
            std::string kickAssPath = "java -jar KickAss.jar -silentMode";
            fs::path tempDir = "temp";
        };

        MusicBuilder(CPU6510* cpu, SIDLoader* sid);

        // Build music without player (ASM to PRG, or PRG copy)
        bool buildMusic(
            const std::string& basename,
            const fs::path& inputFile,
            const fs::path& outputFile,
            const BuildOptions& options);

        // Run assembler on ASM file
        bool runAssembler(
            const fs::path& sourceFile,
            const fs::path& outputFile,
            const std::string& kickAssPath,
            const fs::path& tempDir);

    private:
        CPU6510* cpu_;
        SIDLoader* sid_;
    };
}