@echo off
setlocal
cd /d "%~dp0"

echo ========================================
echo CSDbMusicFetch - Update Releases page
echo ========================================
echo.
echo Reads the release IDs from the screenshots in
echo ..\public\PNG\Releases (one <id>.png per release), fetches each from
echo CSDb, and rewrites the auto-generated release cards in
echo ..\public\index.html (in place).
echo.

REM Locate the built executable (multi-config builds put it under Release\).
set "EXE=build\Release\csdbmusicfetch.exe"
if not exist "%EXE%" set "EXE=build\csdbmusicfetch.exe"
if not exist "%EXE%" set "EXE=build\Debug\csdbmusicfetch.exe"
if not exist "%EXE%" (
    echo ERROR: csdbmusicfetch.exe not found. Run build.bat first.
    pause
    exit /b 1
)

"%EXE%" ..\public\PNG\Releases ..\public\index.html
if errorlevel 1 goto :error

echo.
echo Done. Review the diff in ..\public\index.html and commit it.
pause
endlocal
exit /b 0

:error
echo.
echo Update failed.
pause
exit /b 1
