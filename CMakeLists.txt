cmake_minimum_required(VERSION 3.14)

# Read version from Common.h
file(STRINGS "src/Common.h" VERSION_DEFINE REGEX "^#define SIDWINDER_VERSION")
string(REGEX REPLACE ".*\"(.*)\".*" "\\1" PROJECT_VERSION "${VERSION_DEFINE}")

project(SIDwinder VERSION 0.1.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Include the APP and CPU6510 files
include(${CMAKE_CURRENT_SOURCE_DIR}/app_files.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cpu6510_files.cmake)

# Define sources
set(SOURCES
    src/CodeFormatter.cpp
    src/CommandClass.cpp
    src/CommandLineParser.cpp
    src/Disassembler.cpp
    src/DisassemblyWriter.cpp
    src/LabelGenerator.cpp
    src/Main.cpp
    src/MemoryAnalyzer.cpp
    src/SIDwinderUtils.cpp
    src/SIDLoader.cpp
)

# Add executable with all sources
add_executable(SIDwinder 
    ${SOURCES}
    ${APP_SOURCES}
    ${CPU6510_SOURCES}
 "src/app/TraceLogger.h" "src/app/MusicBuilder.h" "src/app/MusicBuilder.cpp"   "src/app/CommandProcessor.h" "src/app/CommandProcessor.cpp"  "src/app/SIDwinderApp.h" "src/RelocationUtils.cpp" "src/RelocationUtils.h" "src/SIDEmulator.h" "src/SIDEmulator.cpp"    "src/Common.cpp" "src/RelocationStructs.h"  "src/ConfigManager.h" "src/ConfigManager.cpp" "src/SIDWriteTracker.h" "src/SIDWriteTracker.cpp" "src/SIDPatternFinder.h" "src/SIDpatternFinder.cpp" )

# Create source groups for the APP and CPU6510 files (for Visual Studio organization)
source_group("APP" FILES ${APP_SOURCES} ${APP_HEADERS})
source_group("CPU6510" FILES ${CPU6510_SOURCES} ${CPU6510_HEADERS})

# Include directories
target_include_directories(SIDwinder PRIVATE src)

# Define platform-specific settings
if(WIN32)
    target_compile_definitions(SIDwinder PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

# Set optimization flags for Release build
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    if(MSVC)
        target_compile_options(SIDwinder PRIVATE /O2)
    else()
        target_compile_options(SIDwinder PRIVATE -O3)
    endif()
endif()

# Install rule
install(TARGETS SIDwinder DESTINATION bin)
install(DIRECTORY SIDPlayers DESTINATION share/SIDwinder)

# Package with CPack (optional)
include(CPack)
set(CPACK_PACKAGE_NAME "SIDwinder")
set(CPACK_PACKAGE_VENDOR "Genesis Project")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "C64 SID music manipulator extraordinaire!")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})

# Post-build command to copy executable to root directory
add_custom_command(TARGET SIDwinder POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy 
    $<TARGET_FILE:SIDwinder> 
    ${CMAKE_SOURCE_DIR}/SIDwinder.exe
    COMMENT "Copying executable to root directory"
)