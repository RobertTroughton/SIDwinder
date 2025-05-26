// CommandLineParser.cpp - Updated with new command syntax
#include "CommandLineParser.h"
#include "SIDwinderUtils.h"

#include <algorithm>
#include <iostream>
#include <sstream>
#include <set>

namespace sidwinder {

    CommandLineParser::CommandLineParser(int argc, char** argv) {
        // Save program name
        if (argc > 0) {
            programName_ = std::filesystem::path(argv[0]).filename().string();
        }

        // Save all arguments
        for (int i = 1; i < argc; ++i) {
            args_.push_back(argv[i]);
        }
    }

    CommandClass CommandLineParser::parse() const {
        CommandClass cmd;

        // Process arguments
        std::vector<std::string> positionalArgs;

        size_t i = 0;
        while (i < args_.size()) {
            std::string arg = args_[i++];

            // Skip empty arguments
            if (arg.empty()) {
                continue;
            }

            // Check if it's an option (starts with '-')
            if (arg[0] == '-') {
                // Process option with potential parameter
                std::string option = arg.substr(1);  // Remove leading dash
                size_t equalPos = option.find('=');

                if (equalPos != std::string::npos) {
                    // Option with value using equals sign: -option=value
                    std::string name = option.substr(0, equalPos);
                    std::string value = option.substr(equalPos + 1);

                    // Handle special cases for our simplified options
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

                        // Determine format based on file extension
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
                        // Regular parameter
                        cmd.setParameter(name, value);
                    }
                }
                else {
                    // Handle options without equal sign
                    if (option == "player") {
                        cmd.setType(CommandClass::Type::Player);
                    }
                    else if (option == "relocate") {
                        cmd.setType(CommandClass::Type::Relocate);
                        // This is now an error case - will be handled later in the app logic
                    }
                    else if (option == "disassemble") {
                        cmd.setType(CommandClass::Type::Disassemble);
                    }
                    else if (option == "trace") {
                        cmd.setType(CommandClass::Type::Trace);
                        // Default trace file
                        cmd.setParameter("tracelog", "trace.bin");
                        cmd.setParameter("traceformat", "binary");
                    }
                    else if (option == "help" || option == "h") {
                        cmd.setType(CommandClass::Type::Help);
                    }
                    else if (option == "log" && i < args_.size() && args_[i][0] != '-') {
                        // Handle -log filename (old style)
                        cmd.setParameter("logfile", args_[i++]);
                    }
                    // In CommandLineParser::parse()
                    // Find this section and replace/enhance it:
                    else {
                        // Other flag or option with value in next arg
                        // Check if this option expects a value (not a flag)
                        if (i < args_.size() && args_[i][0] != '-') {
                            // List of options that expect values
                            static const std::set<std::string> valueOptions = {
                                "kickass", "input", "title", "author", "copyright",
                                "sidloadaddr", "sidinitaddr", "sidplayaddr", "playeraddr",
                                "exomizer", "define"  // Add "define" here
                            };

                            if (valueOptions.find(option) != valueOptions.end()) {
                                if (option == "define") {
                                    // Special handling for define option
                                    std::string defValue = args_[i++];
                                    size_t eqPos = defValue.find('=');
                                    if (eqPos != std::string::npos) {
                                        std::string key = defValue.substr(0, eqPos);
                                        std::string value = defValue.substr(eqPos + 1);

                                        // Remove quotes if present
                                        if (value.length() >= 2) {
                                            if ((value.front() == '"' && value.back() == '"') ||
                                                (value.front() == '\'' && value.back() == '\'')) {
                                                value = value.substr(1, value.length() - 2);
                                            }
                                        }

                                        cmd.addDefinition(key, value);
                                    }
                                    else {
                                        // Just a flag definition (true/false)
                                        cmd.addDefinition(defValue, "true");
                                    }
                                }
                                else {
                                    cmd.setParameter(option, args_[i++]);
                                }
                            }
                            else {
                                // Flag without value
                                cmd.setFlag(option);
                            }
                        }
                        else {
                            // Flag without value
                            cmd.setFlag(option);
                        }
                    }
                }
            }
            else {
                // This is a positional argument (input or output file)
                positionalArgs.push_back(arg);
            }
        }

        // Handle positional arguments (input and output files)
        if (!positionalArgs.empty()) {
            cmd.setInputFile(positionalArgs[0]);
        }

        if (positionalArgs.size() >= 2) {
            cmd.setOutputFile(positionalArgs[1]);
        }

        // If no valid command was specified, default to help
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

        // Main usage patterns - updated with new command syntax
        std::cout << "USAGE:" << std::endl;
        std::cout << "  " << programName_ << " -relocate=<address> inputfile.sid outputfile.sid" << std::endl;
        std::cout << "  " << programName_ << " -trace[=<file>] inputfile.sid" << std::endl;
        std::cout << "  " << programName_ << " -player[=<type>] inputfile.sid outputfile.prg" << std::endl;
        std::cout << "  " << programName_ << " -disassemble inputfile.sid outputfile.asm" << std::endl;
        std::cout << "  " << programName_ << " -help" << std::endl;
        std::cout << std::endl;

        // Command descriptions - updated with new syntax
        std::cout << "COMMANDS:" << std::endl;
        std::cout << "  -relocate=<address>    Relocate a SID file to a new memory address" << std::endl;
        std::cout << "  -trace[=<file>]        Trace SID register writes during emulation" << std::endl;
        std::cout << "  -player[=<type>]       Link SID music with a player to create executable PRG" << std::endl;
        std::cout << "  -disassemble           Disassemble a SID file to assembly code" << std::endl;
        std::cout << "  -help                  Display this help information" << std::endl;
        std::cout << std::endl;

        // Player command options
        std::cout << "PLAYER OPTIONS:" << std::endl;
        std::cout << "  -player                Use the default player (SimpleRaster)" << std::endl;
        std::cout << "  -player=<type>         Specify player type, e.g.: -player=SimpleBitmap or -player=RaistlinBars" << std::endl;
        std::cout << "  -playeraddr=<address>  Player load address (default: $4000)" << std::endl;
        std::cout << std::endl;

        // Trace command options
        std::cout << "TRACE OPTIONS:" << std::endl;
        std::cout << "  -trace                 Output trace to trace.bin in binary format" << std::endl;
        std::cout << "  -trace=<file>          Specify trace output file" << std::endl;
        std::cout << "                         .bin extension = binary format" << std::endl;
        std::cout << "                         .txt/.log extension = text format" << std::endl;
        std::cout << std::endl;

        // General options
        std::cout << "GENERAL OPTIONS:" << std::endl;
        std::cout << "  -verbose               Enable verbose logging" << std::endl;
        std::cout << "  -force                 Force overwrite of output file" << std::endl;
        std::cout << "  -log=<file>            Log file path (default: SIDwinder.log)" << std::endl;
        std::cout << "  -kickass=<path>        Path to KickAss.jar assembler" << std::endl;
        std::cout << std::endl;

        // Examples - updated with new syntax
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

} // namespace sidwinder