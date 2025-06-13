#pragma once
#include "../Common.h"
#include <string>
#include <map>
#include <filesystem>

namespace fs = std::filesystem;

namespace sidwinder {
    struct PlayerOptions {
        // Player configuration
        std::string playerName = "SimpleRaster";
        u16 playerAddress = 0x4000;

        // Compression settings
        bool compress = true;
        std::string compressorType = "exomizer";
        std::string exomizerPath = "Exomizer.exe";

        // Build settings
        std::string kickAssPath = "java -jar KickAss.jar -silentMode";
        int playCallsPerFrame = 1;

        // SID addresses
        u16 sidLoadAddr = 0x1000;
        u16 sidInitAddr = 0x1000;
        u16 sidPlayAddr = 0x1003;

        // User definitions for assembly
        std::map<std::string, std::string> userDefinitions;

        // Paths
        fs::path tempDir = "temp";
        fs::path playerDirectory = "SIDPlayers";
    };
}