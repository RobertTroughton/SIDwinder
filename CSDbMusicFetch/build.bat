@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ========================================
echo CSDbMusicFetch - Build
echo ========================================
echo.
echo Configures and builds the release-info fetcher with CMake.
echo Requires: CMake, Visual Studio or its Build Tools (C++ workload),
echo and Git (CMake fetches tinyxml2). HTTP uses the built-in WinHTTP, so
echo there is no libcurl/vcpkg setup on Windows.
echo.

where cmake >nul 2>&1
if errorlevel 1 (
    echo ERROR: cmake is not on PATH. Install CMake from https://cmake.org/ and retry.
    pause
    exit /b 1
)

REM --- Detect a Visual Studio generator via vswhere so we do not depend on
REM     nmake/Ninja being on PATH. This lets build.bat run from a plain
REM     command prompt (no "Developer Command Prompt for VS" required).
REM     -products * is required so standalone Build Tools are detected too. ---
set "GENERATOR="
set "VSMAJOR="
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
    for /f "usebackq tokens=1 delims=." %%v in (`"%VSWHERE%" -latest -products * -property installationVersion 2^>nul`) do set "VSMAJOR=%%v"
    echo Detected Visual Studio major version: !VSMAJOR!
    if "!VSMAJOR!"=="17" set "GENERATOR=Visual Studio 17 2022"
    if "!VSMAJOR!"=="16" set "GENERATOR=Visual Studio 16 2019"
    if "!VSMAJOR!"=="15" set "GENERATOR=Visual Studio 15 2017"
) else (
    echo vswhere not found at "%VSWHERE%".
)
echo.

if defined GENERATOR (
    echo Using generator: !GENERATOR!
    echo.
    cmake -B build -G "!GENERATOR!" -A x64 || goto :nocompiler
) else (
    echo Could not auto-detect a Visual Studio generator - trying CMake's default.
    echo.
    cmake -B build || goto :nocompiler
)

cmake --build build --config Release || goto :error

echo.
echo Build complete. Run update-releases.bat to refresh ..\public\index.html.
pause
endlocal
exit /b 0

:nocompiler
echo.
echo CMake configuration failed - no usable C++ compiler was found.
echo.
echo Install Visual Studio (Community is free) or the standalone
echo "Build Tools for Visual Studio", and make sure the
echo "Desktop development with C++" workload is selected:
echo   https://visualstudio.microsoft.com/downloads/
echo.
echo Then re-run build.bat.
pause
endlocal
exit /b 1

:error
echo.
echo Build failed.
pause
exit /b 1
