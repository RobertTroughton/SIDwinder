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

    } // namespace util
} // namespace sidwinder