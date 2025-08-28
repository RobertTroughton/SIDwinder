@echo off
setlocal

java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\Default\Default.asm -showmem -binfile -o public\prg\Default-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\RaistlinBars\RaistlinBars.asm -showmem -binfile -o public\prg\RaistlinBars-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\RaistlinBarsWithLogo\RaistlinBarsWithLogo.asm -showmem -binfile -o public\prg\RaistlinBarsWithLogo-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\RaistlinMirrorBars\RaistlinMirrorBars.asm -showmem -binfile -o public\prg\RaistlinMirrorBars-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\RaistlinMirrorBarsWithLogo\RaistlinMirrorBarsWithLogo.asm -showmem -binfile -o public\prg\RaistlinMirrorBarsWithLogo-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\SimpleBitmap\SimpleBitmap.asm -showmem -binfile -o public\prg\SimpleBitmap-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=20736 :dataAddress=20480 .\SIDPlayers\SimpleBitmapWithScroller\SimpleBitmapWithScroller.asm -showmem -binfile -o public\prg\SimpleBitmapWithScroller-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\SimpleRaster\SimpleRaster.asm -showmem -binfile -o public\prg\SimpleRaster-4000.bin || goto :error

java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\Default\Default.asm -showmem -binfile -o public\prg\Default-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\RaistlinBars\RaistlinBars.asm -showmem -binfile -o public\prg\RaistlinBars-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\RaistlinBarsWithLogo\RaistlinBarsWithLogo.asm -showmem -binfile -o public\prg\RaistlinBarsWithLogo-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\RaistlinMirrorBars\RaistlinMirrorBars.asm -showmem -binfile -o public\prg\RaistlinMirrorBars-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\RaistlinMirrorBarsWithLogo\RaistlinMirrorBarsWithLogo.asm -showmem -binfile -o public\prg\RaistlinMirrorBarsWithLogo-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\SimpleBitmap\SimpleBitmap.asm -showmem -binfile -o public\prg\SimpleBitmap-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=37120 :dataAddress=36864 .\SIDPlayers\SimpleBitmapWithScroller\SimpleBitmapWithScroller.asm -showmem -binfile -o public\prg\SimpleBitmapWithScroller-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\SimpleRaster\SimpleRaster.asm -showmem -binfile -o public\prg\SimpleRaster-8000.bin || goto :error

java -jar .\KickAss.jar :loadAddress=49152 :sysAddress=49408 :dataAddress=49152 .\SIDPlayers\Default\Default.asm -showmem -binfile -o public\prg\Default-C000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=49152 :sysAddress=49408 :dataAddress=49152 .\SIDPlayers\SimpleRaster\SimpleRaster.asm -showmem -binfile -o public\prg\SimpleRaster-C000.bin || goto :error


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
