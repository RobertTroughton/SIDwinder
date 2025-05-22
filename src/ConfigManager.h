// ConfigManager.h
#pragma once

#include "Common.h"
#include <map>
#include <string>
#include <filesystem>

namespace sidwinder {
    namespace util {

        /**
         * @class ConfigManager
         * @brief Central configuration management for SIDwinder
         *
         * Handles loading, saving, and merging of configuration settings.
         * Provides a centralized place for all default values.
         */
        class ConfigManager {
        public:
            /**
             * @brief Initialize the configuration system
             * @param configFile Path to the configuration file
             * @return True if initialization was successful
             */
            static bool initialize(const std::filesystem::path& configFile);

            /**
             * @brief Get a string configuration value
             * @param key Configuration key
             * @param defaultValue Default value if key not found
             * @return Configuration value
             */
            static std::string getString(const std::string& key, const std::string& defaultValue = {});

            /**
             * @brief Get an integer configuration value
             * @param key Configuration key
             * @param defaultValue Default value if key not found
             * @return Configuration value
             */
            static int getInt(const std::string& key, int defaultValue = 0);

            /**
             * @brief Get a boolean configuration value
             * @param key Configuration key
             * @param defaultValue Default value if key not found
             * @return Configuration value
             */
            static bool getBool(const std::string& key, bool defaultValue = false);

            /**
             * @brief Get a double (floating-point) configuration value
             * @param key Configuration key
             * @param defaultValue Default value if key not found
             * @return Configuration value as double
             */
            static double getDouble(const std::string& key, double defaultValue = 0.0);

            /**
             * @brief Set a configuration value
             * @param key Configuration key
             * @param value Value to set
             * @param saveToFile Whether to save changes to file immediately
             */
            static void setValue(const std::string& key, const std::string& value, bool saveToFile = false);

            // Helper methods for common configuration values
            static std::string getKickAssPath();
            static std::string getExomizerPath();
            static std::string getCompressorType();
            static std::string getPlayerName();
            static u16 getPlayerAddress();
            static u16 getDefaultSidLoadAddress();
            static u16 getDefaultSidInitAddress();
            static u16 getDefaultSidPlayAddress();

        private:
            static std::map<std::string, std::string> configValues_;
            static std::filesystem::path configFile_;

            /**
             * @brief Set up the default configuration values
             */
            static void setupDefaults();

            /**
             * @brief Load configuration from a file
             * @param configFile Path to the configuration file
             * @return True if loading succeeded
             */
            static bool loadFromFile(const std::filesystem::path& configFile);

            /**
             * @brief Save configuration to a file
             * @param configFile Path to the configuration file
             * @return True if saving succeeded
             */
            static bool saveToFile(const std::filesystem::path& configFile);

            /**
             * @brief Generate a formatted configuration file with comments
             * @return Formatted configuration content
             */
            static std::string generateFormattedConfig();
        };

    } // namespace util
} // namespace sidwinder