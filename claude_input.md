### FILE: src/CodeFormatter.cpp
```cpp
#include "CodeFormatter.h"
#include "cpu6510.h"
#include "DisassemblyWriter.h"
#include "MemoryConstants.h"
#include <algorithm>
#include <sstream>
namespace sidwinder {
    CodeFormatter::CodeFormatter(
        const CPU6510& cpu,
        const LabelGenerator& labelGenerator,
        std::span<const u8> memory)
        : cpu_(cpu),
        labelGenerator_(labelGenerator),
        memory_(memory),
        removeCIAWrites_(false) {
    }
    std::string CodeFormatter::formatInstruction(u16& pc) const {
        std::ostringstream line;
        const u8 opcode = memory_[pc];
        const std::string mnemonic = std::string(cpu_.getMnemonic(opcode));
        const auto mode = cpu_.getAddressingMode(opcode);
        const int size = cpu_.getInstructionSize(opcode);
        const u16 startPC = pc;
        if (removeCIAWrites_ && static_cast<int>(mode) == static_cast<int>(AddressingMode::Absolute)) {
            const u16 absAddr = memory_[pc + 1] | (memory_[pc + 2] << 8);
            if (isCIAStorePatch(opcode, static_cast<int>(mode), absAddr, mnemonic)) {
                std::ostringstream patched;
                patched << "    bit $abcd   
                    << util::wordToHex(absAddr) << " (CIA Timer)";
                pc += size;
                return patched.str();
            }
        }
        line << "    " << mnemonic;
        if (size > 1) {
            line << " " << formatOperand(pc, static_cast<int>(mode));
        }
        pc += size;
        u16 endPC = startPC + size - 1;
        std::string lineStr = line.str();
        int padding = std::max(0, 97 - static_cast<int>(lineStr.length())); 
        return lineStr + std::string(padding, ' ') + "
            util::wordToHex(startPC) + " - " +
            util::wordToHex(endPC);
    }
    void CodeFormatter::formatDataBytes(
        std::ostream& file,
        u16& pc,
        std::span<const u8> originalMemory,
        u16 originalBase,
        u16 endAddress,
        const std::map<u16, RelocationEntry>& relocationBytes,
        std::span<const MemoryType> memoryTags) const {
        const int commentColumn = 97; 
        while (pc < endAddress && (memoryTags[pc] & MemoryType::Data)) {
            const std::string label = labelGenerator_.getLabel(pc);
            if (!label.empty()) {
                file << label << ":\n";
            }
            auto relocIt = relocationBytes.find(pc);
            if (relocIt != relocationBytes.end()) {
                const u16 target = relocIt->second.targetAddress;
                const std::string targetLabel = labelGenerator_.formatAddress(target);
                const u16 startPC = pc;
                const u16 endPC = pc; 
                std::ostringstream lineSS;
                lineSS << "    .byte ";
                if (relocIt->second.type == RelocationEntry::Type::Low) {
                    lineSS << "<(" << targetLabel << ")";
                }
                else {
                    lineSS << ">(" << targetLabel << ")";
                }
                std::string line = lineSS.str();
                file << line;
                int padding = std::max(0, commentColumn - static_cast<int>(line.length()));
                file << std::string(padding, ' ') << "
                    << util::wordToHex(startPC) << " - "
                    << util::wordToHex(endPC) << "\n";
                ++pc;
                continue;
            }
            u16 lineStartPC = pc; 
            std::ostringstream lineSS;
            lineSS << "    .byte ";
            int count = 0;
            while (pc < endAddress && (memoryTags[pc] & MemoryType::Data)) {
                if (relocationBytes.count(pc)) {
                    break;
                }
                if (count > 0) {
                    lineSS << ", ";
                }
                u8 byte;
                if (pc - originalBase < originalMemory.size()) {
                    byte = originalMemory[pc - originalBase];
                }
                else {
                    byte = memory_[pc];
                }
                bool isUnused = !(memoryTags[pc] & (MemoryType::Accessed | MemoryType::LabelTarget));
                if (isUnused) {
                    byte = 0;  
                }
                lineSS << "$" << util::byteToHex(byte);
                ++pc;
                ++count;
                if ((memoryTags[pc] & MemoryType::Code) || !labelGenerator_.getLabel(pc).empty()) {
                    break;
                }
                if (count == 16) {
                    std::string line = lineSS.str();
                    const u16 lineEndPC = pc - 1; 
                    file << line;
                    int padding = std::max(0, commentColumn - static_cast<int>(line.length()));
                    file << std::string(padding, ' ') << "
                        << util::wordToHex(lineStartPC) << " - "
                        << util::wordToHex(lineEndPC) << "\n";
                    if (pc < endAddress && (memoryTags[pc] & MemoryType::Data)) {
                        lineSS.str("");  
                        lineSS << "    .byte ";
                        count = 0;
                    }
                    lineStartPC = pc;
                }
            }
            if (count > 0) {
                const u16 lineEndPC = pc - 1; 
                std::string line = lineSS.str();
                file << line;
                int padding = std::max(0, commentColumn - static_cast<int>(line.length()));
                file << std::string(padding, ' ') << "
                    << util::wordToHex(lineStartPC) << " - "
                    << util::wordToHex(lineEndPC) << "\n";
            }
        }
    }
    bool CodeFormatter::isCIAStorePatch(
        u8 opcode,
        int mode,
        u16 operand,
        std::string_view mnemonic) const {
        if (mode != static_cast<int>(AddressingMode::Absolute)) {
            return false;
        }
        if (operand != MemoryConstants::CIA1_TIMER_LO && operand != MemoryConstants::CIA1_TIMER_HI) {
            return false;
        }
        return mnemonic == "sta" || mnemonic == "stx" || mnemonic == "sty";
    }
    std::string CodeFormatter::formatOperand(u16 pc, int mode) const {
        const auto addressingMode = static_cast<AddressingMode>(mode);
        switch (addressingMode) {
        case AddressingMode::Immediate: {
            return "#$" + util::byteToHex(memory_[pc + 1]);
        }
        case AddressingMode::ZeroPage: {
            const u8 zp = memory_[pc + 1];
            return labelGenerator_.formatZeroPage(zp);
        }
        case AddressingMode::ZeroPageX: {
            const u8 zp = memory_[pc + 1];
            const std::string baseAddr = labelGenerator_.formatZeroPage(zp);
            return baseAddr + ",X";
        }
        case AddressingMode::ZeroPageY: {
            const u8 zp = memory_[pc + 1];
            const std::string baseAddr = labelGenerator_.formatZeroPage(zp);
            return baseAddr + ",Y";
        }
        case AddressingMode::IndirectX: {
            const u8 zp = memory_[pc + 1];
            const std::string baseAddr = labelGenerator_.formatZeroPage(zp);
            return "(" + baseAddr + ",X)";
        }
        case AddressingMode::IndirectY: {
            const u8 zp = memory_[pc + 1];
            const std::string baseAddr = labelGenerator_.formatZeroPage(zp);
            return "(" + baseAddr + "),Y";
        }
        case AddressingMode::Absolute: {
            const u16 accessAddr = memory_[pc + 1] | (memory_[pc + 2] << 8);
            return labelGenerator_.formatAddress(accessAddr);
        }
        case AddressingMode::AbsoluteX: {
            const u16 baseAddr = memory_[pc + 1] | (memory_[pc + 2] << 8);
            const auto [minIndex, maxIndex] = cpu_.getIndexRange(pc + 1);
            return formatIndexedAddressWithMinOffset(baseAddr, minIndex, 'X');
        }
        case AddressingMode::AbsoluteY: {
            const u16 baseAddr = memory_[pc + 1] | (memory_[pc + 2] << 8);
            const auto [minIndex, maxIndex] = cpu_.getIndexRange(pc + 1);
            return formatIndexedAddressWithMinOffset(baseAddr, minIndex, 'Y');
        }
        case AddressingMode::Indirect: {
            const u16 accessAddr = memory_[pc + 1] | (memory_[pc + 2] << 8);
            return "($" + util::wordToHex(accessAddr) + ")";
        }
        case AddressingMode::Relative: {
            const i8 offset = static_cast<i8>(memory_[pc + 1]);
            const u16 dest = pc + 2 + offset;
            return labelGenerator_.formatAddress(dest);
        }
        default:
            return "";
        }
    }
    std::string CodeFormatter::formatIndexedAddressWithMinOffset(
        u16 baseAddr,
        u8 minOffset,
        char indexReg) const {
        const u16 targetAddr = baseAddr + minOffset;
        const std::string label = labelGenerator_.getLabel(targetAddr);
        if (!label.empty()) {
            if (minOffset == 0) {
                return label + "," + indexReg;
            }
            else {
                return label + "-" + std::to_string(minOffset) + "," + indexReg;
            }
        }
        return labelGenerator_.formatAddress(baseAddr) + "," + indexReg;
    }
    void CodeFormatter::setCIAWriteRemoval(bool removeCIAWrites) const
    {
        removeCIAWrites_ = removeCIAWrites;
    }
}
```


### FILE: src/CommandClass.cpp
```cpp
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
    void CommandClass::addDefinition(const std::string& key, const std::string& value) {
        if (!params_.count("definitions")) {
            params_["definitions"] = "";
        }
        if (!params_["definitions"].empty()) {
            params_["definitions"] += "|";  
        }
        params_["definitions"] += key + "=" + value;
    }
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
}
```


### FILE: src/CommandLineParser.cpp
```cpp
#include "CommandLineParser.h"
#include "SIDwinderUtils.h"
#include <algorithm>
#include <iostream>
#include <sstream>
#include <set>
namespace sidwinder {
    CommandLineParser::CommandLineParser(int argc, char** argv) {
        if (argc > 0) {
            programName_ = std::filesystem::path(argv[0]).filename().string();
        }
        for (int i = 1; i < argc; ++i) {
            args_.push_back(argv[i]);
        }
    }
    CommandClass CommandLineParser::parse() const {
        CommandClass cmd;
        std::vector<std::string> positionalArgs;
        size_t i = 0;
        while (i < args_.size()) {
            std::string arg = args_[i++];
            if (arg.empty()) {
                continue;
            }
            if (arg[0] == '-') {
                std::string option = arg.substr(1);  
                size_t equalPos = option.find('=');
                if (equalPos != std::string::npos) {
                    std::string name = option.substr(0, equalPos);
                    std::string value = option.substr(equalPos + 1);
                    if (name == "player") {
                        cmd.setType(CommandClass::Type::Player);
                        cmd.setParameter("playerName", value);
                    }
                    else if (name == "relocate") {
                        cmd.setType(CommandClass::Type::Relocate);
                        cmd.setParameter("relocateaddr", value);
                    }
                    else if (name == "trace") {
                        cmd.setType(CommandClass::Type::Trace);
                        cmd.setParameter("tracelog", value);
                        std::string ext = getFileExtension(value);
                        if (ext == ".txt" || ext == ".log") {
                            cmd.setParameter("traceformat", "text");
                        }
                        else {
                            cmd.setParameter("traceformat", "binary");
                        }
                    }
                    else if (name == "log") {
                        cmd.setParameter("logfile", value);
                    }
                    else {
                        cmd.setParameter(name, value);
                    }
                }
                else {
                    if (option == "player") {
                        cmd.setType(CommandClass::Type::Player);
                    }
                    else if (option == "relocate") {
                        cmd.setType(CommandClass::Type::Relocate);
                    }
                    else if (option == "disassemble") {
                        cmd.setType(CommandClass::Type::Disassemble);
                    }
                    else if (option == "trace") {
                        cmd.setType(CommandClass::Type::Trace);
                        cmd.setParameter("tracelog", "trace.bin");
                        cmd.setParameter("traceformat", "binary");
                    }
                    else if (option == "help" || option == "h") {
                        cmd.setType(CommandClass::Type::Help);
                    }
                    else if (option == "log" && i < args_.size() && args_[i][0] != '-') {
                        cmd.setParameter("logfile", args_[i++]);
                    }
                    else {
                        if (i < args_.size() && args_[i][0] != '-') {
                            static const std::set<std::string> valueOptions = {
                                "kickass", "input", "title", "author", "copyright",
                                "sidloadaddr", "sidinitaddr", "sidplayaddr", "playeraddr",
                                "exomizer", "define"  
                            };
                            if (valueOptions.find(option) != valueOptions.end()) {
                                if (option == "define") {
                                    std::string defValue = args_[i++];
                                    size_t eqPos = defValue.find('=');
                                    if (eqPos != std::string::npos) {
                                        std::string key = defValue.substr(0, eqPos);
                                        std::string value = defValue.substr(eqPos + 1);
                                        if (value.length() >= 2) {
                                            if ((value.front() == '"' && value.back() == '"') ||
                                                (value.front() == '\'' && value.back() == '\'')) {
                                                value = value.substr(1, value.length() - 2);
                                            }
                                        }
                                        cmd.addDefinition(key, value);
                                    }
                                    else {
                                        cmd.addDefinition(defValue, "true");
                                    }
                                }
                                else {
                                    cmd.setParameter(option, args_[i++]);
                                }
                            }
                            else {
                                cmd.setFlag(option);
                            }
                        }
                        else {
                            cmd.setFlag(option);
                        }
                    }
                }
            }
            else {
                positionalArgs.push_back(arg);
            }
        }
        if (!positionalArgs.empty()) {
            cmd.setInputFile(positionalArgs[0]);
        }
        if (positionalArgs.size() >= 2) {
            cmd.setOutputFile(positionalArgs[1]);
        }
        if (cmd.getType() == CommandClass::Type::Unknown) {
            cmd.setType(CommandClass::Type::Help);
        }
        return cmd;
    }
    const std::string& CommandLineParser::getProgramName() const {
        return programName_;
    }
    void CommandLineParser::printUsage(const std::string& message) const {
        if (!message.empty()) {
            std::cout << message << std::endl << std::endl;
        }
        std::cout << "SIDwinder - C64 SID Music Utility" << std::endl;
        std::cout << "Developed by: Robert Troughton (Raistlin of Genesis Project)" << std::endl;
        std::cout << std::endl;
        std::cout << "USAGE:" << std::endl;
        std::cout << "  " << programName_ << " -relocate=<address> inputfile.sid outputfile.sid" << std::endl;
        std::cout << "  " << programName_ << " -trace[=<file>] inputfile.sid" << std::endl;
        std::cout << "  " << programName_ << " -player[=<type>] inputfile.sid outputfile.prg" << std::endl;
        std::cout << "  " << programName_ << " -disassemble inputfile.sid outputfile.asm" << std::endl;
        std::cout << "  " << programName_ << " -help" << std::endl;
        std::cout << std::endl;
        std::cout << "COMMANDS:" << std::endl;
        std::cout << "  -relocate=<address>    Relocate a SID file to a new memory address" << std::endl;
        std::cout << "  -trace[=<file>]        Trace SID register writes during emulation" << std::endl;
        std::cout << "  -player[=<type>]       Link SID music with a player to create executable PRG" << std::endl;
        std::cout << "  -disassemble           Disassemble a SID file to assembly code" << std::endl;
        std::cout << "  -help                  Display this help information" << std::endl;
        std::cout << std::endl;
        std::cout << "PLAYER OPTIONS:" << std::endl;
        std::cout << "  -player                Use the default player (SimpleRaster)" << std::endl;
        std::cout << "  -player=<type>         Specify player type, e.g.: -player=SimpleBitmap or -player=RaistlinBars" << std::endl;
        std::cout << "  -playeraddr=<address>  Player load address (default: $4000)" << std::endl;
        std::cout << std::endl;
        std::cout << "TRACE OPTIONS:" << std::endl;
        std::cout << "  -trace                 Output trace to trace.bin in binary format" << std::endl;
        std::cout << "  -trace=<file>          Specify trace output file" << std::endl;
        std::cout << "                         .bin extension = binary format" << std::endl;
        std::cout << "                         .txt/.log extension = text format" << std::endl;
        std::cout << std::endl;
        std::cout << "GENERAL OPTIONS:" << std::endl;
        std::cout << "  -verbose               Enable verbose logging" << std::endl;
        std::cout << "  -force                 Force overwrite of output file" << std::endl;
        std::cout << "  -log=<file>            Log file path (default: SIDwinder.log)" << std::endl;
        std::cout << "  -kickass=<path>        Path to KickAss.jar assembler" << std::endl;
        std::cout << std::endl;
        std::cout << "EXAMPLES:" << std::endl;
        std::cout << "  " << programName_ << " -relocate=$2000 music.sid relocated.sid" << std::endl;
        std::cout << "    Relocates music.sid to address $2000 and saves as relocated.sid" << std::endl;
        std::cout << std::endl;
        std::cout << "  " << programName_ << " -trace music.sid" << std::endl;
        std::cout << "    Traces SID register writes to trace.bin in binary format" << std::endl;
        std::cout << std::endl;
        std::cout << "  " << programName_ << " -trace=music.log music.sid" << std::endl;
        std::cout << "    Traces SID register writes to music.log in text format" << std::endl;
        std::cout << std::endl;
        std::cout << "  " << programName_ << " -player music.sid music.prg" << std::endl;
        std::cout << "    Links music.sid with default player to create executable music.prg" << std::endl;
        std::cout << std::endl;
        std::cout << "  " << programName_ << " -player=SimpleBitmap music.sid player.prg" << std::endl;
        std::cout << "    Links music.sid with SimpleBitmap player" << std::endl;
        std::cout << std::endl;
        std::cout << "  " << programName_ << " -disassemble music.sid music.asm" << std::endl;
        std::cout << "    Disassembles music.sid to assembly code in music.asm" << std::endl;
        std::cout << std::endl;
    }
    CommandLineParser& CommandLineParser::addFlagDefinition(
        const std::string& flag,
        const std::string& description,
        const std::string& category) {
        flagDefs_[flag] = { description, category };
        return *this;
    }
    CommandLineParser& CommandLineParser::addOptionDefinition(
        const std::string& option,
        const std::string& argName,
        const std::string& description,
        const std::string& category,
        const std::string& defaultValue) {
        optionDefs_[option] = { argName, description, category, defaultValue };
        return *this;
    }
    CommandLineParser& CommandLineParser::addExample(
        const std::string& example,
        const std::string& description) {
        examples_.push_back({ example, description });
        return *this;
    }
}
```


### FILE: src/Common.cpp
```cpp
#include "Common.h"
#include <algorithm>
std::string getFileExtension(const fs::path& filePath) {
    std::string ext = filePath.extension().string();
    std::transform(ext.begin(), ext.end(), ext.begin(),
        [](unsigned char c) { return std::tolower(c); });
    return ext;
}
```


### FILE: src/ConfigManager.cpp
```cpp
#include "ConfigManager.h"
#include <algorithm>
#include <cctype>
#include <fstream>
#include <iostream>
#include <sstream>
#include <vector>
namespace sidwinder {
    namespace util {
        std::map<std::string, std::string> ConfigManager::configValues_;
        std::filesystem::path ConfigManager::configFile_;
        bool ConfigManager::initialize(const std::filesystem::path& configFile) {
            configFile_ = configFile;
            setupDefaults();
            bool fileExists = std::filesystem::exists(configFile);
            if (fileExists) {
                loadFromFile(configFile);
            }
            saveToFile(configFile);
            return true;
        }
        void ConfigManager::setupDefaults() {
            configValues_["kickassPath"] = "java -jar KickAss.jar -silentMode";
            configValues_["exomizerPath"] = "Exomizer.exe";
            configValues_["compressorType"] = "exomizer";
            configValues_["pucrunchPath"] = "pucrunch";
            configValues_["defaultSidLoadAddress"] = "$1000";
            configValues_["defaultSidInitAddress"] = "$1000";
            configValues_["defaultSidPlayAddress"] = "$1003";
            configValues_["playerName"] = "SimpleRaster";
            configValues_["playerAddress"] = "$4000";
            configValues_["playerDirectory"] = "SIDPlayers";
            configValues_["defaultPlayCallsPerFrame"] = "1";
            configValues_["emulationFrames"] = "30000";
            configValues_["clockStandard"] = "PAL";  
            configValues_["logFile"] = "SIDwinder.log";
            configValues_["logLevel"] = "3";
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
                if (line.empty() || line[0] == '#' || line[0] == ';') {
                    continue;
                }
                const auto pos = line.find('=');
                if (pos == std::string::npos) {
                    continue;
                }
                std::string key = line.substr(0, pos);
                std::string value = line.substr(pos + 1);
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
            file << generateFormattedConfig();
            return file.good();
        }
        std::string ConfigManager::generateFormattedConfig() {
            std::stringstream ss;
            ss << "# SIDwinder Configuration File\n";
            ss << "# -----------------------\n";
            ss << "# This file contains settings for the SIDwinder tool\n";
            ss << "# Edit this file to customize your installation paths and default settings\n\n";
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
            ss << "# SID Default Settings\n";
            ss << "# -------------------\n";
            ss << "# Default load address for SID files ($XXXX format)\n";
            ss << "defaultSidLoadAddress=" << configValues_["defaultSidLoadAddress"] << "\n\n";
            ss << "# Default init address for SID files\n";
            ss << "defaultSidInitAddress=" << configValues_["defaultSidInitAddress"] << "\n\n";
            ss << "# Default play address for SID files\n";
            ss << "defaultSidPlayAddress=" << configValues_["defaultSidPlayAddress"] << "\n\n";
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
            ss << "# Emulation Settings\n";
            ss << "# ----------------\n";
            ss << "# Number of frames to emulate for analysis and tracing\n";
            ss << "emulationFrames=" << configValues_["emulationFrames"] << "\n\n";
            ss << "# Clock standard (PAL or NTSC)\n";
            ss << "clockStandard=" << configValues_["clockStandard"] << "\n\n";
            ss << "# Logging Settings\n";
            ss << "# ---------------\n";
            ss << "# Default log file\n";
            ss << "logFile=" << configValues_["logFile"] << "\n\n";
            ss << "# Default log level (1=Error, 2=Warning, 3=Info, 4=Debug)\n";
            ss << "logLevel=" << configValues_["logLevel"] << "\n\n";
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
            auto it = configValues_.find(key);
            if (it == configValues_.end() || it->second != value) {
                configValues_[key] = value;
                if (saveToFile) {
                    ConfigManager::saveToFile(configFile_);
                }
            }
        }
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
            if (!addrStr.empty() && addrStr[0] == '$') {
                try {
                    return static_cast<u16>(std::stoul(addrStr.substr(1), nullptr, 16));
                }
                catch (const std::exception&) {
                }
            }
            return 0x4000; 
        }
        u16 ConfigManager::getDefaultSidLoadAddress() {
            std::string addrStr = getString("defaultSidLoadAddress", "$1000");
            if (!addrStr.empty() && addrStr[0] == '$') {
                try {
                    return static_cast<u16>(std::stoul(addrStr.substr(1), nullptr, 16));
                }
                catch (const std::exception&) {
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
                }
            }
            return 0x1003;
        }
        std::string ConfigManager::getClockStandard() {
            std::string clockStr = getString("clockStandard", "PAL");
            std::transform(clockStr.begin(), clockStr.end(), clockStr.begin(), ::toupper);
            if (clockStr != "PAL" && clockStr != "NTSC") {
                clockStr = "PAL";
            }
            return clockStr;
        }
        double ConfigManager::getCyclesPerFrame() {
            std::string clockStandard = getClockStandard();
            if (clockStandard == "NTSC") {
                return 65.0 * 263.0;
            }
            else {
                return 63.0 * 312.0;
            }
        }
    } 
}
```


### FILE: src/cpu6510.cpp
```cpp
#include "cpu6510.h"
#include "6510/CPU6510Impl.h"
CPU6510::CPU6510() : pImpl_(std::make_unique<CPU6510Impl>()) {
}
CPU6510::~CPU6510() = default;
void CPU6510::reset() {
    pImpl_->reset();
}
void CPU6510::resetRegistersAndFlags() {
    pImpl_->resetRegistersAndFlags();
}
void CPU6510::step() {
    pImpl_->step();
}
bool CPU6510::executeFunction(u32 address) {
    return pImpl_->executeFunction(address);
}
void CPU6510::jumpTo(u32 address) {
    pImpl_->jumpTo(address);
}
u8 CPU6510::readMemory(u32 addr) {
    return pImpl_->readMemory(addr);
}
void CPU6510::writeByte(u32 addr, u8 value) {
    pImpl_->writeByte(addr, value);
}
void CPU6510::writeMemory(u32 addr, u8 value) {
    pImpl_->writeMemory(addr, value);
}
void CPU6510::copyMemoryBlock(u32 start, std::span<const u8> data) {
    pImpl_->copyMemoryBlock(start, data);
}
void CPU6510::loadData(const std::string& filename, u32 loadAddress) {
    pImpl_->loadData(filename, loadAddress);
}
void CPU6510::setPC(u32 address) {
    pImpl_->setPC(address);
}
u32 CPU6510::getPC() const {
    return pImpl_->getPC();
}
void CPU6510::setSP(u8 sp) {
    pImpl_->setSP(sp);
}
u8 CPU6510::getSP() const {
    return pImpl_->getSP();
}
u64 CPU6510::getCycles() const {
    return pImpl_->getCycles();
}
void CPU6510::setCycles(u64 newCycles) {
    pImpl_->setCycles(newCycles);
}
void CPU6510::resetCycles() {
    pImpl_->resetCycles();
}
std::string_view CPU6510::getMnemonic(u8 opcode) const {
    return pImpl_->getMnemonic(opcode);
}
u8 CPU6510::getInstructionSize(u8 opcode) const {
    return pImpl_->getInstructionSize(opcode);
}
AddressingMode CPU6510::getAddressingMode(u8 opcode) const {
    return pImpl_->getAddressingMode(opcode);
}
bool CPU6510::isIllegalInstruction(u8 opcode) const {
    return pImpl_->isIllegalInstruction(opcode);
}
void CPU6510::dumpMemoryAccess(const std::string& filename) {
    pImpl_->dumpMemoryAccess(filename);
}
std::pair<u8, u8> CPU6510::getIndexRange(u32 pc) const {
    return pImpl_->getIndexRange(pc);
}
std::span<const u8> CPU6510::getMemory() const {
    return pImpl_->getMemory();
}
std::span<const u8> CPU6510::getMemoryAccess() const {
    return pImpl_->getMemoryAccess();
}
u32 CPU6510::getLastWriteTo(u32 addr) const {
    return pImpl_->getLastWriteTo(addr);
}
const std::vector<u32>& CPU6510::getLastWriteToAddr() const {
    return pImpl_->getLastWriteToAddr();
}
RegisterSourceInfo CPU6510::getRegSourceA() const {
    return pImpl_->getRegSourceA();
}
RegisterSourceInfo CPU6510::getRegSourceX() const {
    return pImpl_->getRegSourceX();
}
RegisterSourceInfo CPU6510::getRegSourceY() const {
    return pImpl_->getRegSourceY();
}
RegisterSourceInfo CPU6510::getWriteSourceInfo(u32 addr) const {
    return pImpl_->getWriteSourceInfo(addr);
}
void CPU6510::setOnIndirectReadCallback(IndirectReadCallback callback) {
    pImpl_->setOnIndirectReadCallback(std::move(callback));
}
void CPU6510::setOnWriteMemoryCallback(MemoryWriteCallback callback) {
    pImpl_->setOnWriteMemoryCallback(std::move(callback));
}
void CPU6510::setOnCIAWriteCallback(MemoryWriteCallback callback) {
    pImpl_->setOnCIAWriteCallback(std::move(callback));
}
void CPU6510::setOnSIDWriteCallback(MemoryWriteCallback callback) {
    pImpl_->setOnSIDWriteCallback(std::move(callback));
}
void CPU6510::setOnVICWriteCallback(MemoryWriteCallback callback) {
    pImpl_->setOnVICWriteCallback(std::move(callback));
}
void CPU6510::setOnMemoryFlowCallback(MemoryFlowCallback callback) {
    pImpl_->setOnMemoryFlowCallback(std::move(callback));
}
const MemoryDataFlow& CPU6510::getMemoryDataFlow() const {
    return pImpl_->getMemoryDataFlow();
}
```


### FILE: src/Disassembler.cpp
```cpp
﻿
#include "Disassembler.h"
#include "CodeFormatter.h"
#include "DisassemblyWriter.h"
#include "LabelGenerator.h"
#include "MemoryAnalyzer.h"
#include "SIDLoader.h"
#include "cpu6510.h"
namespace sidwinder {
    Disassembler::Disassembler(const CPU6510& cpu, const SIDLoader& sid)
        : cpu_(cpu),
        sid_(sid) {
        initialize();
    }
    Disassembler::~Disassembler() {
        const_cast<CPU6510&>(cpu_).setOnMemoryFlowCallback(nullptr);
        const_cast<CPU6510&>(cpu_).setOnWriteMemoryCallback(nullptr);
        const_cast<CPU6510&>(cpu_).setOnIndirectReadCallback(nullptr);
    }
    void Disassembler::initialize() {
        analyzer_ = std::make_unique<MemoryAnalyzer>(
            cpu_.getMemory(),
            cpu_.getMemoryAccess(),
            sid_.getLoadAddress(),
            sid_.getLoadAddress() + sid_.getDataSize()
        );
        labelGenerator_ = std::make_unique<LabelGenerator>(
            *analyzer_,
            sid_.getLoadAddress(),
            sid_.getLoadAddress() + sid_.getDataSize(),
            cpu_.getMemory()
        );
        formatter_ = std::make_unique<CodeFormatter>(
            cpu_,
            *labelGenerator_,
            cpu_.getMemory()
        );
        writer_ = std::make_unique<DisassemblyWriter>(
            cpu_,
            sid_,
            *analyzer_,
            *labelGenerator_,
            *formatter_
        );
        const_cast<CPU6510&>(cpu_).setOnIndirectReadCallback([this](u16 pc, u8 zpAddr, u16 targetAddr) {
            if (writer_) {
                writer_->addIndirectAccess(pc, zpAddr, targetAddr);
            }
            });
        const_cast<CPU6510&>(cpu_).setOnMemoryFlowCallback(
            [this](u16 pc, char reg, u16 sourceAddr, u8 value, bool isIndexed) {
                if (writer_) {
                    writer_->onMemoryFlow(pc, reg, sourceAddr, value, isIndexed);
                }
            }
        );
        const_cast<CPU6510&>(cpu_).setOnWriteMemoryCallback([this](u16 addr, u8 value) {
            if (writer_) {
                RegisterSourceInfo sourceInfo = cpu_.getWriteSourceInfo(addr);
                DisassemblyWriter::WriteRecord record = { addr, value, sourceInfo };
                writer_->allWrites_.push_back(record);
            }
            });
    }
    void Disassembler::generateAsmFile(
        const std::string& outputPath,
        u16 sidLoad,
        u16 sidInit,
        u16 sidPlay,
        bool removeCIAWrites) {
        if (!analyzer_ || !labelGenerator_ || !formatter_ || !writer_) {
            util::Logger::error("Disassembler not properly initialized");
            return;
        }
        analyzer_->analyzeExecution();
        analyzer_->analyzeAccesses();
        analyzer_->analyzeData();
        writer_->analyzeWritesForSelfModification();
        writer_->processIndirectAccesses();
        labelGenerator_->generateLabels();
        labelGenerator_->applySubdivisions();
        writer_->generateAsmFile(outputPath, sidLoad, sidInit, sidPlay, removeCIAWrites);
    }
}
```


### FILE: src/DisassemblyWriter.cpp
```cpp
#include "DisassemblyWriter.h"
#include "SIDLoader.h"
#include "cpu6510.h"
#include "MemoryConstants.h"
#include <algorithm>
#include <iostream>
#include <queue>
#include <set>
#include <functional>
namespace sidwinder {
    DisassemblyWriter::DisassemblyWriter(
        const CPU6510& cpu,
        const SIDLoader& sid,
        const MemoryAnalyzer& analyzer,
        const LabelGenerator& labelGenerator,
        const CodeFormatter& formatter)
        : cpu_(cpu),
        sid_(sid),
        analyzer_(analyzer),
        labelGenerator_(labelGenerator),
        formatter_(formatter) {
    }
    void DisassemblyWriter::generateAsmFile(
        const std::string& filename,
        u16 sidLoad,
        u16 sidInit,
        u16 sidPlay,
        bool removeCIAWrites) {
        std::ofstream file(filename);
        if (!file) {
            util::Logger::error("Failed to open output file: " + filename);
            return;
        }
        file << "
        file << "
        file << "
        file << "
        file << "
        file << "
        file << "
        file << ".const SIDLoad = $" << util::wordToHex(sidLoad) << "\n";
        outputHardwareConstants(file);
        emitZPDefines(file);
        disassembleToFile(file, removeCIAWrites);
        file.close();
    }
    void DisassemblyWriter::addIndirectAccess(u16 pc, u8 zpAddr, u16 targetAddr) {
        const auto& lowSource = cpu_.getWriteSourceInfo(zpAddr);
        const auto& highSource = cpu_.getWriteSourceInfo(zpAddr + 1);
        IndirectAccessInfo* existingInfo = nullptr;
        for (auto& existing : indirectAccesses_) {
            if (existing.zpAddr == zpAddr &&
                existing.sourceLowAddress == lowSource.address &&
                existing.sourceHighAddress == highSource.address) {
                existingInfo = &existing;
                break;
            }
        }
        if (!existingInfo) {
            IndirectAccessInfo info;
            info.instructionAddress = pc;
            info.zpAddr = zpAddr;
            if (lowSource.type == RegisterSourceInfo::SourceType::Memory) {
                info.sourceLowAddress = lowSource.address;
            }
            if (highSource.type == RegisterSourceInfo::SourceType::Memory) {
                info.sourceHighAddress = highSource.address;
            }
            info.targetAddresses.push_back(targetAddr);
            indirectAccesses_.push_back(info);
        }
        else {
            if (std::find(existingInfo->targetAddresses.begin(),
                existingInfo->targetAddresses.end(),
                targetAddr) == existingInfo->targetAddresses.end()) {
                existingInfo->targetAddresses.push_back(targetAddr);
            }
        }
    }
    void DisassemblyWriter::processIndirectAccesses() {
        if (indirectAccesses_.empty() && selfModifyingPatterns_.empty()) {
            return;
        }
        const auto& dataFlow = cpu_.getMemoryDataFlow();
        relocTable_.clear();
        for (const auto& access : indirectAccesses_) {
            if (!access.targetAddresses.empty()) {
                u16 targetAddr = access.targetAddresses[0];
                if (access.sourceLowAddress != 0) {
                    relocTable_.addEntry(access.sourceLowAddress, targetAddr, RelocationEntry::Type::Low);
                    const_cast<LabelGenerator&>(labelGenerator_).addPendingSubdivisionAddress(access.sourceLowAddress);
                    processRelocationChain(dataFlow, relocTable_, access.sourceLowAddress, targetAddr, RelocationEntry::Type::Low);
                }
                if (access.sourceHighAddress != 0) {
                    relocTable_.addEntry(access.sourceHighAddress, targetAddr, RelocationEntry::Type::High);
                    const_cast<LabelGenerator&>(labelGenerator_).addPendingSubdivisionAddress(access.sourceHighAddress);
                    processRelocationChain(dataFlow, relocTable_, access.sourceHighAddress, targetAddr, RelocationEntry::Type::High);
                }
            }
        }
        for (const auto& [instrAddr, patterns] : selfModifyingPatterns_) {
            for (const auto& pattern : patterns) {
                if (pattern.hasLowByte && pattern.hasHighByte) {
                    u16 targetAddr = pattern.lowByte | (pattern.highByte << 8);
                    if (pattern.lowByteSource != 0) {
                        relocTable_.addEntry(pattern.lowByteSource, targetAddr, RelocationEntry::Type::Low);
                        const_cast<LabelGenerator&>(labelGenerator_).addPendingSubdivisionAddress(pattern.lowByteSource);
                        processRelocationChain(dataFlow, relocTable_, pattern.lowByteSource, targetAddr, RelocationEntry::Type::Low);
                    }
                    if (pattern.highByteSource != 0) {
                        relocTable_.addEntry(pattern.highByteSource, targetAddr, RelocationEntry::Type::High);
                        const_cast<LabelGenerator&>(labelGenerator_).addPendingSubdivisionAddress(pattern.highByteSource);
                        processRelocationChain(dataFlow, relocTable_, pattern.highByteSource, targetAddr, RelocationEntry::Type::High);
                    }
                }
            }
        }
    }
    void DisassemblyWriter::onMemoryFlow(u16 pc, char reg, u16 sourceAddr, u8 value, bool isIndexed) {
        registerSources_[reg] = { sourceAddr, value, isIndexed };
        const_cast<LabelGenerator&>(labelGenerator_).addPendingSubdivisionAddress(sourceAddr);
    }
    void DisassemblyWriter::processRelocationChain(
        const MemoryDataFlow& dataFlow,
        RelocationTable& relocTable,
        u16 addr,
        u16 targetAddr,
        RelocationEntry::Type relocType) {
        relocTable.addEntry(addr, targetAddr, relocType);
        const_cast<LabelGenerator&>(labelGenerator_).addPendingSubdivisionAddress(addr);
        auto it = dataFlow.memoryWriteSources.find(addr);
        if (it != dataFlow.memoryWriteSources.end()) {
            for (u16 newAddr : it->second) {
                if (newAddr != addr) {
                    processRelocationChain(dataFlow, relocTable, newAddr, targetAddr, relocType);
                }
            }
        }
    }
    void DisassemblyWriter::outputHardwareConstants(std::ofstream& file) {
        std::set<u16> sidBases;
        for (u16 addr = MemoryConstants::SID_START; addr <= MemoryConstants::SID_END; addr++) {
            if (analyzer_.getMemoryType(addr) & (MemoryType::Accessed)) {
                u16 base = addr & 0xFFE0; 
                sidBases.insert(base);
            }
        }
        if (sidBases.empty()) {
            sidBases.insert(MemoryConstants::SID_START);
        }
        int sidIndex = 0;
        for (u16 base : sidBases) {
            const std::string name = "SID" + std::to_string(sidIndex);
            const_cast<LabelGenerator&>(labelGenerator_).addHardwareBase(HardwareType::SID, base, sidIndex, name);
            file << ".const " << name << " = $" << util::wordToHex(MemoryConstants::SID_START + (sidIndex * MemoryConstants::SID_SIZE)) << "\n";
            sidIndex++;
        }
        file << "\n";
    }
    void DisassemblyWriter::emitZPDefines(std::ofstream& file) {
        std::set<u8> usedZP;
        for (u16 addr = 0x0000; addr <= 0x00FF; ++addr) {
            if (analyzer_.getMemoryType(addr) & MemoryType::Accessed) {
                usedZP.insert(static_cast<u8>(addr));
            }
        }
        if (usedZP.empty()) {
            return;
        }
        std::vector<u8> zpList(usedZP.begin(), usedZP.end());
        std::sort(zpList.begin(), zpList.end());
        u8 zpBase = 0xFF - static_cast<u8>(zpList.size()) + 1;
        file << ".const ZP_BASE = $" << util::byteToHex(zpBase) << "\n";
        for (size_t i = 0; i < zpList.size(); ++i) {
            std::string varName = "ZP_" + std::to_string(i);
            file << ".const " << varName << " = ZP_BASE + " << i << " 
            const_cast<LabelGenerator&>(labelGenerator_).addZeroPageVar(zpList[i], varName);
        }
        file << "\n";
    }
    void DisassemblyWriter::disassembleToFile(std::ofstream& file, bool removeCIAWrites) {
        formatter_.setCIAWriteRemoval(removeCIAWrites);
        u16 pc = sid_.getLoadAddress();
        file << "\n* = SIDLoad\n\n";
         const u16 sidEnd = sid_.getLoadAddress() + sid_.getDataSize();
        while (pc < sidEnd) {
            const std::string label = labelGenerator_.getLabel(pc);
            if (!label.empty() && (analyzer_.getMemoryType(pc) & MemoryType::Code)) {
                file << label << ":\n";
            }
            if (analyzer_.getMemoryType(pc) & MemoryType::Code) {
                const u16 startPc = pc;
                const std::string line = formatter_.formatInstruction(pc);
                file << util::padToColumn(line, 96);
                file << " 
                    << util::wordToHex(pc - 1) << "\n";
            }
            else if (analyzer_.getMemoryType(pc) & MemoryType::Data) {
                formatter_.formatDataBytes(
                    file,
                    pc,
                    sid_.getOriginalMemory(),
                    sid_.getOriginalMemoryBase(),
                    sidEnd,
                    relocTable_.getAllEntries(),
                    analyzer_.getMemoryTypes());
            }
            else {
                ++pc;
            }
        }
    }
    void DisassemblyWriter::analyzeWritesForSelfModification() {
        for (const auto& write : allWrites_) {
            if (analyzer_.getMemoryType(write.addr) & MemoryType::Code) {
                u16 instrStart = analyzer_.findInstructionStartCovering(write.addr);
                if (instrStart != write.addr) {
                    int offset = write.addr - instrStart;
                    auto& patterns = selfModifyingPatterns_[instrStart];
                    SelfModifyingPattern* currentPattern = nullptr;
                    for (auto& pattern : patterns) {
                        if (pattern.hasLowByte && !pattern.hasHighByte && offset == 2) {
                            currentPattern = &pattern;
                            break;
                        }
                        else if (!pattern.hasLowByte && pattern.hasHighByte && offset == 1) {
                            currentPattern = &pattern;
                            break;
                        }
                        else if (pattern.hasLowByte && pattern.hasHighByte) {
                            continue;
                        }
                    }
                    if (!currentPattern) {
                        patterns.push_back(SelfModifyingPattern{});
                        currentPattern = &patterns.back();
                    }
                    bool foundInRegister = false;
                    for (const auto& [reg, flow] : registerSources_) {
                        if (flow.value == write.value) {
                            if (write.sourceInfo.type == RegisterSourceInfo::SourceType::Memory ||
                                flow.isIndexed) {
                                if (offset == 1) {
                                    currentPattern->lowByteSource = flow.sourceAddr;
                                    currentPattern->lowByte = write.value;
                                    currentPattern->hasLowByte = true;
                                }
                                else if (offset == 2) {
                                    currentPattern->highByteSource = flow.sourceAddr;
                                    currentPattern->highByte = write.value;
                                    currentPattern->hasHighByte = true;
                                }
                                foundInRegister = true;
                                break;
                            }
                        }
                    }
                    if (!foundInRegister && write.sourceInfo.type == RegisterSourceInfo::SourceType::Memory) {
                        if (offset == 1) {
                            currentPattern->lowByteSource = write.sourceInfo.address;
                            currentPattern->lowByte = write.value;
                            currentPattern->hasLowByte = true;
                        }
                        else if (offset == 2) {
                            currentPattern->highByteSource = write.sourceInfo.address;
                            currentPattern->highByte = write.value;
                            currentPattern->hasHighByte = true;
                        }
                    }
                }
            }
        }
    }
}
```


### FILE: src/LabelGenerator.cpp
```cpp
#include "LabelGenerator.h"
#include "SIDwinderUtils.h"
#include "MemoryConstants.h"
#include <algorithm>
#include <sstream>
namespace sidwinder {
    namespace {
        constexpr int INSTRUCTION_SIZES[256] = {
            1, 2, 1, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3, 
            2, 2, 1, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3, 
            3, 2, 1, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3, 
            2, 2, 1, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3, 
            1, 2, 1, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3, 
            2, 2, 1, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3, 
            1, 2, 1, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3, 
            2, 2, 1, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3, 
            2, 2, 2, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3, 
            2, 2, 1, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3, 
            2, 2, 2, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3, 
            2, 2, 1, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3, 
            2, 2, 2, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3, 
            2, 2, 1, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3, 
            2, 2, 2, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3, 
            2, 2, 1, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3  
        };
        constexpr u8 MemoryAccess_OpCode = 1 << 4;
    }
    LabelGenerator::LabelGenerator(
        const MemoryAnalyzer& analyzer,
        u16 loadAddress,
        u16 endAddress,
        std::span<const u8> memory)
        : analyzer_(analyzer),
        loadAddress_(loadAddress),
        endAddress_(endAddress),
        memory_(memory) {
    }
    void LabelGenerator::generateLabels() {
        std::vector<u16> labelTargets = analyzer_.findLabelTargets();
        for (u16 targetAddr : labelTargets) {
            if (targetAddr >= loadAddress_ && targetAddr < endAddress_) {
                if (analyzer_.getMemoryType(targetAddr) & MemoryType::Code) {
                    bool foundMidInstruction = false;
                    for (int lookback = 1; lookback <= 2; ++lookback) {
                        if (targetAddr >= lookback) {
                            u16 possibleStart = targetAddr - lookback;
                            if ((analyzer_.getMemoryType(possibleStart) & MemoryType::Code) &&
                                isProbableOpcode(possibleStart)) {
                                u8 opcode = memory_[possibleStart];
                                int instrSize = getInstructionSize(opcode);
                                if (possibleStart + instrSize > targetAddr) {
                                    u16 offset = targetAddr - possibleStart;
                                    midInstructionLabels_[targetAddr] = { possibleStart, offset };
                                    if (labelMap_.find(possibleStart) == labelMap_.end()) {
                                        labelMap_[possibleStart] = "Label_" + std::to_string(codeLabelCounter_++);
                                    }
                                    foundMidInstruction = true;
                                    break; 
                                }
                            }
                        }
                    }
                    if (!foundMidInstruction) {
                        labelMap_[targetAddr] = "Label_" + std::to_string(codeLabelCounter_++);
                    }
                }
            }
        }
        std::vector<std::pair<u16, u16>> codeRanges = analyzer_.findCodeRanges();
        std::sort(codeRanges.begin(), codeRanges.end());
        u16 prevEnd = loadAddress_;
        for (const auto& [start, end] : codeRanges) {
            if (start > prevEnd) {
                std::string label = "DataBlock_" + std::to_string(dataLabelCounter_++);
                labelMap_[prevEnd] = label;
                dataBlocks_.push_back({ label, prevEnd, static_cast<u16>(start - 1) });
            }
            prevEnd = end + 1;
        }
        if (prevEnd < endAddress_) {
            std::string label = "DataBlock_" + std::to_string(dataLabelCounter_++);
            labelMap_[prevEnd] = label;
            dataBlocks_.push_back({ label, prevEnd, static_cast<u16>(endAddress_ - 1) });
        }
    }
    std::string LabelGenerator::getLabel(u16 addr) const {
        auto it = labelMap_.find(addr);
        return (it != labelMap_.end()) ? it->second : "";
    }
    const std::vector<DataBlock>& LabelGenerator::getDataBlocks() const {
        return dataBlocks_;
    }
    std::string LabelGenerator::formatAddress(u16 addr) const {
        if (MemoryConstants::isIO(addr)) {
            if (MemoryConstants::isSID(addr)) {
                u8 reg = MemoryConstants::getSIDRegister(addr);
                u16 base = MemoryConstants::getSIDBase(addr);
                for (const auto& hw : usedHardwareBases_) {
                    if (hw.type == HardwareType::SID && hw.address == base) {
                        if (reg == 0) {
                            return hw.name; 
                        }
                        else {
                            return hw.name + "+" + std::to_string(reg); 
                        }
                    }
                }
                return "SID0+" + std::to_string(reg);
            }
            return "$" + util::wordToHex(addr);
        }
        auto midIt = midInstructionLabels_.find(addr);
        if (midIt != midInstructionLabels_.end()) {
            u16 instrStart = midIt->second.first;
            u16 offset = midIt->second.second;
            auto labelIt = labelMap_.find(instrStart);
            if (labelIt != labelMap_.end()) {
                return labelIt->second + " + " + std::to_string(offset);
            }
        }
        auto it = labelMap_.find(addr);
        if (it != labelMap_.end()) {
            return it->second;
        }
        u16 bestBase = 0;
        std::string bestLabel;
        for (const auto& [labelAddr, label] : labelMap_) {
            if (labelAddr <= addr) {
                if (labelAddr > bestBase) {
                    bestBase = labelAddr;
                    bestLabel = label;
                }
            }
        }
        if (!bestLabel.empty()) {
            const u16 offset = addr - bestBase;
            if (offset == 0) {
                return bestLabel;
            }
            else {
                std::ostringstream oss;
                oss << bestLabel << " + $" << std::hex << std::uppercase << offset;
                return oss.str();
            }
        }
        for (const auto& block : dataBlocks_) {
            if (addr >= block.start && addr <= block.end) {
                u16 offset = addr - block.start;
                if (offset == 0) {
                    return block.label;
                }
                else {
                    std::ostringstream oss;
                    oss << block.label << " + $" << std::hex << std::uppercase << offset;
                    return oss.str();
                }
            }
        }
        return "$" + util::wordToHex(addr);
    }
    std::string LabelGenerator::formatZeroPage(u8 addr) const {
        auto it = zeroPageVars_.find(addr);
        if (it != zeroPageVars_.end()) {
            return it->second;
        }
        return "$" + util::byteToHex(addr);
    }
    void LabelGenerator::addZeroPageVar(u8 addr, const std::string& label) {
        zeroPageVars_[addr] = label;
    }
    const std::map<u8, std::string>& LabelGenerator::getZeroPageVars() const {
        return zeroPageVars_;
    }
    void LabelGenerator::addDataBlockSubdivision(
        const std::string& blockLabel,
        u16 startOffset,
        u16 endOffset) {
        auto it = std::find_if(dataBlocks_.begin(), dataBlocks_.end(),
            [&](const DataBlock& b) { return b.label == blockLabel; });
        if (it == dataBlocks_.end()) {
            return;
        }
        auto& ranges = dataBlockSubdivisions_[blockLabel];
        bool overlap = std::any_of(ranges.begin(), ranges.end(), [&](const auto& r) {
            return !(endOffset <= r.first || startOffset >= r.second);
            });
        if (!overlap) {
            ranges.emplace_back(startOffset, endOffset);
            const size_t subdivIndex = ranges.size();
            const u16 blockStart = it->start;
            const u16 realStart = blockStart + startOffset;
            const std::string subLabel = blockLabel + "_" + std::to_string(subdivIndex);
            labelMap_[realStart] = subLabel;
        }
    }
    void LabelGenerator::addPendingSubdivisionAddress(u16 addr) {
        if (addr >= loadAddress_ && addr < endAddress_) {
            pendingSubdivisionAddresses_.insert(addr);
        }
    }
    void LabelGenerator::applySubdivisions() {
        std::vector<u16> sorted(pendingSubdivisionAddresses_.begin(), pendingSubdivisionAddresses_.end());
        std::sort(sorted.begin(), sorted.end());
        std::map<std::string, std::vector<std::pair<u16, u16>>> blockRanges;
        for (size_t i = 0; i < sorted.size(); ) {
            u16 start = sorted[i];
            u16 end = start + 1;
            while ((i + 1) < sorted.size() && sorted[i + 1] == end) {
                ++end;
                ++i;
            }
            for (const auto& block : dataBlocks_) {
                if (start >= block.end || end <= block.start) {
                    continue;
                }
                const std::string label = block.label;
                const u16 offsetStart = std::max<u16>(start, block.start) - block.start;
                const u16 offsetEnd = std::min<u16>(end, block.end) - block.start;
                blockRanges[label].emplace_back(offsetStart, offsetEnd);
                break;
            }
            ++i;
        }
        for (const auto& [label, ranges] : blockRanges) {
            auto& existing = dataBlockSubdivisions_[label];
            for (const auto& [start, end] : ranges) {
                bool overlap = std::any_of(existing.begin(), existing.end(),
                    [start, end](const auto& r) {  
                        return !(end <= r.first || start >= r.second);
                    });
                if (!overlap) {
                    existing.emplace_back(start, end);
                }
            }
        }
        std::vector<DataBlock> newBlocks;
        for (auto& [label, ranges] : dataBlockSubdivisions_) {
            auto it = std::find_if(dataBlocks_.begin(), dataBlocks_.end(),
                [&](const DataBlock& b) { return b.label == label; });
            if (it == dataBlocks_.end()) {
                continue;
            }
            const u16 blockStart = it->start;
            std::sort(ranges.begin(), ranges.end());
            for (size_t i = 0; i < ranges.size(); ++i) {
                const u16 startOffset = ranges[i].first;
                const u16 endOffset = ranges[i].second;
                const u16 realStart = blockStart + startOffset;
                const u16 realEnd = blockStart + endOffset - 1;
                const std::string subLabel = label + "_" + std::to_string(i + 1);
                labelMap_[realStart] = subLabel;
                newBlocks.push_back({ subLabel, realStart, realEnd });
            }
            const auto oldLabel = label;
            const auto newLabel = label + "_0";
            labelMap_[it->start] = newLabel;
            it->label = newLabel;
        }
        dataBlocks_.insert(dataBlocks_.end(), newBlocks.begin(), newBlocks.end());
        pendingSubdivisionAddresses_.clear();
    }
    const std::map<u16, std::string>& LabelGenerator::getLabelMap() const {
        return labelMap_;
    }
    void LabelGenerator::addHardwareBase(
        HardwareType type,
        u16 address,
        int index,
        const std::string& name) {
        HardwareBase base;
        base.type = type;
        base.address = address;
        base.index = index;
        base.name = name;
        usedHardwareBases_.push_back(base);
    }
    const std::vector<HardwareBase>& LabelGenerator::getHardwareBases() const {
        return usedHardwareBases_;
    }
    int LabelGenerator::getInstructionSize(u8 opcode) const {
        return INSTRUCTION_SIZES[opcode];
    }
    bool LabelGenerator::isProbableOpcode(u16 addr) const {
        u8 accessFlags = analyzer_.getMemoryAccess(addr);
        constexpr u8 MemoryAccess_OpCode = 1 << 4;
        return (accessFlags & MemoryAccess_OpCode) != 0;
    }
}
```


### FILE: src/Main.cpp
```cpp
#include "app/SIDwinderApp.h"
#include "SIDwinderUtils.h"
#include <iostream>
#include <filesystem>
namespace fs = std::filesystem;
using namespace sidwinder;
int main(int argc, char** argv) {
    try {
        std::vector<fs::path> configPaths = {
            "SIDwinder.cfg",                                
            fs::path(argv[0]).parent_path() / "SIDwinder.cfg", 
            #ifdef _WIN32
            fs::path(getenv("APPDATA") ? getenv("APPDATA") : "") / "SIDwinder" / "SIDwinder.cfg", 
            #else
            fs::path(getenv("HOME") ? getenv("HOME") : "") / ".config" / "sidwinder" / "SIDwinder.cfg", 
            fs::path(getenv("HOME") ? getenv("HOME") : "") / ".sidwinder" / "SIDwinder.cfg",       
            "/etc/sidwinder/SIDwinder.cfg",                
            #endif
        };
        SIDwinderApp app(argc, argv);
        return app.run();
    }
    catch (const std::exception& e) {
        std::cerr << "Fatal error: " << e.what() << std::endl;
        return 1;
    }
}
```


### FILE: src/MemoryAnalyzer.cpp
```cpp
#include "MemoryAnalyzer.h"
#include "SIDwinderUtils.h"
namespace sidwinder {
    namespace {
        constexpr u8 MemoryAccess_Execute = 1 << 0;
        constexpr u8 MemoryAccess_Read = 1 << 1;
        constexpr u8 MemoryAccess_Write = 1 << 2;
        constexpr u8 MemoryAccess_JumpTarget = 1 << 3;
        constexpr u8 MemoryAccess_OpCode = 1 << 4;
    }
    MemoryAnalyzer::MemoryAnalyzer(
        std::span<const u8> memory,
        std::span<const u8> memoryAccess,
        u16 startAddress,
        u16 endAddress)
        : memory_(memory),
        memoryAccess_(memoryAccess),
        startAddress_(startAddress),
        endAddress_(endAddress) {
        memoryTypes_.resize(65536, MemoryType::Unknown);
    }
    void MemoryAnalyzer::analyzeExecution() {
        int codeCount = 0;
        int jumpCount = 0;
        for (u32 addr = 0; addr < 0x10000; ++addr) {
            if (memoryAccess_[addr] & MemoryAccess_Execute) {
                memoryTypes_[addr] |= MemoryType::Code;
                codeCount++;
            }
            if (memoryAccess_[addr] & MemoryAccess_JumpTarget) {
                memoryTypes_[addr] |= MemoryType::LabelTarget;
                jumpCount++;
            }
        }
    }
    void MemoryAnalyzer::analyzeAccesses() {
        for (u32 addr = 0; addr < 0x10000; ++addr) {
            if (memoryAccess_[addr] & (MemoryAccess_Read | MemoryAccess_Write)) {
                memoryTypes_[addr] |= MemoryType::Accessed;
                if (memoryTypes_[addr] & MemoryType::Code) {
                    u16 instrStart = findInstructionStartCovering(addr);
                    memoryTypes_[instrStart] |= MemoryType::LabelTarget;
                }
            }
        }
    }
    void MemoryAnalyzer::analyzeData() {
        for (u32 addr = 0; addr < 0x10000; ++addr) {
            if (!(memoryTypes_[addr] & MemoryType::Code)) {
                memoryTypes_[addr] |= MemoryType::Data;
            }
        }
    }
    u16 MemoryAnalyzer::findInstructionStartCovering(u16 addr) const {
        for (int i = 0; i < 3; i++) {
            if (addr < i) {
                break; 
            }
            u16 search = addr - i;
            if (memoryAccess_[search] & MemoryAccess_OpCode) {
                return search;
            }
        }
        return addr;
    }
    MemoryType MemoryAnalyzer::getMemoryType(u16 addr) const {
        if (addr < memoryTypes_.size()) {
            return memoryTypes_[addr];
        }
        return MemoryType::Unknown;
    }
    std::span<const MemoryType> MemoryAnalyzer::getMemoryTypes() const {
        return std::span<const MemoryType>(memoryTypes_.data(), memoryTypes_.size());
    }
    std::vector<std::pair<u16, u16>> MemoryAnalyzer::findDataRanges() const {
        std::vector<std::pair<u16, u16>> ranges;
        bool inDataRange = false;
        u16 rangeStart = 0;
        for (u32 addr = startAddress_; addr < endAddress_; ++addr) {
            const bool isData = memoryTypes_[addr] & MemoryType::Data;
            if (isData && !inDataRange) {
                rangeStart = addr;
                inDataRange = true;
            }
            else if (!isData && inDataRange) {
                ranges.emplace_back(rangeStart, addr - 1);
                inDataRange = false;
            }
        }
        if (inDataRange) {
            ranges.emplace_back(rangeStart, endAddress_ - 1);
        }
        return ranges;
    }
    std::vector<std::pair<u16, u16>> MemoryAnalyzer::findCodeRanges() const {
        std::vector<std::pair<u16, u16>> ranges;
        bool inCodeRange = false;
        u16 rangeStart = 0;
        for (u32 addr = startAddress_; addr < endAddress_; ++addr) {
            const bool isCode = memoryTypes_[addr] & MemoryType::Code;
            if (isCode && !inCodeRange) {
                rangeStart = addr;
                inCodeRange = true;
            }
            else if (!isCode && inCodeRange) {
                ranges.emplace_back(rangeStart, addr - 1);
                inCodeRange = false;
            }
        }
        if (inCodeRange) {
            ranges.emplace_back(rangeStart, endAddress_ - 1);
        }
        return ranges;
    }
    std::vector<u16> MemoryAnalyzer::findLabelTargets() const {
        std::vector<u16> targets;
        for (u32 addr = startAddress_; addr < endAddress_; ++addr) {
            if (memoryTypes_[addr] & MemoryType::LabelTarget) {
                targets.push_back(addr);
            }
        }
        return targets;
    }
}
```


### FILE: src/RelocationUtils.cpp
```cpp
#include "RelocationUtils.h"
#include "SIDwinderUtils.h"
#include "ConfigManager.h"
#include "cpu6510.h"
#include "SIDEmulator.h"
#include "SIDLoader.h"
#include "Disassembler.h"
#include <fstream>
namespace sidwinder {
    namespace util {
        RelocationResult relocateSID(
            CPU6510* cpu,
            SIDLoader* sid,
            const RelocationParams& params) {
            RelocationResult result;
            result.success = false;
            const std::string inExt = getFileExtension(params.inputFile);
            if (inExt != ".sid") {
                result.message = "Input file must be a SID file (.sid): " + params.inputFile.string();
                Logger::error(result.message);
                return result;
            }
            const std::string outExt = getFileExtension(params.outputFile);
            if (outExt != ".sid") {
                result.message = "Output file must be a SID file (.sid): " + params.outputFile.string();
                Logger::error(result.message);
                return result;
            }
            try {
                fs::create_directories(params.tempDir);
            }
            catch (const std::exception& e) {
                result.message = std::string("Failed to create temp directory: ") + e.what();
                Logger::error(result.message);
                return result;
            }
            if (!sid->loadSID(params.inputFile.string())) {
                result.message = "Failed to load file for relocation: " + params.inputFile.string();
                Logger::error(result.message);
                return result;
            }
            result.originalLoad = sid->getLoadAddress();
            result.originalInit = sid->getInitAddress();
            result.originalPlay = sid->getPlayAddress();
            const SIDHeader& originalHeader = sid->getHeader();
            u16 originalFlags = originalHeader.flags;
            u8 secondSIDAddress = originalHeader.secondSIDAddress;
            u8 thirdSIDAddress = originalHeader.thirdSIDAddress;
            u16 version = originalHeader.version;
            u32 speed = originalHeader.speed;
            result.newLoad = params.relocationAddress;
            result.newInit = result.newLoad + (result.originalInit - result.originalLoad);
            result.newPlay = result.newLoad + (result.originalPlay - result.originalLoad);
            Disassembler disassembler(*cpu, *sid);
            const int numFrames = util::ConfigManager::getInt("emulationFrames");
            if (!runSIDEmulation(cpu, sid, numFrames)) {
                result.message = "Failed to run SID emulation for memory analysis";
                Logger::error(result.message);
                return result;
            }
            const std::string basename = params.inputFile.stem().string();
            const fs::path tempAsmFile = params.tempDir / (basename + "-relocated.asm");
            const fs::path tempPrgFile = params.tempDir / (basename + "-relocated.prg");
            disassembler.generateAsmFile(
                tempAsmFile.string(),
                result.newLoad,
                result.newInit,
                result.newPlay,
                false);
            if (!assembleAsmToPrg(tempAsmFile, tempPrgFile, params.kickAssPath, params.tempDir)) {
                result.message = "Failed to assemble relocated code: " + tempAsmFile.string();
                Logger::error(result.message);
                return result;
            }
            const std::string title = originalHeader.name;
            const std::string author = originalHeader.author;
            const std::string copyright = originalHeader.copyright;
            if (!createSIDFromPRG(
                tempPrgFile,
                params.outputFile,
                result.newLoad,
                result.newInit,
                result.newPlay,
                title,
                author,
                copyright,
                originalFlags,
                secondSIDAddress,
                thirdSIDAddress,
                version,
                speed)) {
                Logger::warning("SID file generation failed. Saving as PRG instead.");
                try {
                    fs::copy_file(tempPrgFile, params.outputFile, fs::copy_options::overwrite_existing);
                    result.success = true;
                    result.message = "Relocation complete (saved as PRG).";
                }
                catch (const std::exception& e) {
                    result.message = std::string("Failed to copy output file: ") + e.what();
                    Logger::error(result.message);
                    return result;
                }
            }
            else {
                result.success = true;
                result.message = "Relocation to SID complete. ";
            }
            return result;
        }
        RelocationVerificationResult relocateAndVerifySID(
            CPU6510* cpu,
            SIDLoader* sid,
            const fs::path& inputFile,
            const fs::path& outputFile,
            u16 relocationAddress,
            const fs::path& tempDir,
            const std::string& kickAssPath) {  
            RelocationVerificationResult result;
            result.success = false;
            result.verified = false;
            result.outputsMatch = false;
            fs::path originalTrace = tempDir / (inputFile.stem().string() + "-original.trace");
            fs::path relocatedTrace = tempDir / (inputFile.stem().string() + "-relocated.trace");
            fs::path diffReport = tempDir / (inputFile.stem().string() + "-diff.txt");
            result.originalTrace = originalTrace.string();
            result.relocatedTrace = relocatedTrace.string();
            result.diffReport = diffReport.string();
            try {
                util::RelocationParams relocParams;
                relocParams.inputFile = inputFile;
                relocParams.outputFile = outputFile;
                relocParams.tempDir = tempDir;
                relocParams.relocationAddress = relocationAddress;
                relocParams.kickAssPath = kickAssPath;  
                util::RelocationResult relocResult = util::relocateSID(cpu, sid, relocParams);
                if (!relocResult.success) {
                    result.message = "Relocation failed: " + relocResult.message;
                    return result;
                }
                result.success = true;
                if (!sid->loadSID(inputFile.string())) {
                    result.message = "Failed to load original SID file";
                    return result;
                }
                SIDEmulator originalEmulator(cpu, sid);
                SIDEmulator::EmulationOptions options;
                options.frames = DEFAULT_SID_EMULATION_FRAMES;
                options.traceEnabled = true;
                options.traceLogPath = originalTrace.string();
                cpu->reset();
                if (!originalEmulator.runEmulation(options)) {
                    result.message = "Failed to emulate original SID file";
                    return result;
                }
                if (!sid->loadSID(outputFile.string())) {
                    result.message = "Failed to load relocated SID file";
                    return result;
                }
                SIDEmulator relocatedEmulator(cpu, sid);
                options.traceLogPath = relocatedTrace.string();
                cpu->reset();
                if (!relocatedEmulator.runEmulation(options)) {
                    result.message = "Emulation of relocated SID file failed";
                    return result;
                }
                result.verified = true;
                result.outputsMatch = TraceLogger::compareTraceLogs(
                    originalTrace.string(),
                    relocatedTrace.string(),
                    diffReport.string());
                if (result.outputsMatch) {
                    result.message = "SID file relocated OK with matching before/after trace outputs";
                }
                else {
                    result.message = "SID relocation verification failed - before/after trace outputs differ";
                }
                return result;
            }
            catch (const std::exception& e) {
                result.message = std::string("Exception during relocation/verification: ") + e.what();
                return result;
            }
        }
        bool assembleAsmToPrg(
            const fs::path& sourceFile,
            const fs::path& outputFile,
            const std::string& kickAssPath,
            const fs::path& tempDir) {
            fs::path logFile = tempDir / (sourceFile.stem().string() + "_kickass.log");
            const std::string kickCommand = kickAssPath + " " +
                "\"" + sourceFile.string() + "\" -o \"" +
                outputFile.string() + "\" > \"" +
                logFile.string() + "\" 2>&1";
            const int result = std::system(kickCommand.c_str());
            if (result != 0) {
                util::Logger::error("FAILURE: " + sourceFile.string() + " - please see output log for details: " + logFile.string());
                return false;
            }
            return true;
        }
        bool createSIDFromPRG(
            const fs::path& prgFile,
            const fs::path& sidFile,
            u16 loadAddr,
            u16 initAddr,
            u16 playAddr,
            const std::string& title,
            const std::string& author,
            const std::string& copyright,
            u16 flags,
            u8 secondSIDAddress,
            u8 thirdSIDAddress,
            u16 version,
            u32 speed) {
            std::ifstream prg(prgFile, std::ios::binary | std::ios::ate);
            if (!prg) {
                Logger::error("Failed to open PRG file: " + prgFile.string());
                return false;
            }
            const auto filePos = prg.tellg();
            const size_t fileSize = static_cast<size_t>(filePos);
            prg.seekg(0, std::ios::beg);
            if (fileSize < 2) {
                Logger::error("PRG file too small: " + prgFile.string());
                return false;
            }
            u8 lo, hi;
            prg.read(reinterpret_cast<char*>(&lo), 1);
            prg.read(reinterpret_cast<char*>(&hi), 1);
            const u16 prgLoadAddr = (hi << 8) | lo;
            if (prgLoadAddr != loadAddr) {
                Logger::warning("PRG file load address ($" + wordToHex(prgLoadAddr) +
                    ") doesn't match specified address ($" + wordToHex(loadAddr) + ")");
                loadAddr = prgLoadAddr;
            }
            SIDHeader header;
            std::memcpy(header.magicID, "PSID", 4);  
            header.version = version;        
            header.dataOffset = (version == 1) ? 0x76 : 0x7C;  
            header.loadAddress = 0;          
            header.initAddress = initAddr;   
            header.playAddress = playAddr;   
            header.songs = 1;                
            header.startSong = 1;            
            header.speed = speed;
            std::memset(header.name, 0, sizeof(header.name));
            std::memset(header.author, 0, sizeof(header.author));
            std::memset(header.copyright, 0, sizeof(header.copyright));
            if (!title.empty()) {
                std::strncpy(header.name, title.c_str(), sizeof(header.name) - 1);
            }
            if (!author.empty()) {
                std::strncpy(header.author, author.c_str(), sizeof(header.author) - 1);
            }
            if (!copyright.empty()) {
                std::strncpy(header.copyright, copyright.c_str(), sizeof(header.copyright) - 1);
            }
            header.flags = flags;                
            header.startPage = 0;                
            header.pageLength = 0;               
            if (version >= 3) {
                header.secondSIDAddress = secondSIDAddress;
            }
            else {
                header.secondSIDAddress = 0;
                if (secondSIDAddress != 0) {
                    Logger::warning("Second SID address information ($" +
                        wordToHex(secondSIDAddress << 4) +
                        ") lost due to SID version " +
                        std::to_string(version) + " (requires v3+)");
                }
            }
            if (version >= 4) {
                header.thirdSIDAddress = thirdSIDAddress;
            }
            else {
                header.thirdSIDAddress = 0;
                if (thirdSIDAddress != 0) {
                    Logger::warning("Third SID address information ($" +
                        wordToHex(thirdSIDAddress << 4) +
                        ") lost due to SID version " +
                        std::to_string(version) + " (requires v4)");
                }
            }
            header.version = util::swapEndian(header.version);
            header.dataOffset = util::swapEndian(header.dataOffset);
            header.loadAddress = util::swapEndian(header.loadAddress);
            header.initAddress = util::swapEndian(header.initAddress);
            header.playAddress = util::swapEndian(header.playAddress);
            header.songs = util::swapEndian(header.songs);
            header.startSong = util::swapEndian(header.startSong);
            header.flags = util::swapEndian(header.flags);
            header.speed = util::swapEndian(header.speed);
            std::ofstream sid_file(sidFile, std::ios::binary);
            if (!sid_file) {
                Logger::error("Failed to create SID file: " + sidFile.string());
                return false;
            }
            sid_file.write(reinterpret_cast<const char*>(&header), sizeof(header));
            sid_file.write(reinterpret_cast<const char*>(&lo), 1);
            sid_file.write(reinterpret_cast<const char*>(&hi), 1);
            const size_t dataSize = fileSize - 2;
            std::vector<char> buffer(dataSize);
            prg.read(buffer.data(), dataSize);
            sid_file.write(buffer.data(), dataSize);
            sid_file.close();
            return true;
        }
        bool runSIDEmulation(
            CPU6510* cpu,
            SIDLoader* sid,
            int frames) {
            SIDEmulator emulator(cpu, sid);
            SIDEmulator::EmulationOptions options;
            options.frames = frames;
            options.traceEnabled = false;
            return emulator.runEmulation(options);
        }
    }
}
```


### FILE: src/SIDEmulator.cpp
```cpp
#include "SIDEmulator.h"
#include "cpu6510.h"
#include "SIDLoader.h"
#include "SIDwinderUtils.h"
#include "MemoryConstants.h"
#include "ConfigManager.h"
#include <set>
namespace sidwinder {
    SIDEmulator::SIDEmulator(CPU6510* cpu, SIDLoader* sid)
        : cpu_(cpu), sid_(sid) {
    }
    bool SIDEmulator::runEmulation(const EmulationOptions& options) {
        if (!cpu_ || !sid_) {
            util::Logger::error("Invalid CPU or SID loader for emulation");
            return false;
        }
        bool temporaryTrackingEnabled = false;
        if (options.registerTrackingEnabled) {
            writeTracker_.reset();
        }
        if (options.patternDetectionEnabled) {
            patternFinder_.reset();
        }
        if (options.traceEnabled && !options.traceLogPath.empty()) {
            traceLogger_ = std::make_unique<TraceLogger>(options.traceLogPath, options.traceFormat);
        }
        else {
            traceLogger_.reset();
        }
        auto updateSIDCallback = [this, &temporaryTrackingEnabled, &options](bool enableTracking) {
            cpu_->setOnSIDWriteCallback([this, enableTracking, &options](u16 addr, u8 value) {
                if (enableTracking) {
                    writeTracker_.recordWrite(addr, value);
                }
                if (options.patternDetectionEnabled) {
                    patternFinder_.recordWrite(addr, value);
                }
                });
            };
        sid_->backupMemory();
        const u16 initAddr = sid_->getInitAddress();
        const u16 playAddr = sid_->getPlayAddress();
        cpu_->resetRegistersAndFlags();
        updateSIDCallback(false);
        cpu_->executeFunction(initAddr);
        const int numEmulationFrames = util::ConfigManager::getInt("emulationFrames", DEFAULT_SID_EMULATION_FRAMES);
        for (int frame = 0; frame < numEmulationFrames; ++frame) {
            for (int call = 0; call < options.callsPerFrame; ++call) {
                cpu_->resetRegistersAndFlags();
                if (!cpu_->executeFunction(playAddr)) {
                    return false;
                }
                if (options.traceEnabled && traceLogger_) {
                    traceLogger_->logFrameMarker();
                }
                if (options.registerTrackingEnabled) {
                    writeTracker_.endFrame();
                }
                if (options.patternDetectionEnabled) {
                    patternFinder_.endFrame();
                }
            }
        }
        u32 testAddr = 0;
        if (playAddr == initAddr + 3)
            testAddr = initAddr + 6;
        if (playAddr == initAddr + 6)
            testAddr = initAddr + 3;
        if ((testAddr != 0) && (cpu_->readMemory(testAddr) == 0x4C))
            cpu_->executeFunction(testAddr);
        cpu_->resetRegistersAndFlags();
        updateSIDCallback(false);
        cpu_->executeFunction(initAddr);
        if (options.traceEnabled && traceLogger_) {
            traceLogger_->logFrameMarker();
        }
        totalCycles_ = 0;
        maxCyclesPerFrame_ = 0;
        framesExecuted_ = 0;
        if (options.registerTrackingEnabled || options.patternDetectionEnabled) {
            cpu_->executeFunction(playAddr);    
            temporaryTrackingEnabled = true;
            updateSIDCallback(true);
        }
        u64 lastCycles = cpu_->getCycles();
        bool bGood = true;
        for (int frame = 0; frame < options.frames; ++frame) {
            for (int call = 0; call < options.callsPerFrame; ++call) {
                cpu_->resetRegistersAndFlags();
                bGood = cpu_->executeFunction(playAddr);
                if (!bGood) {
                    break;
                }
            }
            if (!bGood) {
                break;
            }
            const u64 curCycles = cpu_->getCycles();
            const u64 frameCycles = curCycles - lastCycles;
            maxCyclesPerFrame_ = std::max(maxCyclesPerFrame_, frameCycles);
            totalCycles_ += frameCycles;
            lastCycles = curCycles;
            if (options.traceEnabled && traceLogger_) {
                traceLogger_->logFrameMarker();
            }
            if (options.registerTrackingEnabled) {
                writeTracker_.endFrame();
            }
            if (options.patternDetectionEnabled) {
                patternFinder_.endFrame();
            }
            framesExecuted_++;
        }
        if ((playAddr == initAddr + 3) && (cpu_->readMemory(testAddr) == 0x4C))
        {
            cpu_->executeFunction(testAddr);
        }
        if (temporaryTrackingEnabled) {
            writeTracker_.analyzePattern();
        }
        if (options.patternDetectionEnabled) {
            patternFinder_.analyzePattern();
        }
        sid_->restoreMemory();
        return true;
    }
    std::pair<u64, u64> SIDEmulator::getCycleStats() const {
        const u64 avgCycles = framesExecuted_ > 0 ? totalCycles_ / framesExecuted_ : 0;
        return { avgCycles, maxCyclesPerFrame_ };
    }
    bool SIDEmulator::generateHelpfulDataFile(const std::string& filename) const {
        std::ofstream file(filename);
        if (!file) {
            util::Logger::error("Failed to create helpful data file: " + filename);
            return false;
        }
        file << "
        file << "
        std::set<u16> writtenAddresses;
        auto accessFlags = cpu_->getMemoryAccess();
        for (u32 addr = 0; addr < 65536; ++addr) {
            if (accessFlags[addr] & static_cast<u8>(MemoryAccessFlag::Write)) {
                writtenAddresses.insert(addr);
            }
        }
        file << "
        file << ".var SIDModifiedMemory = List()";
        int numItems = 0;
        for (u16 addr : writtenAddresses) {
            if (!MemoryConstants::isSID(addr)) {
                file << ".add($" << util::wordToHex(addr) << ")";
                numItems++;
            }
        }
        file << "\n.var SIDModifiedMemoryCount = SIDModifiedMemory.size()  
        if (writeTracker_.hasConsistentPattern()) {
            file << "
            file << "#define SID_REGISTER_REORDER_AVAILABLE\n";
            file << writeTracker_.getWriteOrderString() << "\n";
        }
        else {
            file << "
            file << ".var SIDRegisterCount = 0\n";
            file << ".var SIDRegisterOrder = List()\n\n";
        }
        if (patternFinder_.getPatternPeriod() > 0) {
            file << "
            file << "#define SID_PATTERN_DETECTED\n";
            file << ".var SIDInitFrames = " << patternFinder_.getInitFramesCount() << "\n";
            file << ".var SIDPatternPeriod = " << patternFinder_.getPatternPeriod() << "\n\n";
        }
        else {
            file << "
            file << ".var SIDInitFrames = 0\n";
            file << ".var SIDPatternPeriod = 0\n\n";
        }
        return true;
    }
}
```


### FILE: src/SIDLoader.cpp
```cpp
﻿
#include "cpu6510.h"
#include "SIDLoader.h"
#include "SIDwinderUtils.h"
#include <algorithm>
#include <cstring>
#include <fstream>
#include <iostream>
#include <stdexcept>
using namespace sidwinder;
SIDLoader::SIDLoader() {
    std::memset(&header_, 0, sizeof(header_));
}
void SIDLoader::setCPU(CPU6510* cpuPtr) {
    cpu_ = cpuPtr;
}
void SIDLoader::setInitAddress(u16 address) {
    header_.initAddress = address;
}
void SIDLoader::setPlayAddress(u16 address) {
    header_.playAddress = address;
}
void SIDLoader::setLoadAddress(u16 address) {
    header_.loadAddress = address;
}
bool SIDLoader::loadSID(const std::string& filename) {
    if (!cpu_) {
        std::cerr << "CPU not set!\n";
        return false;
    }
    std::ifstream file(filename, std::ios::binary);
    if (!file) {
        std::cerr << "Failed to open file: " << filename << "\n";
        return false;
    }
    file.seekg(0, std::ios::end);
    std::streamsize fileSize = file.tellg();
    file.seekg(0, std::ios::beg);
    if (fileSize <= 0) {
        std::cerr << "File is empty: " << filename << "\n";
        return false;
    }
    std::vector<u8> buffer(static_cast<size_t>(fileSize));
    if (!file.read(reinterpret_cast<char*>(buffer.data()), fileSize)) {
        std::cerr << "Failed to read file: " << filename << "\n";
        return false;
    }
    if (fileSize < sizeof(SIDHeader)) {
        std::cerr << "SID file too small to contain a valid header!\n";
        return false;
    }
    std::memcpy(&header_, buffer.data(), sizeof(header_));
    if (std::string(header_.magicID, 4) == "RSID") {
        std::cerr << "RSID file format detected: \"" << filename << "\"\n";
        std::cerr << "RSID files require a true C64 environment and cannot be emulated by SIDwinder.\n";
        std::cerr << "Please use a PSID formatted file instead.\n";
        return false;
    }
    if (std::string(header_.magicID, 4) != "PSID") {
        std::cerr << "Invalid SID file: Expected 'PSID' magic ID, found '"
            << std::string(header_.magicID, 4) << "'\n";
        return false;
    }
    header_.version = util::swapEndian(header_.version);
    header_.dataOffset = util::swapEndian(header_.dataOffset);
    header_.loadAddress = util::swapEndian(header_.loadAddress);
    header_.initAddress = util::swapEndian(header_.initAddress);
    header_.playAddress = util::swapEndian(header_.playAddress);
    header_.songs = util::swapEndian(header_.songs);
    header_.startSong = util::swapEndian(header_.startSong);
    header_.speed = util::swapEndian(header_.speed);
    header_.flags = util::swapEndian(header_.flags);
    if (header_.version < 1 || header_.version > 4) {
        std::cerr << "Unsupported SID version: " << header_.version
            << ". Supported versions are 1-4.\n";
        return false;
    }
    if (header_.version >= 3) {
        if (header_.secondSIDAddress != 0) {
            u16 secondSIDAddr = header_.secondSIDAddress << 4;  
        }
        if (header_.version >= 4 && header_.thirdSIDAddress != 0) {
            u16 thirdSIDAddr = header_.thirdSIDAddress << 4;  
        }
    }
    u16 expectedOffset = (header_.version == 1) ? 0x76 : 0x7C;
    if (header_.dataOffset != expectedOffset) {
        util::Logger::warning("Unexpected dataOffset value: " + std::to_string(header_.dataOffset) +
            ", expected: " + std::to_string(expectedOffset));
    }
    if (header_.loadAddress == 0) {
        if (fileSize < header_.dataOffset + 2) {
            std::cerr << "SID file corrupt (missing embedded load address)!\n";
            return false;
        }
        const u8 lo = buffer[header_.dataOffset];
        const u8 hi = buffer[header_.dataOffset + 1];
        header_.loadAddress = static_cast<u16>(lo | (hi << 8));
        header_.dataOffset += 2;
    }
    dataSize_ = static_cast<u16>(fileSize - header_.dataOffset);
    if (dataSize_ <= 0) {
        std::cerr << "SID file contains no music data!\n";
        return false;
    }
    if (header_.loadAddress + dataSize_ > 65536) {
        std::cerr << "SID file data exceeds C64 memory limits! (Load address: $" << util::wordToHex(header_.loadAddress) << ", Size: " << dataSize_ << " bytes)\n";
        return false;
    }
    const u8* musicData = &buffer[header_.dataOffset];
    if (!copyMusicToMemory(musicData, dataSize_, header_.loadAddress)) {
        std::cerr << "Failed to copy music data to memory!\n";
        return false;
    }
    return true;
}
bool SIDLoader::copyMusicToMemory(const u8* data, u16 size, u16 loadAddr) {
    if (!cpu_) {
        std::cerr << "CPU not set!\n";
        return false;
    }
    if (size == 0 || loadAddr + size > 65536) {
        std::cerr << "Invalid data size or load address!\n";
        return false;
    }
    for (u32 i = 0; i < size; ++i) {
        cpu_->writeByte(loadAddr + i, data[i]);
    }
    dataSize_ = size;
    originalMemory_.assign(data, data + size);
    originalMemoryBase_ = loadAddr;
    return true;
}
bool SIDLoader::backupMemory() {
    if (!cpu_) {
        util::Logger::error("CPU not set for memory backup!");
        return false;
    }
    auto cpuMemory = cpu_->getMemory();
    memoryBackup_.assign(cpuMemory.begin(), cpuMemory.end());
    return true;
}
bool SIDLoader::restoreMemory() {
    if (!cpu_) {
        return false;
    }
    if (memoryBackup_.empty()) {
        return false;  
    }
    for (size_t addr = 0; addr < memoryBackup_.size(); ++addr) {
        cpu_->writeByte(static_cast<u16>(addr), memoryBackup_[addr]);
    }
    return true;
}
```


### FILE: src/SIDpatternFinder.cpp
```cpp
#include "SIDPatternFinder.h"
#include "SIDwinderUtils.h"
#include "MemoryConstants.h"
#include <sstream>
#include <functional>
#include <algorithm>
#include <unordered_map>
namespace sidwinder {
    SIDPatternFinder::SIDPatternFinder() {
        reset();
    }
    void SIDPatternFinder::reset() {
        frames_.clear();
        currentFrame_.clear();
        patternPeriod_ = 0;
        initFramesCount_ = 0;
        patternFound_ = false;
    }
    void SIDPatternFinder::recordWrite(u16 addr, u8 value) {
        if (MemoryConstants::isSID(addr)) {
            bool alreadyWritten = false;
            for (const auto& write : currentFrame_) {
                if (write.addr == addr) {
                    alreadyWritten = true;
                    break;
                }
            }
            if (!alreadyWritten) {
                currentFrame_.push_back({ addr, value });
            }
        }
    }
    void SIDPatternFinder::endFrame() {
        if (!currentFrame_.empty()) {
            frames_.push_back(currentFrame_);
            currentFrame_.clear();
        }
    }
    bool SIDPatternFinder::analyzePattern(int maxInitFrames) {
        if (frames_.size() < 10) {
            return false;
        }
        for (size_t initFrames = 0; initFrames <= std::min(static_cast<size_t>(maxInitFrames), frames_.size() / 2); initFrames++) {
            size_t period = findSmallestPeriod(initFrames);
            if (period > 0 && period < (frames_.size() - initFrames) / 2) {
                patternPeriod_ = period;
                initFramesCount_ = initFrames;
                patternFound_ = true;
                return true;
            }
        }
        return false;
    }
    size_t SIDPatternFinder::hashFrame(const std::vector<SIDWrite>& frame) const {
        std::size_t hash = 0;
        std::vector<SIDWrite> sortedWrites = frame;
        std::sort(sortedWrites.begin(), sortedWrites.end(),
            [](const SIDWrite& a, const SIDWrite& b) { return a.addr < b.addr; });
        for (const auto& write : sortedWrites) {
            hash = hash * 31 + write.addr;
            hash = hash * 31 + write.value;
        }
        return hash;
    }
    bool SIDPatternFinder::framesEqual(const std::vector<SIDWrite>& frame1, const std::vector<SIDWrite>& frame2) const {
        if (frame1.size() != frame2.size()) {
            return false;
        }
        std::vector<SIDWrite> sorted1 = frame1;
        std::vector<SIDWrite> sorted2 = frame2;
        std::sort(sorted1.begin(), sorted1.end(),
            [](const SIDWrite& a, const SIDWrite& b) { return a.addr < b.addr; });
        std::sort(sorted2.begin(), sorted2.end(),
            [](const SIDWrite& a, const SIDWrite& b) { return a.addr < b.addr; });
        for (size_t i = 0; i < sorted1.size(); i++) {
            if (!(sorted1[i].addr == sorted2[i].addr && sorted1[i].value == sorted2[i].value)) {
                return false;
            }
        }
        return true;
    }
    size_t SIDPatternFinder::findSmallestPeriod(size_t initFrames) const {
        std::vector<size_t> frameHashes;
        for (size_t i = initFrames; i < frames_.size(); i++) {
            frameHashes.push_back(hashFrame(frames_[i]));
        }
        const size_t maxPeriod = frameHashes.size() / 2;
        for (size_t period = 1; period <= maxPeriod; period++) {
            if (verifyPattern(initFrames, period)) {
                return period;
            }
        }
        return 0;
    }
    bool SIDPatternFinder::verifyPattern(size_t initFrames, size_t period) const {
        if (period == 0 || initFrames + period * 2 > frames_.size()) {
            return false;
        }
        for (size_t i = initFrames; i + period < frames_.size(); i++) {
            if (!framesEqual(frames_[i], frames_[i + period])) {
                return false;
            }
        }
        return true;
    }
    std::string SIDPatternFinder::getPatternDescription() const {
        std::stringstream ss;
        if (!patternFound_) {
            ss << "No repeating pattern detected in " << frames_.size() << " frames of SID register writes.";
            return ss.str();
        }
        ss << "Detected repeating pattern:\n";
        ss << "- " << initFramesCount_ << " initialization frame(s)\n";
        ss << "- Pattern repeats every " << patternPeriod_ << " frame(s)\n";
        ss << "- Total frames analyzed: " << frames_.size() << "\n";
        return ss.str();
    }
}
```


### FILE: src/SIDwinderUtils.cpp
```cpp
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
        Logger::Level Logger::minLevel_ = Logger::Level::Info;
        std::optional<std::filesystem::path> Logger::logFile_ = std::nullopt;
        bool Logger::consoleOutput_ = true;
        std::optional<u16> parseHex(std::string_view str) {
            const auto start = str.find_first_not_of(" \t\r\n");
            if (start == std::string_view::npos) {
                return std::nullopt;
            }
            const auto end = str.find_last_not_of(" \t\r\n");
            const auto trimmed = str.substr(start, end - start + 1);
            try {
                if (!trimmed.empty() && trimmed[0] == '$') {
                    return static_cast<u16>(std::stoul(std::string(trimmed.substr(1)), nullptr, 16));
                }
                else if (trimmed.size() > 2 && trimmed.substr(0, 2) == "0x") {
                    return static_cast<u16>(std::stoul(std::string(trimmed), nullptr, 16));
                }
                else {
                    return static_cast<u16>(std::stoul(std::string(trimmed), nullptr, 10));
                }
            }
            catch (const std::exception&) {
                return std::nullopt;
            }
        }
        std::string padToColumn(std::string_view str, size_t width) {
            if (str.length() >= width) {
                return std::string(str);
            }
            return std::string(str) + std::string(width - str.length(), ' ');
        }
        void IndexRange::update(int offset) {
            min_ = std::min(min_, offset);
            max_ = std::max(max_, offset);
        }
        std::pair<int, int> IndexRange::getRange() const {
            if (min_ > max_) {
                return { 0, 0 };  
            }
            return { min_, max_ };
        }
        std::tm getLocalTime(const std::time_t& time) {
            std::tm timeInfo = {};
#ifdef _WIN32
            localtime_s(&timeInfo, &time);
#else
            localtime_r(&time, &timeInfo);
#endif
            return timeInfo;
        }
        void Logger::initialize(const std::filesystem::path& logFile) {
            logFile_ = logFile;
            consoleOutput_ = !logFile_.has_value();
            if (logFile_) {
                const auto parent = logFile_->parent_path();
                if (!parent.empty()) {
                    std::filesystem::create_directories(parent);
                }
                std::ofstream file(logFile_.value(), std::ios::trunc);
                if (!file) {
                    std::cerr << "Warning: Could not open log file: " << logFile_.value().string() << std::endl;
                    logFile_ = std::nullopt;
                    consoleOutput_ = true;
                }
                else {
                    auto now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
                    std::tm timeInfo = getLocalTime(now);
                    file << "===== SIDwinder Log Started at "
                        << std::put_time(&timeInfo, "%Y-%m-%d %H:%M:%S")
                        << " =====\n";
                }
            }
        }
        void Logger::setLogLevel(Level level) {
            minLevel_ = level;
        }
        void Logger::log(Level level, const std::string& message, bool toConsole) {
            if (level < minLevel_) {
                return;
            }
            const auto now = std::chrono::system_clock::now();
            const auto nowTime = std::chrono::system_clock::to_time_t(now);
            std::tm timeInfo = getLocalTime(nowTime);
            std::stringstream timestampStr;
            timestampStr << std::put_time(&timeInfo, "%Y-%m-%d %H:%M:%S");
            std::string levelStr;
            switch (level) {
            case Level::Debug:   levelStr = "DEBUG"; break;
            case Level::Info:    levelStr = "INFO"; break;
            case Level::Warning: levelStr = "WARNING"; break;
            case Level::Error:   levelStr = "ERROR"; break;
            }
            std::stringstream fullMessage;
            fullMessage << "[" << timestampStr.str() << "] [" << levelStr << "] " << message;
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
        void Logger::debug(const std::string& message, bool toConsole) {
            log(Level::Debug, message, toConsole);
        }
        void Logger::info(const std::string& message, bool toConsole) {
            log(Level::Info, message, toConsole);
        }
        void Logger::warning(const std::string& message, bool toConsole) {
            log(Level::Warning, message, toConsole);
        }
        void Logger::error(const std::string& message, bool toConsole) {
            log(Level::Error, message, toConsole);
        }
    } 
}
```


### FILE: src/SIDWriteTracker.cpp
```cpp
#include "SIDWriteTracker.h"
#include "SIDwinderUtils.h"
#include <algorithm>
#include <sstream>
#include <set>
#include <iomanip>
namespace sidwinder {
    SIDWriteTracker::SIDWriteTracker() {
    }
    void SIDWriteTracker::recordWrite(u16 addr, u8 value) {
        u8 reg = addr & 0x1F;
        if (reg <= 0x18) {
            if (std::find(currentFrameSequence_.begin(), currentFrameSequence_.end(), reg)
                == currentFrameSequence_.end()) {
                currentFrameSequence_.push_back(reg);
            }
            registersUsed_[reg] = true;
            registerWriteCounts_[reg]++;
        }
    }
    void SIDWriteTracker::endFrame() {
        if (!currentFrameSequence_.empty()) {
            frameSequences_.push_back(currentFrameSequence_);
            currentFrameSequence_.clear();
            frameCount_++;
        }
    }
    void SIDWriteTracker::reset() {
        frameSequences_.clear();
        currentFrameSequence_.clear();
        writeOrder_.clear();
        consistentPattern_ = false;
        frameCount_ = 0;
        std::fill(registersUsed_.begin(), registersUsed_.end(), false);
        std::fill(registerWriteCounts_.begin(), registerWriteCounts_.end(), 0);
    }
    bool SIDWriteTracker::analyzePattern() {
        if (frameSequences_.size() < 10) {
            return false;
        }
        bool samePattern = true;
        const auto& firstSeq = frameSequences_[0];
        for (size_t i = 10; i < frameSequences_.size(); i++) {
            if (frameSequences_[i] != firstSeq) {
                samePattern = false;
                break;
            }
        }
        if (samePattern && !firstSeq.empty()) {
            writeOrder_ = firstSeq;
            consistentPattern_ = true;
            return true;
        }
        std::set<u8> usedRegs;
        for (u8 i = 0; i <= 0x18; i++) {
            if (registersUsed_[i]) {
                usedRegs.insert(i);
            }
        }
        if (!usedRegs.empty()) {
            writeOrder_.clear();
            writeOrder_.insert(writeOrder_.end(), usedRegs.begin(), usedRegs.end());
            return true;
        }
        return false;
    }
    std::string SIDWriteTracker::getWriteOrderString() const {
        std::stringstream ss;
        if (writeOrder_.empty()) {
            return ".var SIDRegisterCount = 0\n.var SIDRegisterOrder = List()\n";
        }
        ss << ".var SIDRegisterOrder = List()";
        for (size_t i = 0; i < writeOrder_.size(); i++) {
            ss << ".add($" << util::byteToHex(writeOrder_[i]) << ")";
        }
        ss << "\n.var SIDRegisterCount = SIDRegisterOrder.size()\n\n";
        return ss.str();
    }
    std::string SIDWriteTracker::getRegisterUsageStats() const {
        std::stringstream ss;
        ss << "SID Register Usage Statistics:\n";
        ss << "-----------------------------\n";
        ss << "Total frames analyzed: " << frameCount_ << "\n\n";
        ss << "Register | Used | Write Count | Avg Writes/Frame\n";
        ss << "---------+------+-------------+----------------\n";
        for (u8 i = 0; i <= 0x18; i++) {
            if (registersUsed_[i]) {
                float avgWrites = frameCount_ > 0 ?
                    static_cast<float>(registerWriteCounts_[i]) / frameCount_ : 0;
                ss << "$" << util::byteToHex(i) << "     | Yes  | "
                    << std::setw(11) << registerWriteCounts_[i] << " | "
                    << std::fixed << std::setprecision(2) << avgWrites << "\n";
            }
        }
        return ss.str();
    }
}
```


### FILE: src/6510/AddressingModes.cpp
```cpp
#include "AddressingModes.h"
#include "CPU6510Impl.h"
#include <iostream>
AddressingModes::AddressingModes(CPU6510Impl& cpu) : cpu_(cpu) {
}
u32 AddressingModes::getAddress(AddressingMode mode) {
    CPUState& cpuState = cpu_.cpuState_;
    MemorySubsystem& memory = cpu_.memory_;
    if (mode == AddressingMode::AbsoluteX || mode == AddressingMode::AbsoluteY ||
        mode == AddressingMode::ZeroPageX || mode == AddressingMode::ZeroPageY ||
        mode == AddressingMode::IndirectX || mode == AddressingMode::IndirectY) {
        u8 index = 0;
        if (mode == AddressingMode::AbsoluteY || mode == AddressingMode::ZeroPageY || mode == AddressingMode::IndirectY) {
            index = cpuState.getY();
        }
        else if (mode == AddressingMode::AbsoluteX || mode == AddressingMode::ZeroPageX || mode == AddressingMode::IndirectX) {
            index = cpuState.getX();
        }
        recordIndexOffset(cpuState.getPC(), index);
    }
    switch (mode) {
    case AddressingMode::Immediate: {
        u32 addr = cpuState.getPC();
        cpuState.incrementPC();
        return addr;
    }
    case AddressingMode::ZeroPage: {
        u32 addr = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        return addr;
    }
    case AddressingMode::ZeroPageX: {
        u8 zeroPageAddr = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        return (zeroPageAddr + cpuState.getX()) & 0xFF;
    }
    case AddressingMode::ZeroPageY: {
        u8 zeroPageAddr = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        return (zeroPageAddr + cpuState.getY()) & 0xFF;
    }
    case AddressingMode::Absolute: {
        u32 addr = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        addr |= (cpu_.fetchOperand(cpuState.getPC()) << 8);
        cpuState.incrementPC();
        return addr;
    }
    case AddressingMode::AbsoluteX: {
        const u32 base = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        const u32 highByte = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        const u32 baseAddr = base | (highByte << 8);
        const u32 addr = baseAddr + cpuState.getX();
        if ((baseAddr & 0xFF00) != (addr & 0xFF00)) {
            cpuState.addCycles(1);
        }
        return addr;
    }
    case AddressingMode::AbsoluteY: {
        const u32 base = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        const u32 highByte = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        const u32 baseAddr = base | (highByte << 8);
        const u32 addr = baseAddr + cpuState.getY();
        if ((baseAddr & 0xFF00) != (addr & 0xFF00)) {
            cpuState.addCycles(1);
        }
        return addr;
    }
    case AddressingMode::Indirect: {
        const u32 ptr = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        const u32 highByte = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        const u32 indirectAddr = ptr | (highByte << 8);
        const u8 low = memory.readMemory(indirectAddr);
        const u8 high = memory.readMemory((indirectAddr & 0xFF00) | ((indirectAddr + 1) & 0x00FF));
        return static_cast<u32>(low) | (static_cast<u32>(high) << 8);
    }
    case AddressingMode::IndirectX: {
        const u8 zp = (cpu_.fetchOperand(cpuState.getPC()) + cpuState.getX()) & 0xFF;
        cpuState.incrementPC();
        const u32 targetAddr = cpu_.readWordZeroPage(zp);
        if (cpu_.onIndirectReadCallback_) {
            cpu_.onIndirectReadCallback_(cpu_.originalPc_, zp, targetAddr);
        }
        return targetAddr;
    }
    case AddressingMode::IndirectY: {
        const u8 zpAddr = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        const u32 base = cpu_.readWordZeroPage(zpAddr);
        const u32 addr = base + cpuState.getY();
        if (cpu_.onIndirectReadCallback_) {
            cpu_.onIndirectReadCallback_(cpu_.originalPc_, zpAddr, addr);
        }
        if ((base & 0xFF00) != (addr & 0xFF00)) {
            cpuState.addCycles(1);
        }
        return addr;
    }
    default:
        std::cout << "Unsupported addressing mode: " << static_cast<int>(mode) << std::endl;
        return 0;
    }
}
void AddressingModes::recordIndexOffset(u32 pc, u8 offset) {
    cpu_.recordIndexOffset(pc, offset);
}
```


### FILE: src/6510/CPU6510Impl.cpp
```cpp
#include "CPU6510Impl.h"
#include "SIDwinderUtils.h"
#include "MemoryConstants.h"
#include <algorithm>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <set>
#include <sstream>
using namespace sidwinder;
CPU6510Impl::CPU6510Impl()
    : cpuState_(*this),
    memory_(*this),
    instructionExecutor_(*this),
    addressingModes_(*this)
{
    reset();
}
void CPU6510Impl::reset() {
    cpuState_.reset();
    memory_.reset();
    originalPc_ = 0;
    onIndirectReadCallback_ = nullptr;
    onWriteMemoryCallback_ = nullptr;
    onCIAWriteCallback_ = nullptr;
    onSIDWriteCallback_ = nullptr;
    onVICWriteCallback_ = nullptr;
}
void CPU6510Impl::resetRegistersAndFlags() {
    cpuState_.setA(0);
    cpuState_.setX(0);
    cpuState_.setY(0);
    cpuState_.setStatus(static_cast<u8>(StatusFlag::Interrupt) | static_cast<u8>(StatusFlag::Unused));
}
void CPU6510Impl::step() {
    originalPc_ = cpuState_.getPC();
    const u8 opcode = fetchOpcode(cpuState_.getPC());
    cpuState_.incrementPC();
    const OpcodeInfo& info = opcodeTable_[opcode];
    instructionExecutor_.execute(info.instruction, info.mode);
    cpuState_.addCycles(info.cycles);
}
bool CPU6510Impl::executeFunction(u32 address) {
    const int MAX_STEPS = DEFAULT_SID_EMULATION_FRAMES;
    int stepCount = 0;
    const int HISTORY_SIZE = 8;
    u32 pcHistory[HISTORY_SIZE] = { 0 };
    int historyIndex = 0;
    const u32 returnAddress = cpuState_.getPC() - 1; 
    push((returnAddress >> 8) & 0xFF); 
    push(returnAddress & 0xFF);         
    cpuState_.setPC(address);
    const u8 targetSP = cpuState_.getSP(); 
    while (stepCount < MAX_STEPS) {
        const u32 currentPC = cpuState_.getPC();
        pcHistory[historyIndex] = currentPC;
        historyIndex = (historyIndex + 1) % HISTORY_SIZE;
        if (currentPC < 0x0002) {  
            util::Logger::error("CRITICAL: Execution at $" +
                util::wordToHex(currentPC) +
                " detected - illegal jump target");
            return false;
        }
        const u8 opcode = fetchOpcode(currentPC);
        const auto mode = getAddressingMode(opcode);
        const int size = getInstructionSize(opcode);
        step();
        stepCount++;
        if (opcodeTable_[opcode].instruction == Instruction::RTS) {
            if (cpuState_.getSP() == targetSP + 2) { 
                break;
            }
        }
    }
    if (stepCount >= MAX_STEPS) {
        util::Logger::error("Function execution aborted after " + std::to_string(MAX_STEPS) +
            " steps - possible infinite loop");
        util::Logger::error("Last PC: $" + util::wordToHex(cpuState_.getPC()) +
            ", SP: $" + util::byteToHex(cpuState_.getSP()));
        std::ostringstream pcHistoryStr;
        pcHistoryStr << "Recent PC history: ";
        for (int i = 0; i < HISTORY_SIZE; i++) {
            int idx = (historyIndex + i) % HISTORY_SIZE;
            pcHistoryStr << "$" << util::wordToHex(pcHistory[idx]) << " ";
        }
        util::Logger::error(pcHistoryStr.str());
        return false;
    }
    return true;
}
void CPU6510Impl::jumpTo(u32 address) {
    cpuState_.setPC(address);
}
u8 CPU6510Impl::readMemory(u32 addr) {
    return memory_.readMemory(addr);
}
void CPU6510Impl::writeByte(u32 addr, u8 value) {
    memory_.writeByte(addr, value);
}
void CPU6510Impl::writeMemory(u32 addr, u8 value) {
    memory_.writeMemory(addr, value, originalPc_);
    if (onWriteMemoryCallback_) {
        onWriteMemoryCallback_(addr, value);
    }
    if (onCIAWriteCallback_ && MemoryConstants::isCIA(addr)) {
        onCIAWriteCallback_(addr, value);
    }
    if (onSIDWriteCallback_ && MemoryConstants::isSID(addr)) {
        onSIDWriteCallback_(addr, value);
    }
    if (onVICWriteCallback_ && MemoryConstants::isVIC(addr)) {
        onVICWriteCallback_(addr, value);
    }
}
void CPU6510Impl::copyMemoryBlock(u32 start, std::span<const u8> data) {
    memory_.copyMemoryBlock(start, data);
}
void CPU6510Impl::loadData(const std::string& filename, u32 loadAddress) {
    std::ifstream file(filename, std::ios::binary);
    if (!file) {
        throw std::runtime_error("Failed to open file: " + filename);
    }
    u32 addr = loadAddress;
    u8 byte;
    while (file.read(reinterpret_cast<char*>(&byte), 1)) {
        memory_.writeByte(addr++, byte);
    }
}
void CPU6510Impl::setPC(u32 address) {
    cpuState_.setPC(address);
}
u32 CPU6510Impl::getPC() const {
    return cpuState_.getPC();
}
void CPU6510Impl::setSP(u8 sp) {
    cpuState_.setSP(sp);
}
u8 CPU6510Impl::getSP() const {
    return cpuState_.getSP();
}
u64 CPU6510Impl::getCycles() const {
    return cpuState_.getCycles();
}
void CPU6510Impl::setCycles(u64 newCycles) {
    cpuState_.setCycles(newCycles);
}
void CPU6510Impl::resetCycles() {
    cpuState_.resetCycles();
}
u8 CPU6510Impl::fetchOpcode(u32 addr) {
    memory_.markMemoryAccess(addr, MemoryAccessFlag::Execute);
    memory_.markMemoryAccess(addr, MemoryAccessFlag::OpCode);
    return memory_.getMemoryAt(addr);
}
u8 CPU6510Impl::fetchOperand(u32 addr) {
    memory_.markMemoryAccess(addr, MemoryAccessFlag::Execute);
    return memory_.getMemoryAt(addr);
}
u8 CPU6510Impl::readByAddressingMode(u32 addr, AddressingMode mode) {
    switch (mode) {
    case AddressingMode::Indirect:
    case AddressingMode::Immediate:
        return fetchOperand(addr);
    default:
        return readMemory(addr);
    }
}
void CPU6510Impl::push(u8 value) {
    memory_.writeByte(0x0100 + cpuState_.getSP(), value);
    cpuState_.decrementSP();
}
u8 CPU6510Impl::pop() {
    cpuState_.incrementSP();
    return memory_.getMemoryAt(0x0100 + cpuState_.getSP());
}
u16 CPU6510Impl::readWord(u32 addr) {
    const u8 low = readMemory(addr);
    const u8 high = readMemory(addr + 1);
    return static_cast<u16>(low) | (static_cast<u16>(high) << 8);
}
u16 CPU6510Impl::readWordZeroPage(u8 addr) {
    const u8 low = readMemory(addr);
    const u8 high = readMemory((addr + 1) & 0xFF); 
    return static_cast<u16>(low) | (static_cast<u16>(high) << 8);
}
std::string_view CPU6510Impl::getMnemonic(u8 opcode) const {
    return opcodeTable_[opcode].mnemonic;
}
u8 CPU6510Impl::getInstructionSize(u8 opcode) const {
    const AddressingMode mode = opcodeTable_[opcode].mode;
    switch (mode) {
    case AddressingMode::Immediate:
    case AddressingMode::ZeroPage:
    case AddressingMode::ZeroPageX:
    case AddressingMode::ZeroPageY:
    case AddressingMode::Relative:
    case AddressingMode::IndirectX:
    case AddressingMode::IndirectY:
        return 2;
    case AddressingMode::Absolute:
    case AddressingMode::AbsoluteX:
    case AddressingMode::AbsoluteY:
    case AddressingMode::Indirect:
        return 3;
    case AddressingMode::Accumulator:
    case AddressingMode::Implied:
    default:
        return 1;
    }
}
AddressingMode CPU6510Impl::getAddressingMode(u8 opcode) const {
    return opcodeTable_[opcode].mode;
}
bool CPU6510Impl::isIllegalInstruction(u8 opcode) const {
    return opcodeTable_[opcode].illegal;
}
void CPU6510Impl::recordIndexOffset(u32 pc, u8 offset) {
    pcIndexRanges_[pc].update(offset);
}
std::pair<u8, u8> CPU6510Impl::getIndexRange(u32 pc) const {
    auto it = pcIndexRanges_.find(pc);
    if (it == pcIndexRanges_.end()) {
        return { 0, 0 };
    }
    return it->second.getRange();
}
void CPU6510Impl::dumpMemoryAccess(const std::string& filename) {
    memory_.dumpMemoryAccess(filename);
}
std::span<const u8> CPU6510Impl::getMemory() const {
    return memory_.getMemory();
}
std::span<const u8> CPU6510Impl::getMemoryAccess() const {
    return memory_.getMemoryAccess();
}
u32 CPU6510Impl::getLastWriteTo(u32 addr) const {
    return memory_.getLastWriteTo(addr);
}
const std::vector<u32>& CPU6510Impl::getLastWriteToAddr() const {
    return memory_.getLastWriteToAddr();
}
RegisterSourceInfo CPU6510Impl::getRegSourceA() const {
    return cpuState_.getRegSourceA();
}
RegisterSourceInfo CPU6510Impl::getRegSourceX() const {
    return cpuState_.getRegSourceX();
}
RegisterSourceInfo CPU6510Impl::getRegSourceY() const {
    return cpuState_.getRegSourceY();
}
RegisterSourceInfo CPU6510Impl::getWriteSourceInfo(u32 addr) const {
    return memory_.getWriteSourceInfo(addr);
}
void CPU6510Impl::setOnIndirectReadCallback(IndirectReadCallback callback) {
    onIndirectReadCallback_ = std::move(callback);
}
void CPU6510Impl::setOnWriteMemoryCallback(MemoryWriteCallback callback) {
    onWriteMemoryCallback_ = std::move(callback);
}
void CPU6510Impl::setOnCIAWriteCallback(MemoryWriteCallback callback) {
    onCIAWriteCallback_ = std::move(callback);
}
void CPU6510Impl::setOnSIDWriteCallback(MemoryWriteCallback callback) {
    onSIDWriteCallback_ = std::move(callback);
}
void CPU6510Impl::setOnVICWriteCallback(MemoryWriteCallback callback) {
    onVICWriteCallback_ = std::move(callback);
}
void CPU6510Impl::setOnMemoryFlowCallback(MemoryFlowCallback callback) {
    onMemoryFlowCallback_ = std::move(callback);
}
const MemoryDataFlow& CPU6510Impl::getMemoryDataFlow() const {
    return memory_.getMemoryDataFlow();
}
```


### FILE: src/6510/CPUState.cpp
```cpp
#include "CPUState.h"
#include "CPU6510Impl.h"
CPUState::CPUState(CPU6510Impl& cpu) : cpu_(cpu) {
    reset();
}
void CPUState::reset() {
    pc_ = 0;
    sp_ = 0xFD;
    regA_ = regX_ = regY_ = 0;
    statusReg_ = static_cast<u8>(StatusFlag::Interrupt) | static_cast<u8>(StatusFlag::Unused);
    cycles_ = 0;
    regSourceA_ = regSourceX_ = regSourceY_ = RegisterSourceInfo{};
}
u16 CPUState::getPC() const {
    return pc_;
}
void CPUState::setPC(u16 value) {
    pc_ = value;
}
void CPUState::incrementPC() {
    pc_++;
}
u8 CPUState::getSP() const {
    return sp_;
}
void CPUState::setSP(u8 value) {
    sp_ = value;
}
void CPUState::incrementSP() {
    sp_++;
}
void CPUState::decrementSP() {
    sp_--;
}
u8 CPUState::getA() const {
    return regA_;
}
void CPUState::setA(u8 value) {
    regA_ = value;
}
u8 CPUState::getX() const {
    return regX_;
}
void CPUState::setX(u8 value) {
    regX_ = value;
}
u8 CPUState::getY() const {
    return regY_;
}
void CPUState::setY(u8 value) {
    regY_ = value;
}
u8 CPUState::getStatus() const {
    return statusReg_;
}
void CPUState::setStatus(u8 value) {
    statusReg_ = value;
}
void CPUState::setFlag(StatusFlag flag, bool value) {
    if (value) {
        statusReg_ |= static_cast<u8>(flag);
    }
    else {
        statusReg_ &= ~static_cast<u8>(flag);
    }
}
bool CPUState::testFlag(StatusFlag flag) const {
    return (statusReg_ & static_cast<u8>(flag)) != 0;
}
void CPUState::setZN(u8 value) {
    setFlag(StatusFlag::Zero, value == 0);
    setFlag(StatusFlag::Negative, (value & 0x80) != 0);
}
u64 CPUState::getCycles() const {
    return cycles_;
}
void CPUState::setCycles(u64 newCycles) {
    cycles_ = newCycles;
}
void CPUState::addCycles(u64 cycles) {
    cycles_ += cycles;
}
void CPUState::resetCycles() {
    cycles_ = 0;
}
RegisterSourceInfo CPUState::getRegSourceA() const {
    return regSourceA_;
}
void CPUState::setRegSourceA(const RegisterSourceInfo& info) {
    regSourceA_ = info;
}
RegisterSourceInfo CPUState::getRegSourceX() const {
    return regSourceX_;
}
void CPUState::setRegSourceX(const RegisterSourceInfo& info) {
    regSourceX_ = info;
}
RegisterSourceInfo CPUState::getRegSourceY() const {
    return regSourceY_;
}
void CPUState::setRegSourceY(const RegisterSourceInfo& info) {
    regSourceY_ = info;
}
```


### FILE: src/6510/InstructionExecutor.cpp
```cpp
#include "InstructionExecutor.h"
#include "CPU6510Impl.h"
#include <iostream>
InstructionExecutor::InstructionExecutor(CPU6510Impl& cpu) : cpu_(cpu) {
}
void InstructionExecutor::execute(Instruction instr, AddressingMode mode) {
    executeInstruction(instr, mode);
}
void InstructionExecutor::executeInstruction(Instruction instr, AddressingMode mode) {
    switch (instr) {
    case Instruction::LDA:
    case Instruction::LDX:
    case Instruction::LDY:
    case Instruction::LAX:
        executeLoad(instr, mode);
        break;
    case Instruction::STA:
    case Instruction::STX:
    case Instruction::STY:
    case Instruction::SAX:
        executeStore(instr, mode);
        break;
    case Instruction::ADC:
    case Instruction::SBC:
    case Instruction::INC:
    case Instruction::INX:
    case Instruction::INY:
    case Instruction::DEC:
    case Instruction::DEX:
    case Instruction::DEY:
        executeArithmetic(instr, mode);
        break;
    case Instruction::AND:
    case Instruction::ORA:
    case Instruction::EOR:
    case Instruction::BIT:
        executeLogical(instr, mode);
        break;
    case Instruction::BCC:
    case Instruction::BCS:
    case Instruction::BEQ:
    case Instruction::BMI:
    case Instruction::BNE:
    case Instruction::BPL:
    case Instruction::BVC:
    case Instruction::BVS:
        executeBranch(instr, mode);
        break;
    case Instruction::JMP:
    case Instruction::JSR:
    case Instruction::RTS:
    case Instruction::RTI:
    case Instruction::BRK:
        executeJump(instr, mode);
        break;
    case Instruction::PHA:
    case Instruction::PHP:
    case Instruction::PLA:
    case Instruction::PLP:
        executeStack(instr, mode);
        break;
    case Instruction::TAX:
    case Instruction::TAY:
    case Instruction::TXA:
    case Instruction::TYA:
    case Instruction::TSX:
    case Instruction::TXS:
        executeRegister(instr, mode);
        break;
    case Instruction::CLC:
    case Instruction::CLD:
    case Instruction::CLI:
    case Instruction::CLV:
    case Instruction::SEC:
    case Instruction::SED:
    case Instruction::SEI:
        executeFlag(instr, mode);
        break;
    case Instruction::ASL:
    case Instruction::LSR:
    case Instruction::ROL:
    case Instruction::ROR:
        executeShift(instr, mode);
        break;
    case Instruction::CMP:
    case Instruction::CPX:
    case Instruction::CPY:
        executeCompare(instr, mode);
        break;
    case Instruction::NOP:
        break;
    case Instruction::SLO:
    case Instruction::RLA:
    case Instruction::SRE:
    case Instruction::RRA:
    case Instruction::DCP:
    case Instruction::ISC:
    case Instruction::ANC:
    case Instruction::ALR:
    case Instruction::ARR:
    case Instruction::AXS:
    case Instruction::KIL:
    case Instruction::LAS:
    case Instruction::AHX:
    case Instruction::TAS:
    case Instruction::SHA:
    case Instruction::SHX:
    case Instruction::SHY:
    case Instruction::XAA:
        executeIllegal(instr, mode);
        break;
    default:
        std::cout << "Unimplemented instruction: " << static_cast<int>(instr) << std::endl;
        break;
    }
}
void InstructionExecutor::executeLoad(Instruction instr, AddressingMode mode) {
    const u32 addr = cpu_.addressingModes_.getAddress(mode);
    const u8 value = cpu_.readByAddressingMode(addr, mode);
    u8 index = 0;
    bool isIndexed = false;  
    if (mode == AddressingMode::AbsoluteY || mode == AddressingMode::ZeroPageY || mode == AddressingMode::IndirectY) {
        index = cpu_.cpuState_.getY();
        isIndexed = true;
    }
    else if (mode == AddressingMode::AbsoluteX || mode == AddressingMode::ZeroPageX || mode == AddressingMode::IndirectX) {
        index = cpu_.cpuState_.getX();
        isIndexed = true;
    }
    RegisterSourceInfo sourceInfo = {
        RegisterSourceInfo::SourceType::Memory,
        addr,
        value,
        index
    };
    char targetReg = 'A';  
    switch (instr) {
    case Instruction::LDA:
        cpu_.cpuState_.setA(value);
        cpu_.cpuState_.setRegSourceA(sourceInfo);
        targetReg = 'A';
        break;
    case Instruction::LDX:
        cpu_.cpuState_.setX(value);
        cpu_.cpuState_.setRegSourceX(sourceInfo);
        targetReg = 'X';
        break;
    case Instruction::LDY:
        cpu_.cpuState_.setY(value);
        cpu_.cpuState_.setRegSourceY(sourceInfo);
        targetReg = 'Y';
        break;
    case Instruction::LAX:
        cpu_.cpuState_.setA(value);
        cpu_.cpuState_.setX(value);
        cpu_.cpuState_.setRegSourceA(sourceInfo);
        cpu_.cpuState_.setRegSourceX(sourceInfo);
        targetReg = 'A';  
        break;
    default:
        break;
    }
    if (mode != AddressingMode::Immediate && cpu_.onMemoryFlowCallback_) {
        cpu_.onMemoryFlowCallback_(cpu_.originalPc_, targetReg, addr, value, isIndexed);
    }
    if (instr == Instruction::LDX || instr == Instruction::LAX) {
        cpu_.cpuState_.setZN(cpu_.cpuState_.getX());
    }
    else if (instr == Instruction::LDY) {
        cpu_.cpuState_.setZN(cpu_.cpuState_.getY());
    }
    else {
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
    }
}
void InstructionExecutor::executeStore(Instruction instr, AddressingMode mode) {
    const u32 addr = cpu_.addressingModes_.getAddress(mode);
    switch (instr) {
    case Instruction::STA:
        cpu_.memory_.setWriteSourceInfo(addr, cpu_.cpuState_.getRegSourceA());
        cpu_.writeMemory(addr, cpu_.cpuState_.getA());
        break;
    case Instruction::STX:
        cpu_.memory_.setWriteSourceInfo(addr, cpu_.cpuState_.getRegSourceX());
        cpu_.writeMemory(addr, cpu_.cpuState_.getX());
        break;
    case Instruction::STY:
        cpu_.memory_.setWriteSourceInfo(addr, cpu_.cpuState_.getRegSourceY());
        cpu_.writeMemory(addr, cpu_.cpuState_.getY());
        break;
    case Instruction::SAX:
        cpu_.writeMemory(addr, cpu_.cpuState_.getA() & cpu_.cpuState_.getX());
        break;
    default:
        break;
    }
}
void InstructionExecutor::executeArithmetic(Instruction instr, AddressingMode mode) {
    switch (instr) {
    case Instruction::ADC: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);
        if (cpu_.cpuState_.testFlag(StatusFlag::Decimal)) {
            u8 al = (cpu_.cpuState_.getA() & 0x0F) + (value & 0x0F) + (cpu_.cpuState_.testFlag(StatusFlag::Carry) ? 1 : 0);
            u8 ah = (cpu_.cpuState_.getA() >> 4) + (value >> 4);
            if (al > 9) {
                al -= 10;
                ah++;
            }
            if (ah > 9) {
                ah -= 10;
                cpu_.cpuState_.setFlag(StatusFlag::Carry, true);
            }
            else {
                cpu_.cpuState_.setFlag(StatusFlag::Carry, false);
            }
            const u8 result = (ah << 4) | (al & 0x0F);
            cpu_.cpuState_.setA(result);
            cpu_.cpuState_.setZN(result);
        }
        else {
            const u32 sum = static_cast<u32>(cpu_.cpuState_.getA()) + static_cast<u32>(value) + (cpu_.cpuState_.testFlag(StatusFlag::Carry) ? 1 : 0);
            cpu_.cpuState_.setFlag(StatusFlag::Carry, sum > 0xFF);
            cpu_.cpuState_.setFlag(StatusFlag::Zero, (sum & 0xFF) == 0);
            cpu_.cpuState_.setFlag(StatusFlag::Overflow,
                ((~(cpu_.cpuState_.getA() ^ value) & (cpu_.cpuState_.getA() ^ sum) & 0x80) != 0));
            cpu_.cpuState_.setFlag(StatusFlag::Negative, (sum & 0x80) != 0);
            cpu_.cpuState_.setA(static_cast<u8>(sum & 0xFF));
        }
        break;
    }
    case Instruction::SBC: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);
        const u8 invertedValue = value ^ 0xFF;
        if (cpu_.cpuState_.testFlag(StatusFlag::Decimal)) {
            u8 al = (cpu_.cpuState_.getA() & 0x0F) + (invertedValue & 0x0F) +
                (cpu_.cpuState_.testFlag(StatusFlag::Carry) ? 1 : 0);
            u8 ah = (cpu_.cpuState_.getA() >> 4) + (invertedValue >> 4);
            if (al > 9) {
                al -= 10;
                ah++;
            }
            if (ah > 9) {
                ah -= 10;
                cpu_.cpuState_.setFlag(StatusFlag::Carry, true);
            }
            else {
                cpu_.cpuState_.setFlag(StatusFlag::Carry, false);
            }
            const u8 result = (ah << 4) | (al & 0x0F);
            cpu_.cpuState_.setA(result);
            cpu_.cpuState_.setZN(result);
        }
        else {
            const u32 diff = static_cast<u32>(cpu_.cpuState_.getA()) + static_cast<u32>(invertedValue) + (cpu_.cpuState_.testFlag(StatusFlag::Carry) ? 1 : 0);
            cpu_.cpuState_.setFlag(StatusFlag::Carry, diff > 0xFF);
            cpu_.cpuState_.setFlag(StatusFlag::Zero, (diff & 0xFF) == 0);
            cpu_.cpuState_.setFlag(StatusFlag::Overflow, ((~(cpu_.cpuState_.getA() ^ invertedValue) & (cpu_.cpuState_.getA() ^ diff) & 0x80) != 0));
            cpu_.cpuState_.setFlag(StatusFlag::Negative, (diff & 0x80) != 0);
            cpu_.cpuState_.setA(static_cast<u8>(diff & 0xFF));
        }
        break;
    }
    case Instruction::INC: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);
        value++;
        cpu_.writeMemory(addr, value);
        cpu_.cpuState_.setZN(value);
        break;
    }
    case Instruction::INX:
        cpu_.cpuState_.setX(cpu_.cpuState_.getX() + 1);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getX());
        break;
    case Instruction::INY:
        cpu_.cpuState_.setY(cpu_.cpuState_.getY() + 1);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getY());
        break;
    case Instruction::DEC: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);
        value--;
        cpu_.writeMemory(addr, value);
        cpu_.cpuState_.setZN(value);
        break;
    }
    case Instruction::DEX:
        cpu_.cpuState_.setX(cpu_.cpuState_.getX() - 1);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getX());
        break;
    case Instruction::DEY:
        cpu_.cpuState_.setY(cpu_.cpuState_.getY() - 1);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getY());
        break;
    default:
        break;
    }
}
void InstructionExecutor::executeLogical(Instruction instr, AddressingMode mode) {
    const u32 addr = cpu_.addressingModes_.getAddress(mode);
    const u8 value = cpu_.readByAddressingMode(addr, mode);
    switch (instr) {
    case Instruction::AND:
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() & value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    case Instruction::ORA:
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() | value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    case Instruction::EOR:
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() ^ value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    case Instruction::BIT:
        cpu_.cpuState_.setFlag(StatusFlag::Zero, (cpu_.cpuState_.getA() & value) == 0);
        cpu_.cpuState_.setFlag(StatusFlag::Negative, (value & 0x80) != 0);
        cpu_.cpuState_.setFlag(StatusFlag::Overflow, (value & 0x40) != 0);
        break;
    default:
        break;
    }
}
void InstructionExecutor::executeBranch(Instruction instr, AddressingMode mode) {
    const i8 offset = static_cast<i8>(cpu_.fetchOperand(cpu_.cpuState_.getPC()));
    cpu_.cpuState_.incrementPC();
    bool branchTaken = false;
    switch (instr) {
    case Instruction::BCC:
        branchTaken = !cpu_.cpuState_.testFlag(StatusFlag::Carry);
        break;
    case Instruction::BCS:
        branchTaken = cpu_.cpuState_.testFlag(StatusFlag::Carry);
        break;
    case Instruction::BEQ:
        branchTaken = cpu_.cpuState_.testFlag(StatusFlag::Zero);
        break;
    case Instruction::BMI:
        branchTaken = cpu_.cpuState_.testFlag(StatusFlag::Negative);
        break;
    case Instruction::BNE:
        branchTaken = !cpu_.cpuState_.testFlag(StatusFlag::Zero);
        break;
    case Instruction::BPL:
        branchTaken = !cpu_.cpuState_.testFlag(StatusFlag::Negative);
        break;
    case Instruction::BVC:
        branchTaken = !cpu_.cpuState_.testFlag(StatusFlag::Overflow);
        break;
    case Instruction::BVS:
        branchTaken = cpu_.cpuState_.testFlag(StatusFlag::Overflow);
        break;
    default:
        break;
    }
    if (branchTaken) {
        const u32 oldPC = cpu_.cpuState_.getPC();
        const u32 newPC = oldPC + offset;
        cpu_.cpuState_.setPC(newPC);
        cpu_.memory_.markMemoryAccess(newPC, MemoryAccessFlag::JumpTarget);
        cpu_.cpuState_.addCycles(1);
        if ((oldPC & 0xFF00) != (newPC & 0xFF00)) {
            cpu_.cpuState_.addCycles(1);
        }
    }
}
void InstructionExecutor::executeJump(Instruction instr, AddressingMode mode) {
    switch (instr) {
    case Instruction::JMP: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        cpu_.memory_.markMemoryAccess(addr, MemoryAccessFlag::JumpTarget);
        cpu_.cpuState_.setPC(addr);
        break;
    }
    case Instruction::JSR: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        cpu_.memory_.markMemoryAccess(addr, MemoryAccessFlag::JumpTarget);
        u32 returnAddr = cpu_.cpuState_.getPC() - 1;
        cpu_.push((returnAddr >> 8) & 0xFF); 
        cpu_.push(returnAddr & 0xFF);        
        cpu_.cpuState_.setPC(addr);
        break;
    }
    case Instruction::RTS: {
        const u8 lo = cpu_.pop();
        const u8 hi = cpu_.pop();
        const u32 addr = (hi << 8) | lo;
        cpu_.cpuState_.setPC(addr + 1); 
        break;
    }
    case Instruction::RTI: {
        const u8 status = cpu_.pop();
        const u8 lo = cpu_.pop();
        const u8 hi = cpu_.pop();
        const u32 addr = (hi << 8) | lo;
        cpu_.cpuState_.setStatus(status);
        cpu_.cpuState_.setPC(addr);
        break;
    }
    case Instruction::BRK: {
        cpu_.cpuState_.incrementPC();
        u32 returnAddr = cpu_.cpuState_.getPC();
        cpu_.push((returnAddr >> 8) & 0xFF); 
        cpu_.push(returnAddr & 0xFF);        
        cpu_.push(cpu_.cpuState_.getStatus() |
            static_cast<u8>(StatusFlag::Break) |
            static_cast<u8>(StatusFlag::Unused));
        cpu_.cpuState_.setFlag(StatusFlag::Interrupt, true);
        const u32 vectorAddr = cpu_.readMemory(0xFFFE) | (cpu_.readMemory(0xFFFF) << 8);
        cpu_.cpuState_.setPC(vectorAddr);
        break;
    }
    default:
        break;
    }
}
void InstructionExecutor::executeStack(Instruction instr, AddressingMode mode) {
    switch (instr) {
    case Instruction::PHA:
        cpu_.push(cpu_.cpuState_.getA());
        break;
    case Instruction::PHP:
        cpu_.push(cpu_.cpuState_.getStatus() |
            static_cast<u8>(StatusFlag::Break) |
            static_cast<u8>(StatusFlag::Unused));
        break;
    case Instruction::PLA:
        cpu_.cpuState_.setA(cpu_.pop());
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    case Instruction::PLP:
        cpu_.cpuState_.setStatus(cpu_.pop());
        break;
    default:
        break;
    }
}
void InstructionExecutor::executeRegister(Instruction instr, AddressingMode mode) {
    switch (instr) {
    case Instruction::TAX:
        cpu_.cpuState_.setX(cpu_.cpuState_.getA());
        cpu_.cpuState_.setZN(cpu_.cpuState_.getX());
        break;
    case Instruction::TAY:
        cpu_.cpuState_.setY(cpu_.cpuState_.getA());
        cpu_.cpuState_.setZN(cpu_.cpuState_.getY());
        break;
    case Instruction::TXA:
        cpu_.cpuState_.setA(cpu_.cpuState_.getX());
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    case Instruction::TYA:
        cpu_.cpuState_.setA(cpu_.cpuState_.getY());
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    case Instruction::TSX:
        cpu_.cpuState_.setX(cpu_.cpuState_.getSP());
        cpu_.cpuState_.setZN(cpu_.cpuState_.getX());
        break;
    case Instruction::TXS:
        cpu_.cpuState_.setSP(cpu_.cpuState_.getX());
        break;
    default:
        break;
    }
}
void InstructionExecutor::executeFlag(Instruction instr, AddressingMode mode) {
    switch (instr) {
    case Instruction::CLC:
        cpu_.cpuState_.setFlag(StatusFlag::Carry, false);
        break;
    case Instruction::CLD:
        cpu_.cpuState_.setFlag(StatusFlag::Decimal, false);
        break;
    case Instruction::CLI:
        cpu_.cpuState_.setFlag(StatusFlag::Interrupt, false);
        break;
    case Instruction::CLV:
        cpu_.cpuState_.setFlag(StatusFlag::Overflow, false);
        break;
    case Instruction::SEC:
        cpu_.cpuState_.setFlag(StatusFlag::Carry, true);
        break;
    case Instruction::SED:
        cpu_.cpuState_.setFlag(StatusFlag::Decimal, true);
        break;
    case Instruction::SEI:
        cpu_.cpuState_.setFlag(StatusFlag::Interrupt, true);
        break;
    default:
        break;
    }
}
void InstructionExecutor::executeShift(Instruction instr, AddressingMode mode) {
    u32 addr = 0;
    u8 value = 0;
    if (mode == AddressingMode::Accumulator) {
        value = cpu_.cpuState_.getA();
    }
    else {
        addr = cpu_.addressingModes_.getAddress(mode);
        value = cpu_.readByAddressingMode(addr, mode);
    }
    switch (instr) {
    case Instruction::ASL: {
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x80) != 0);
        value <<= 1;
        break;
    }
    case Instruction::LSR: {
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x01) != 0);
        value >>= 1;
        break;
    }
    case Instruction::ROL: {
        const bool oldCarry = cpu_.cpuState_.testFlag(StatusFlag::Carry);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x80) != 0);
        value = (value << 1) | (oldCarry ? 1 : 0);
        break;
    }
    case Instruction::ROR: {
        const bool oldCarry = cpu_.cpuState_.testFlag(StatusFlag::Carry);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x01) != 0);
        value = (value >> 1) | (oldCarry ? 0x80 : 0x00);
        break;
    }
    default:
        break;
    }
    cpu_.cpuState_.setZN(value);
    if (mode == AddressingMode::Accumulator) {
        cpu_.cpuState_.setA(value);
    }
    else {
        cpu_.writeMemory(addr, value);
    }
}
void InstructionExecutor::executeCompare(Instruction instr, AddressingMode mode) {
    const u32 addr = cpu_.addressingModes_.getAddress(mode);
    const u8 value = cpu_.readByAddressingMode(addr, mode);
    u8 regValue = 0;
    switch (instr) {
    case Instruction::CMP:
        regValue = cpu_.cpuState_.getA();
        break;
    case Instruction::CPX:
        regValue = cpu_.cpuState_.getX();
        break;
    case Instruction::CPY:
        regValue = cpu_.cpuState_.getY();
        break;
    default:
        break;
    }
    cpu_.cpuState_.setFlag(StatusFlag::Carry, regValue >= value);
    cpu_.cpuState_.setFlag(StatusFlag::Zero, regValue == value);
    cpu_.cpuState_.setFlag(StatusFlag::Negative, ((regValue - value) & 0x80) != 0);
}
void InstructionExecutor::executeIllegal(Instruction instr, AddressingMode mode) {
    switch (instr) {
    case Instruction::SLO: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x80) != 0);
        value <<= 1;
        cpu_.writeMemory(addr, value);
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() | value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    }
    case Instruction::RLA: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);
        const bool oldCarry = cpu_.cpuState_.testFlag(StatusFlag::Carry);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x80) != 0);
        value = (value << 1) | (oldCarry ? 1 : 0);
        cpu_.writeMemory(addr, value);
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() & value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    }
    case Instruction::SRE: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x01) != 0);
        value >>= 1;
        cpu_.writeMemory(addr, value);
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() ^ value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    }
    case Instruction::RRA: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);
        const bool oldCarry = cpu_.cpuState_.testFlag(StatusFlag::Carry);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x01) != 0);
        value = (value >> 1) | (oldCarry ? 0x80 : 0x00);
        cpu_.writeMemory(addr, value);
        const u32 sum = static_cast<u32>(cpu_.cpuState_.getA()) + static_cast<u32>(value) + (cpu_.cpuState_.testFlag(StatusFlag::Carry) ? 1 : 0);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, sum > 0xFF);
        cpu_.cpuState_.setFlag(StatusFlag::Zero, (sum & 0xFF) == 0);
        cpu_.cpuState_.setFlag(StatusFlag::Overflow, ((~(cpu_.cpuState_.getA() ^ value) & (cpu_.cpuState_.getA() ^ sum) & 0x80) != 0));
        cpu_.cpuState_.setFlag(StatusFlag::Negative, (sum & 0x80) != 0);
        cpu_.cpuState_.setA(static_cast<u8>(sum & 0xFF));
        break;
    }
    case Instruction::DCP: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);
        value--;
        cpu_.writeMemory(addr, value);
        const u8 regA = cpu_.cpuState_.getA();
        cpu_.cpuState_.setFlag(StatusFlag::Carry, regA >= value);
        cpu_.cpuState_.setFlag(StatusFlag::Zero, regA == value);
        cpu_.cpuState_.setFlag(StatusFlag::Negative, ((regA - value) & 0x80) != 0);
        break;
    }
    case Instruction::ISC: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);
        value++;
        cpu_.writeMemory(addr, value);
        const u8 invertedValue = value ^ 0xFF;
        const u32 diff = static_cast<u32>(cpu_.cpuState_.getA()) + static_cast<u32>(invertedValue) + (cpu_.cpuState_.testFlag(StatusFlag::Carry) ? 1 : 0);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, diff > 0xFF);
        cpu_.cpuState_.setFlag(StatusFlag::Zero, (diff & 0xFF) == 0);
        cpu_.cpuState_.setFlag(StatusFlag::Overflow,
            ((~(cpu_.cpuState_.getA() ^ invertedValue) & (cpu_.cpuState_.getA() ^ diff) & 0x80) != 0));
        cpu_.cpuState_.setFlag(StatusFlag::Negative, (diff & 0x80) != 0);
        cpu_.cpuState_.setA(static_cast<u8>(diff & 0xFF));
        break;
    }
    case Instruction::ANC: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() & value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (cpu_.cpuState_.getA() & 0x80) != 0);
        break;
    }
    case Instruction::ALR: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() & value);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (cpu_.cpuState_.getA() & 0x01) != 0);
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() >> 1);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    }
    case Instruction::ARR: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() & value);
        const bool oldCarry = cpu_.cpuState_.testFlag(StatusFlag::Carry);
        cpu_.cpuState_.setA((cpu_.cpuState_.getA() >> 1) | (oldCarry ? 0x80 : 0x00));
        cpu_.cpuState_.setFlag(StatusFlag::Zero, cpu_.cpuState_.getA() == 0);
        cpu_.cpuState_.setFlag(StatusFlag::Negative, (cpu_.cpuState_.getA() & 0x80) != 0);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (cpu_.cpuState_.getA() & 0x40) != 0);
        cpu_.cpuState_.setFlag(StatusFlag::Overflow,
            ((cpu_.cpuState_.getA() & 0x40) ^ ((cpu_.cpuState_.getA() & 0x20) << 1)) != 0);
        break;
    }
    case Instruction::AXS: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);
        const u8 temp = cpu_.cpuState_.getA() & cpu_.cpuState_.getX();
        const u32 result = static_cast<u32>(temp) - static_cast<u32>(value);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, temp >= value);
        cpu_.cpuState_.setFlag(StatusFlag::Zero, (result & 0xFF) == 0);
        cpu_.cpuState_.setFlag(StatusFlag::Negative, (result & 0x80) != 0);
        cpu_.cpuState_.setX(static_cast<u8>(result & 0xFF));
        break;
    }
    case Instruction::LAS: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);
        const u8 result = value & cpu_.cpuState_.getSP();
        cpu_.cpuState_.setA(result);
        cpu_.cpuState_.setX(result);
        cpu_.cpuState_.setSP(result);
        cpu_.cpuState_.setZN(result);
        break;
    }
    case Instruction::KIL: {
        cpu_.cpuState_.setPC(cpu_.cpuState_.getPC() - 1); 
        break;
    }
    case Instruction::XAA: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);
        cpu_.cpuState_.setA(cpu_.cpuState_.getX() & value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    }
    case Instruction::AHX:
    case Instruction::SHA: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 high = (addr >> 8) & 0xFF;
        const u8 result = cpu_.cpuState_.getA() & cpu_.cpuState_.getX() & (high + 1);
        cpu_.writeMemory(addr, result);
        break;
    }
    case Instruction::SHX: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 high = (addr >> 8) & 0xFF;
        const u8 result = cpu_.cpuState_.getX() & (high + 1);
        cpu_.writeMemory(addr, result);
        break;
    }
    case Instruction::SHY: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 high = (addr >> 8) & 0xFF;
        const u8 result = cpu_.cpuState_.getY() & (high + 1);
        cpu_.writeMemory(addr, result);
        break;
    }
    case Instruction::TAS: {
        const u32 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 high = (addr >> 8) & 0xFF;
        cpu_.cpuState_.setSP(cpu_.cpuState_.getA() & cpu_.cpuState_.getX());
        const u8 result = cpu_.cpuState_.getSP() & (high + 1);
        cpu_.writeMemory(addr, result);
        break;
    }
    default:
        break;
    }
}
```


### FILE: src/6510/MemorySubsystem.cpp
```cpp
#include "MemorySubsystem.h"
#include "CPU6510Impl.h"
#include <algorithm>
#include <iomanip>
#include <iostream>
MemorySubsystem::MemorySubsystem(CPU6510Impl& cpu) : cpu_(cpu) {
    reset();
}
void MemorySubsystem::reset() {
    lastWriteToAddr_.resize(65536, 0);
    writeSourceInfo_.resize(65536);
    std::fill(memoryAccess_.begin(), memoryAccess_.end(), 0);
}
u8 MemorySubsystem::readMemory(u32 addr) {
    markMemoryAccess(addr, MemoryAccessFlag::Read);
    return memory_[addr];
}
void MemorySubsystem::writeByte(u32 addr, u8 value) {
    memory_[addr] = value;
}
void MemorySubsystem::writeMemory(u32 addr, u8 value, u32 sourcePC) {
    markMemoryAccess(addr, MemoryAccessFlag::Write);
    memory_[addr] = value;
    lastWriteToAddr_[addr] = sourcePC;
}
void MemorySubsystem::copyMemoryBlock(u32 start, std::span<const u8> data) {
    if (start >= memory_.size()) return;
    const size_t maxCopy = std::min(data.size(), memory_.size() - start);
    std::copy_n(data.begin(), maxCopy, memory_.begin() + start);
}
void MemorySubsystem::markMemoryAccess(u32 addr, MemoryAccessFlag flag) {
    memoryAccess_[addr] |= static_cast<u8>(flag);
}
u8 MemorySubsystem::getMemoryAt(u32 addr) const {
    return memory_[addr];
}
void MemorySubsystem::dumpMemoryAccess(const std::string& filename) {
    std::ofstream file(filename);
    if (!file) {
        return;
    }
    for (u32 addr = 0; addr < 65536; ++addr) {
        if (memoryAccess_[addr] != 0) {
            file << std::hex << std::setw(4) << std::setfill('0') << addr << ": ";
            file << ((memoryAccess_[addr] & static_cast<u8>(MemoryAccessFlag::Execute)) ? "E" : ".");
            file << ((memoryAccess_[addr] & static_cast<u8>(MemoryAccessFlag::OpCode)) ? "1" : ".");
            file << ((memoryAccess_[addr] & static_cast<u8>(MemoryAccessFlag::Read)) ? "R" : ".");
            file << ((memoryAccess_[addr] & static_cast<u8>(MemoryAccessFlag::Write)) ? "W" : ".");
            file << ((memoryAccess_[addr] & static_cast<u8>(MemoryAccessFlag::JumpTarget)) ? "J" : ".");
            file << "\n";
        }
    }
}
std::span<const u8> MemorySubsystem::getMemory() const {
    return std::span<const u8>(memory_.data(), memory_.size());
}
std::span<const u8> MemorySubsystem::getMemoryAccess() const {
    return std::span<const u8>(memoryAccess_.data(), memoryAccess_.size());
}
u32 MemorySubsystem::getLastWriteTo(u32 addr) const {
    return lastWriteToAddr_[addr];
}
const std::vector<u32>& MemorySubsystem::getLastWriteToAddr() const {
    return lastWriteToAddr_;
}
RegisterSourceInfo MemorySubsystem::getWriteSourceInfo(u32 addr) const {
    return writeSourceInfo_[addr];
}
void MemorySubsystem::setWriteSourceInfo(u32 addr, const RegisterSourceInfo& info) {
    writeSourceInfo_[addr] = info;
    if (info.type == RegisterSourceInfo::SourceType::Memory && info.address != addr) {
        u32 sourceAddr = info.address;
        auto& sources = dataFlow_.memoryWriteSources[addr];
        bool alreadyExists = false;
        for (const auto& existingSource : sources) {
            if (existingSource == sourceAddr) {
                alreadyExists = true;
                break;
            }
        }
        if (!alreadyExists) {
            sources.push_back(sourceAddr);
        }
    }
}
const MemoryDataFlow& MemorySubsystem::getMemoryDataFlow() const {
    return dataFlow_;
}
```


### FILE: src/6510/OpcodeTable.cpp
```cpp
#include "CPU6510Impl.h"
const std::array<OpcodeInfo, 256> CPU6510Impl::opcodeTable_ = { {
        {Instruction::BRK, "brk", AddressingMode::Implied, 7, false},
        {Instruction::ORA, "ora", AddressingMode::IndirectX, 6, false},
        {Instruction::KIL, "kil", AddressingMode::Implied, 0, true},
        {Instruction::SLO, "slo", AddressingMode::IndirectX, 8, true},
        {Instruction::NOP, "nop", AddressingMode::ZeroPage, 3, true},
        {Instruction::ORA, "ora", AddressingMode::ZeroPage, 3, false},
        {Instruction::ASL, "asl", AddressingMode::ZeroPage, 5, false},
        {Instruction::SLO, "slo", AddressingMode::ZeroPage, 5, true},
        {Instruction::PHP, "php", AddressingMode::Implied, 3, false},
        {Instruction::ORA, "ora", AddressingMode::Immediate, 2, false},
        {Instruction::ASL, "asl", AddressingMode::Accumulator, 2, false},
        {Instruction::ANC, "anc", AddressingMode::Immediate, 2, true},
        {Instruction::NOP, "nop", AddressingMode::Absolute, 4, true},
        {Instruction::ORA, "ora", AddressingMode::Absolute, 4, false},
        {Instruction::ASL, "asl", AddressingMode::Absolute, 6, false},
        {Instruction::SLO, "slo", AddressingMode::Absolute, 6, true},
        {Instruction::BPL, "bpl", AddressingMode::Relative, 2, false},
        {Instruction::ORA, "ora", AddressingMode::IndirectY, 5, false},
        {Instruction::KIL, "kil", AddressingMode::Implied, 0, true},
        {Instruction::SLO, "slo", AddressingMode::IndirectY, 8, true},
        {Instruction::NOP, "nop", AddressingMode::ZeroPageX, 4, true},
        {Instruction::ORA, "ora", AddressingMode::ZeroPageX, 4, false},
        {Instruction::ASL, "asl", AddressingMode::ZeroPageX, 6, false},
        {Instruction::SLO, "slo", AddressingMode::ZeroPageX, 6, true},
        {Instruction::CLC, "clc", AddressingMode::Implied, 2, false},
        {Instruction::ORA, "ora", AddressingMode::AbsoluteY, 4, false},
        {Instruction::NOP, "nop", AddressingMode::Implied, 2, true},
        {Instruction::SLO, "slo", AddressingMode::AbsoluteY, 7, true},
        {Instruction::NOP, "nop", AddressingMode::AbsoluteX, 4, true},
        {Instruction::ORA, "ora", AddressingMode::AbsoluteX, 4, false},
        {Instruction::ASL, "asl", AddressingMode::AbsoluteX, 7, false},
        {Instruction::SLO, "slo", AddressingMode::AbsoluteX, 7, true},
        {Instruction::JSR, "jsr", AddressingMode::Absolute, 6, false},
        {Instruction::AND, "and", AddressingMode::IndirectX, 6, false},
        {Instruction::KIL, "kil", AddressingMode::Implied, 0, true},
        {Instruction::RLA, "rla", AddressingMode::IndirectX, 8, true},
        {Instruction::BIT, "bit", AddressingMode::ZeroPage, 3, false},
        {Instruction::AND, "and", AddressingMode::ZeroPage, 3, false},
        {Instruction::ROL, "rol", AddressingMode::ZeroPage, 5, false},
        {Instruction::RLA, "rla", AddressingMode::ZeroPage, 5, true},
        {Instruction::PLP, "plp", AddressingMode::Implied, 4, false},
        {Instruction::AND, "and", AddressingMode::Immediate, 2, false},
        {Instruction::ROL, "rol", AddressingMode::Accumulator, 2, false},
        {Instruction::ANC, "anc", AddressingMode::Immediate, 2, true},
        {Instruction::BIT, "bit", AddressingMode::Absolute, 4, false},
        {Instruction::AND, "and", AddressingMode::Absolute, 4, false},
        {Instruction::ROL, "rol", AddressingMode::Absolute, 6, false},
        {Instruction::RLA, "rla", AddressingMode::Absolute, 6, true},
        {Instruction::BMI, "bmi", AddressingMode::Relative, 2, false},
        {Instruction::AND, "and", AddressingMode::IndirectY, 5, false},
        {Instruction::KIL, "kil", AddressingMode::Implied, 0, true},
        {Instruction::RLA, "rla", AddressingMode::IndirectY, 8, true},
        {Instruction::NOP, "nop", AddressingMode::ZeroPageX, 4, true},
        {Instruction::AND, "and", AddressingMode::ZeroPageX, 4, false},
        {Instruction::ROL, "rol", AddressingMode::ZeroPageX, 6, false},
        {Instruction::RLA, "rla", AddressingMode::ZeroPageX, 6, true},
        {Instruction::SEC, "sec", AddressingMode::Implied, 2, false},
        {Instruction::AND, "and", AddressingMode::AbsoluteY, 4, false},
        {Instruction::NOP, "nop", AddressingMode::Implied, 2, true},
        {Instruction::RLA, "rla", AddressingMode::AbsoluteY, 7, true},
        {Instruction::NOP, "nop", AddressingMode::AbsoluteX, 4, true},
        {Instruction::AND, "and", AddressingMode::AbsoluteX, 4, false},
        {Instruction::ROL, "rol", AddressingMode::AbsoluteX, 7, false},
        {Instruction::RLA, "rla", AddressingMode::AbsoluteX, 7, true},
        {Instruction::RTI, "rti", AddressingMode::Implied, 6, false},
        {Instruction::EOR, "eor", AddressingMode::IndirectX, 6, false},
        {Instruction::KIL, "kil", AddressingMode::Implied, 0, true},
        {Instruction::SRE, "sre", AddressingMode::IndirectX, 8, true},
        {Instruction::NOP, "nop", AddressingMode::ZeroPage, 3, true},
        {Instruction::EOR, "eor", AddressingMode::ZeroPage, 3, false},
        {Instruction::LSR, "lsr", AddressingMode::ZeroPage, 5, false},
        {Instruction::SRE, "sre", AddressingMode::ZeroPage, 5, true},
        {Instruction::PHA, "pha", AddressingMode::Implied, 3, false},
        {Instruction::EOR, "eor", AddressingMode::Immediate, 2, false},
        {Instruction::LSR, "lsr", AddressingMode::Accumulator, 2, false},
        {Instruction::ALR, "alr", AddressingMode::Immediate, 2, true},
        {Instruction::JMP, "jmp", AddressingMode::Absolute, 3, false},
        {Instruction::EOR, "eor", AddressingMode::Absolute, 4, false},
        {Instruction::LSR, "lsr", AddressingMode::Absolute, 6, false},
        {Instruction::SRE, "sre", AddressingMode::Absolute, 6, true},
        {Instruction::BVC, "bvc", AddressingMode::Relative, 2, false},
        {Instruction::EOR, "eor", AddressingMode::IndirectY, 5, false},
        {Instruction::KIL, "kil", AddressingMode::Implied, 0, true},
        {Instruction::SRE, "sre", AddressingMode::IndirectY, 8, true},
        {Instruction::NOP, "nop", AddressingMode::ZeroPageX, 4, true},
        {Instruction::EOR, "eor", AddressingMode::ZeroPageX, 4, false},
        {Instruction::LSR, "lsr", AddressingMode::ZeroPageX, 6, false},
        {Instruction::SRE, "sre", AddressingMode::ZeroPageX, 6, true},
        {Instruction::CLI, "cli", AddressingMode::Implied, 2, false},
        {Instruction::EOR, "eor", AddressingMode::AbsoluteY, 4, false},
        {Instruction::NOP, "nop", AddressingMode::Implied, 2, true},
        {Instruction::SRE, "sre", AddressingMode::AbsoluteY, 7, true},
        {Instruction::NOP, "nop", AddressingMode::AbsoluteX, 4, true},
        {Instruction::EOR, "eor", AddressingMode::AbsoluteX, 4, false},
        {Instruction::LSR, "lsr", AddressingMode::AbsoluteX, 7, false},
        {Instruction::SRE, "sre", AddressingMode::AbsoluteX, 7, true},
        {Instruction::RTS, "rts", AddressingMode::Implied, 6, false},
        {Instruction::ADC, "adc", AddressingMode::IndirectX, 6, false},
        {Instruction::KIL, "kil", AddressingMode::Implied, 0, true},
        {Instruction::RRA, "rra", AddressingMode::IndirectX, 8, true},
        {Instruction::NOP, "nop", AddressingMode::ZeroPage, 3, true},
        {Instruction::ADC, "adc", AddressingMode::ZeroPage, 3, false},
        {Instruction::ROR, "ror", AddressingMode::ZeroPage, 5, false},
        {Instruction::RRA, "rra", AddressingMode::ZeroPage, 5, true},
        {Instruction::PLA, "pla", AddressingMode::Implied, 4, false},
        {Instruction::ADC, "adc", AddressingMode::Immediate, 2, false},
        {Instruction::ROR, "ror", AddressingMode::Accumulator, 2, false},
        {Instruction::ARR, "arr", AddressingMode::Immediate, 2, true},
        {Instruction::JMP, "jmp", AddressingMode::Indirect, 5, false},
        {Instruction::ADC, "adc", AddressingMode::Absolute, 4, false},
        {Instruction::ROR, "ror", AddressingMode::Absolute, 6, false},
        {Instruction::RRA, "rra", AddressingMode::Absolute, 6, true},
        {Instruction::BVS, "bvs", AddressingMode::Relative, 2, false},
        {Instruction::ADC, "adc", AddressingMode::IndirectY, 5, false},
        {Instruction::KIL, "kil", AddressingMode::Implied, 0, true},
        {Instruction::RRA, "rra", AddressingMode::IndirectY, 8, true},
        {Instruction::NOP, "nop", AddressingMode::ZeroPageX, 4, true},
        {Instruction::ADC, "adc", AddressingMode::ZeroPageX, 4, false},
        {Instruction::ROR, "ror", AddressingMode::ZeroPageX, 6, false},
        {Instruction::RRA, "rra", AddressingMode::ZeroPageX, 6, true},
        {Instruction::SEI, "sei", AddressingMode::Implied, 2, false},
        {Instruction::ADC, "adc", AddressingMode::AbsoluteY, 4, false},
        {Instruction::NOP, "nop", AddressingMode::Implied, 2, true},
        {Instruction::RRA, "rra", AddressingMode::AbsoluteY, 7, true},
        {Instruction::NOP, "nop", AddressingMode::AbsoluteX, 4, true},
        {Instruction::ADC, "adc", AddressingMode::AbsoluteX, 4, false},
        {Instruction::ROR, "ror", AddressingMode::AbsoluteX, 7, false},
        {Instruction::RRA, "rra", AddressingMode::AbsoluteX, 7, true},
        {Instruction::NOP, "nop", AddressingMode::Immediate, 2, true},
        {Instruction::STA, "sta", AddressingMode::IndirectX, 6, false},
        {Instruction::NOP, "nop", AddressingMode::Immediate, 2, true},
        {Instruction::SAX, "sax", AddressingMode::IndirectX, 6, true},
        {Instruction::STY, "sty", AddressingMode::ZeroPage, 3, false},
        {Instruction::STA, "sta", AddressingMode::ZeroPage, 3, false},
        {Instruction::STX, "stx", AddressingMode::ZeroPage, 3, false},
        {Instruction::SAX, "sax", AddressingMode::ZeroPage, 3, true},
        {Instruction::DEY, "dey", AddressingMode::Implied, 2, false},
        {Instruction::NOP, "nop", AddressingMode::Immediate, 2, false},
        {Instruction::TXA, "txa", AddressingMode::Implied, 2, false},
        {Instruction::XAA, "xaa", AddressingMode::Immediate, 2, true},
        {Instruction::STY, "sty", AddressingMode::Absolute, 4, false},
        {Instruction::STA, "sta", AddressingMode::Absolute, 4, false},
        {Instruction::STX, "stx", AddressingMode::Absolute, 4, false},
        {Instruction::SAX, "sax", AddressingMode::Absolute, 4, true},
        {Instruction::BCC, "bcc", AddressingMode::Relative, 2, false},
        {Instruction::STA, "sta", AddressingMode::IndirectY, 6, false},
        {Instruction::KIL, "kil", AddressingMode::Implied, 0, true},
        {Instruction::AHX, "ahx", AddressingMode::IndirectY, 6, true},
        {Instruction::STY, "sty", AddressingMode::ZeroPageX, 4, false},
        {Instruction::STA, "sta", AddressingMode::ZeroPageX, 4, false},
        {Instruction::STX, "stx", AddressingMode::ZeroPageY, 4, false},
        {Instruction::SAX, "sax", AddressingMode::ZeroPageY, 4, true},
        {Instruction::TYA, "tya", AddressingMode::Implied, 2, false},
        {Instruction::STA, "sta", AddressingMode::AbsoluteY, 5, false},
        {Instruction::TXS, "txs", AddressingMode::Implied, 2, false},
        {Instruction::TAS, "tas", AddressingMode::AbsoluteY, 5, true},
        {Instruction::SHY, "shy", AddressingMode::AbsoluteX, 5, true},
        {Instruction::STA, "sta", AddressingMode::AbsoluteX, 5, false},
        {Instruction::SHX, "shx", AddressingMode::AbsoluteY, 5, true},
        {Instruction::AHX, "ahx", AddressingMode::AbsoluteY, 5, true},
        {Instruction::LDY, "ldy", AddressingMode::Immediate, 2, false},
        {Instruction::LDA, "lda", AddressingMode::IndirectX, 6, false},
        {Instruction::LDX, "ldx", AddressingMode::Immediate, 2, false},
        {Instruction::LAX, "lax", AddressingMode::IndirectX, 6, true},
        {Instruction::LDY, "ldy", AddressingMode::ZeroPage, 3, false},
        {Instruction::LDA, "lda", AddressingMode::ZeroPage, 3, false},
        {Instruction::LDX, "ldx", AddressingMode::ZeroPage, 3, false},
        {Instruction::LAX, "lax", AddressingMode::ZeroPage, 3, true},
        {Instruction::TAY, "tay", AddressingMode::Implied, 2, false},
        {Instruction::LDA, "lda", AddressingMode::Immediate, 2, false},
        {Instruction::TAX, "tax", AddressingMode::Implied, 2, false},
        {Instruction::LAX, "lax", AddressingMode::Immediate, 2, true},
        {Instruction::LDY, "ldy", AddressingMode::Absolute, 4, false},
        {Instruction::LDA, "lda", AddressingMode::Absolute, 4, false},
        {Instruction::LDX, "ldx", AddressingMode::Absolute, 4, false},
        {Instruction::LAX, "lax", AddressingMode::Absolute, 4, true},
        {Instruction::BCS, "bcs", AddressingMode::Relative, 2, false},
        {Instruction::LDA, "lda", AddressingMode::IndirectY, 5, false},
        {Instruction::KIL, "kil", AddressingMode::Implied, 0, true},
        {Instruction::LAX, "lax", AddressingMode::IndirectY, 5, true},
        {Instruction::LDY, "ldy", AddressingMode::ZeroPageX, 4, false},
        {Instruction::LDA, "lda", AddressingMode::ZeroPageX, 4, false},
        {Instruction::LDX, "ldx", AddressingMode::ZeroPageY, 4, false},
        {Instruction::LAX, "lax", AddressingMode::ZeroPageY, 4, true},
        {Instruction::CLV, "clv", AddressingMode::Implied, 2, false},
        {Instruction::LDA, "lda", AddressingMode::AbsoluteY, 4, false},
        {Instruction::TSX, "tsx", AddressingMode::Implied, 2, false},
        {Instruction::LAS, "las", AddressingMode::AbsoluteY, 4, true},
        {Instruction::LDY, "ldy", AddressingMode::AbsoluteX, 4, false},
        {Instruction::LDA, "lda", AddressingMode::AbsoluteX, 4, false},
        {Instruction::LDX, "ldx", AddressingMode::AbsoluteY, 4, false},
        {Instruction::LAX, "lax", AddressingMode::AbsoluteY, 4, true},
        {Instruction::CPY, "cpy", AddressingMode::Immediate, 2, false},
        {Instruction::CMP, "cmp", AddressingMode::IndirectX, 6, false},
        {Instruction::NOP, "nop", AddressingMode::Immediate, 2, true},
        {Instruction::DCP, "dcp", AddressingMode::IndirectX, 8, true},
        {Instruction::CPY, "cpy", AddressingMode::ZeroPage, 3, false},
        {Instruction::CMP, "cmp", AddressingMode::ZeroPage, 3, false},
        {Instruction::DEC, "dec", AddressingMode::ZeroPage, 5, false},
        {Instruction::DCP, "dcp", AddressingMode::ZeroPage, 5, true},
        {Instruction::INY, "iny", AddressingMode::Implied, 2, false},
        {Instruction::CMP, "cmp", AddressingMode::Immediate, 2, false},
        {Instruction::DEX, "dex", AddressingMode::Implied, 2, false},
        {Instruction::AXS, "axs", AddressingMode::Immediate, 2, true},
        {Instruction::CPY, "cpy", AddressingMode::Absolute, 4, false},
        {Instruction::CMP, "cmp", AddressingMode::Absolute, 4, false},
        {Instruction::DEC, "dec", AddressingMode::Absolute, 6, false},
        {Instruction::DCP, "dcp", AddressingMode::Absolute, 6, true},
        {Instruction::BNE, "bne", AddressingMode::Relative, 2, false},
        {Instruction::CMP, "cmp", AddressingMode::IndirectY, 5, false},
        {Instruction::KIL, "kil", AddressingMode::Implied, 0, true},
        {Instruction::DCP, "dcp", AddressingMode::IndirectY, 8, true},
        {Instruction::NOP, "nop", AddressingMode::ZeroPageX, 4, true},
        {Instruction::CMP, "cmp", AddressingMode::ZeroPageX, 4, false},
        {Instruction::DEC, "dec", AddressingMode::ZeroPageX, 6, false},
        {Instruction::DCP, "dcp", AddressingMode::ZeroPageX, 6, true},
        {Instruction::CLD, "cld", AddressingMode::Implied, 2, false},
        {Instruction::CMP, "cmp", AddressingMode::AbsoluteY, 4, false},
        {Instruction::NOP, "nop", AddressingMode::Implied, 2, true},
        {Instruction::DCP, "dcp", AddressingMode::AbsoluteY, 7, true},
        {Instruction::NOP, "nop", AddressingMode::AbsoluteX, 4, true},
        {Instruction::CMP, "cmp", AddressingMode::AbsoluteX, 4, false},
        {Instruction::DEC, "dec", AddressingMode::AbsoluteX, 7, false},
        {Instruction::DCP, "dcp", AddressingMode::AbsoluteX, 7, true},
        {Instruction::CPX, "cpx", AddressingMode::Immediate, 2, false},
        {Instruction::SBC, "sbc", AddressingMode::IndirectX, 6, false},
        {Instruction::NOP, "nop", AddressingMode::Immediate, 2, true},
        {Instruction::ISC, "isc", AddressingMode::IndirectX, 8, true},
        {Instruction::CPX, "cpx", AddressingMode::ZeroPage, 3, false},
        {Instruction::SBC, "sbc", AddressingMode::ZeroPage, 3, false},
        {Instruction::INC, "inc", AddressingMode::ZeroPage, 5, false},
        {Instruction::ISC, "isc", AddressingMode::ZeroPage, 5, true},
        {Instruction::INX, "inx", AddressingMode::Implied, 2, false},
        {Instruction::SBC, "sbc", AddressingMode::Immediate, 2, false},
        {Instruction::NOP, "nop", AddressingMode::Implied, 2, true},
        {Instruction::SBC, "sbc", AddressingMode::Immediate, 2, true},
        {Instruction::CPX, "cpx", AddressingMode::Absolute, 4, false},
        {Instruction::SBC, "sbc", AddressingMode::Absolute, 4, false},
        {Instruction::INC, "inc", AddressingMode::Absolute, 6, false},
        {Instruction::ISC, "isc", AddressingMode::Absolute, 6, true},
        {Instruction::BEQ, "beq", AddressingMode::Relative, 2, false},
        {Instruction::SBC, "sbc", AddressingMode::IndirectY, 5, false},
        {Instruction::KIL, "kil", AddressingMode::Implied, 0, true},
        {Instruction::ISC, "isc", AddressingMode::IndirectY, 8, true},
        {Instruction::NOP, "nop", AddressingMode::ZeroPageX, 4, true},
        {Instruction::SBC, "sbc", AddressingMode::ZeroPageX, 4, false},
        {Instruction::INC, "inc", AddressingMode::ZeroPageX, 6, false},
        {Instruction::ISC, "isc", AddressingMode::ZeroPageX, 6, true},
        {Instruction::SED, "sed", AddressingMode::Implied, 2, false},
        {Instruction::SBC, "sbc", AddressingMode::AbsoluteY, 4, false},
        {Instruction::NOP, "nop", AddressingMode::Implied, 2, true},
        {Instruction::ISC, "isc", AddressingMode::AbsoluteY, 7, true},
        {Instruction::NOP, "nop", AddressingMode::AbsoluteX, 4, true},
        {Instruction::SBC, "sbc", AddressingMode::AbsoluteX, 4, false},
        {Instruction::INC, "inc", AddressingMode::AbsoluteX, 7, false},
        {Instruction::ISC, "isc", AddressingMode::AbsoluteX, 7, true},
} };
```


### FILE: src/app/CommandProcessor.cpp
```cpp
#include "CommandProcessor.h"
#include "../SIDwinderUtils.h"
#include "../ConfigManager.h"
#include "../cpu6510.h"
#include "../SIDEmulator.h"
#include "../SIDLoader.h"
#include "../Disassembler.h"
#include "../RelocationUtils.h"
#include "MusicBuilder.h"
#include "MemoryConstants.h"
#include <algorithm>
#include <fstream>
#include <cctype>
namespace sidwinder {
    CommandProcessor::CommandProcessor() {
        cpu_ = std::make_unique<CPU6510>();
        cpu_->reset();
        sid_ = std::make_unique<SIDLoader>();
        sid_->setCPU(cpu_.get());
    }
    CommandProcessor::~CommandProcessor() {
        traceLogger_.reset();
    }
    bool CommandProcessor::processFile(const ProcessingOptions& options) {
        try {
            fs::create_directories(options.tempDir);
            if (options.enableTracing && !options.traceLogPath.empty()) {
                traceLogger_ = std::make_unique<TraceLogger>(options.traceLogPath, options.traceFormat);
            }
            if (!loadInputFile(options)) {
                return false;
            }
            applySIDMetadataOverrides(options);
            if (options.includePlayer && getFileExtension(options.outputFile) == ".prg" && options.analyzeRegisterOrder) {
                SIDEmulator emulator(cpu_.get(), sid_.get());
                SIDEmulator::EmulationOptions emulationOptions;
                emulationOptions.frames = options.frames > 0 ?
                    options.frames : util::ConfigManager::getInt("emulationFrames", DEFAULT_SID_EMULATION_FRAMES);
                emulationOptions.registerTrackingEnabled = true;
                emulationOptions.patternDetectionEnabled = true;
                u8 CIATimerLo = 0;
                u8 CIATimerHi = 0;
                cpu_->setOnCIAWriteCallback([&](u16 addr, u8 value) {
                    if (addr == MemoryConstants::CIA1_TIMER_LO) CIATimerLo = value;
                    if (addr == MemoryConstants::CIA1_TIMER_HI) CIATimerHi = value;
                    });
                if (!emulator.runEmulation(emulationOptions)) {
                    util::Logger::warning("SID pattern analysis failed - continuing without pattern info");
                }
                int playCallsPerFrame = calculatePlayCallsPerFrame(CIATimerLo, CIATimerHi);
                sid_->setNumPlayCallsPerFrame(playCallsPerFrame);
            }
            bool needsEmulation = false;
            if (getFileExtension(options.outputFile) == ".asm" ||
                (getFileExtension(options.outputFile) == ".sid" && options.hasRelocation)) {
                needsEmulation = true;
            }
            if (options.enableTracing) {
                needsEmulation = true;
            }
            if (options.includePlayer && getFileExtension(options.outputFile) == ".prg") {
                needsEmulation = false;
            }
            if (needsEmulation) {
                if (!analyzeMusic(options)) {
                    return false;
                }
            }
            else {
                disassembler_ = std::make_unique<Disassembler>(*cpu_, *sid_);
            }
            if (!generateOutput(options)) {
                return false;
            }
            return true;
        }
        catch (const std::exception& e) {
            util::Logger::error(std::string("Error processing file: ") + e.what());
            return false;
        }
    }
    bool CommandProcessor::loadInputFile(const ProcessingOptions& options) {
        std::string basename = options.inputFile.stem().string();
        fs::path tempExtractedPrg = options.tempDir / (basename + "-original.prg");
        std::string ext = getFileExtension(options.inputFile);
        if (ext != ".sid")
        {
            util::Logger::error("Unsupported file type: " + options.inputFile.string() + " - only SID files accepted.");
            return false;
        }
        if (!loadSidFile(options, tempExtractedPrg)) {
            util::Logger::error("Failed to load file: " + options.inputFile.string());
            return false;
        }
        return true;
    }
    bool CommandProcessor::loadSidFile(const ProcessingOptions& options, const fs::path& tempExtractedPrg) {
        bool loaded = sid_->loadSID(options.inputFile.string());
        if (loaded) {
            if (options.hasOverrideInit) {
                sid_->setInitAddress(options.overrideInitAddress);
            }
            if (options.hasOverridePlay) {
                sid_->setPlayAddress(options.overridePlayAddress);
            }
            if (options.hasOverrideLoad) {
                sid_->setLoadAddress(options.overrideLoadAddress);
            }
            MusicBuilder builder(cpu_.get(), sid_.get());
            builder.extractPrgFromSid(options.inputFile, tempExtractedPrg);
        }
        return loaded;
    }
    void CommandProcessor::applySIDMetadataOverrides(const ProcessingOptions& options) {
        if (!options.overrideTitle.empty()) {
            sid_->setTitle(options.overrideTitle);
        }
        if (!options.overrideAuthor.empty()) {
            sid_->setAuthor(options.overrideAuthor);
        }
        if (!options.overrideCopyright.empty()) {
            sid_->setCopyright(options.overrideCopyright);
        }
    }
    bool CommandProcessor::analyzeMusic(const ProcessingOptions& options) {
        sid_->backupMemory();
        u8 CIATimerLo = 0;
        u8 CIATimerHi = 0;
        cpu_->setOnCIAWriteCallback([&](u16 addr, u8 value) {
            if (addr == MemoryConstants::CIA1_TIMER_LO) CIATimerLo = value;
            if (addr == MemoryConstants::CIA1_TIMER_HI) CIATimerHi = value;
            });
        disassembler_ = std::make_unique<Disassembler>(*cpu_, *sid_);
        SIDEmulator emulator(cpu_.get(), sid_.get());
        SIDEmulator::EmulationOptions emulationOptions;
        emulationOptions.frames = options.frames > 0 ?
            options.frames : util::ConfigManager::getInt("emulationFrames", DEFAULT_SID_EMULATION_FRAMES);
        emulationOptions.traceEnabled = options.enableTracing;
        emulationOptions.traceFormat = options.traceFormat;
        emulationOptions.traceLogPath = options.traceLogPath;
        emulationOptions.registerTrackingEnabled = false;
        if (!emulator.runEmulation(emulationOptions)) {
            util::Logger::error("SID emulation failed");
            return false;
        }
        int playCallsPerFrame = calculatePlayCallsPerFrame(CIATimerLo, CIATimerHi);
        sid_->setNumPlayCallsPerFrame(playCallsPerFrame);
        const u16 sidLoad = sid_->getLoadAddress();
        const u16 sidInit = sid_->getInitAddress();
        const u16 sidPlay = sid_->getPlayAddress();
        auto [avgCycles, maxCycles] = emulator.getCycleStats();
        return true;
    }
    int CommandProcessor::calculatePlayCallsPerFrame(u8 CIATimerLo, u8 CIATimerHi) {
        const uint32_t speedBits = sid_->getHeader().speed;
        int count = 0;
        for (int i = 0; i < 32; ++i) {
            if (speedBits & (1u << i)) {
                ++count;
            }
        }
        int defaultCalls = util::ConfigManager::getInt("defaultPlayCallsPerFrame", 1);
        int numPlayCallsPerFrame = std::clamp(count == 0 ? defaultCalls : count, 1, 16);
        if ((CIATimerLo != 0) || (CIATimerHi != 0)) {
            const u16 timerValue = CIATimerLo | (CIATimerHi << 8);
            const double NumCyclesPerFrame = util::ConfigManager::getCyclesPerFrame();
            const double freq = NumCyclesPerFrame / std::max(1, static_cast<int>(timerValue));
            const int numCalls = static_cast<int>(freq + 0.5);
            numPlayCallsPerFrame = std::clamp(numCalls, 1, 16);
        }
        return numPlayCallsPerFrame;
    }
    bool CommandProcessor::generateOutput(const ProcessingOptions& options) {
        u16 newSidLoad;
        u16 newSidInit;
        u16 newSidPlay;
        const u16 sidLoad = sid_->getLoadAddress();
        const u16 sidInit = sid_->getInitAddress();
        const u16 sidPlay = sid_->getPlayAddress();
        if (options.hasRelocation) {
            newSidLoad = options.relocationAddress;
            newSidInit = newSidLoad + (sidInit - sidLoad);
            newSidPlay = newSidLoad + (sidPlay - sidLoad);
        }
        else {
            newSidLoad = sidLoad;
            newSidInit = sidInit;
            newSidPlay = sidPlay;
        }
        std::string ext = getFileExtension(options.outputFile);
        if (ext == ".prg") {
            return generatePRGOutput(options);
        }
        else if (ext == ".sid") {
            return generateSIDOutput(options);
        }
        else if (ext == ".asm") {
            return generateASMOutput(options);
        }
        util::Logger::error("Unsupported output format");
        return false;
    }
    bool CommandProcessor::generatePRGOutput(const ProcessingOptions& options) {
        std::string basename = options.inputFile.stem().string();
        fs::path tempDir = options.tempDir;
        fs::path tempExtractedPrg = tempDir / (basename + "-original.prg");
        std::string inputExt = getFileExtension(options.inputFile);
        bool bIsSID = (inputExt == ".sid");
        bool bIsASM = (inputExt == ".asm");
        bool bIsPRG = (inputExt == ".prg");
        if (options.includePlayer && bIsSID) {
            MusicBuilder builder(cpu_.get(), sid_.get());
            MusicBuilder::BuildOptions buildOptions;
            buildOptions.includePlayer = true;
            buildOptions.playerName = options.playerName;
            buildOptions.playerAddress = options.playerAddress;
            buildOptions.compress = options.compress;
            buildOptions.compressorType = options.compressorType;
            buildOptions.exomizerPath = options.exomizerPath;
            buildOptions.kickAssPath = options.kickAssPath;
            buildOptions.tempDir = tempDir;
            buildOptions.playCallsPerFrame = sid_->getNumPlayCallsPerFrame();
            buildOptions.userDefinitions = options.userDefinitions;
            buildOptions.sidLoadAddr = sid_->getLoadAddress();
            buildOptions.sidInitAddr = sid_->getInitAddress();
            buildOptions.sidPlayAddr = sid_->getPlayAddress();
            return builder.buildMusic(basename, options.inputFile, options.outputFile, buildOptions);
        }
        bool bRelocation = options.hasRelocation;
        u16 newSidLoad = options.relocationAddress;
        if ((!bRelocation) && (bIsSID) && (!fs::exists(tempExtractedPrg))) {
            MusicBuilder builder(cpu_.get(), sid_.get());
            builder.extractPrgFromSid(options.inputFile, tempExtractedPrg);
        }
        if (bRelocation) {
            sid_->restoreMemory();
            fs::path tempAsmFile = tempDir / (basename + ".asm");
            const u16 sidLoad = sid_->getLoadAddress();
            const u16 newSidInit = newSidLoad + (sid_->getInitAddress() - sidLoad);
            const u16 newSidPlay = newSidLoad + (sid_->getPlayAddress() - sidLoad);
            disassembler_->generateAsmFile(tempAsmFile.string(), newSidLoad, newSidInit, newSidPlay, true);
            MusicBuilder builder(cpu_.get(), sid_.get());
            MusicBuilder::BuildOptions buildOptions;
            buildOptions.includePlayer = options.includePlayer;
            buildOptions.playerName = options.playerName;
            buildOptions.playerAddress = options.playerAddress;
            buildOptions.compress = options.compress;
            buildOptions.compressorType = options.compressorType;
            buildOptions.exomizerPath = options.exomizerPath;
            buildOptions.kickAssPath = options.kickAssPath;
            buildOptions.tempDir = tempDir;
            buildOptions.sidLoadAddr = newSidLoad;
            buildOptions.sidInitAddr = newSidInit;
            buildOptions.sidPlayAddr = newSidPlay;
            buildOptions.playCallsPerFrame = sid_->getNumPlayCallsPerFrame();
            buildOptions.userDefinitions = options.userDefinitions;
            return builder.buildMusic(basename, tempAsmFile, options.outputFile, buildOptions);
        }
        else if (bIsSID) {
            MusicBuilder builder(cpu_.get(), sid_.get());
            MusicBuilder::BuildOptions buildOptions;
            buildOptions.includePlayer = options.includePlayer;
            buildOptions.playerName = options.playerName;
            buildOptions.playerAddress = options.playerAddress;
            buildOptions.compress = options.compress;
            buildOptions.compressorType = options.compressorType;
            buildOptions.exomizerPath = options.exomizerPath;
            buildOptions.kickAssPath = options.kickAssPath;
            buildOptions.tempDir = tempDir;
            buildOptions.playCallsPerFrame = sid_->getNumPlayCallsPerFrame();
            buildOptions.userDefinitions = options.userDefinitions;
            return builder.buildMusic(basename, options.inputFile, options.outputFile, buildOptions);
        }
        else {
            MusicBuilder builder(cpu_.get(), sid_.get());
            MusicBuilder::BuildOptions buildOptions;
            buildOptions.includePlayer = options.includePlayer;
            buildOptions.playerName = options.playerName;
            buildOptions.playerAddress = options.playerAddress;
            buildOptions.compress = options.compress;
            buildOptions.compressorType = options.compressorType;
            buildOptions.exomizerPath = options.exomizerPath;
            buildOptions.kickAssPath = options.kickAssPath;
            buildOptions.tempDir = tempDir;
            buildOptions.playCallsPerFrame = sid_->getNumPlayCallsPerFrame();
            buildOptions.userDefinitions = options.userDefinitions;
            fs::path inputToUse = bIsASM ? options.inputFile : tempExtractedPrg;
            return builder.buildMusic(basename, inputToUse, options.outputFile, buildOptions);
        }
    }
    bool CommandProcessor::generateSIDOutput(const ProcessingOptions& options) {
        if (options.hasRelocation) {
            util::RelocationParams params;
            params.inputFile = options.inputFile;
            params.outputFile = options.outputFile;
            params.tempDir = options.tempDir;
            params.relocationAddress = options.relocationAddress;
            params.kickAssPath = options.kickAssPath;
            util::RelocationResult result = util::relocateSID(cpu_.get(), sid_.get(), params);
            return result.success;
        }
        else {
            std::string ext = getFileExtension(options.inputFile);
            if (ext == ".sid") {
                try {
                    fs::copy_file(options.inputFile, options.outputFile, fs::copy_options::overwrite_existing);
                    return true;
                }
                catch (const std::exception& e) {
                    util::Logger::error(std::string("Failed to copy SID file: ") + e.what());
                    return false;
                }
            }
            else if (ext == ".prg") {
                u16 loadAddr = options.hasOverrideLoad ?
                    options.overrideLoadAddress : util::ConfigManager::getDefaultSidLoadAddress();
                u16 initAddr = options.hasOverrideInit ?
                    options.overrideInitAddress : util::ConfigManager::getDefaultSidInitAddress();
                u16 playAddr = options.hasOverridePlay ?
                    options.overridePlayAddress : util::ConfigManager::getDefaultSidPlayAddress();
                const SIDHeader& originalHeader = sid_->getHeader();
                u16 flags = originalHeader.flags;
                u8 secondSIDAddress = originalHeader.secondSIDAddress;
                u8 thirdSIDAddress = originalHeader.thirdSIDAddress;
                u16 version = originalHeader.version;
                u32 speed = originalHeader.speed;
                bool success = util::createSIDFromPRG(
                    options.inputFile,
                    options.outputFile,
                    loadAddr,
                    initAddr,
                    playAddr,
                    options.overrideTitle,
                    options.overrideAuthor,
                    options.overrideCopyright,
                    flags,
                    secondSIDAddress,
                    thirdSIDAddress,
                    version,
                    speed);
                if (!success) {
                    try {
                        fs::copy_file(options.inputFile, options.outputFile, fs::copy_options::overwrite_existing);
                        return true;
                    }
                    catch (const std::exception& e) {
                        util::Logger::error(std::string("Failed to copy PRG file: ") + e.what());
                        return false;
                    }
                }
                return success;
            }
            else {
                util::Logger::error("Unsupported input file type for SID output");
                return false;
            }
        }
    }
    bool CommandProcessor::generateASMOutput(const ProcessingOptions& options) {
        std::string basename = options.inputFile.stem().string();
        fs::path tempDir = options.tempDir;
        sid_->restoreMemory();
        u16 outputSidLoad = options.hasRelocation ?
            options.relocationAddress : sid_->getLoadAddress();
        const u16 sidLoad = sid_->getLoadAddress();
        const u16 newSidInit = outputSidLoad + (sid_->getInitAddress() - sidLoad);
        const u16 newSidPlay = outputSidLoad + (sid_->getPlayAddress() - sidLoad);
        disassembler_->generateAsmFile(options.outputFile.string(), outputSidLoad, newSidInit, newSidPlay, true);
        return true;
    }
}
```


### FILE: src/app/MusicBuilder.cpp
```cpp
#include "MusicBuilder.h"
#include "../SIDwinderUtils.h"
#include "../ConfigManager.h"
#include "../cpu6510.h"
#include "../SIDLoader.h"
#include <algorithm>
#include <fstream>
#include <cctype>
namespace sidwinder {
    MusicBuilder::MusicBuilder(const CPU6510* cpu, const SIDLoader* sid)
        : cpu_(cpu), sid_(sid) {
        emulator_ = std::make_unique<SIDEmulator>(const_cast<CPU6510*>(cpu), const_cast<SIDLoader*>(sid));
    }
    bool MusicBuilder::buildMusic(
        const std::string& basename,
        const fs::path& inputFile,
        const fs::path& outputFile,
        const BuildOptions& options) {
        try {
            fs::create_directories(options.tempDir);
        }
        catch (const std::exception& e) {
            util::Logger::error(std::string("Failed to create temp directory: ") + e.what());
            return false;
        }
        fs::path tempDir = options.tempDir;
        fs::path tempPrgFile = tempDir / (basename + ".prg");
        fs::path tempPlayerPrgFile = tempDir / (basename + "-player.prg");
        fs::path tempLinkerFile = tempDir / (basename + "-linker.asm");
        std::string ext = getFileExtension(inputFile);
        bool bIsSID = (ext == ".sid");
        bool bIsASM = (ext == ".asm");
        bool bIsPRG = (ext == ".prg");
        if (!options.playerName.empty()) {
            std::string playerToUse = options.playerName;
            if (playerToUse == "default") {
                playerToUse = util::ConfigManager::getPlayerName();
            }
            std::string playerDir = util::ConfigManager::getString("playerDirectory", "SIDPlayers");
            fs::path playerAsmFile = fs::path(playerDir) / playerToUse / (playerToUse + ".asm");
            fs::create_directories(playerAsmFile.parent_path());
            fs::path helpfulDataFile = tempDir / (basename + "-HelpfulData.asm");
            if (emulator_) {
                SIDEmulator::EmulationOptions options;
                options.frames = 100; 
                options.registerTrackingEnabled = true; 
                options.patternDetectionEnabled = true;
                options.shadowRegisterDetectionEnabled = true; 
                if (emulator_->runEmulation(options)) {
                    emulator_->generateHelpfulDataFile(helpfulDataFile.string());
                }
            }
            if (!createLinkerFile(tempLinkerFile, inputFile, playerAsmFile, options)) {
                return false;
            }
            if (!runAssembler(tempLinkerFile, tempPlayerPrgFile, options.kickAssPath, options.tempDir)) {
                return false;
            }
            if (options.compress) {
                if (!compressPrg(tempPlayerPrgFile, outputFile, options.playerAddress, options)) {
                    try {
                        fs::copy_file(tempPlayerPrgFile, outputFile,
                            fs::copy_options::overwrite_existing);
                        return true;
                    }
                    catch (const std::exception& e) {
                        util::Logger::error(std::string("Failed to copy uncompressed PRG: ") + e.what());
                        return false;
                    }
                }
                return true;
            }
            else {
                try {
                    fs::copy_file(tempPlayerPrgFile, outputFile,
                        fs::copy_options::overwrite_existing);
                    return true;
                }
                catch (const std::exception& e) {
                    util::Logger::error(std::string("Failed to copy uncompressed PRG: ") + e.what());
                    return false;
                }
            }
        }
        else {
            if (bIsASM) {
                if (!runAssembler(inputFile, outputFile, options.kickAssPath, options.tempDir)) {
                    return false;
                }
                return true;
            }
            else if (bIsPRG) {
                try {
                    fs::copy_file(inputFile, outputFile, fs::copy_options::overwrite_existing);
                    return true;
                }
                catch (const std::exception& e) {
                    util::Logger::error(std::string("Failed to copy PRG file: ") + e.what());
                    return false;
                }
            }
            else if (bIsSID) {
                return extractPrgFromSid(inputFile, outputFile);
            }
            else {
                util::Logger::error("Unsupported input file type for pure music output");
                return false;
            }
        }
        return true;
    }
    void MusicBuilder::addUserDefinitions(std::ofstream& file, const BuildOptions& options)
    {
        if (!options.userDefinitions.empty()) {
            file << "
            for (const auto& [key, value] : options.userDefinitions) {
                bool isNumber = true;
                bool isHex = false;
                if (value.length() > 1 && value[0] == '$') {
                    isHex = true;
                    for (size_t i = 1; i < value.length(); i++) {
                        if (!std::isxdigit(value[i])) {
                            isNumber = false;
                            break;
                        }
                    }
                }
                else if (value.length() > 2 && value.substr(0, 2) == "0x") {
                    isHex = true;
                    for (size_t i = 2; i < value.length(); i++) {
                        if (!std::isxdigit(value[i])) {
                            isNumber = false;
                            break;
                        }
                    }
                }
                else {
                    for (char c : value) {
                        if (!std::isdigit(c) && c != '-' && c != '+') {
                            isNumber = false;
                            break;
                        }
                    }
                }
                file << "#define USERDEFINES_" << key << "\n";
                if (isNumber) {
                    file << ".var " << key << " = " << value << "\n";
                }
                else {
                    std::string escaped = value;
                    size_t pos = 0;
                    while ((pos = escaped.find('"', pos)) != std::string::npos) {
                        escaped.insert(pos, "\\");
                        pos += 2;
                    }
                    file << ".var " << key << " = \"" << escaped << "\"\n";
                }
            }
            file << "\n";
        }
    }
    bool MusicBuilder::createLinkerFile(
        const fs::path& linkerFile,
        const fs::path& musicFile,
        const fs::path& playerAsmFile,
        const BuildOptions& options) {
        std::string ext = getFileExtension(musicFile);
        bool bIsSID = (ext == ".sid");
        bool bIsASM = (ext == ".asm");
        if ((!bIsSID) && (!bIsASM))
        {
            util::Logger::error(std::string("Only SID and ASM files can be linked - '" + musicFile.string() + "' rejected."));
            return false;
        }
        std::ofstream file(linkerFile);
        if (!file) {
            util::Logger::error("Failed to create linker file: " + linkerFile.string());
            return false;
        }
        file << "
        file << "
        file << "
        file << "\n";
        if (bIsSID)
        {
            file << ".var music_prg = LoadSid(\"" << musicFile.string() << "\")\n";
            file << "* = music_prg.location \"SID\"\n";
            file << ".fill music_prg.size, music_prg.getData(i)\n";
            file << "\n";
            file << ".var SIDInit = music_prg.init\n";
            file << ".var SIDPlay = music_prg.play\n";
        }
        else
        {
            u16 sidInit = options.sidInitAddr;
            u16 sidPlay = options.sidPlayAddr;
            file << ".var SIDInit = $" << util::wordToHex(sidInit) << "\n";
            file << ".var SIDPlay = $" << util::wordToHex(sidPlay) << "\n";
        }
        file << ".var NumCallsPerFrame = " << options.playCallsPerFrame << "\n";
        file << ".var PlayerADDR = $" << util::wordToHex(options.playerAddress) << "\n";
        file << "\n";
        std::string basename = musicFile.stem().string();
        fs::path helpfulDataFile = options.tempDir / (basename + "-HelpfulData.asm");
        bool hasHelpfulDataFile = fs::exists(helpfulDataFile);
        if (hasHelpfulDataFile) {
            file << "
            file << ".import source \"" << helpfulDataFile.string() << "\"\n";
        }
        else {
            file << "
            file << ".var SIDModifiedMemoryCount = 0\n";
            file << ".var SIDModifiedMemory = List()\n";
            file << ".var SIDRegisterCount = 0\n";
            file << ".var SIDRegisterOrder = List()\n";
        }
        file << "\n";
        if (sid_) {
            const auto& header = sid_->getHeader();
            auto cleanString = [](const std::string& str) {
                std::string result;
                for (unsigned char c : str) {
                    if (std::isalnum(c) || c == ' ' || c == '-' || c == '_' || c == '!') {
                        result.push_back(c);
                    }
                    else {
                        result.push_back('_');
                    }
                }
                return result;
                };
            file << "
            file << ".var SIDName = \"" << cleanString(std::string(header.name)) << "\"\n";
            file << ".var SIDAuthor = \"" << cleanString(std::string(header.author)) << "\"\n";
            file << ".var SIDCopyright = \"" << cleanString(std::string(header.copyright)) << "\"\n\n";
            file << "\n";
        }
        addUserDefinitions(file, options);
        file << "* = PlayerADDR\n";
        file << ".import source \"" << playerAsmFile.string() << "\"\n";
        file << "\n";
        if (bIsASM)
        {
            u16 sidLoad = options.sidLoadAddr;
            file << "* = $" << util::wordToHex(sidLoad) << "\n";
            file << ".import source \"" << musicFile.string() << "\"\n";
            file << "\n";
        }
        file.close();
        return true;
    }
    bool MusicBuilder::runAssembler(
        const fs::path& sourceFile,
        const fs::path& outputFile,
        const std::string& kickAssPath,
        const fs::path& tempDir) {
        fs::path logFile = tempDir / (sourceFile.stem().string() + "_kickass.log");
        const std::string kickCommand = kickAssPath + " " +
            "\"" + sourceFile.string() + "\" -o \"" +
            outputFile.string() + "\" > \"" +
            logFile.string() + "\" 2>&1";
        const int result = std::system(kickCommand.c_str());
        if (result != 0) {
            util::Logger::error("FAILURE: " + sourceFile.string() + " - please see output log for details: " + logFile.string());
            return false;
        }
        return true;
    }
    bool MusicBuilder::compressPrg(
        const fs::path& inputPrg,
        const fs::path& outputPrg,
        u16 loadAddress,
        const BuildOptions& options) {
        std::string compressCommand;
        if (options.compressorType == "exomizer") {
            std::string exomizerOptions = util::ConfigManager::getString("exomizerOptions", "-x 3 -q");
            compressCommand = options.exomizerPath + " sfx " + std::to_string(loadAddress) +
                " " + exomizerOptions + " \"" + inputPrg.string() + "\" -o \"" + outputPrg.string() + "\"";
        }
        else if (options.compressorType == "pucrunch") {
            std::string pucrunchPath = util::ConfigManager::getString("pucrunchPath", "pucrunch");
            std::string pucrunchOptions = util::ConfigManager::getString("pucrunchOptions", "-x");
            compressCommand = pucrunchPath + " " + pucrunchOptions + " " + std::to_string(loadAddress) +
                " \"" + inputPrg.string() + "\" \"" + outputPrg.string() + "\"";
        }
        else {
            util::Logger::error("Unsupported compressor type: " + options.compressorType);
            return false;
        }
        const int result = std::system(compressCommand.c_str());
        if (result != 0) {
            util::Logger::error("Compression failed: " + compressCommand);
            return false;
        }
        return true;
    }
    bool MusicBuilder::extractPrgFromSid(const fs::path& sidFile, const fs::path& outputPrg) {
        std::ifstream input(sidFile, std::ios::binary);
        if (!input) {
            util::Logger::error("Failed to open SID file for extraction: " + sidFile.string());
            return false;
        }
        SIDHeader header;
        input.read(reinterpret_cast<char*>(&header), sizeof(header));
        u16 dataOffset = (header.dataOffset >> 8) | (header.dataOffset << 8);
        u16 loadAddress = (header.loadAddress >> 8) | (header.loadAddress << 8);
        if (loadAddress == 0) {
            if (input.seekg(dataOffset, std::ios::beg)) {
                u8 lo, hi;
                input.read(reinterpret_cast<char*>(&lo), 1);
                input.read(reinterpret_cast<char*>(&hi), 1);
                loadAddress = (hi << 8) | lo;
                dataOffset += 2; 
            }
            else {
                util::Logger::error("Error seeking to data in SID file");
                return false;
            }
        }
        std::ofstream output(outputPrg, std::ios::binary);
        if (!output) {
            util::Logger::error("Failed to create PRG file: " + outputPrg.string());
            return false;
        }
        const u8 lo = loadAddress & 0xFF;
        const u8 hi = (loadAddress >> 8) & 0xFF;
        output.write(reinterpret_cast<const char*>(&lo), 1);
        output.write(reinterpret_cast<const char*>(&hi), 1);
        if (!input.seekg(dataOffset, std::ios::beg)) {
            util::Logger::error("Error seeking to data in SID file");
            return false;
        }
        char buffer[4096];
        while (input) {
            input.read(buffer, sizeof(buffer));
            std::streamsize bytesRead = input.gcount();
            if (bytesRead > 0) {
                output.write(buffer, bytesRead);
            }
            else {
                break;
            }
        }
        return true;
    }
}
```


### FILE: src/app/SIDwinderApp.cpp
```cpp
﻿
#include "SIDwinderApp.h"
#include "CommandProcessor.h"
#include "RelocationUtils.h"
#include "../SIDwinderUtils.h"
#include "../ConfigManager.h"
#include "../cpu6510.h"
#include "../SIDLoader.h"
#include "../SIDEmulator.h"
#include <iostream>
#include <filesystem>
namespace sidwinder {
    SIDwinderApp::SIDwinderApp(int argc, char** argv)
        : cmdParser_(argc, argv),
        command_(CommandClass::Type::Unknown) {
        setupCommandLine();
    }
    int SIDwinderApp::run() {
        fs::path configFile = "SIDwinder.cfg";
        if (!fs::exists(configFile)) {
            configFile = fs::path(cmdParser_.getProgramName()).parent_path() / "SIDwinder.cfg";
        }
        util::ConfigManager::initialize(configFile);
        command_ = cmdParser_.parse();
        initializeLogging();
        return executeCommand();
    }
    void SIDwinderApp::setupCommandLine() {
        cmdParser_.addFlagDefinition("player", "Link SID music with a player (convert .sid to playable .prg)", "Commands");
        cmdParser_.addFlagDefinition("relocate", "Relocate a SID file to a new address (use -relocate=<address>)", "Commands");
        cmdParser_.addFlagDefinition("disassemble", "Disassemble a SID file to assembly code", "Commands");
        cmdParser_.addFlagDefinition("trace", "Trace SID register writes during emulation", "Commands");
        std::string defaultPlayerName = util::ConfigManager::getPlayerName();
        cmdParser_.addOptionDefinition("log", "file", "Log file path", "General", util::ConfigManager::getString("logFile", "SIDwinder.log"));
        cmdParser_.addOptionDefinition("kickass", "path", "Path to KickAss.jar", "General", util::ConfigManager::getKickAssPath());
        cmdParser_.addOptionDefinition("exomizer", "path", "Path to Exomizer", "General", util::ConfigManager::getExomizerPath());
        cmdParser_.addOptionDefinition("define", "key=value", "Add user definition (can be used multiple times)", "Assembly");
        cmdParser_.addFlagDefinition("verbose", "Enable verbose logging", "General");
        cmdParser_.addFlagDefinition("help", "Display this help message", "General");
        cmdParser_.addFlagDefinition("force", "Force overwrite of output file", "General");
        cmdParser_.addFlagDefinition("nocompress", "Disable compression for PRG output", "General");
        cmdParser_.addFlagDefinition("noverify", "Skip verification after relocation", "Relocation");
        cmdParser_.addExample(
            "SIDwinder -player music.sid music.prg",
            "Links music.sid with the default player to create an executable music.prg");
        cmdParser_.addExample(
            "SIDwinder -player=SimpleBitmap music.sid player.prg",
            "Links music.sid with SimpleBitmap player");
        cmdParser_.addExample(
            "SIDwinder -relocate=$2000 music.sid relocated.sid",
            "Relocates music.sid to $2000 and saves as relocated.sid");
        cmdParser_.addExample(
            "SIDwinder -disassemble music.sid music.asm",
            "Disassembles music.sid to assembly code in music.asm");
        cmdParser_.addExample(
            "SIDwinder -trace music.sid",
            "Traces SID register writes to trace.bin in binary format");
        cmdParser_.addExample(
            "SIDwinder -trace=music.log music.sid",
            "Traces SID register writes to music.log in text format");
        cmdParser_.addExample(
            "SIDwinder -player -define BackgroundColor=$02 -define PlayerName=Dave music.sid game.prg",
            "Creates player with custom definitions accessible in the player code");
        cmdParser_.addExample(
            "SIDwinder -player=RaistlinBarsWithLogo -define LogoFile=\"Logos/MCH.kla\" music.sid game.prg",
            "Example with different logo for the player");
    }
    void SIDwinderApp::initializeLogging() {
        std::string logFilePath = command_.getParameter("logfile",
            util::ConfigManager::getString("logFile", "SIDwinder.log"));
        logFile_ = fs::path(logFilePath);
        verbose_ = command_.hasFlag("verbose");
        int configLogLevel = util::ConfigManager::getInt("logLevel", 3); 
        auto logLevel = verbose_ ?
            util::Logger::Level::Debug :
            static_cast<util::Logger::Level>(std::min(std::max(configLogLevel - 1, 0), 3));
        util::Logger::initialize(logFile_);
        util::Logger::setLogLevel(logLevel);
    }
    int SIDwinderApp::executeCommand() {
        switch (command_.getType()) {
        case CommandClass::Type::Help:
            return showHelp();
        case CommandClass::Type::Player:
            return processPlayer();
        case CommandClass::Type::Relocate:
            return processRelocation();
        case CommandClass::Type::Disassemble:
            return processDisassembly();
        case CommandClass::Type::Trace:
            return processTrace();
        default:
            std::cout << "Unknown command or no command specified" << std::endl << std::endl;
            return showHelp();
        }
    }
    CommandProcessor::ProcessingOptions SIDwinderApp::createProcessingOptions() {
        CommandProcessor::ProcessingOptions options;
        options.inputFile = fs::path(command_.getInputFile());
        options.outputFile = fs::path(command_.getOutputFile());
        options.tempDir = fs::path("temp");
        try {
            fs::create_directories(options.tempDir);
        }
        catch (const std::exception& e) {
            util::Logger::error(std::string("Failed to create temp directory: ") + e.what());
        }
        options.userDefinitions = command_.getDefinitions();
        if (command_.getType() == CommandClass::Type::Player) {
            options.includePlayer = true;
            options.playerName = command_.getParameter("playerName", util::ConfigManager::getPlayerName());
            options.playerAddress = command_.getHexParameter("playeraddr", util::ConfigManager::getPlayerAddress());
            options.analyzeRegisterOrder = true; 
        }
        else {
            options.includePlayer = false;
        }
        options.kickAssPath = command_.getParameter("kickass", util::ConfigManager::getKickAssPath());
        options.exomizerPath = command_.getParameter("exomizer", util::ConfigManager::getExomizerPath());
        options.compressorType = util::ConfigManager::getCompressorType();
        options.compress = !command_.hasFlag("nocompress");
        if (command_.getType() == CommandClass::Type::Relocate) {
            options.relocationAddress = command_.getHexParameter("relocateaddr", 0);
            options.hasRelocation = true;
        }
        options.traceLogPath = command_.getParameter("tracelog", "");
        options.enableTracing = !options.traceLogPath.empty() || (command_.getType() == CommandClass::Type::Trace);
        std::string traceFormat = command_.getParameter("traceformat", "binary");
        options.traceFormat = (traceFormat == "text") ?
            TraceFormat::Text : TraceFormat::Binary;
        options.frames = command_.getIntParameter("frames",
            util::ConfigManager::getInt("emulationFrames", DEFAULT_SID_EMULATION_FRAMES));
        return options;
    }
    int SIDwinderApp::showHelp() {
        cmdParser_.printUsage(SIDwinder_VERSION);
        return 0;
    }
    int SIDwinderApp::processPlayer() {
        fs::path inputFile = fs::path(command_.getInputFile());
        fs::path outputFile = fs::path(command_.getOutputFile());
        if (inputFile.empty()) {
            std::cout << "Error: No input file specified for player command" << std::endl;
            return 1;
        }
        if (outputFile.empty()) {
            std::cout << "Error: No output file specified for player command" << std::endl;
            return 1;
        }
        if (!fs::exists(inputFile)) {
            std::cout << "Error: Input file not found: " << inputFile.string() << std::endl;
            return 1;
        }
        std::string inExt = getFileExtension(inputFile);
        if (inExt != ".sid") {
            std::cout << "Error: Player command requires a .sid input file, got: " << inExt << std::endl;
            return 1;
        }
        std::string outExt = getFileExtension(outputFile);
        if (outExt != ".prg") {
            std::cout << "Error: Player command requires a .prg output file, got: " << outExt << std::endl;
            return 1;
        }
        CommandProcessor::ProcessingOptions options = createProcessingOptions();
        options.includePlayer = true;
        options.playerName = command_.getParameter("playerName", util::ConfigManager::getPlayerName());
        options.playerAddress = command_.getHexParameter("playeraddr", util::ConfigManager::getPlayerAddress());
        CommandProcessor processor;
        bool success = processor.processFile(options);
        if (success)
        {
            std::cout << "SUCCESS: " << outputFile << " successfully generated" << std::endl;
        }
        return success ? 0 : 1;
    }
    int SIDwinderApp::processRelocation() {
        fs::path inputFile = fs::path(command_.getInputFile());
        fs::path outputFile = fs::path(command_.getOutputFile());
        if (inputFile.empty()) {
            std::cout << "Error: No input file specified for relocate command" << std::endl;
            return 1;
        }
        if (outputFile.empty()) {
            std::cout << "Error: No output file specified for relocate command" << std::endl;
            return 1;
        }
        auto cpu = std::make_unique<CPU6510>();
        cpu->reset();
        auto sid = std::make_unique<SIDLoader>();
        sid->setCPU(cpu.get());
        u16 relocAddress = command_.getHexParameter("relocateaddr", 0);
        bool skipVerify = command_.hasFlag("noverify");
        if (skipVerify) {
            util::RelocationParams params;
            params.inputFile = inputFile;
            params.outputFile = outputFile;
            params.tempDir = fs::path("temp");
            params.relocationAddress = relocAddress;
            params.kickAssPath = command_.getParameter("kickass", util::ConfigManager::getKickAssPath());
            params.verbose = command_.hasFlag("verbose");
            try {
                fs::create_directories(params.tempDir);
            }
            catch (const std::exception& e) {
                util::Logger::error(std::string("Failed to create temp directory: ") + e.what());
                return 1;
            }
            util::RelocationResult result = util::relocateSID(cpu.get(), sid.get(), params);
            if (result.success) {
                return 0;
            }
            else {
                util::Logger::error("Failed to relocate " + inputFile.string() + ": " + result.message);
                return 1;
            }
        }
        else {
            fs::path tempDir = fs::path("temp");
            try {
                fs::create_directories(tempDir);
            }
            catch (const std::exception& e) {
                util::Logger::error(std::string("Failed to create temp directory: ") + e.what());
                return 1;
            }
            util::RelocationVerificationResult result = util::relocateAndVerifySID(cpu.get(), sid.get(), inputFile, outputFile, relocAddress, tempDir, command_.getParameter("kickass", util::ConfigManager::getKickAssPath()));
            bool bTotalSuccess = result.success && result.verified && result.outputsMatch;
            std::cout << (bTotalSuccess ? "SUCCESS" : "FAILURE") << ": " << inputFile << " " << result.message << std::endl;
            return bTotalSuccess ? 0 : 1;
        }
    }
    int SIDwinderApp::processDisassembly() {
        fs::path inputFile = fs::path(command_.getInputFile());
        fs::path outputFile = fs::path(command_.getOutputFile());
        if (inputFile.empty()) {
            std::cout << "Error: No input file specified for disassemble command" << std::endl;
            return 1;
        }
        if (outputFile.empty()) {
            std::cout << "Error: No output file specified for disassemble command" << std::endl;
            return 1;
        }
        if (!fs::exists(inputFile)) {
            std::cout << "Error: Input file not found: " << inputFile.string() << std::endl;
            return 1;
        }
        std::string inExt = getFileExtension(inputFile);
        if (inExt != ".sid") {
            std::cout << "Error: Disassemble command requires a .sid input file, got: " << inExt << std::endl;
            return 1;
        }
        std::string outExt = getFileExtension(outputFile);
        if (outExt != ".asm") {
            std::cout << "Error: Disassemble command requires an .asm output file, got: " << outExt << std::endl;
            return 1;
        }
        CommandProcessor::ProcessingOptions options = createProcessingOptions();
        CommandProcessor processor;
        bool success = processor.processFile(options);
        if (!success) {
            util::Logger::error("Failed to disassemble " + inputFile.string());
        }
        return success ? 0 : 1;
    }
    int SIDwinderApp::processTrace() {
        fs::path inputFile = fs::path(command_.getInputFile());
        if (inputFile.empty()) {
            std::cout << "Error: No input file specified for trace command" << std::endl;
            return 1;
        }
        if (!fs::exists(inputFile)) {
            std::cout << "Error: Input file not found: " << inputFile.string() << std::endl;
            return 1;
        }
        std::string inExt = getFileExtension(inputFile);
        if (inExt != ".sid") {
            std::cout << "Error: Trace command requires a .sid input file, got: " << inExt << std::endl;
            return 1;
        }
        std::string traceLogPath = command_.getParameter("tracelog", "trace.bin");
        std::string traceFormatStr = command_.getParameter("traceformat", "binary");
        TraceFormat traceFormat = (traceFormatStr == "text") ? TraceFormat::Text : TraceFormat::Binary;
        auto cpu = std::make_unique<CPU6510>();
        cpu->reset();
        auto sid = std::make_unique<SIDLoader>();
        sid->setCPU(cpu.get());
        if (!sid->loadSID(inputFile.string())) {
            std::cout << "Error: Failed to load SID file: " << inputFile.string() << std::endl;
            return 1;
        }
        auto traceLogger = std::make_unique<TraceLogger>(traceLogPath, traceFormat);
        SIDEmulator emulator(cpu.get(), sid.get());
        SIDEmulator::EmulationOptions options;
        options.frames = command_.getIntParameter("frames",
            util::ConfigManager::getInt("emulationFrames", DEFAULT_SID_EMULATION_FRAMES));
        options.traceEnabled = true;
        options.traceFormat = traceFormat;
        options.traceLogPath = traceLogPath;
        bool success = emulator.runEmulation(options);
        if (success) {
            return 0;
        }
        else {
            util::Logger::error("Error occurred during SID emulation on " + inputFile.string());
            return 1;
        }
    }
}
```


### FILE: src/app/TraceLogger.cpp
```cpp
#include "TraceLogger.h"
#include "../SIDwinderUtils.h"
#include <map>
namespace sidwinder {
    TraceLogger::TraceLogger(const std::string& filename, TraceFormat format)
        : format_(format), isOpen_(false) {
        if (filename.empty()) {
            return;
        }
        file_.open(filename, format == TraceFormat::Binary ?
            (std::ios::binary | std::ios::out) : std::ios::out);
        isOpen_ = file_.is_open();
        if (!isOpen_) {
            util::Logger::error("Failed to open trace log file: " + filename);
        }
    }
    TraceLogger::~TraceLogger() {
        if (isOpen_) {
            if (format_ == TraceFormat::Binary) {
                TraceRecord record(FRAME_MARKER);
                writeBinaryRecord(record);
            }
            file_.close();
        }
    }
    void TraceLogger::logFrameMarker() {
        if (!isOpen_) return;
        if (format_ == TraceFormat::Text) {
            file_ << "\nFRAME: ";
        }
        else {
            TraceRecord record(FRAME_MARKER);
            writeBinaryRecord(record);
        }
    }
    void TraceLogger::flushLog() {
        if (isOpen_) {
            file_.flush();
        }
    }
    void TraceLogger::writeTextRecord(u16 addr, u8 value) {
        file_ << util::wordToHex(addr) << ":$" << util::byteToHex(value) << ",";
    }
    void TraceLogger::writeBinaryRecord(const TraceRecord& record) {
        file_.write(reinterpret_cast<const char*>(&record), sizeof(TraceRecord));
    }
    bool TraceLogger::compareTraceLogs(
        const std::string& originalLog,
        const std::string& relocatedLog,
        const std::string& reportFile) {
        std::ifstream original(originalLog, std::ios::binary);
        std::ifstream relocated(relocatedLog, std::ios::binary);
        std::ofstream report(reportFile);
        if (!original || !relocated || !report) {
            util::Logger::error("Failed to open trace log files for comparison");
            return false;
        }
        bool identical = true;
        int frameCount = 0;
        int originalFrameCount = 0;
        int relocatedFrameCount = 0;
        int differentFrameCount = 0;
        const int maxDifferenceOutput = 64; 
        report << "SIDwinder Trace Log Comparison Report\n";
        report << "Original: " << originalLog << "\n";
        report << "Relocated: " << relocatedLog << "\n\n";
        std::vector<std::pair<u16, u8>> originalFrameData;
        std::vector<std::pair<u16, u8>> relocatedFrameData;
        TraceRecord origRecord, relocRecord;
        bool origEof = false;
        bool relocEof = false;
        while (!origEof && !relocEof) {
            originalFrameData.clear();
            while (original.read(reinterpret_cast<char*>(&origRecord), sizeof(TraceRecord))) {
                if (origRecord.commandTag == FRAME_MARKER) {
                    originalFrameCount++;
                    break;
                }
                originalFrameData.emplace_back(origRecord.write.address, origRecord.write.value);
            }
            if (original.eof()) {
                origEof = true;
            }
            relocatedFrameData.clear();
            while (relocated.read(reinterpret_cast<char*>(&relocRecord), sizeof(TraceRecord))) {
                if (relocRecord.commandTag == FRAME_MARKER) {
                    relocatedFrameCount++;
                    break;
                }
                relocatedFrameData.emplace_back(relocRecord.write.address, relocRecord.write.value);
            }
            if (relocated.eof()) {
                relocEof = true;
            }
            if (origEof || relocEof) {
                break;
            }
            frameCount++;
            std::string origLine = "  Orig: ";
            std::string reloLine = "  Relo: ";
            bool first = true;
            for (const auto& [addr, value] : originalFrameData) {
                if (!first) origLine += ",";
                origLine += util::wordToHex(addr) + ":" + util::byteToHex(value);
                first = false;
            }
            first = true;
            for (const auto& [addr, value] : relocatedFrameData) {
                if (!first) reloLine += ",";
                reloLine += util::wordToHex(addr) + ":" + util::byteToHex(value);
                first = false;
            }
            std::map<u16, u8> origMap;
            std::map<u16, u8> reloMap;
            for (const auto& [addr, value] : originalFrameData) {
                origMap[addr] = value;
            }
            for (const auto& [addr, value] : relocatedFrameData) {
                reloMap[addr] = value;
            }
            bool frameIdentical = (originalFrameData == relocatedFrameData);
            if (!frameIdentical) {
                differentFrameCount++;
                identical = false;
                if (differentFrameCount <= maxDifferenceOutput) {
                    report << "Frame " << frameCount << ":\n";
                    report << origLine << "\n";
                    report << reloLine << "\n";
                    const size_t indicatorLength = std::max(origLine.length(), reloLine.length());
                    std::string indicatorLine(indicatorLength, ' ');
                    size_t origPos = 8; 
                    for (const auto& [addr, value] : originalFrameData) {
                        std::string entry = util::wordToHex(addr) + ":" + util::byteToHex(value);
                        bool found = (reloMap.find(addr) != reloMap.end());
                        if (!found || reloMap[addr] != value) {
                            for (size_t i = 0; i < 7 && (origPos + i) < indicatorLength; i++) {
                                indicatorLine[origPos + i] = '*';
                            }
                        }
                        origPos += entry.length() + 1;
                    }
                    size_t reloPos = 8; 
                    for (const auto& [addr, value] : relocatedFrameData) {
                        std::string entry = util::wordToHex(addr) + ":" + util::byteToHex(value);
                        bool found = (origMap.find(addr) != origMap.end());
                        if (!found || origMap[addr] != value) {
                            for (size_t i = 0; i < 7 && (reloPos + i) < indicatorLength; i++) {
                                indicatorLine[reloPos + i] = '*';
                            }
                        }
                        reloPos += entry.length() + 1;
                    }
                    if (originalFrameData.size() > relocatedFrameData.size() && !relocatedFrameData.empty()) {
                        size_t markPos = reloPos;
                        while (markPos < indicatorLength) {
                            for (int i = 0; i < 7 && markPos + i < indicatorLength; i++) {
                                indicatorLine[markPos + i] = '*';
                            }
                            markPos += 8; 
                        }
                    }
                    else if (relocatedFrameData.size() > originalFrameData.size() && !originalFrameData.empty()) {
                        size_t markPos = origPos;
                        while (markPos < indicatorLength) {
                            for (int i = 0; i < 7 && markPos + i < indicatorLength; i++) {
                                indicatorLine[markPos + i] = '*';
                            }
                            markPos += 8; 
                        }
                    }
                    report << indicatorLine << "\n\n";
                }
                else if (differentFrameCount == maxDifferenceOutput + 1) {
                    report << "Additional differences omitted...\n\n";
                }
            }
        }
        if (originalFrameCount != relocatedFrameCount) {
            report << "Frame count mismatch: Original has " << originalFrameCount
                << " frames, Relocated has " << relocatedFrameCount << " frames\n\n";
            identical = false;
        }
        report << "Summary:\n";
        if (identical) {
            report << "File 1: " << originalFrameCount << " frames\n";
            report << "File 2: " << relocatedFrameCount << " frames\n";
            report << "Result: NO DIFFERENCES FOUND - " << frameCount << " frames verified\n";
        }
        else {
            report << "Result: DIFFERENCES FOUND - "
                << differentFrameCount << " frames out of "
                << frameCount << " differed\n";
        }
        return identical;
    }
}
```


### FILE: src/CodeFormatter.h
```cpp
#pragma once
#include "LabelGenerator.h"
#include "SIDwinderUtils.h"
#include "RelocationStructs.h"
#include <memory>
#include <span>
#include <string>
#include <vector>
class CPU6510;
namespace sidwinder {
    class CodeFormatter {
    public:
        CodeFormatter(
            const CPU6510& cpu,
            const LabelGenerator& labelGenerator,
            std::span<const u8> memory);
        std::string formatInstruction(u16& pc) const;
        void formatDataBytes(
            std::ostream& file,
            u16& pc,
            std::span<const u8> originalMemory,
            u16 originalBase,
            u16 endAddress,
            const std::map<u16, RelocationEntry>& relocationBytes,
            std::span<const MemoryType> memoryTags) const;
        bool isCIAStorePatch(
            u8 opcode,
            int mode,
            u16 operand,
            std::string_view mnemonic) const;
        std::string formatOperand(u16 pc, int mode) const;
        std::string formatIndexedAddressWithMinOffset(
            u16 baseAddr,
            u8 minOffset,
            char indexReg) const;
        void setCIAWriteRemoval(bool removeCIAWrites) const;
    private:
        const CPU6510& cpu_;                      
        const LabelGenerator& labelGenerator_;    
        std::span<const u8> memory_;              
        mutable bool removeCIAWrites_;            
    };
}
```


### FILE: src/CommandClass.h
```cpp
#pragma once
#include "Common.h"
#include <string>
#include <map>
#include <vector>
#include <optional>
namespace sidwinder {
    class CommandClass {
    public:
        enum class Type {
            Player,        
            Relocate,      
            Disassemble,   
            Trace,         
            Help,          
            Unknown        
        };
        CommandClass(Type type = Type::Unknown);
        Type getType() const { return type_; }
        void setType(Type type) { type_ = type; }
        const std::string& getInputFile() const { return inputFile_; }
        void setInputFile(const std::string& inputFile) { inputFile_ = inputFile; }
        const std::string& getOutputFile() const { return outputFile_; }
        void setOutputFile(const std::string& outputFile) { outputFile_ = outputFile; }
        std::string getParameter(const std::string& key, const std::string& defaultValue = "") const;
        bool hasParameter(const std::string& key) const;
        void setParameter(const std::string& key, const std::string& value);
        void addDefinition(const std::string& key, const std::string& value);
        std::map<std::string, std::string> getDefinitions() const;
        bool hasFlag(const std::string& flag) const;
        void setFlag(const std::string& flag, bool value = true);
        u16 getHexParameter(const std::string& key, u16 defaultValue = 0) const;
        int getIntParameter(const std::string& key, int defaultValue = 0) const;
        bool getBoolParameter(const std::string& key, bool defaultValue = false) const;
    private:
        Type type_;                               
        std::string inputFile_;                   
        std::string outputFile_;                  
        std::map<std::string, std::string> params_; 
        std::vector<std::string> flags_;          
    };
}
```


### FILE: src/CommandLineParser.h
```cpp
#pragma once
#include "CommandClass.h"
#include <filesystem>
#include <string>
#include <map>
#include <vector>
namespace sidwinder {
    class CommandLineParser {
    public:
        CommandLineParser(int argc, char** argv);
        CommandClass parse() const;
        const std::string& getProgramName() const;
        void printUsage(const std::string& message = "") const;
        CommandLineParser& addFlagDefinition(
            const std::string& flag,
            const std::string& description,
            const std::string& category = "General");
        CommandLineParser& addOptionDefinition(
            const std::string& option,
            const std::string& argName,
            const std::string& description,
            const std::string& category = "General",
            const std::string& defaultValue = "");
        CommandLineParser& addExample(
            const std::string& example,
            const std::string& description);
    private:
        std::vector<std::string> args_;            
        std::string programName_;                  
        struct OptionDefinition {
            std::string argName;       
            std::string description;   
            std::string category;      
            std::string defaultValue;  
        };
        struct FlagDefinition {
            std::string description;   
            std::string category;      
        };
        struct ExampleUsage {
            std::string example;       
            std::string description;   
        };
        std::map<std::string, OptionDefinition> optionDefs_;  
        std::map<std::string, FlagDefinition> flagDefs_;      
        std::vector<ExampleUsage> examples_;                  
    };
}
```


### FILE: src/Common.h
```cpp
#pragma once
#include <cstdint>
#include <filesystem>
namespace fs = std::filesystem;
#define SIDwinder_VERSION "SIDwinder 0.2.0"
#define DEFAULT_SID_EMULATION_FRAMES (10 * 60 * 50) 
using u8 = std::uint8_t;
using u16 = std::uint16_t;
using u32 = std::uint32_t;
using u64 = std::uint64_t;
using i8 = std::int8_t;
using i16 = std::int16_t;
using i32 = std::int32_t;
using i64 = std::int64_t;
std::string getFileExtension(const fs::path& filePath);
```


### FILE: src/ConfigManager.h
```cpp
#pragma once
#include "Common.h"
#include <map>
#include <string>
#include <filesystem>
namespace sidwinder {
    namespace util {
        class ConfigManager {
        public:
            static bool initialize(const std::filesystem::path& configFile);
            static std::string getString(const std::string& key, const std::string& defaultValue = {});
            static int getInt(const std::string& key, int defaultValue = 0);
            static bool getBool(const std::string& key, bool defaultValue = false);
            static double getDouble(const std::string& key, double defaultValue = 0.0);
            static void setValue(const std::string& key, const std::string& value, bool saveToFile = false);
            static std::string getKickAssPath();
            static std::string getExomizerPath();
            static std::string getCompressorType();
            static std::string getPlayerName();
            static u16 getPlayerAddress();
            static u16 getDefaultSidLoadAddress();
            static u16 getDefaultSidInitAddress();
            static u16 getDefaultSidPlayAddress();
            static std::string getClockStandard();
            static double getCyclesPerFrame();
        private:
            static std::map<std::string, std::string> configValues_;
            static std::filesystem::path configFile_;
            static void setupDefaults();
            static bool loadFromFile(const std::filesystem::path& configFile);
            static bool saveToFile(const std::filesystem::path& configFile);
            static std::string generateFormattedConfig();
        };
    } 
}
```


### FILE: src/cpu6510.h
```cpp
#pragma once
#include "Common.h"
#include <array>
#include <functional>
#include <limits>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <map>
#include <unordered_map>
#include <vector>
class CPU6510Impl;
enum class AddressingMode {
    Implied,
    Immediate,
    ZeroPage,
    ZeroPageX,
    ZeroPageY,
    Absolute,
    AbsoluteX,
    AbsoluteY,
    Indirect,
    IndirectX,
    IndirectY,
    Relative,
    Accumulator
};
enum class MemoryAccessFlag : u8 {
    Execute = 1 << 0,
    Read = 1 << 1,
    Write = 1 << 2,
    JumpTarget = 1 << 3,
    OpCode = 1 << 4,
};
inline MemoryAccessFlag operator|(MemoryAccessFlag a, MemoryAccessFlag b) {
    return static_cast<MemoryAccessFlag>(static_cast<u8>(a) | static_cast<u8>(b));
}
inline MemoryAccessFlag& operator|=(MemoryAccessFlag& a, MemoryAccessFlag b) {
    a = a | b;
    return a;
}
inline bool operator&(MemoryAccessFlag a, MemoryAccessFlag b) {
    return (static_cast<u8>(a) & static_cast<u8>(b)) != 0;
}
enum class StatusFlag : u8 {
    Carry = 0x01,      
    Zero = 0x02,       
    Interrupt = 0x04,  
    Decimal = 0x08,    
    Break = 0x10,      
    Unused = 0x20,     
    Overflow = 0x40,   
    Negative = 0x80    
};
inline u8 operator|(StatusFlag a, StatusFlag b) {
    return static_cast<u8>(a) | static_cast<u8>(b);
}
inline u8 operator|(u8 a, StatusFlag b) {
    return a | static_cast<u8>(b);
}
inline u8& operator|=(u8& a, StatusFlag b) {
    a = a | static_cast<u8>(b);
    return a;
}
inline u8 operator&(u8 a, StatusFlag b) {
    return a & static_cast<u8>(b);
}
inline u8& operator&=(u8& a, StatusFlag b) {
    a = a & static_cast<u8>(b);
    return a;
}
inline u8 operator~(StatusFlag a) {
    return ~static_cast<u8>(a);
}
enum class Instruction {
    ADC, AND, ASL, BCC, BCS, BEQ, BIT, BMI,
    BNE, BPL, BRK, BVC, BVS, CLC, CLD, CLI,
    CLV, CMP, CPX, CPY, DEC, DEX, DEY, EOR,
    INC, INX, INY, JMP, JSR, LDA, LDX, LDY,
    LSR, NOP, ORA, PHA, PHP, PLA, PLP, ROL,
    ROR, RTI, RTS, SBC, SEC, SED, SEI, STA,
    STX, STY, TAX, TAY, TSX, TXA, TXS, TYA,
    AHX, ANC, ALR, ARR, AXS, DCP, ISC, KIL,
    LAS, LAX, RLA, RRA, SAX, SLO, SRE, TAS,
    SHA, SHX, SHY, XAA
};
struct RegisterSourceInfo {
    enum class SourceType { Unknown, Immediate, Memory };
    SourceType type = SourceType::Unknown;
    u32 address = 0;
    u8 value = 0;
    u8 index = 0;
};
struct IndexRange {
    int min = std::numeric_limits<int>::max();
    int max = std::numeric_limits<int>::min();
    void update(int offset) {
        min = std::min(min, offset);
        max = std::max(max, offset);
    }
    std::pair<int, int> getRange() const {
        if (min > max) return { 0, 0 };  
        return { min, max };
    }
};
struct OpcodeInfo {
    Instruction instruction;
    std::string_view mnemonic;
    AddressingMode mode;
    u8 cycles;
    bool illegal;
};
struct MemoryDataFlow {
    std::map<u32, std::vector<u32>> memoryWriteSources;
};
class CPU6510 {
public:
    CPU6510();
    ~CPU6510();
    CPU6510(const CPU6510&) = delete;
    CPU6510& operator=(const CPU6510&) = delete;
    CPU6510(CPU6510&&) = delete;
    CPU6510& operator=(CPU6510&&) = delete;
    void reset();
    void resetRegistersAndFlags();
    void step();
    bool executeFunction(u32 address);
    void jumpTo(u32 address);
    u8 readMemory(u32 addr);
    void writeByte(u32 addr, u8 value);
    void writeMemory(u32 addr, u8 value);
    void copyMemoryBlock(u32 start, std::span<const u8> data);
    void loadData(const std::string& filename, u32 loadAddress);
    void setPC(u32 address);
    u32 getPC() const;
    void setSP(u8 sp);
    u8 getSP() const;
    u64 getCycles() const;
    void setCycles(u64 newCycles);
    void resetCycles();
    std::string_view getMnemonic(u8 opcode) const;
    u8 getInstructionSize(u8 opcode) const;
    AddressingMode getAddressingMode(u8 opcode) const;
    bool isIllegalInstruction(u8 opcode) const;
    void dumpMemoryAccess(const std::string& filename);
    std::pair<u8, u8> getIndexRange(u32 pc) const;
    std::span<const u8> getMemory() const;
    std::span<const u8> getMemoryAccess() const;
    u32 getLastWriteTo(u32 addr) const;
    const std::vector<u32>& getLastWriteToAddr() const;
    RegisterSourceInfo getRegSourceA() const;
    RegisterSourceInfo getRegSourceX() const;
    RegisterSourceInfo getRegSourceY() const;
    RegisterSourceInfo getWriteSourceInfo(u32 addr) const;
    const MemoryDataFlow& getMemoryDataFlow() const;
    using IndirectReadCallback = std::function<void(u32 pc, u8 zpAddr, u32 targetAddr)>;
    using MemoryWriteCallback = std::function<void(u32 addr, u8 value)>;
    using MemoryFlowCallback = std::function<void(u32 pc, char reg, u32 sourceAddr, u8 value, bool isIndexed)>;
    void setOnIndirectReadCallback(IndirectReadCallback callback);
    void setOnWriteMemoryCallback(MemoryWriteCallback callback);
    void setOnCIAWriteCallback(MemoryWriteCallback callback);
    void setOnSIDWriteCallback(MemoryWriteCallback callback);
    void setOnVICWriteCallback(MemoryWriteCallback callback);
    void setOnMemoryFlowCallback(MemoryFlowCallback callback);
private:
    std::unique_ptr<CPU6510Impl> pImpl_;
};
```


### FILE: src/Disassembler.h
```cpp
#pragma once
#include "SIDwinderUtils.h"
#include <functional>
#include <memory>
#include <string>
class CPU6510;
class SIDLoader;
namespace sidwinder {
    class MemoryAnalyzer;
    class LabelGenerator;
    class CodeFormatter;
    class DisassemblyWriter;
    class Disassembler {
    public:
        Disassembler(const CPU6510& cpu, const SIDLoader& sid);
        ~Disassembler();
        void generateAsmFile(
            const std::string& outputPath,
            u16 sidLoad,
            u16 sidInit,
            u16 sidPlay,
            bool removeCIAWrites = false);
    private:
        const CPU6510& cpu_;  
        const SIDLoader& sid_;  
        std::unique_ptr<MemoryAnalyzer> analyzer_;
        std::unique_ptr<LabelGenerator> labelGenerator_;
        std::unique_ptr<CodeFormatter> formatter_;
        std::unique_ptr<DisassemblyWriter> writer_;
        void initialize();
    };
}
```


### FILE: src/DisassemblyWriter.h
```cpp
#pragma once
#include "cpu6510.h"
#include "CodeFormatter.h"
#include "LabelGenerator.h"
#include "MemoryAnalyzer.h"
#include "SIDwinderUtils.h"
#include "RelocationStructs.h"
#include <fstream>
#include <map>
#include <string>
#include <vector>
class SIDLoader;
class CPU6510;
namespace sidwinder {
    struct RelocationInfo {
        u16 targetAddr;                  
        enum class Type { Low, High } type; 
    };
    class DisassemblyWriter {
    public:
        DisassemblyWriter(
            const CPU6510& cpu,
            const SIDLoader& sid,
            const MemoryAnalyzer& analyzer,
            const LabelGenerator& labelGenerator,
            const CodeFormatter& formatter);
        void generateAsmFile(
            const std::string& filename,
            u16 sidLoad,
            u16 sidInit,
            u16 sidPlay,
            bool removeCIAWrites = false);
        void addIndirectAccess(u16 pc, u8 zpAddr, u16 targetAddr);
        void processIndirectAccesses();
        void onMemoryFlow(u16 pc, char reg, u16 sourceAddr, u8 value, bool isIndexed);
        void updateSelfModifyingPattern(u16 instrAddr, int offset, u16 sourceAddr, u8 value) {
            auto& patterns = selfModifyingPatterns_[instrAddr];
            SelfModifyingPattern* currentPattern = nullptr;
            for (auto& pattern : patterns) {
                if (pattern.hasLowByte && !pattern.hasHighByte && offset == 2) {
                    currentPattern = &pattern;
                    break;
                }
                else if (!pattern.hasLowByte && pattern.hasHighByte && offset == 1) {
                    currentPattern = &pattern;
                    break;
                }
            }
            if (!currentPattern) {
                patterns.push_back(SelfModifyingPattern{});
                currentPattern = &patterns.back();
            }
            if (offset == 1) {
                currentPattern->lowByteSource = sourceAddr;
                currentPattern->lowByte = value;
                currentPattern->hasLowByte = true;
            }
            else if (offset == 2) {
                currentPattern->highByteSource = sourceAddr;
                currentPattern->highByte = value;
                currentPattern->hasHighByte = true;
            }
        }
        void analyzeWritesForSelfModification();
    private:
        const CPU6510& cpu_;                      
        const SIDLoader& sid_;                    
        const MemoryAnalyzer& analyzer_;          
        const LabelGenerator& labelGenerator_;    
        const CodeFormatter& formatter_;          
        RelocationTable relocTable_;              
        struct IndirectAccessInfo {
            u16 instructionAddress = 0;   
            u8 zpAddr = 0;                
            u16 sourceLowAddress = 0;     
            u16 sourceHighAddress = 0;    
            std::vector<u16> targetAddresses; 
        };
        std::vector<IndirectAccessInfo> indirectAccesses_;  
        struct MemoryFlowInfo {
            u16 sourceAddr;
            u8 value;
            bool isIndexed;
        };
        std::map<char, MemoryFlowInfo> registerSources_;
        struct SelfModifyingPattern {
            u16 lowByteSource = 0;
            u16 highByteSource = 0;
            u8 lowByte = 0;
            u8 highByte = 0;
            bool hasLowByte = false;
            bool hasHighByte = false;
        };
        std::map<u16, std::vector<SelfModifyingPattern>> selfModifyingPatterns_;
        void outputHardwareConstants(std::ofstream& file);
        void emitZPDefines(std::ofstream& file);
        void disassembleToFile(std::ofstream& file, bool removeCIAWrites);
        void processRelocationChain(const MemoryDataFlow& dataFlow, RelocationTable& relocTable, u16 addr, u16 targetAddr, RelocationEntry::Type relocType);
        struct WriteRecord {
            u16 addr;
            u8 value;
            RegisterSourceInfo sourceInfo;
        };
        std::vector<WriteRecord> allWrites_;
        friend class Disassembler;
    };
}
```


### FILE: src/LabelGenerator.h
```cpp
#pragma once
#include "MemoryAnalyzer.h"
#include "SIDwinderUtils.h"
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>
namespace sidwinder {
    struct DataBlock {
        std::string label;  
        u16 start;          
        u16 end;            
    };
    enum class HardwareType {
        SID,    
        VIC,    
        CIA1,   
        CIA2,   
        Other   
    };
    struct HardwareBase {
        HardwareType type;  
        u16 address;        
        int index;          
        std::string name;   
    };
    class LabelGenerator {
    public:
        LabelGenerator(
            const MemoryAnalyzer& analyzer,
            u16 loadAddress,
            u16 endAddress,
            std::span<const u8> memory);
        void generateLabels();
        std::string getLabel(u16 addr) const;
        const std::vector<DataBlock>& getDataBlocks() const;
        std::string formatAddress(u16 addr) const;
        std::string formatZeroPage(u8 addr) const;
        void addZeroPageVar(u8 addr, const std::string& label);
        const std::map<u8, std::string>& getZeroPageVars() const;
        void addHardwareBase(HardwareType type, u16 address, int index, const std::string& name);
        const std::vector<HardwareBase>& getHardwareBases() const;
        void addDataBlockSubdivision(
            const std::string& blockLabel,
            u16 startOffset,
            u16 endOffset);
        void addPendingSubdivisionAddress(u16 addr);
        void applySubdivisions();
        const std::map<u16, std::string>& getLabelMap() const;
    private:
        const MemoryAnalyzer& analyzer_;  
        u16 loadAddress_;                 
        u16 endAddress_;                  
        std::span<const u8> memory_;      
        int codeLabelCounter_ = 0;        
        int dataLabelCounter_ = 0;        
        std::map<u16, std::string> labelMap_;          
        std::vector<DataBlock> dataBlocks_;            
        std::map<u8, std::string> zeroPageVars_;       
        std::vector<HardwareBase> usedHardwareBases_;  
        std::map<u16, std::pair<u16, u16>> midInstructionLabels_; 
        struct AccessInfo {
            u16 offset;     
            u16 absAddr;    
            u16 pc;         
            bool isWrite;   
        };
        std::unordered_map<std::string, std::vector<AccessInfo>> dataBlockAccessMap_;
        std::unordered_map<std::string, std::vector<std::pair<u16, u16>>> dataBlockSubdivisions_;
        std::set<u16> pendingSubdivisionAddresses_;  
        int getInstructionSize(u8 opcode) const;
        bool isProbableOpcode(u16 addr) const;
    };
}
```


### FILE: src/MemoryAnalyzer.h
```cpp
#pragma once
#include "SIDwinderUtils.h"
#include <memory>
#include <span>
#include <vector>
namespace sidwinder {
    enum class MemoryType : u8 {
        Unknown = 0,        
        Code = 1 << 0,      
        Data = 1 << 1,      
        LabelTarget = 1 << 2, 
        Accessed = 1 << 3   
    };
    inline MemoryType operator|(MemoryType a, MemoryType b) {
        return static_cast<MemoryType>(static_cast<u8>(a) | static_cast<u8>(b));
    }
    inline bool operator&(MemoryType a, MemoryType b) {
        return (static_cast<u8>(a) & static_cast<u8>(b)) != 0;
    }
    inline MemoryType& operator|=(MemoryType& a, MemoryType b) {
        a = static_cast<MemoryType>(static_cast<u8>(a) | static_cast<u8>(b));
        return a;
    }
    class MemoryAnalyzer {
    public:
        MemoryAnalyzer(
            std::span<const u8> memory,
            std::span<const u8> memoryAccess,
            u16 startAddress,
            u16 endAddress);
        void analyzeExecution();
        void analyzeAccesses();
        void analyzeData();
        u16 findInstructionStartCovering(u16 addr) const;
        MemoryType getMemoryType(u16 addr) const;
        std::span<const MemoryType> getMemoryTypes() const;
        std::vector<std::pair<u16, u16>> findDataRanges() const;
        std::vector<std::pair<u16, u16>> findCodeRanges() const;
        std::vector<u16> findLabelTargets() const;
        u8 getMemoryAccess(u16 addr) const {
            if (addr < memoryAccess_.size()) {
                return memoryAccess_[addr];
            }
            return 0;
        }
    private:
        std::span<const u8> memory_;        
        std::span<const u8> memoryAccess_;  
        u16 startAddress_;                  
        u16 endAddress_;                    
        std::vector<MemoryType> memoryTypes_; 
    };
}
```


### FILE: src/MemoryConstants.h
```cpp
#pragma once
#include "Common.h"
namespace sidwinder {
    struct MemoryConstants {
        static constexpr u16 ZERO_PAGE_START = 0x0000;
        static constexpr u16 ZERO_PAGE_END = 0x00FF;
        static constexpr u16 STACK_BASE = 0x0100;
        static constexpr u16 STACK_END = 0x01FF;
        static constexpr u8 STACK_INIT_VALUE = 0xFD;
        static constexpr u16 VIC_START = 0xD000;
        static constexpr u16 VIC_END = 0xD3FF;
        static constexpr u16 SID_START = 0xD400;
        static constexpr u16 SID_END = 0xD7FF;
        static constexpr u16 SID_SIZE = 0x20;  
        static constexpr u16 SID_REGISTER_COUNT = 0x19;  
        static constexpr u16 COLOR_RAM_START = 0xD800;
        static constexpr u16 COLOR_RAM_END = 0xDBFF;
        static constexpr u16 CIA1_START = 0xDC00;
        static constexpr u16 CIA1_END = 0xDCFF;
        static constexpr u16 CIA1_TIMER_LO = 0xDC04;
        static constexpr u16 CIA1_TIMER_HI = 0xDC05;
        static constexpr u16 CIA2_START = 0xDD00;
        static constexpr u16 CIA2_END = 0xDDFF;
        static constexpr u16 IO_AREA_START = 0xD000;
        static constexpr u16 IO_AREA_END = 0xDFFF;
        static constexpr u16 IRQ_VECTOR = 0xFFFE;
        static constexpr u16 RESET_VECTOR = 0xFFFC;
        static constexpr u16 NMI_VECTOR = 0xFFFA;
        static constexpr u32 MEMORY_SIZE = 0x10000;  
        static bool isZeroPage(u16 addr) {
            return addr <= ZERO_PAGE_END;
        }
        static bool isStack(u16 addr) {
            return addr >= STACK_BASE && addr <= STACK_END;
        }
        static bool isSID(u16 addr) {
            return addr >= SID_START && addr <= SID_END;
        }
        static bool isVIC(u16 addr) {
            return addr >= VIC_START && addr <= VIC_END;
        }
        static bool isCIA1(u16 addr) {
            return addr >= CIA1_START && addr <= CIA1_END;
        }
        static bool isCIA2(u16 addr) {
            return addr >= CIA2_START && addr <= CIA2_END;
        }
        static bool isCIA(u16 addr) {
            return isCIA1(addr) || isCIA2(addr);
        }
        static bool isIO(u16 addr) {
            return addr >= IO_AREA_START && addr <= IO_AREA_END;
        }
        static u16 getSIDBase(u16 addr) {
            if (!isSID(addr)) return 0;
            return addr & ~(SID_SIZE - 1);  
        }
        static u8 getSIDRegister(u16 addr) {
            if (!isSID(addr)) return 0xFF;
            return addr & (SID_SIZE - 1);  
        }
    };
}
```


### FILE: src/RelocationStructs.h
```cpp
#pragma once
#include "Common.h"
#include "SIDwinderUtils.h"
#include <string>
#include <map>
namespace sidwinder {
    struct RelocationEntry {
        u16 targetAddress;          
        enum class Type {
            Low,                    
            High                    
        } type;
        std::string toString() const {
            return std::string(type == Type::Low ? "LOW" : "HIGH") +
                " byte of $" + util::wordToHex(targetAddress);
        }
    };
    class RelocationTable {
    public:
        void addEntry(u16 addr, u16 targetAddr, RelocationEntry::Type type) {
            entries_[addr] = { targetAddr, type };
        }
        bool hasEntry(u16 addr) const {
            return entries_.find(addr) != entries_.end();
        }
        const RelocationEntry* getEntry(u16 addr) const {
            auto it = entries_.find(addr);
            if (it != entries_.end()) {
                return &it->second;
            }
            return nullptr;
        }
        const std::map<u16, RelocationEntry>& getAllEntries() const {
            return entries_;
        }
        void clear() {
            entries_.clear();
        }
    private:
        std::map<u16, RelocationEntry> entries_;
    };
}
```


### FILE: src/RelocationUtils.h
```cpp
#pragma once
#include "Common.h"
#include <filesystem>
#include <string>
namespace fs = std::filesystem;
class CPU6510;
class SIDLoader;
namespace sidwinder {
    class Disassembler;
}
namespace sidwinder {
    namespace util {
        struct RelocationParams {
            fs::path inputFile;           
            fs::path outputFile;          
            fs::path tempDir;             
            u16 relocationAddress = 0;    
            std::string kickAssPath;      
            bool verbose = false;         
        };
        struct RelocationResult {
            bool success;                 
            u16 originalLoad;             
            u16 originalInit;             
            u16 originalPlay;             
            u16 newLoad;                  
            u16 newInit;                  
            u16 newPlay;                  
            std::string message;          
        };
        RelocationResult relocateSID(
            CPU6510* cpu,
            SIDLoader* sid,
            const RelocationParams& params);
        struct RelocationVerificationResult {
            bool success;                
            bool verified;               
            bool outputsMatch;           
            std::string originalTrace;   
            std::string relocatedTrace;  
            std::string diffReport;      
            std::string message;         
        };
        RelocationVerificationResult relocateAndVerifySID(
            CPU6510* cpu,
            SIDLoader* sid,
            const fs::path& inputFile,
            const fs::path& outputFile,
            u16 relocationAddress,
            const fs::path& tempDir,
            const std::string& kickAssPath = "");
        bool assembleAsmToPrg(
            const fs::path& asmFile,
            const fs::path& prgFile,
            const std::string& kickAssPath,
            const fs::path& tempDir);
        bool createSIDFromPRG(
            const fs::path& prgFile,
            const fs::path& sidFile,
            u16 loadAddr,
            u16 initAddr,
            u16 playAddr,
            const std::string& title = "",
            const std::string& author = "",
            const std::string& copyright = "",
            u16 flags = 0,
            u8 secondSIDAddress = 0,
            u8 thirdSIDAddress = 0,
            u16 version = 2,
            u32 speed = 0);
        bool runSIDEmulation(
            CPU6510* cpu,
            SIDLoader* sid,
            int frames);
    }
}
```


### FILE: src/SIDEmulator.h
```cpp
#pragma once
#include "Common.h"
#include "app/TraceLogger.h"
#include "SIDPatternFinder.h"
#include "SIDWriteTracker.h"
#include <functional>
#include <memory>
class CPU6510;
class SIDLoader;
namespace sidwinder {
    class SIDEmulator {
    public:
        struct EmulationOptions {
            int frames = DEFAULT_SID_EMULATION_FRAMES;   
            bool traceEnabled = false;                   
            TraceFormat traceFormat = TraceFormat::Binary; 
            std::string traceLogPath;                    
            int callsPerFrame = 1;                       
            bool registerTrackingEnabled = false;        
            bool patternDetectionEnabled = false;        
            bool shadowRegisterDetectionEnabled = false;  
        };
        SIDEmulator(CPU6510* cpu, SIDLoader* sid);
        bool runEmulation(const EmulationOptions& options);
        std::pair<u64, u64> getCycleStats() const;
        const SIDWriteTracker& getWriteTracker() const { return writeTracker_; }
        const SIDPatternFinder& getPatternFinder() const { return patternFinder_; }
        bool generateHelpfulDataFile(const std::string& filename) const;
    private:
        CPU6510* cpu_;                 
        SIDLoader* sid_;               
        std::unique_ptr<TraceLogger> traceLogger_; 
        u64 totalCycles_ = 0;          
        u64 maxCyclesPerFrame_ = 0;    
        int framesExecuted_ = 0;       
        SIDWriteTracker writeTracker_; 
        SIDPatternFinder patternFinder_; 
    };
}
```


### FILE: src/SIDFileFormat.h
```cpp
#pragma once
#include "Common.h"
#pragma pack(push, 1)
struct SIDHeader {
    char magicID[4];     
    u16 version;         
    u16 dataOffset;      
    u16 loadAddress;     
    u16 initAddress;     
    u16 playAddress;     
    u16 songs;           
    u16 startSong;       
    u32 speed;           
    char name[32];       
    char author[32];     
    char copyright[32];  
    u16 flags;           
    u8 startPage;        
    u8 pageLength;       
    u8 secondSIDAddress; 
    u8 thirdSIDAddress;  
};
#pragma pack(pop)
enum class SIDModel {
    UNKNOWN = 0,
    MOS6581 = 1,    
    MOS8580 = 2,    
    ANY = 3     
};
enum class ClockSpeed {
    UNKNOWN = 0,
    PAL = 1,    
    NTSC = 2,    
    ANY = 3     
};
constexpr u16 SID_FLAG_MUS_DATA = 0x0001;  
constexpr u16 SID_FLAG_PSID_SPECIFIC = 0x0002;  
constexpr u16 SID_FLAG_CLOCK_PAL = 0x0004;  
constexpr u16 SID_FLAG_CLOCK_NTSC = 0x0008;  
constexpr u16 SID_FLAG_SID_6581 = 0x0010;  
constexpr u16 SID_FLAG_SID_8580 = 0x0020;
```


### FILE: src/SIDLoader.h
```cpp
#pragma once
#include "Common.h"
#include "SIDFileFormat.h"
#include <cstring>
#include <memory>
#include <string>
#include <string_view>
#include <vector>
class CPU6510;
class SIDLoader {
public:
    SIDLoader();
    void setCPU(CPU6510* cpu);
    void setInitAddress(u16 address);
    void setPlayAddress(u16 address);
    void setLoadAddress(u16 address);
    void setTitle(const std::string& title) {
        strncpy(header_.name, title.c_str(), sizeof(header_.name) - 1);
        header_.name[sizeof(header_.name) - 1] = '\0';
    }
    void setAuthor(const std::string& author) {
        strncpy(header_.author, author.c_str(), sizeof(header_.author) - 1);
        header_.author[sizeof(header_.author) - 1] = '\0';
    }
    void setCopyright(const std::string& copyright) {
        strncpy(header_.copyright, copyright.c_str(), sizeof(header_.copyright) - 1);
        header_.copyright[sizeof(header_.copyright) - 1] = '\0';
    }
    bool loadSID(const std::string& filename);
    u16 getInitAddress() const { return header_.initAddress; }
    u16 getPlayAddress() const { return header_.playAddress; }
    u16 getLoadAddress() const { return header_.loadAddress; }
    u16 getDataSize() const { return dataSize_; }
    const SIDHeader& getHeader() const { return header_; }
    const std::vector<u8>& getOriginalMemory() const { return originalMemory_; }
    u16 getOriginalMemoryBase() const { return originalMemoryBase_; }
    int getNumPlayCallsPerFrame() const { return numPlayCallsPerFrame_; }
    void setNumPlayCallsPerFrame(int num) { numPlayCallsPerFrame_ = num; }
    bool backupMemory();
    bool restoreMemory();
private:
    bool copyMusicToMemory(const u8* data, u16 size, u16 loadAddr);
    SIDHeader header_;          
    u16 dataSize_ = 0;          
    CPU6510* cpu_ = nullptr;    
    std::vector<u8> originalMemory_;    
    u16 originalMemoryBase_ = 0;        
    u8 numPlayCallsPerFrame_ = 1;       
    std::vector<u8> memoryBackup_;      
};
```


### FILE: src/SIDPatternFinder.h
```cpp
#pragma once
#include "Common.h"
#include <vector>
#include <string>
#include <optional>
namespace sidwinder {
    class SIDPatternFinder {
    public:
        SIDPatternFinder();
        void reset();
        void recordWrite(u16 addr, u8 value);
        void endFrame();
        bool analyzePattern(int maxInitFrames = 15);
        size_t getPatternPeriod() const { return patternPeriod_; }
        size_t getInitFramesCount() const { return initFramesCount_; }
        std::string getPatternDescription() const;
    private:
        struct SIDWrite {
            u16 addr;
            u8 value;
            bool operator==(const SIDWrite& other) const {
                return addr == other.addr && value == other.value;
            }
        };
        std::vector<std::vector<SIDWrite>> frames_;
        std::vector<SIDWrite> currentFrame_;
        size_t patternPeriod_ = 0;
        size_t initFramesCount_ = 0;
        bool patternFound_ = false;
        size_t hashFrame(const std::vector<SIDWrite>& frame) const;
        bool framesEqual(const std::vector<SIDWrite>& frame1, const std::vector<SIDWrite>& frame2) const;
        size_t findSmallestPeriod(size_t initFrames) const;
        bool verifyPattern(size_t initFrames, size_t period) const;
    };
}
```


### FILE: src/SIDwinderUtils.h
```cpp
#pragma once
#include "Common.h"
#include <array>
#include <filesystem>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
namespace sidwinder {
    namespace util {
        inline u16 swapEndian(u16 value) {
            return (value >> 8) | (value << 8);
        }
        inline u32 swapEndian(u32 value) {
            return ((value & 0xff000000) >> 24)
                | ((value & 0x00ff0000) >> 8)
                | ((value & 0x0000ff00) << 8)
                | ((value & 0x000000ff) << 24);
        }
        inline std::string byteToHex(u8 value, bool upperCase = true) {
            std::ostringstream ss;
            ss << (upperCase ? std::uppercase : std::nouppercase)
                << std::hex << std::setw(2) << std::setfill('0')
                << static_cast<int>(value);
            return ss.str();
        }
        inline std::string wordToHex(u16 value, bool upperCase = true)
        {
            std::ostringstream ss;
            ss << (upperCase ? std::uppercase : std::nouppercase)
                << std::hex << std::setw(4) << std::setfill('0')
                << value;
            return ss.str();
        }
        std::optional<u16> parseHex(std::string_view str);
        std::string padToColumn(std::string_view str, size_t width);
        class IndexRange {
        public:
            void update(int offset);
            std::pair<int, int> getRange() const;
        private:
            int min_ = std::numeric_limits<int>::max();  
            int max_ = std::numeric_limits<int>::min();  
        };
        class Logger {
        public:
            enum class Level {
                Debug,    
                Info,     
                Warning,  
                Error     
            };
            static void initialize(const std::filesystem::path& logFile = {});
            static void setLogLevel(Level level);
            static void log(Level level, const std::string& message, bool toConsole = false);
            static void debug(const std::string& message, bool toConsole = false);
            static void info(const std::string& message, bool toConsole = false);
            static void warning(const std::string& message, bool toConsole = false);
            static void error(const std::string& message, bool toConsole = false);
        private:
            static Level minLevel_;                                  
            static std::optional<std::filesystem::path> logFile_;    
            static bool consoleOutput_;                              
        };
    } 
}
```


### FILE: src/SIDWriteTracker.h
```cpp
#pragma once
#include "Common.h"
#include <vector>
#include <map>
#include <array>
#include <string>
namespace sidwinder {
    class SIDWriteTracker {
    public:
        SIDWriteTracker();
        void recordWrite(u16 addr, u8 value);
        void endFrame();
        bool analyzePattern();
        void reset();
        const std::vector<u8>& getWriteOrder() const { return writeOrder_; }
        std::string getWriteOrderString() const;
        bool hasConsistentPattern() const { return consistentPattern_; }
        std::string getRegisterUsageStats() const;
    private:
        std::vector<std::vector<u8>> frameSequences_;
        std::vector<u8> currentFrameSequence_;
        std::vector<u8> writeOrder_;
        std::array<bool, 0x19> registersUsed_ = { false };
        std::array<int, 0x19> registerWriteCounts_ = { 0 };
        bool consistentPattern_ = false;
        int frameCount_ = 0;
    };
}
```


### FILE: src/6510/AddressingModes.h
```cpp
#pragma once
#include "cpu6510.h"
class CPU6510Impl;
class AddressingModes {
public:
    explicit AddressingModes(CPU6510Impl& cpu);
    u32 getAddress(AddressingMode mode);
private:
    CPU6510Impl& cpu_;
    void recordIndexOffset(u32 pc, u8 offset);
};
```


### FILE: src/6510/CPU6510Impl.h
```cpp
#pragma once
#include "cpu6510.h"
#include "InstructionExecutor.h"
#include "MemorySubsystem.h"
#include "AddressingModes.h"
#include "CPUState.h"
struct MemoryDataFlow;  
class CPU6510Impl {
public:
    CPU6510Impl();
    ~CPU6510Impl() = default;
    void reset();
    void resetRegistersAndFlags();
    void step();
    bool executeFunction(u32 address);
    void jumpTo(u32 address);
    u8 readMemory(u32 addr);
    void writeByte(u32 addr, u8 value);
    void writeMemory(u32 addr, u8 value);
    void copyMemoryBlock(u32 start, std::span<const u8> data);
    void loadData(const std::string& filename, u32 loadAddress);
    void setPC(u32 address);
    u32 getPC() const;
    void setSP(u8 sp);
    u8 getSP() const;
    u64 getCycles() const;
    void setCycles(u64 newCycles);
    void resetCycles();
    std::string_view getMnemonic(u8 opcode) const;
    u8 getInstructionSize(u8 opcode) const;
    AddressingMode getAddressingMode(u8 opcode) const;
    bool isIllegalInstruction(u8 opcode) const;
    void dumpMemoryAccess(const std::string& filename);
    std::pair<u8, u8> getIndexRange(u32 pc) const;
    std::span<const u8> getMemory() const;
    std::span<const u8> getMemoryAccess() const;
    u32 getLastWriteTo(u32 addr) const;
    const std::vector<u32>& getLastWriteToAddr() const;
    RegisterSourceInfo getRegSourceA() const;
    RegisterSourceInfo getRegSourceX() const;
    RegisterSourceInfo getRegSourceY() const;
    RegisterSourceInfo getWriteSourceInfo(u32 addr) const;
    const MemoryDataFlow& getMemoryDataFlow() const;
    using IndirectReadCallback = CPU6510::IndirectReadCallback;
    using MemoryWriteCallback = CPU6510::MemoryWriteCallback;
    using MemoryFlowCallback = CPU6510::MemoryFlowCallback;
    void setOnIndirectReadCallback(IndirectReadCallback callback);
    void setOnWriteMemoryCallback(MemoryWriteCallback callback);
    void setOnCIAWriteCallback(MemoryWriteCallback callback);
    void setOnSIDWriteCallback(MemoryWriteCallback callback);
    void setOnVICWriteCallback(MemoryWriteCallback callback);
    void setOnMemoryFlowCallback(MemoryFlowCallback callback);
private:
    CPUState cpuState_;
    MemorySubsystem memory_;
    InstructionExecutor instructionExecutor_;
    AddressingModes addressingModes_;
    u32 originalPc_ = 0;
    std::unordered_map<u32, IndexRange> pcIndexRanges_;
    IndirectReadCallback onIndirectReadCallback_;
    MemoryWriteCallback onWriteMemoryCallback_;
    MemoryWriteCallback onCIAWriteCallback_;
    MemoryWriteCallback onSIDWriteCallback_;
    MemoryWriteCallback onVICWriteCallback_;
    MemoryFlowCallback onMemoryFlowCallback_;
    void recordIndexOffset(u32 pc, u8 offset);
    void push(u8 value);
    u8 pop();
    u16 readWord(u32 addr);
    u16 readWordZeroPage(u8 addr);
    u8 fetchOpcode(u32 addr);
    u8 fetchOperand(u32 addr);
    u8 readByAddressingMode(u32 addr, AddressingMode mode);
    static const std::array<OpcodeInfo, 256> opcodeTable_;
    friend class InstructionExecutor;
    friend class MemorySubsystem;
    friend class AddressingModes;
    friend class CPUState;
};
```


### FILE: src/6510/CPUState.h
```cpp
#pragma once
#include "cpu6510.h"
class CPU6510Impl;
class CPUState {
public:
    explicit CPUState(CPU6510Impl& cpu);
    void reset();
    u16 getPC() const;
    void setPC(u16 value);
    void incrementPC();
    u8 getSP() const;
    void setSP(u8 value);
    void incrementSP();
    void decrementSP();
    u8 getA() const;
    void setA(u8 value);
    u8 getX() const;
    void setX(u8 value);
    u8 getY() const;
    void setY(u8 value);
    u8 getStatus() const;
    void setStatus(u8 value);
    void setFlag(StatusFlag flag, bool value);
    bool testFlag(StatusFlag flag) const;
    void setZN(u8 value);
    u64 getCycles() const;
    void setCycles(u64 newCycles);
    void addCycles(u64 cycles);
    void resetCycles();
    RegisterSourceInfo getRegSourceA() const;
    void setRegSourceA(const RegisterSourceInfo& info);
    RegisterSourceInfo getRegSourceX() const;
    void setRegSourceX(const RegisterSourceInfo& info);
    RegisterSourceInfo getRegSourceY() const;
    void setRegSourceY(const RegisterSourceInfo& info);
private:
    CPU6510Impl& cpu_;
    u16 pc_ = 0;      
    u8 sp_ = 0;       
    u8 regA_ = 0;     
    u8 regX_ = 0;     
    u8 regY_ = 0;     
    u8 statusReg_ = 0; 
    u64 cycles_ = 0;
    RegisterSourceInfo regSourceA_;
    RegisterSourceInfo regSourceX_;
    RegisterSourceInfo regSourceY_;
};
```


### FILE: src/6510/InstructionExecutor.h
```cpp
#pragma once
#include "cpu6510.h"
class CPU6510Impl;
class InstructionExecutor {
public:
    explicit InstructionExecutor(CPU6510Impl& cpu);
    void execute(Instruction instr, AddressingMode mode);
private:
    CPU6510Impl& cpu_;
    void executeInstruction(Instruction instr, AddressingMode mode);
    void executeLoad(Instruction instr, AddressingMode mode);
    void executeStore(Instruction instr, AddressingMode mode);
    void executeArithmetic(Instruction instr, AddressingMode mode);
    void executeLogical(Instruction instr, AddressingMode mode);
    void executeBranch(Instruction instr, AddressingMode mode);
    void executeJump(Instruction instr, AddressingMode mode);
    void executeStack(Instruction instr, AddressingMode mode);
    void executeRegister(Instruction instr, AddressingMode mode);
    void executeFlag(Instruction instr, AddressingMode mode);
    void executeShift(Instruction instr, AddressingMode mode);
    void executeCompare(Instruction instr, AddressingMode mode);
    void executeIllegal(Instruction instr, AddressingMode mode);
};
```


### FILE: src/6510/MemorySubsystem.h
```cpp
﻿#pragma once
#include "cpu6510.h"
#include <array>
#include <span>
#include <vector>
#include <fstream>
class CPU6510Impl;
class MemorySubsystem {
public:
    explicit MemorySubsystem(CPU6510Impl& cpu);
    void reset();
    u8 readMemory(u32 addr);
    void writeByte(u32 addr, u8 value);
    void writeMemory(u32 addr, u8 value, u32 sourcePC);
    void copyMemoryBlock(u32 start, std::span<const u8> data);
    void markMemoryAccess(u32 addr, MemoryAccessFlag flag);
    u8 getMemoryAt(u32 addr) const;
    void dumpMemoryAccess(const std::string& filename);
    std::span<const u8> getMemory() const;
    std::span<const u8> getMemoryAccess() const;
    u32 getLastWriteTo(u32 addr) const;
    const std::vector<u32>& getLastWriteToAddr() const;
    RegisterSourceInfo getWriteSourceInfo(u32  addr) const;
    void setWriteSourceInfo(u32 addr, const RegisterSourceInfo& info);
    const MemoryDataFlow& getMemoryDataFlow() const;
private:
    CPU6510Impl& cpu_;
    std::array<u8, 65536> memory_;
    std::array<u8, 65536> memoryAccess_;
    std::vector<u32> lastWriteToAddr_;
    std::vector<RegisterSourceInfo> writeSourceInfo_;
    MemoryDataFlow dataFlow_;  
};
```


### FILE: src/app/CommandProcessor.h
```cpp
#pragma once
#include "../Common.h"
#include "../SIDWriteTracker.h"
#include "TraceLogger.h"
#include "Disassembler.h"
#include <memory>
#include <string>
class CPU6510;
class SIDLoader;
namespace sidwinder {
    class CommandProcessor {
    public:
        struct ProcessingOptions {
            fs::path inputFile;               
            fs::path outputFile;              
            fs::path tempDir = "temp";        
            u16 relocationAddress = 0;        
            bool hasRelocation = false;       
            u16 overrideInitAddress = 0;      
            u16 overridePlayAddress = 0;      
            u16 overrideLoadAddress = 0;      
            bool hasOverrideInit = false;     
            bool hasOverridePlay = false;     
            bool hasOverrideLoad = false;     
            std::string overrideTitle;        
            std::string overrideAuthor;       
            std::string overrideCopyright;    
            std::map<std::string, std::string> userDefinitions;  
            bool includePlayer = true;               
            std::string playerName = "SimpleRaster"; 
            u16 playerAddress = 0x4000;              
            bool compress = true;             
            std::string compressorType = "exomizer";          
            std::string exomizerPath = "Exomizer.exe";        
            std::string kickAssPath = "java -jar KickAss.jar -silentMode"; 
            std::string traceLogPath;              
            bool enableTracing = false;            
            TraceFormat traceFormat = TraceFormat::Binary;  
            int frames = DEFAULT_SID_EMULATION_FRAMES;    
            bool analyzeRegisterOrder = false;   
        };
        CommandProcessor();
        ~CommandProcessor();
        bool processFile(const ProcessingOptions& options);
    private:
        std::unique_ptr<CPU6510> cpu_;             
        std::unique_ptr<SIDLoader> sid_;           
        std::unique_ptr<TraceLogger> traceLogger_; 
        std::unique_ptr<Disassembler> disassembler_; 
        bool loadInputFile(const ProcessingOptions& options);
        bool loadSidFile(const ProcessingOptions& options, const fs::path& tempExtractedPrg);
        bool analyzeMusic(const ProcessingOptions& options);
        bool generateOutput(const ProcessingOptions& options);
        bool generatePRGOutput(const ProcessingOptions& options);
        bool generateSIDOutput(const ProcessingOptions& options);
        bool generateASMOutput(const ProcessingOptions& options);
        int calculatePlayCallsPerFrame(u8 CIATimerLo, u8 CIATimerHi);
        void applySIDMetadataOverrides(const ProcessingOptions& options);
    };
}
```


### FILE: src/app/MusicBuilder.h
```cpp
#pragma once
#include "../Common.h"
#include "../SIDFileFormat.h"
#include "../SIDEmulator.h"
#include <filesystem>
#include <memory>
#include <string>
#include <map>
namespace fs = std::filesystem;
class CPU6510;
class SIDLoader;
namespace sidwinder {
    class MusicBuilder {
    public:
        struct BuildOptions {
            bool includePlayer = true;     
            std::string playerName = "SimpleRaster";  
            u16 playerAddress = 0x4000;    
            bool compress = true;          
            std::string compressorType = "exomizer";  
            std::string exomizerPath = "Exomizer.exe";  
            std::string kickAssPath = "java -jar KickAss.jar -silentMode";  
            int playCallsPerFrame = 1;     
            u16 sidLoadAddr = 0x1000;      
            u16 sidInitAddr = 0x1000;      
            u16 sidPlayAddr = 0x1003;      
            std::map<std::string, std::string> userDefinitions;  
            fs::path tempDir = "temp";     
        };
        MusicBuilder(const CPU6510* cpu, const SIDLoader* sid);
        bool buildMusic(
            const std::string& basename,
            const fs::path& inputFile,
            const fs::path& outputFile,
            const BuildOptions& options);
        bool extractPrgFromSid(
            const fs::path& sidFile,
            const fs::path& outputPrg);
    private:
        const CPU6510* cpu_;  
        const SIDLoader* sid_;  
        std::unique_ptr<SIDEmulator> emulator_; 
        enum class InputType {
            SID,  
            PRG,  
            ASM,  
            BIN   
        };
        void addUserDefinitions(std::ofstream& file, const BuildOptions& options);
        bool createLinkerFile(
            const fs::path& linkerFile,
            const fs::path& musicFile,
            const fs::path& playerAsmFile,
            const BuildOptions& options);
        bool runAssembler(
            const fs::path& sourceFile,
            const fs::path& outputFile,
            const std::string& kickAssPath,
            const fs::path& tempDir);
        bool compressPrg(
            const fs::path& inputPrg,
            const fs::path& outputPrg,
            u16 loadAddress,
            const BuildOptions& options);
    };
}
```


### FILE: src/app/SIDwinderApp.h
```cpp
#pragma once
#include "../CommandLineParser.h"
#include "CommandProcessor.h"
#include "../CommandClass.h"
#include "TraceLogger.h"
#include <memory>
#include <string>
namespace sidwinder {
    class SIDwinderApp {
    public:
        SIDwinderApp(int argc, char** argv);
        int run();
    private:
        CommandLineParser cmdParser_;  
        CommandClass command_;         
        fs::path logFile_;             
        bool verbose_ = false;         
        void setupCommandLine();
        void initializeLogging();
        int executeCommand();
        CommandProcessor::ProcessingOptions createProcessingOptions();
        int showHelp();
        int processPlayer();
        int processRelocation();
        int processDisassembly();
        int processTrace();
    };
}
```


### FILE: src/app/TraceLogger.h
```cpp
#pragma once
#include "Common.h"
#include <fstream>
#include <string>
#include <vector>
namespace sidwinder {
    enum class TraceFormat {
        Text,   
        Binary  
    };
    class TraceLogger {
    public:
        TraceLogger(const std::string& filename, TraceFormat format = TraceFormat::Text);
        ~TraceLogger();
        void logFrameMarker();
        void flushLog();
        static bool compareTraceLogs(
            const std::string& originalLog,
            const std::string& relocatedLog,
            const std::string& reportFile);
    private:
        static constexpr u32 FRAME_MARKER = 0xFFFFFFFF;
        struct TraceRecord {
            union {
                struct {
                    u16 address;  
                    u8 value;     
                    u8 unused;    
                } write;
                u32 commandTag;   
            };
            TraceRecord() : commandTag(0) {}
            TraceRecord(u16 addr, u8 val) : write{ addr, val, 0 } {}
            TraceRecord(u32 cmd) : commandTag(cmd) {}
        };
        std::ofstream file_;     
        TraceFormat format_;     
        bool isOpen_;            
        void writeTextRecord(u16 addr, u8 value);
        void writeBinaryRecord(const TraceRecord& record);
    };
}
```
