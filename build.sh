#!/bin/bash
# Cross-platform build script for SIDwinder

# Create build directory if it doesn't exist
mkdir -p build
cd build

# Configure with CMake
cmake ..

# Build the project
cmake --build .

echo "Build complete. Executable is in the build directory."