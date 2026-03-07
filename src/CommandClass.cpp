// CommandClass.cpp
#include "CommandClass.h"
#include "SIDwinderUtils.h"
#include <algorithm>

namespace sidwinder {

    CommandClass::CommandClass(Type type)
        : type_(type) {
    }

    std::string CommandClass::getParameter(const std::string& key, const std::string& defaultValue) const {
        auto it = params_.find(key);
        if (it != params_.end()) {
            return it->second;
        }
        return defaultValue;
    }

    bool CommandClass::hasParameter(const std::string& key) const {
        return params_.find(key) != params_.end();
    }

    void CommandClass::setParameter(const std::string& key, const std::string& value) {
        params_[key] = value;
    }

    /**
     * @brief Add a user definition
     * @param key Definition key
     * @param value Definition value
     */
    void CommandClass::addDefinition(const std::string& key, const std::string& value) {
        if (!params_.count("definitions")) {
            params_["definitions"] = "";
        }
        if (!params_["definitions"].empty()) {
            params_["definitions"] += "|";  // Use | as separator
        }
        params_["definitions"] += key + "=" + value;
    }

    /**
     * @brief Get all user definitions
     * @return Map of key-value pairs
     */
    std::map<std::string, std::string> CommandClass::getDefinitions() const {
        std::map<std::string, std::string> defs;
        auto defsStr = getParameter("definitions", "");
        if (!defsStr.empty()) {
            size_t pos = 0;
            while (pos < defsStr.length()) {
                size_t pipePos = defsStr.find('|', pos);
                if (pipePos == std::string::npos) pipePos = defsStr.length();

                std::string def = defsStr.substr(pos, pipePos - pos);
                size_t eqPos = def.find('=');
                if (eqPos != std::string::npos) {
                    defs[def.substr(0, eqPos)] = def.substr(eqPos + 1);
                }
                pos = pipePos + 1;
            }
        }
        return defs;
    }

    bool CommandClass::hasFlag(const std::string& flag) const {
        return std::find(flags_.begin(), flags_.end(), flag) != flags_.end();
    }

    void CommandClass::setFlag(const std::string& flag, bool value) {
        auto it = std::find(flags_.begin(), flags_.end(), flag);
        if (value) {
            if (it == flags_.end()) {
                flags_.push_back(flag);
            }
        }
        else {
            if (it != flags_.end()) {
                flags_.erase(it);
            }
        }
    }

    u16 CommandClass::getHexParameter(const std::string& key, u16 defaultValue) const {
        auto value = getParameter(key);
        if (value.empty()) {
            return defaultValue;
        }

        auto result = util::parseHex(value);
        return result.value_or(defaultValue);
    }

    int CommandClass::getIntParameter(const std::string& key, int defaultValue) const {
        auto value = getParameter(key);
        if (value.empty()) {
            return defaultValue;
        }

        try {
            return std::stoi(value);
        }
        catch (const std::exception&) {
            return defaultValue;
        }
    }

    bool CommandClass::getBoolParameter(const std::string& key, bool defaultValue) const {
        auto value = getParameter(key);
        if (value.empty()) {
            return defaultValue;
        }

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

} // namespace sidwinder