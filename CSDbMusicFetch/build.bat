@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ========================================
echo CSDbMusicFetch - Build
echo ========================================
echo.
echo Configures and builds the release-info fetcher with CMake.
echo Requires: CMake, and Visual Studio or its Build Tools with the
echo "Desktop development with C++" workload. (HTTP uses the built-in
echo WinHTTP, so there is no libcurl/vcpkg setup on Windows.)
echo.

where cmake >nul 2>&1
if errorlevel 1 (
    echo ERROR: cmake is not on PATH. Install CMake from https://cmake.org/
    echo        and tick "Add CMake to the system PATH" during setup, then retry.
    pause
    exit /b 1
)

REM --- Import the Visual Studio C++ environment so this works from a plain
REM     double-click, not only from a "Developer Command Prompt for VS".
REM     vcvars64.bat puts the compiler/tools on PATH; CMake then needs no
REM     special generator handling. If cl is already available (you launched
REM     from a dev prompt) we skip this. ---
where cl >nul 2>&1
if not errorlevel 1 (
    echo C++ compiler already on PATH - skipping Visual Studio setup.
    echo.
    goto :configure
)

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" set "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
    echo ERROR: Could not find vswhere.exe - is Visual Studio installed?
    goto :nocompiler
)

set "VSPATH="
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2^>nul`) do set "VSPATH=%%i"
if not defined VSPATH (
    echo ERROR: No Visual Studio with the C++ toolset (Desktop development
    echo        with C++) was found.
    goto :nocompiler
)

set "VCVARS=!VSPATH!\VC\Auxiliary\Build\vcvars64.bat"
if not exist "!VCVARS!" (
    echo ERROR: vcvars64.bat not found under:
    echo   !VSPATH!
    goto :nocompiler
)

echo Using Visual Studio at:
echo   !VSPATH!
echo Importing the C++ build environment...
call "!VCVARS!" >nul
if errorlevel 1 (
    echo ERROR: failed to import the Visual Studio environment.
    goto :nocompiler
)
echo.

:configure
cmake -B build -DCMAKE_BUILD_TYPE=Release
if errorlevel 1 (
    echo.
    echo Configure failed - retrying from a clean build directory...
    rmdir /s /q build 2>nul
    cmake -B build -DCMAKE_BUILD_TYPE=Release || goto :error
)

cmake --build build --config Release || goto :error

echo.
echo Build complete. Run update-releases.bat to refresh ..\public\index.html.
pause
endlocal
exit /b 0

:nocompiler
echo.
echo Install Visual Studio (Community is free) or the standalone
echo "Build Tools for Visual Studio", with the
echo "Desktop development with C++" workload selected:
echo   https://visualstudio.microsoft.com/downloads/
echo.
echo Then re-run build.bat.
pause
endlocal
exit /b 1

:error
echo.
echo Build failed. See the messages above.
pause
endlocal
exit /b 1
