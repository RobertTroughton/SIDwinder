cmake_minimum_required(VERSION 3.14)

# Read version from Common.h
file(STRINGS "src/Common.h" VERSION_DEFINE REGEX "^#define SIDwinder_VERSION")
string(REGEX REPLACE ".*\"(.*)\".*" "\\1" PROJECT_VERSION "${VERSION_DEFINE}")

project(SIDwinder VERSION 0.2.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Include the APP and CPU6510 files
include(${CMAKE_CURRENT_SOURCE_DIR}/app_files.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cpu6510_files.cmake)

# Define core sources
set(CORE_SOURCES
    src/CodeFormatter.cpp
    src/CommandClass.cpp
    src/CommandLineParser.cpp
    src/ConfigManager.cpp
    src/Disassembler.cpp
    src/DisassemblyWriter.cpp
    src/LabelGenerator.cpp
    src/Main.cpp
    src/MemoryAnalyzer.cpp
    src/RelocationUtils.cpp
    src/SIDEmulator.cpp
    src/SIDLoader.cpp
    src/SIDPatternFinder.cpp
    src/SIDwinderUtils.cpp
    src/SIDWriteTracker.cpp
)

# Define app sources
set(APP_SOURCES
    src/app/CommandProcessor.cpp
    src/app/MusicBuilder.cpp
    src/app/SIDwinderApp.cpp
    src/app/TraceLogger.cpp
)

# Define SIDplayers sources
set(SIDPLAYERS_SOURCES
    src/SIDplayers/PlayerBuilder.cpp
    src/SIDplayers/PlayerManager.cpp
)

# Add executable with all sources
add_executable(SIDwinder 
    ${CORE_SOURCES}
    ${APP_SOURCES}
    ${CPU6510_SOURCES}
    ${SIDPLAYERS_SOURCES}
)

# Create source groups for Visual Studio organization
source_group("Core" FILES ${CORE_SOURCES})
source_group("APP" FILES ${APP_SOURCES})
source_group("CPU6510" FILES ${CPU6510_SOURCES} ${CPU6510_HEADERS})
source_group("SIDplayers" FILES ${SIDPLAYERS_SOURCES})

# Include directories
target_include_directories(SIDwinder PRIVATE 
    src
    src/app
    src/SIDplayers
)

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
    ${CMAKE_SOURCE_DIR}/SIDwinder$<$<PLATFORM_ID:Windows>:.exe>
    COMMENT "Copying executable to root directory"
)