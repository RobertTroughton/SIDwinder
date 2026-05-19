@echo off
setlocal

echo ========================================
echo SIDwinder HVSC Search Index Builder
echo ========================================
echo.
echo Crawls hvsc.etv.cx and writes public\hvsc-index.json
echo (title/author/released for every SID). This takes
echo roughly 30-60 minutes on a full run.
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
