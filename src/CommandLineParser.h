// CommandLineParser.h
#pragma once

#include "CommandClass.h"
#include <filesystem>
#include <string>
#include <map>
#include <vector>

namespace sidwinder {

    /**
     * @class CommandLineParser
     * @brief Parser for command line arguments
     *
     * Parses command line arguments into a Command object.
     */
    class CommandLineParser {
    public:
        /**
         * @brief Constructor
         * @param argc Number of command line arguments
         * @param argv Array of command line arguments
         */
        CommandLineParser(int argc, char** argv);

        /**
         * @brief Parse the command line arguments
         * @return Command object representing the parsed arguments
         */
        CommandClass parse() const;

        /**
         * @brief Get the program name
         * @return Program name (from argv[0])
         */
        const std::string& getProgramName() const;

        /**
         * @brief Print usage information
         * @param message Optional message to display before usage
         */
        void printUsage(const std::string& message = "") const;

        /**
         * @brief Add a flag definition for usage help
         * @param flag Flag name (without leading dashes)
         * @param description Flag description
         * @param category Category for grouping in help text
         * @return Reference to this parser (for chaining)
         */
        CommandLineParser& addFlagDefinition(
            const std::string& flag,
            const std::string& description,
            const std::string& category = "General");

        /**
         * @brief Add an option definition for usage help
         * @param option Option name (without leading dashes)
         * @param argName Name of the option's argument
         * @param description Option description
         * @param category Category for grouping in help text
         * @param defaultValue Default value (empty for no default)
         * @return Reference to this parser (for chaining)
         */
        CommandLineParser& addOptionDefinition(
            const std::string& option,
            const std::string& argName,
            const std::string& description,
            const std::string& category = "General",
            const std::string& defaultValue = "");

        /**
         * @brief Add example usage for help text
         * @param example Example command line
         * @param description Description of what the example does
         * @return Reference to this parser (for chaining)
         */
        CommandLineParser& addExample(
            const std::string& example,
            const std::string& description);

    private:
        std::vector<std::string> args_;            ///< Command line arguments
        std::string programName_;                  ///< Program name from argv[0]

        // For usage help
        struct OptionDefinition {
            std::string argName;       ///< Name of the option's argument
            std::string description;   ///< Description of the option
            std::string category;      ///< Category for grouping
            std::string defaultValue;  ///< Default value
        };

        struct FlagDefinition {
            std::string description;   ///< Description of the flag
            std::string category;      ///< Category for grouping
        };

        struct ExampleUsage {
            std::string example;       ///< Example command line
            std::string description;   ///< Description of the example
        };

        std::map<std::string, OptionDefinition> optionDefs_;  ///< Option definitions
        std::map<std::string, FlagDefinition> flagDefs_;      ///< Flag definitions
        std::vector<ExampleUsage> examples_;                  ///< Example usages
    };

} // namespace sidwinder