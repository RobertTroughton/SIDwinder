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
REM     command prompt (no "Developer Command Prompt for VS" required). ---
set "GENERATOR="
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
    for /f "usebackq tokens=*" %%v in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property catalog_productLineVersion 2^>nul`) do set "VSYEAR=%%v"
    if "!VSYEAR!"=="2022" set "GENERATOR=Visual Studio 17 2022"
    if "!VSYEAR!"=="2019" set "GENERATOR=Visual Studio 16 2019"
    if "!VSYEAR!"=="2017" set "GENERATOR=Visual Studio 15 2017"
)

if defined GENERATOR (
    echo Using generator: !GENERATOR!
    echo.
    cmake -B build -G "!GENERATOR!" -A x64 || goto :error
) else (
    echo Could not auto-detect Visual Studio - using CMake's default generator.
    echo If configuration fails, install the "Desktop development with C++"
    echo workload, or re-run this from a "Developer Command Prompt for VS".
    echo.
    cmake -B build || goto :error
)

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
