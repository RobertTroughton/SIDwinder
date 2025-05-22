// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#include "SIDwinderUtils.h"

#include <algorithm>
#include <cctype>
#include <chrono>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <unordered_map>
#include <ctime>

namespace sidwinder {
    namespace util {

        // Initialize static members
        Logger::Level Logger::minLevel_ = Logger::Level::Info;
        std::optional<std::filesystem::path> Logger::logFile_ = std::nullopt;
        bool Logger::consoleOutput_ = true;
        std::unordered_map<std::string, std::string> Configuration::configValues_ = {
            {"kickassPath", DEFAULT_KICKASS_PATH},
            {"exomizerPath", DEFAULT_EXOMIZER_PATH},
            {"compressorType", DEFAULT_COMPRESSOR_TYPE},
            {"playerName", DEFAULT_PLAYER_NAME},
            {"playerAddress", DEFAULT_PLAYER_ADDRESS},
            {"defaultSidLoadAddress", DEFAULT_SID_LOAD_ADDRESS},
            {"defaultSidInitAddress", DEFAULT_SID_INIT_ADDRESS},
            {"defaultSidPlayAddress", DEFAULT_SID_PLAY_ADDRESS}
        };

        /**
         * @brief Convert a byte to a hexadecimal string
         *
         * @param value Byte value to convert
         * @param upperCase Whether to use uppercase letters
         * @return Formatted hex string (always 2 characters)
         */
        std::string byteToHex(u8 value, bool upperCase) {
            std::ostringstream ss;
            ss << (upperCase ? std::uppercase : std::nouppercase)
                << std::hex << std::setw(2) << std::setfill('0')
                << static_cast<int>(value);
            return ss.str();
        }

        /**
         * @brief Convert a word to a hexadecimal string
         *
         * @param value Word value to convert
         * @param upperCase Whether to use uppercase letters
         * @return Formatted hex string (always 4 characters)
         */
        std::string wordToHex(u16 value, bool upperCase) {
            std::ostringstream ss;
            ss << (upperCase ? std::uppercase : std::nouppercase)
                << std::hex << std::setw(4) << std::setfill('0')
                << value;
            return ss.str();
        }

        /**
         * @brief Parse a hexadecimal string into a numeric value
         *
         * Handles different formats including:
         * - "1234" (decimal)
         * - "$1234" (hex with $ prefix)
         * - "0x1234" (hex with 0x prefix)
         *
         * @param str String to parse
         * @return Parsed value, or std::nullopt if parsing failed
         */
        std::optional<u16> parseHex(std::string_view str) {
            // Trim whitespace
            const auto start = str.find_first_not_of(" \t\r\n");
            if (start == std::string_view::npos) {
                return std::nullopt;
            }
            const auto end = str.find_last_not_of(" \t\r\n");
            const auto trimmed = str.substr(start, end - start + 1);

            try {
                // Check for hex prefix
                if (!trimmed.empty() && trimmed[0] == '$') {
                    // Convert from "$XXXX" format
                    return static_cast<u16>(std::stoul(std::string(trimmed.substr(1)), nullptr, 16));
                }
                else if (trimmed.size() > 2 && trimmed.substr(0, 2) == "0x") {
                    // Convert from "0xXXXX" format
                    return static_cast<u16>(std::stoul(std::string(trimmed), nullptr, 16));
                }
                else {
                    // Try to parse as decimal
                    return static_cast<u16>(std::stoul(std::string(trimmed), nullptr, 10));
                }
            }
            catch (const std::exception&) {
                // Catch any exceptions from stoul
                return std::nullopt;
            }
        }

        /**
         * @brief Pad a string to a specific width with spaces
         *
         * Adds trailing spaces to reach the desired width, useful for
         * aligning columns in formatted output.
         *
         * @param str String to pad
         * @param width Target width
         * @return Padded string
         */
        std::string padToColumn(std::string_view str, size_t width) {
            if (str.length() >= width) {
                return std::string(str);
            }

            return std::string(str) + std::string(width - str.length(), ' ');
        }

        /**
         * @brief Update the index range to include a new offset
         *
         * Records a new value in the range, updating the min/max if needed.
         *
         * @param offset Value to include in the range
         */
        void IndexRange::update(int offset) {
            min_ = std::min(min_, offset);
            max_ = std::max(max_, offset);
        }

        /**
         * @brief Get the current min/max range
         *
         * @return Pair containing min and max values
         */
        std::pair<int, int> IndexRange::getRange() const {
            if (min_ > max_) {
                return { 0, 0 };  // No valid data
            }
            return { min_, max_ };
        }

        /**
         * @brief Helper function for safe localtime
         *
         * Provides a cross-platform way to get the local time structure
         * that works on both Windows and POSIX systems.
         *
         * @param time Time value to convert
         * @return Local time structure
         */
        std::tm getLocalTime(const std::time_t& time) {
            std::tm timeInfo = {};
#ifdef _WIN32
            // Windows-specific version
            localtime_s(&timeInfo, &time);
#else
            // POSIX version
            localtime_r(&time, &timeInfo);
#endif
            return timeInfo;
        }

        /**
         * @brief Initialize the logger
         *
         * Sets up the logging system with the specified output destination.
         * If a log file is provided, output is directed there; otherwise,
         * output goes to the console.
         *
         * @param logFile Path to log file (optional)
         */
        void Logger::initialize(const std::filesystem::path& logFile) {
            logFile_ = logFile;
            consoleOutput_ = !logFile_.has_value();
            if (logFile_) {
                // Create directories if needed
                const auto parent = logFile_->parent_path();
                if (!parent.empty()) {
                    std::filesystem::create_directories(parent);
                }
                // Test if we can write to the log file
                std::ofstream file(logFile_.value(), std::ios::trunc);
                if (!file) {
                    std::cerr << "Warning: Could not open log file: " << logFile_.value().string() << std::endl;
                    logFile_ = std::nullopt;
                    consoleOutput_ = true;
                }
                else {
                    // Write header
                    auto now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
                    std::tm timeInfo = getLocalTime(now);
                    file << "===== SIDwinder Log Started at "
                        << std::put_time(&timeInfo, "%Y-%m-%d %H:%M:%S")
                        << " =====\n";
                }
            }
        }

        /**
         * @brief Set minimum log level to show
         *
         * Configures the logger to only display messages at or above
         * the specified severity level.
         *
         * @param level Minimum level
         */
        void Logger::setLogLevel(Level level) {
            minLevel_ = level;
        }

        /**
         * @brief Log a message
         *
         * Core logging function that formats and outputs a message
         * with timestamp and severity level.
         *
         * @param level Message severity
         * @param message Text to log
         */
        void Logger::log(Level level, const std::string& message, bool toConsole) {
            if (level < minLevel_) {
                return;
            }

            // Format timestamp
            const auto now = std::chrono::system_clock::now();
            const auto nowTime = std::chrono::system_clock::to_time_t(now);
            std::tm timeInfo = getLocalTime(nowTime);

            std::stringstream timestampStr;
            timestampStr << std::put_time(&timeInfo, "%Y-%m-%d %H:%M:%S");

            // Format level
            std::string levelStr;
            switch (level) {
            case Level::Debug:   levelStr = "DEBUG"; break;
            case Level::Info:    levelStr = "INFO"; break;
            case Level::Warning: levelStr = "WARNING"; break;
            case Level::Error:   levelStr = "ERROR"; break;
            }

            // Format full message
            std::stringstream fullMessage;
            fullMessage << "[" << timestampStr.str() << "] [" << levelStr << "] " << message;

            // Write to file if enabled
            if (logFile_) {
                std::ofstream file(logFile_.value(), std::ios::app);
                if (file) {
                    file << fullMessage.str() << std::endl;
                }
            }

            if (level == Level::Error) {
                std::cerr << fullMessage.str() << std::endl;
            }
            if (toConsole) {
                std::cout << fullMessage.str() << std::endl;
            }
        }

        /**
         * @brief Log a debug message
         *
         * For detailed debugging information.
         *
         * @param message Text to log
         */
        void Logger::debug(const std::string& message, bool toConsole) {
            log(Level::Debug, message, toConsole);
        }

        /**
         * @brief Log an info message
         *
         * For general information messages.
         *
         * @param message Text to log
         */
        void Logger::info(const std::string& message, bool toConsole) {
            log(Level::Info, message, toConsole);
        }

        /**
         * @brief Log a warning message
         *
         * For warning messages about potential issues.
         *
         * @param message Text to log
         */
        void Logger::warning(const std::string& message, bool toConsole) {
            log(Level::Warning, message, toConsole);
        }

        /**
         * @brief Log an error message
         *
         * For error messages about failures.
         *
         * @param message Text to log
         */
        void Logger::error(const std::string& message, bool toConsole) {
            log(Level::Error, message, toConsole);
        }

        /**
         * @brief Load configuration from a file
         *
         * Reads key=value pairs from a configuration file and stores them
         * in the configuration map. Comments starting with # or ; are ignored.
         *
         * @param configFile Path to configuration file
         * @return true if loading succeeded
         */
        bool Configuration::loadFromFile(const std::filesystem::path& configFile) {
            std::ifstream file(configFile);
            if (!file) {
                Logger::warning("Could not open configuration file: " + configFile.string());
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

                // Store in config map
                if (!key.empty()) {
                    configValues_[key] = value;
                }
            }

            Logger::info("Configuration loaded from: " + configFile.string());
            return true;
        }

        /**
         * @brief Set a configuration value
         *
         * Adds or updates a key-value pair in the configuration map.
         *
         * @param key Configuration key
         * @param value Value to set
         */
        void Configuration::setValue(const std::string& key, const std::string& value) {
            configValues_[key] = value;
        }

        /**
         * @brief Get a string configuration value
         *
         * Retrieves a string value from the configuration map.
         *
         * @param key Configuration key
         * @param defaultValue Default value if key not found
         * @return Configuration value or default
         */
        std::string Configuration::getString(const std::string& key, const std::string& defaultValue) {
            const auto it = configValues_.find(key);
            return (it != configValues_.end()) ? it->second : defaultValue;
        }

        /**
         * @brief Get an integer configuration value
         *
         * Retrieves a value from the configuration map and converts it to an integer.
         *
         * @param key Configuration key
         * @param defaultValue Default value if key not found or conversion fails
         * @return Configuration value as integer or default
         */
        int Configuration::getInt(const std::string& key, int defaultValue) {
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


        /**
         * @brief Get a boolean configuration value
         *
         * Retrieves a value from the configuration map and converts it to a boolean.
         * Recognizes various string formats for true/false values.
         *
         * @param key Configuration key
         * @param defaultValue Default value if key not found or conversion fails
         * @return Configuration value as boolean or default
         */
        bool Configuration::getBool(const std::string& key, bool defaultValue) {
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

        /**
         * @brief Get a double (floating-point) configuration value
         *
         * Retrieves a value from the configuration map and converts it to a double.
         *
         * @param key Configuration key
         * @param defaultValue Default value if key not found or conversion fails
         * @return Configuration value as double or default
         */
        double Configuration::getDouble(const std::string& key, double defaultValue) {
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

        /**
         * @brief Get the path to the KickAss assembler
         *
         * @return Path to KickAss assembler
         */
        std::string Configuration::getKickAssPath() {
            return getString("kickassPath", DEFAULT_KICKASS_PATH);
        }

        /**
         * @brief Get the path to the Exomizer compressor
         *
         * @return Path to Exomizer compressor
         */
        std::string Configuration::getExomizerPath() {
            return getString("exomizerPath", DEFAULT_EXOMIZER_PATH);
        }

        /**
         * @brief Get the compressor type
         *
         * @return Type of compressor to use
         */
        std::string Configuration::getCompressorType() {
            return getString("compressorType", DEFAULT_COMPRESSOR_TYPE);
        }

        /**
         * @brief Get the player name
         *
         * @return Name of player to use
         */
        std::string Configuration::getPlayerName() {
            return getString("playerName", DEFAULT_PLAYER_NAME);
        }

        /**
         * @brief Get the player address
         *
         * Parses the player address configuration value as a hexadecimal address.
         *
         * @return Address to load player at
         */
        u16 Configuration::getPlayerAddress() {
            std::string addrStr = getString("playerAddress", DEFAULT_PLAYER_ADDRESS);
            auto addr = parseHex(addrStr);
            return addr.value_or(0x0400); // Default to $0400 if parsing fails
        }

        /**
         * @brief Get the default SID load address
         *
         * Parses the default SID load address configuration value.
         *
         * @return Default SID load address
         */
        u16 Configuration::getDefaultSidLoadAddress() {
            std::string addrStr = getString("defaultSidLoadAddress", DEFAULT_SID_LOAD_ADDRESS);
            auto addr = parseHex(addrStr);
            return addr.value_or(0x1000); // Default to $1000 if parsing fails
        }

        /**
         * @brief Get the default SID init address
         *
         * Parses the default SID init address configuration value.
         *
         * @return Default SID init address
         */
        u16 Configuration::getDefaultSidInitAddress() {
            std::string addrStr = getString("defaultSidInitAddress", DEFAULT_SID_INIT_ADDRESS);
            auto addr = parseHex(addrStr);
            return addr.value_or(0x1000); // Default to $1000 if parsing fails
        }

        /**
         * @brief Get the default SID play address
         *
         * Parses the default SID play address configuration value.
         *
         * @return Default SID play address
         */
        u16 Configuration::getDefaultSidPlayAddress() {
            std::string addrStr = getString("defaultSidPlayAddress", DEFAULT_SID_PLAY_ADDRESS);
            auto addr = parseHex(addrStr);
            return addr.value_or(0x1003); // Default to $1003 if parsing fails
        }

    } // namespace util
} // namespace sidwinder