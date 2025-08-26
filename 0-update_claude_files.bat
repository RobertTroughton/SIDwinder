@echo off
echo Updating Claude files...
echo.

echo [1/2] Exporting C++ source code...
python.exe export_for_claude.py
echo.

echo [2/2] Exporting SIDPlayers ASM files...
python.exe export_sidplayers_for_claude.py
echo.

echo All exports complete!
@pause