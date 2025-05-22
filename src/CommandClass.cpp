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