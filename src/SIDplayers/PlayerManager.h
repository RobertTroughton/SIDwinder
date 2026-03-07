#pragma once
#include "PlayerOptions.h"
#include "../Common.h"
#include <filesystem>
#include <memory>
#include <vector>
#include <string>

namespace fs = std::filesystem;

class CPU6510;
class SIDLoader;

namespace sidwinder {
    class PlayerBuilder;

    class PlayerManager {
    public:
        PlayerManager(CPU6510* cpu, SIDLoader* sid);
        ~PlayerManager();

        // Process music file with player
        bool processWithPlayer(
            const fs::path& inputFile,
            const fs::path& outputFile,
            const PlayerOptions& options);

        // Get available player names
        std::vector<std::string> getAvailablePlayers() const;

        // Validate player exists
        bool validatePlayer(const std::string& playerName) const;

        // Analyze music for player optimization
        bool analyzeMusicForPlayer(const PlayerOptions& options);

    private:
        CPU6510* cpu_;
        SIDLoader* sid_;
        std::unique_ptr<PlayerBuilder> builder_;

        // Get player assembly file path
        fs::path getPlayerAsmPath(const std::string& playerName) const;

        // Check if the player has required components
        bool validatePlayerComponents(const std::string& playerName) const;
    };
}