@echo off
setlocal

java -jar .\KickAss.jar :loadAddress=16384 .\SIDPlayers\Default\Default.asm -showmem -binfile -o public\prg\Default.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 .\SIDPlayers\RaistlinBars\RaistlinBars.asm -showmem -binfile -o public\prg\RaistlinBars.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 .\SIDPlayers\RaistlinBarsWithLogo\RaistlinBarsWithLogo.asm -showmem -binfile -o public\prg\RaistlinBarsWithLogo.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 .\SIDPlayers\RaistlinMirrorBars\RaistlinMirrorBars.asm -showmem -binfile -o public\prg\RaistlinMirrorBars.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 .\SIDPlayers\RaistlinMirrorBarsWithLogo\RaistlinMirrorBarsWithLogo.asm -showmem -binfile -o public\prg\RaistlinMirrorBarsWithLogo.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 .\SIDPlayers\SimpleBitmap\SimpleBitmap.asm -showmem -binfile -o public\prg\SimpleBitmap.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 .\SIDPlayers\SimpleRaster\SimpleRaster.asm -showmem -binfile -o public\prg\SimpleRaster.bin || goto :error

echo.
echo ==================================
echo All builds completed successfully.
echo ==================================
echo.
pause
exit /b 0

:error
echo.
echo ===============================
echo Build failed. See errors above.
echo ===============================
echo.
pause
exit /b 1
