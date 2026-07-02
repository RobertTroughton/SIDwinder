@echo off
setlocal

echo ========================================
echo SIDwinder HVSC Search Index Builder
echo ========================================
echo.
echo Reads the local HVSC mirror in public\HVSC and writes
echo public\hvsc-index.json (title/author/released + STIL text
echo for every SID). Takes only a few seconds.
echo.
echo Requires public\HVSC\C64Music to exist. If it doesn't, run
echo   npm run extract-hvsc
echo first to unpack the archive from hvsc-data\.
echo.

where node >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is not on PATH. Install from https://nodejs.org/ and retry.
    pause
    exit /b 1
)

node tools\build-hvsc-index.js %*
if errorlevel 1 (
    echo.
    echo Build failed.
    pause
    exit /b 1
)

echo.
echo Done. Commit public\hvsc-index.json to ship the updated search index.
pause
endlocal
