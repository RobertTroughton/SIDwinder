cmake_minimum_required(VERSION 3.14)
project(CSDbMusicFetch CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# tinyxml2 is fetched and built automatically on every platform, so there is
# nothing to vendor by hand.
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
    HtmlGenerator.cpp
)

target_link_libraries(csdbmusicfetch PRIVATE tinyxml2::tinyxml2)

# HTTP backend: WinHTTP on Windows (ships with the OS - no extra dependency),
# libcurl everywhere else.
if(WIN32)
    target_link_libraries(csdbmusicfetch PRIVATE winhttp)
else()
    find_package(CURL REQUIRED)
    target_link_libraries(csdbmusicfetch PRIVATE CURL::libcurl)
endif()
