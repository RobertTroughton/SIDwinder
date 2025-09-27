@echo off
echo Updating Claude files...
echo.

echo [1/3] Exporting C++ source code...
python.exe export_for_claude.py
echo.

echo [2/3] Exporting SIDPlayers ASM files...
python.exe export_sidplayers_for_claude.py
echo.

echo [3/3] Exporting public HTML...
python.exe export_public_for_claude.py
echo.

echo All exports complete!
@pause