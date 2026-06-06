cmake_minimum_required(VERSION 3.14)
project(CSDbMusicFetch CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# libcurl: system-provided (libcurl4-openssl-dev / curl on Homebrew / vcpkg).
find_package(CURL REQUIRED)

# tinyxml2: fetched and built automatically, so no manual vendoring needed.
include(FetchContent)
FetchContent_Declare(
    tinyxml2
    GIT_REPOSITORY https://github.com/leethomason/tinyxml2.git
    GIT_TAG        10.0.0
)
set(tinyxml2_BUILD_TESTING OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(tinyxml2)

add_executable(csdbmusicfetch
    main.cpp
    CSDbFetch.cpp
)

target_link_libraries(csdbmusicfetch PRIVATE CURL::libcurl tinyxml2::tinyxml2)
