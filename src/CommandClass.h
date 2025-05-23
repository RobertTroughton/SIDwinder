// CommandClass.h - Updated with new command types
#pragma once

#include "Common.h"
#include <string>
#include <map>
#include <vector>
#include <optional>

namespace sidwinder {

    /**
     * @class CommandClass
     * @brief Represents a single command operation in SIDwinder
     *
     * Commands encapsulate the parameters and operation type for a single
     * SIDwinder operation, such as conversion, relocation, etc.
     */
    class CommandClass {
    public:
        /**
         * @enum Type
         * @brief Types of commands supported by SIDwinder
         */
        enum class Type {
            Player,        ///< Link SID with player code to create executable PRG (renamed from LinkPlayer)
            Relocate,      ///< Relocate a SID file to a new address
            Disassemble,   ///< Disassemble a SID file to assembly
            Trace,         ///< Trace SID register writes
            Help,          ///< Show help information
            Unknown        ///< Unknown command
        };

        /**
         * @brief Constructor
         * @param type Command type
         */
        CommandClass(Type type = Type::Unknown);

        /**
         * @brief Get the command type
         * @return Command type
         */
        Type getType() const { return type_; }

        /**
         * @brief Set the command type
         * @param type Command type
         */
        void setType(Type type) { type_ = type; }

        /**
         * @brief Get the input file path
         * @return Input file path
         */
        const std::string& getInputFile() const { return inputFile_; }

        /**
         * @brief Set the input file path
         * @param inputFile Input file path
         */
        void setInputFile(const std::string& inputFile) { inputFile_ = inputFile; }

        /**
         * @brief Get the output file path
         * @return Output file path
         */
        const std::string& getOutputFile() const { return outputFile_; }

        /**
         * @brief Set the output file path
         * @param outputFile Output file path
         */
        void setOutputFile(const std::string& outputFile) { outputFile_ = outputFile; }

        /**
         * @brief Get a parameter value
         * @param key Parameter key
         * @param defaultValue Default value if parameter not found
         * @return Parameter value or default
         */
        std::string getParameter(const std::string& key, const std::string& defaultValue = "") const;

        /**
         * @brief Check if a parameter exists
         * @param key Parameter key
         * @return True if parameter exists
         */
        bool hasParameter(const std::string& key) const;

        /**
         * @brief Set a parameter value
         * @param key Parameter key
         * @param value Parameter value
         */
        void setParameter(const std::string& key, const std::string& value);

        /**
         * @brief Add a user definition
         * @param key Definition key
         * @param value Definition value
         */
        void addDefinition(const std::string& key, const std::string& value);

        /**
         * @brief Get all user definitions
         * @return Map of key-value pairs
         */
        std::map<std::string, std::string> getDefinitions() const;

        /**
         * @brief Check if a flag is set
         * @param flag Flag to check
         * @return True if flag is set
         */
        bool hasFlag(const std::string& flag) const;

        /**
         * @brief Set a flag
         * @param flag Flag to set
         * @param value Flag value (true to set, false to unset)
         */
        void setFlag(const std::string& flag, bool value = true);

        /**
         * @brief Parse a hex value from a parameter
         * @param key Parameter key
         * @param defaultValue Default value if parameter not found or invalid
         * @return Parsed hex value or default
         */
        u16 getHexParameter(const std::string& key, u16 defaultValue = 0) const;

        /**
         * @brief Parse an integer value from a parameter
         * @param key Parameter key
         * @param defaultValue Default value if parameter not found or invalid
         * @return Parsed integer value or default
         */
        int getIntParameter(const std::string& key, int defaultValue = 0) const;

        /**
         * @brief Get a boolean value from a parameter
         * @param key Parameter key
         * @param defaultValue Default value if parameter not found
         * @return Boolean value or default
         */
        bool getBoolParameter(const std::string& key, bool defaultValue = false) const;

    private:
        Type type_;                               ///< Command type
        std::string inputFile_;                   ///< Input file path
        std::string outputFile_;                  ///< Output file path
        std::map<std::string, std::string> params_; ///< Command parameters
        std::vector<std::string> flags_;          ///< Command flags

    };

} // namespace sidwinder