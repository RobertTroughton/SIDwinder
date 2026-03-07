@echo off
echo Updating Claude files...
echo.

echo Exporting public HTML...
python.exe export_public_for_claude.py
echo.

echo Export complete!
@pause