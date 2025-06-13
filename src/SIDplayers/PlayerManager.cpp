// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#include "PlayerManager.h"
#include "PlayerBuilder.h"
#include "../SIDwinderUtils.h"
#include "../ConfigManager.h"
#include "../cpu6510.h"
#include "../SIDLoader.h"
#include "../MemoryConstants.h"

#include <algorithm>

namespace sidwinder {

    PlayerManager::PlayerManager(CPU6510* cpu, SIDLoader* sid)
        : cpu_(cpu), sid_(sid) {
        builder_ = std::make_unique<PlayerBuilder>(cpu_, sid_);
    }

    PlayerManager::~PlayerManager() = default;

    bool PlayerManager::processWithPlayer(
        const fs::path& inputFile,
        const fs::path& outputFile,
        const PlayerOptions& options) {

        // Validate player exists
        if (!validatePlayer(options.playerName)) {
            util::Logger::error("Player not found: " + options.playerName);
            return false;
        }

        // Get base name for temporary files
        std::string basename = inputFile.stem().string();

        // Build music with player
        return builder_->buildMusicWithPlayer(basename, inputFile, outputFile, options);
    }

    std::vector<std::string> PlayerManager::getAvailablePlayers() const {
        std::vector<std::string> players;

        // Get player directory from config
        std::string playerDir = util::ConfigManager::getString("playerDirectory", "SIDPlayers");
        fs::path playerPath(playerDir);

        if (!fs::exists(playerPath)) {
            return players;
        }

        // Scan for player directories
        for (const auto& entry : fs::directory_iterator(playerPath)) {
            if (entry.is_directory()) {
                // Check if it has a matching .asm file
                fs::path asmFile = entry.path() / (entry.path().filename().string() + ".asm");
                if (fs::exists(asmFile)) {
                    players.push_back(entry.path().filename().string());
                }
            }
        }

        std::sort(players.begin(), players.end());
        return players;
    }

    bool PlayerManager::validatePlayer(const std::string& playerName) const {
        std::string playerToCheck = playerName;

        // Handle "default" player name
        if (playerToCheck == "default") {
            playerToCheck = util::ConfigManager::getPlayerName();
        }

        fs::path playerAsmPath = getPlayerAsmPath(playerToCheck);
        return fs::exists(playerAsmPath);
    }

    bool PlayerManager::analyzeMusicForPlayer(const PlayerOptions& options) {
        if (!cpu_ || !sid_) {
            return false;
        }

        // Generate helpful data for player optimization
        fs::path helpfulDataFile = options.tempDir / "analysis-HelpfulData.asm";
        return builder_->generateHelpfulData(helpfulDataFile, options);
    }

    fs::path PlayerManager::getPlayerAsmPath(const std::string& playerName) const {
        std::string playerDir = util::ConfigManager::getString("playerDirectory", "SIDPlayers");
        return fs::path(playerDir) / playerName / (playerName + ".asm");
    }

} // namespace sidwinder