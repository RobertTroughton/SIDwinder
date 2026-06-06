@echo off
setlocal
cd /d "%~dp0"

echo ========================================
echo CSDbMusicFetch - Build
echo ========================================
echo.
echo Configures and builds the release-info fetcher with CMake.
echo Requires: CMake, a C++17 compiler (MSVC / Visual Studio Build Tools),
echo and Git (CMake fetches tinyxml2). HTTP uses the built-in WinHTTP, so
echo there is no libcurl/vcpkg setup on Windows.
echo.

where cmake >nul 2>&1
if errorlevel 1 (
    echo ERROR: cmake is not on PATH. Install CMake from https://cmake.org/ and retry.
    pause
    exit /b 1
)

cmake -B build || goto :error
cmake --build build --config Release || goto :error

echo.
echo Build complete. Run update-releases.bat to refresh ..\public\index.html.
pause
endlocal
exit /b 0

:error
echo.
echo Build failed.
pause
exit /b 1
