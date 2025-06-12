// Main.cpp
#include "app/SIDwinderApp.h"
#include "SIDwinderUtils.h"
#include <iostream>
#include <filesystem>

namespace fs = std::filesystem;

using namespace sidwinder;

/**
 * @brief Main entry point for the SIDwinder application
 *
 * Creates and runs an instance of the SIDwinderApp, handling any exceptions
 * that might be thrown during execution.
 *
 * @param argc Number of command line arguments
 * @param argv Array of command line argument strings
 * @return Exit code (0 on success, 1 on error)
 */
int main(int argc, char** argv) {
    try {
        // Look for configuration file in current directory, executable directory, 
        // and common config locations
        std::vector<fs::path> configPaths = {
            "SIDwinder.cfg",                                // Current directory
            fs::path(argv[0]).parent_path() / "SIDwinder.cfg", // Executable directory

            #ifdef _WIN32
            fs::path(getenv("APPDATA") ? getenv("APPDATA") : "") / "SIDwinder" / "SIDwinder.cfg", // Windows AppData
            #else
            fs::path(getenv("HOME") ? getenv("HOME") : "") / ".config" / "sidwinder" / "SIDwinder.cfg", // Unix/Linux ~/.config
            fs::path(getenv("HOME") ? getenv("HOME") : "") / ".sidwinder" / "SIDwinder.cfg",       // Unix/Linux ~/.sidwinder
            "/etc/sidwinder/SIDwinder.cfg",                // System-wide config
            #endif
        };

        // Create and run the application
        SIDwinderApp app(argc, argv);
        return app.run();
    }
    catch (const std::exception& e) {
        std::cerr << "Fatal error: " << e.what() << std::endl;
        return 1;
    }
}