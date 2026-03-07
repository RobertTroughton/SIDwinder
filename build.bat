@echo off
REM Cross-platform build script for SIDwinder (Windows version)

REM Check if CMake is installed
where cmake >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo CMake not found. Please install CMake and add it to your PATH.
    echo Download from: https://cmake.org/download/
    pause
    exit /b 1
)

REM Create build directory if it doesn't exist
if not exist build mkdir build
cd build

REM Configure with CMake
cmake ..

REM Build the project
cmake --build . --config Release

echo Build complete. Executable is in the build directory.