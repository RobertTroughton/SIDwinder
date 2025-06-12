// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#pragma once

#include "Common.h"
#include "SIDFileFormat.h"

#include <array>
#include <filesystem>
#include <functional>
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

        std::optional<std::vector<u8>> readBinaryFile(const fs::path& path);
        bool readTextFileLines(const fs::path& path, std::function<bool(const std::string&)> lineHandler);
        bool writeBinaryFile(const fs::path& path, const void* data, size_t size);
        bool writeBinaryFile(const fs::path& path, const std::vector<u8>& data);

        inline u16 swapEndian(u16 value) {
            return (value >> 8) | (value << 8);
        }

        inline u32 swapEndian(u32 value) {
            return ((value & 0xff000000) >> 24)
                | ((value & 0x00ff0000) >> 8)
                | ((value & 0x0000ff00) << 8)
                | ((value & 0x000000ff) << 24);
        }

        std::string getFileExtension(const fs::path& filePath);

        // Helper for case-insensitive extension comparison
        bool hasExtension(const fs::path& filePath, const std::string& extension);

        // Validate file extensions for specific operations
        bool isValidSIDFile(const fs::path& filePath);
        bool isValidPRGFile(const fs::path& filePath);
        bool isValidASMFile(const fs::path& filePath);

        void fixSIDHeaderEndianness(SIDHeader& header);

        class HexFormatter {
        public:
            static std::string hexbyte(u8 value, bool prefix = false, bool upperCase = true);
            static std::string hexword(u16 value, bool prefix = false, bool upperCase = true);
            static std::string hexdword(u32 value, bool prefix = false, bool upperCase = true);

            // Specialized C64 formatting
            static std::string address(u16 addr) { return "$" + hexword(addr, false, true); }
            static std::string registerValue(u8 value) { return "$" + hexbyte(value, false, true); }
            static std::string memoryDump(u16 addr, u8 value) {
                return hexword(addr, false, true) + ":$" + hexbyte(value, false, true);
            }
        };

        // Replace scattered formatting with these
        inline std::string byteToHex(u8 value, bool upperCase = true) {
            return HexFormatter::hexbyte(value, false, upperCase);
        }

        inline std::string wordToHex(u16 value, bool upperCase = true) {
            return HexFormatter::hexword(value, false, upperCase);
        }

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

        // Text file writing utilities
        bool writeTextFile(const fs::path& path, const std::string& content);
        bool writeTextFileLines(const fs::path& path, const std::vector<std::string>& lines);

        // Template for objects that can stream themselves
        template<typename T>
        bool writeStreamableToFile(const fs::path& path, const T& obj) {
            std::ofstream file(path);
            if (!file) {
                Logger::error("Failed to create file: " + path.string());
                return false;
            }
            file << obj;
            return file.good();
        }

        // String builder utility for complex text generation
        class TextFileBuilder {
        public:
            TextFileBuilder& line(const std::string& text = "") {
                content_ += text + "\n";
                return *this;
            }

            TextFileBuilder& append(const std::string& text) {
                content_ += text;
                return *this;
            }

            TextFileBuilder& section(const std::string& title) {
                if (!content_.empty()) content_ += "\n";
                content_ += "// " + title + "\n";
                content_ += "// " + std::string(title.length(), '-') + "\n";
                return *this;
            }

            bool saveToFile(const fs::path& path) const {
                return writeTextFile(path, content_);
            }

            const std::string& getString() const { return content_; }

        private:
            std::string content_;
        };

    } // namespace util
} // namespace sidwinder

