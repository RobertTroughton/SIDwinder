// ConfigManager.cpp
#include "ConfigManager.h"
#include <algorithm>
#include <cctype>
#include <fstream>
#include <iostream>
#include <sstream>
#include <vector>

namespace sidwinder {
    namespace util {

        // Initialize static members
        std::map<std::string, std::string> ConfigManager::configValues_;
        std::filesystem::path ConfigManager::configFile_;

        bool ConfigManager::initialize(const std::filesystem::path& configFile) {
            configFile_ = configFile;

            // 1. Set up default values
            setupDefaults();

            // 2. Try to load and merge with existing config file
            bool fileExists = std::filesystem::exists(configFile);

            if (fileExists) {
                loadFromFile(configFile);
            }

            // 3. Save the configuration file
            saveToFile(configFile);

            return true;
        }

        void ConfigManager::setupDefaults() {
            // Tool Paths
            configValues_["kickassPath"] = "java -jar KickAss.jar -silentMode";
            configValues_["exomizerPath"] = "Exomizer.exe";
            configValues_["compressorType"] = "exomizer";
            configValues_["pucrunchPath"] = "pucrunch";

            // SID Default Settings
            configValues_["defaultSidLoadAddress"] = "$1000";
            configValues_["defaultSidInitAddress"] = "$1000";
            configValues_["defaultSidPlayAddress"] = "$1003";

            // Player Settings
            configValues_["playerName"] = "SimpleRaster";
            configValues_["playerAddress"] = "$4000";
            configValues_["playerDirectory"] = "SIDPlayers";
            configValues_["defaultPlayCallsPerFrame"] = "1";

            // Emulation Settings
            configValues_["emulationFrames"] = "30000";
            configValues_["clockStandard"] = "PAL";  // PAL or NTSC

            // Logging Settings
            configValues_["logFile"] = "SIDwinder.log";
            configValues_["logLevel"] = "3";

            // Compression tool options
            configValues_["exomizerOptions"] = "-x 3 -q";
            configValues_["pucrunchOptions"] = "-x";
        }

        bool ConfigManager::loadFromFile(const std::filesystem::path& configFile) {
            std::ifstream file(configFile);
            if (!file) {
                std::cerr << "Could not open configuration file: " << configFile.string() << std::endl;
                return false;
            }

            std::string line;
            while (std::getline(file, line)) {
                // Skip empty lines and comments
                if (line.empty() || line[0] == '#' || line[0] == ';') {
                    continue;
                }

                // Find key-value separator
                const auto pos = line.find('=');
                if (pos == std::string::npos) {
                    continue;
                }

                // Extract key and value
                std::string key = line.substr(0, pos);
                std::string value = line.substr(pos + 1);

                // Trim whitespace
                key.erase(0, key.find_first_not_of(" \t"));
                key.erase(key.find_last_not_of(" \t") + 1);
                value.erase(0, value.find_first_not_of(" \t"));
                value.erase(value.find_last_not_of(" \t") + 1);

                configValues_[key] = value;
            }

            return true;
        }

        bool ConfigManager::saveToFile(const std::filesystem::path& configFile) {
            std::ofstream file(configFile);
            if (!file) {
                std::cerr << "Could not create configuration file: " << configFile.string() << std::endl;
                return false;
            }

            // Write formatted configuration
            file << generateFormattedConfig();

            return file.good();
        }

        std::string ConfigManager::generateFormattedConfig() {
            std::stringstream ss;

            ss << "# SIDwinder Configuration File\n";
            ss << "# -----------------------\n";
            ss << "# This file contains settings for the SIDwinder tool\n";
            ss << "# Edit this file to customize your installation paths and default settings\n\n";

            // Tool Paths
            ss << "# Tool Paths\n";
            ss << "# ----------\n";
            ss << "# Path to KickAss jar file (include 'java -jar' prefix if needed)\n";
            ss << "kickassPath=" << configValues_["kickassPath"] << "\n\n";

            ss << "# Path to Exomizer executable\n";
            ss << "exomizerPath=" << configValues_["exomizerPath"] << "\n\n";

            ss << "# Path to Pucrunch executable\n";
            ss << "pucrunchPath=" << configValues_["pucrunchPath"] << "\n\n";

            ss << "# Compression Tool to use (exomizer, pucrunch, etc)\n";
            ss << "compressorType=" << configValues_["compressorType"] << "\n\n";

            ss << "# Compression tool options\n";
            ss << "exomizerOptions=" << configValues_["exomizerOptions"] << "\n";
            ss << "pucrunchOptions=" << configValues_["pucrunchOptions"] << "\n\n";

            // SID Default Settings
            ss << "# SID Default Settings\n";
            ss << "# -------------------\n";
            ss << "# Default load address for SID files ($XXXX format)\n";
            ss << "defaultSidLoadAddress=" << configValues_["defaultSidLoadAddress"] << "\n\n";

            ss << "# Default init address for SID files\n";
            ss << "defaultSidInitAddress=" << configValues_["defaultSidInitAddress"] << "\n\n";

            ss << "# Default play address for SID files\n";
            ss << "defaultSidPlayAddress=" << configValues_["defaultSidPlayAddress"] << "\n\n";

            // Player Settings
            ss << "# Player Settings\n";
            ss << "# --------------\n";
            ss << "# Default player name (corresponds to folder in player directory)\n";
            ss << "playerName=" << configValues_["playerName"] << "\n\n";

            ss << "# Default player load address\n";
            ss << "playerAddress=" << configValues_["playerAddress"] << "\n\n";

            ss << "# Directory containing player code\n";
            ss << "playerDirectory=" << configValues_["playerDirectory"] << "\n\n";

            ss << "# Default number of play calls per frame (may be overridden by CIA timer detection)\n";
            ss << "defaultPlayCallsPerFrame=" << configValues_["defaultPlayCallsPerFrame"] << "\n\n";

            // Emulation Settings
            ss << "# Emulation Settings\n";
            ss << "# ----------------\n";
            ss << "# Number of frames to emulate for analysis and tracing\n";
            ss << "emulationFrames=" << configValues_["emulationFrames"] << "\n\n";

            ss << "# Clock standard (PAL or NTSC)\n";
            ss << "clockStandard=" << configValues_["clockStandard"] << "\n\n";

            // Logging Settings
            ss << "# Logging Settings\n";
            ss << "# ---------------\n";
            ss << "# Default log file\n";
            ss << "logFile=" << configValues_["logFile"] << "\n\n";

            ss << "# Default log level (1=Error, 2=Warning, 3=Info, 4=Debug)\n";
            ss << "logLevel=" << configValues_["logLevel"] << "\n\n";

            // Add any custom settings not included in our sections
            std::vector<std::string> handledKeys = {
                "kickassPath", "exomizerPath", "pucrunchPath", "compressorType", "exomizerOptions", "pucrunchOptions",
                "defaultSidLoadAddress", "defaultSidInitAddress", "defaultSidPlayAddress",
                "playerName", "playerAddress", "playerDirectory", "defaultPlayCallsPerFrame",
                "emulationFrames", "clockStandard",
                "logFile", "logLevel"
            };

            bool hasCustomSettings = false;
            for (const auto& [key, value] : configValues_) {
                if (std::find(handledKeys.begin(), handledKeys.end(), key) == handledKeys.end()) {
                    if (!hasCustomSettings) {
                        ss << "# Custom Settings\n";
                        ss << "# --------------\n";
                        hasCustomSettings = true;
                    }
                    ss << key << "=" << value << "\n";
                }
            }

            return ss.str();
        }

        std::string ConfigManager::getString(const std::string& key, const std::string& defaultValue) {
            const auto it = configValues_.find(key);
            return (it != configValues_.end()) ? it->second : defaultValue;
        }

        int ConfigManager::getInt(const std::string& key, int defaultValue) {
            const auto it = configValues_.find(key);
            if (it == configValues_.end()) {
                return defaultValue;
            }

            try {
                return std::stoi(it->second);
            }
            catch (const std::exception&) {
                return defaultValue;
            }
        }

        bool ConfigManager::getBool(const std::string& key, bool defaultValue) {
            const auto it = configValues_.find(key);
            if (it == configValues_.end()) {
                return defaultValue;
            }

            const auto& value = it->second;
            if (value == "true" || value == "yes" || value == "1" ||
                value == "on" || value == "enable" || value == "enabled") {
                return true;
            }
            else if (value == "false" || value == "no" || value == "0" ||
                value == "off" || value == "disable" || value == "disabled") {
                return false;
            }

            return defaultValue;
        }

        double ConfigManager::getDouble(const std::string& key, double defaultValue) {
            const auto it = configValues_.find(key);
            if (it == configValues_.end()) {
                return defaultValue;
            }

            try {
                return std::stod(it->second);
            }
            catch (const std::exception&) {
                return defaultValue;
            }
        }

        void ConfigManager::setValue(const std::string& key, const std::string& value, bool saveToFile) {
            // Check if value is changing
            auto it = configValues_.find(key);
            if (it == configValues_.end() || it->second != value) {
                configValues_[key] = value;
                if (saveToFile) {
                    ConfigManager::saveToFile(configFile_);
                }
            }
        }

        // Helper methods for common configuration values
        std::string ConfigManager::getKickAssPath() {
            return getString("kickassPath", "java -jar KickAss.jar -silentMode");
        }

        std::string ConfigManager::getExomizerPath() {
            return getString("exomizerPath", "Exomizer.exe");
        }

        std::string ConfigManager::getCompressorType() {
            return getString("compressorType", "exomizer");
        }

        std::string ConfigManager::getPlayerName() {
            return getString("playerName", "SimpleRaster");
        }

        u16 ConfigManager::getPlayerAddress() {
            std::string addrStr = getString("playerAddress", "$4000");

            // Simple hex parser for $XXXX format
            if (!addrStr.empty() && addrStr[0] == '$') {
                try {
                    return static_cast<u16>(std::stoul(addrStr.substr(1), nullptr, 16));
                }
                catch (const std::exception&) {
                    // Fall through to default
                }
            }

            return 0x4000; // Default player address
        }

        u16 ConfigManager::getDefaultSidLoadAddress() {
            std::string addrStr = getString("defaultSidLoadAddress", "$1000");

            if (!addrStr.empty() && addrStr[0] == '$') {
                try {
                    return static_cast<u16>(std::stoul(addrStr.substr(1), nullptr, 16));
                }
                catch (const std::exception&) {
                    // Fall through to default
                }
            }

            return 0x1000;
        }

        u16 ConfigManager::getDefaultSidInitAddress() {
            std::string addrStr = getString("defaultSidInitAddress", "$1000");

            if (!addrStr.empty() && addrStr[0] == '$') {
                try {
                    return static_cast<u16>(std::stoul(addrStr.substr(1), nullptr, 16));
                }
                catch (const std::exception&) {
                    // Fall through to default
                }
            }

            return 0x1000;
        }

        u16 ConfigManager::getDefaultSidPlayAddress() {
            std::string addrStr = getString("defaultSidPlayAddress", "$1003");

            if (!addrStr.empty() && addrStr[0] == '$') {
                try {
                    return static_cast<u16>(std::stoul(addrStr.substr(1), nullptr, 16));
                }
                catch (const std::exception&) {
                    // Fall through to default
                }
            }

            return 0x1003;
        }

        std::string ConfigManager::getClockStandard() {
            std::string clockStr = getString("clockStandard", "PAL");
            std::transform(clockStr.begin(), clockStr.end(), clockStr.begin(), ::toupper);

            // Validate - default to PAL if invalid
            if (clockStr != "PAL" && clockStr != "NTSC") {
                clockStr = "PAL";
            }

            return clockStr;
        }

        double ConfigManager::getCyclesPerFrame() {
            std::string clockStandard = getClockStandard();

            if (clockStandard == "NTSC") {
                // NTSC: 65 cycles per line, 263 lines per frame
                return 65.0 * 263.0;
            }
            else {
                // PAL: 63 cycles per line, 312 lines per frame
                return 63.0 * 312.0;
            }
        }

    } // namespace util
} // namespace sidwinder