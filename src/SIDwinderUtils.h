// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#pragma once

#include "Common.h"

#include <array>
#include <filesystem>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>

/**
 * @file SIDwinderUtils.h
 * @brief Utility functions and classes for SIDwinder
 *
 * Provides various utility functions and classes used throughout
 * the SIDwinder codebase, including logging, configuration,
 * and string formatting utilities.
 */

namespace sidwinder {

    namespace util {

        /**
         * @brief Convert a byte to a hexadecimal string
         * @param value Byte value to convert
         * @param upperCase Whether to use uppercase letters (default: true)
         * @return Formatted hex string (always 2 characters)
         */
        std::string byteToHex(u8 value, bool upperCase = true);

        /**
         * @brief Convert a word to a hexadecimal string
         * @param value Word value to convert
         * @param upperCase Whether to use uppercase letters (default: true)
         * @return Formatted hex string (always 4 characters)
         */
        std::string wordToHex(u16 value, bool upperCase = true);

        /**
         * @brief Parse a hexadecimal string into a numeric value
         * @param str String to parse
         * @return Parsed value, or std::nullopt if parsing failed
         *
         * Supports various formats including:
         * - "1234" (decimal)
         * - "$1234" (hex with $ prefix)
         * - "0x1234" (hex with 0x prefix)
         */
        std::optional<u16> parseHex(std::string_view str);

        /**
         * @brief Pad a string to a specific width with spaces
         * @param str String to pad
         * @param width Target width
         * @return Padded string
         *
         * Useful for aligning columns in formatted output.
         */
        std::string padToColumn(std::string_view str, size_t width);

        /**
         * @class IndexRange
         * @brief A range of indices (min to max)
         *
         * Tracks a range of index values by recording the minimum and maximum
         * values seen.
         */
        class IndexRange {
        public:
            /**
             * @brief Update the range to include a new offset
             * @param offset Value to include in the range
             */
            void update(int offset);

            /**
             * @brief Get the current min,max range
             * @return Pair containing min and max values
             */
            std::pair<int, int> getRange() const;

        private:
            int min_ = std::numeric_limits<int>::max();  // Minimum value seen
            int max_ = std::numeric_limits<int>::min();  // Maximum value seen
        };

        /**
         * @class Logger
         * @brief Logging utility for the SIDwinder project
         *
         * Provides a centralized logging facility with support for
         * different severity levels and output to file or console.
         */
        class Logger {
        public:
            /**
             * @brief Log severity levels
             */
            enum class Level {
                Debug,    // Detailed debugging information
                Info,     // General information messages
                Warning,  // Warning messages
                Error     // Error messages
            };

            /**
             * @brief Initialize the logger
             * @param logFile Path to log file (optional, uses console if not provided)
             *
             * Sets up the logging system with the specified output destination.
             */
            static void initialize(const std::filesystem::path& logFile = {});

            /**
             * @brief Set minimum log level to show
             * @param level Minimum level
             */
            static void setLogLevel(Level level);

            /**
             * @brief Log a message
             * @param level Message severity
             * @param message Text to log
             *
             * Logs a message with the specified severity level.
             */
            static void log(Level level, const std::string& message, bool toConsole = false);

            /**
             * @brief Log a debug message
             * @param message Text to log
             */
            static void debug(const std::string& message, bool toConsole = false);

            /**
             * @brief Log an info message
             * @param message Text to log
             */
            static void info(const std::string& message, bool toConsole = false);

            /**
             * @brief Log a warning message
             * @param message Text to log
             */
            static void warning(const std::string& message, bool toConsole = false);

            /**
             * @brief Log an error message
             * @param message Text to log
             */
            static void error(const std::string& message, bool toConsole = false);

        private:
            static Level minLevel_;                                  // Minimum level to log
            static std::optional<std::filesystem::path> logFile_;    // Path to log file
            static bool consoleOutput_;                              // Whether to output to console
        };

    } // namespace util
} // namespace sidwinder