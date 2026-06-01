@echo off
setlocal enabledelayedexpansion

echo ========================================
echo SIDwinder Build Script
echo ========================================
echo.

REM --- Step 1: Generate Frequency Table ---
echo [1/3] Generating Frequency Table...
python.exe FreqTableGen.py || goto :error
echo.

REM --- Step 2: Build SID Players for Web ---
echo [2/3] Building SID Players for Web...
echo.

java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\Default\Default.asm -showmem -binfile -o public\prg\Default-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\DefaultWithLogo\DefaultWithLogo.asm -showmem -binfile -o public\prg\DefaultWithLogo-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\RaistlinBars\RaistlinBars.asm -showmem -binfile -o public\prg\RaistlinBars-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\RaistlinBarsWithLogo\RaistlinBarsWithLogo.asm -showmem -binfile -o public\prg\RaistlinBarsWithLogo-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\RaistlinMirrorBars\RaistlinMirrorBars.asm -showmem -binfile -o public\prg\RaistlinMirrorBars-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\RaistlinMirrorBarsWithLogo\RaistlinMirrorBarsWithLogo.asm -showmem -binfile -o public\prg\RaistlinMirrorBarsWithLogo-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\RaistlinTripleBars\RaistlinTripleBars.asm -showmem -binfile -o public\prg\RaistlinTripleBars-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\RaistlinTripleMirrorBars\RaistlinTripleMirrorBars.asm -showmem -binfile -o public\prg\RaistlinTripleMirrorBars-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\SimpleBitmap\SimpleBitmap.asm -showmem -binfile -o public\prg\SimpleBitmap-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=20736 :dataAddress=20480 .\SIDPlayers\SimpleBitmapWithScroller\SimpleBitmapWithScroller.asm -showmem -binfile -o public\prg\SimpleBitmapWithScroller-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\SimpleRaster\SimpleRaster.asm -showmem -binfile -o public\prg\SimpleRaster-4000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=16384 :sysAddress=16640 :dataAddress=16384 .\SIDPlayers\ScrapColumns\ScrapColumns.asm -showmem -binfile -o public\prg\ScrapColumns-4000.bin || goto :error

java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\Default\Default.asm -showmem -binfile -o public\prg\Default-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\DefaultWithLogo\DefaultWithLogo.asm -showmem -binfile -o public\prg\DefaultWithLogo-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\RaistlinBars\RaistlinBars.asm -showmem -binfile -o public\prg\RaistlinBars-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\RaistlinBarsWithLogo\RaistlinBarsWithLogo.asm -showmem -binfile -o public\prg\RaistlinBarsWithLogo-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\RaistlinMirrorBars\RaistlinMirrorBars.asm -showmem -binfile -o public\prg\RaistlinMirrorBars-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\RaistlinMirrorBarsWithLogo\RaistlinMirrorBarsWithLogo.asm -showmem -binfile -o public\prg\RaistlinMirrorBarsWithLogo-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\RaistlinTripleBars\RaistlinTripleBars.asm -showmem -binfile -o public\prg\RaistlinTripleBars-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\RaistlinTripleMirrorBars\RaistlinTripleMirrorBars.asm -showmem -binfile -o public\prg\RaistlinTripleMirrorBars-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\SimpleBitmap\SimpleBitmap.asm -showmem -binfile -o public\prg\SimpleBitmap-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=37120 :dataAddress=36864 .\SIDPlayers\SimpleBitmapWithScroller\SimpleBitmapWithScroller.asm -showmem -binfile -o public\prg\SimpleBitmapWithScroller-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\SimpleRaster\SimpleRaster.asm -showmem -binfile -o public\prg\SimpleRaster-8000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=32768 :sysAddress=33024 :dataAddress=32768 .\SIDPlayers\ScrapColumns\ScrapColumns.asm -showmem -binfile -o public\prg\ScrapColumns-8000.bin || goto :error

java -jar .\KickAss.jar :loadAddress=49152 :sysAddress=49408 :dataAddress=49152 .\SIDPlayers\Default\Default.asm -showmem -binfile -o public\prg\Default-C000.bin || goto :error
java -jar .\KickAss.jar :loadAddress=49152 :sysAddress=49408 :dataAddress=49152 .\SIDPlayers\SimpleRaster\SimpleRaster.asm -showmem -binfile -o public\prg\SimpleRaster-C000.bin || goto :error

echo.
echo SID Players built successfully.
echo.

REM --- Step 3: WASM Build ---
echo [3/3] Building WASM modules...
echo.

REM Set up Emscripten environment
REM Auto-detect the Emscripten SDK. Resolution order:
REM   1. An EMSDK_PATH you set yourself before running this script (wins).
REM   2. The EMSDK env var that "emsdk activate" sets.
REM   3. A list of common install locations (edit/add your own below).
REM To force a path, run e.g.  set EMSDK_PATH=C:\path\to\emsdk  before this script.

if defined EMSDK_PATH goto :emsdk_check

if defined EMSDK if exist "%EMSDK%\emsdk_env.bat" set "EMSDK_PATH=%EMSDK%"

if not defined EMSDK_PATH (
    for %%D in (
        "D:\git\emsdk"
        "C:\git\emsdk"
        "%USERPROFILE%\emsdk"
        "%LOCALAPPDATA%\emsdk"
        "C:\emsdk"
        "C:\tools\emsdk"
    ) do (
        if not defined EMSDK_PATH if exist "%%~D\emsdk_env.bat" set "EMSDK_PATH=%%~D"
    )
)

:emsdk_check
if not defined EMSDK_PATH (
    echo ERROR: Could not locate the Emscripten SDK.
    echo Searched the EMSDK env var and common install locations.
    echo Install it from https://github.com/emscripten-core/emsdk then either:
    echo   - run "emsdk activate latest" so the EMSDK variable is set, or
    echo   - set EMSDK_PATH before running this script, e.g. set EMSDK_PATH=C:\path\to\emsdk
    echo Skipping WASM build.
    goto :done
)

if not exist "%EMSDK_PATH%\emsdk_env.bat" (
    echo ERROR: EMSDK_PATH is "%EMSDK_PATH%" but no emsdk_env.bat was found there.
    echo Please correct EMSDK_PATH or reinstall the Emscripten SDK.
    echo Skipping WASM build.
    goto :done
)

echo Using Emscripten SDK at: %EMSDK_PATH%

REM Check output directory
if not exist "public" (
    echo Creating public directory...
    mkdir public
)

REM Activate Emscripten environment
echo Activating Emscripten environment...
call "%EMSDK_PATH%\emsdk_env.bat"

REM emsdk_env.bat exists even on a fresh clone, but emcc only lands on PATH
REM after the toolchain is installed AND activated. Verify before compiling.
where emcc >nul 2>nul
if errorlevel 1 (
    echo.
    echo ERROR: Found emsdk at "%EMSDK_PATH%" but 'emcc' is not on the PATH.
    echo The toolchain is probably not installed/activated yet. Run once:
    echo     cd /d "%EMSDK_PATH%"
    echo     emsdk install latest
    echo     emsdk activate latest
    echo then re-run this build. Skipping WASM build.
    goto :done
)

echo.
echo Compiling WASM module (cpu6510 + SID processor + PNG converter + reSID audio)...
echo.

pushd wasm
call emcc cpu6510_wasm.cpp sid_processor.cpp png_converter.cpp sid_audio.cpp ^
    resid\sid.cc resid\voice.cc resid\wave.cc resid\envelope.cc ^
    resid\filter8580new.cc resid\extfilt.cc ^
    resid\pot.cc resid\dac.cc resid\version.cc ^
    -I. ^
    -O3 ^
    -s WASM=1 ^
    -s EXPORTED_FUNCTIONS="['_cpu_init','_cpu_load_memory','_cpu_read_memory','_cpu_write_memory','_cpu_step','_cpu_execute_function','_cpu_get_pc','_cpu_set_pc','_cpu_get_sp','_cpu_get_a','_cpu_get_x','_cpu_get_y','_cpu_get_cycles','_cpu_get_memory_access','_cpu_get_sid_writes','_cpu_get_total_sid_writes','_cpu_get_sid_chip_count','_cpu_get_sid_chip_address','_cpu_get_zp_writes','_cpu_get_total_zp_writes','_cpu_set_record_writes','_cpu_set_tracking','_cpu_get_write_sequence_length','_cpu_get_write_sequence_item','_cpu_analyze_memory','_cpu_get_last_write_pc','_sid_init','_sid_load','_sid_analyze','_sid_get_header_string','_sid_get_header_value','_sid_set_header_string','_sid_create_modified','_sid_get_modified_count','_sid_get_modified_address','_sid_get_zp_count','_sid_get_zp_address','_sid_get_code_bytes','_sid_get_data_bytes','_sid_get_sid_writes','_sid_get_sid_chip_count','_sid_get_sid_chip_address','_sid_get_clock_type','_sid_get_sid_model','_sid_cleanup','_png_converter_init','_png_converter_set_image','_png_converter_convert','_png_converter_create_c64_bitmap','_png_converter_get_background_color','_png_converter_get_bitmap_mode','_png_converter_get_color_stats','_png_converter_get_map_data','_png_converter_get_scr_data','_png_converter_get_col_data','_png_converter_set_palette','_png_converter_get_palette_count','_png_converter_get_palette_name','_png_converter_get_current_palette','_png_converter_get_palette_color','_png_converter_cleanup','_audio_init','_audio_load_sid','_audio_set_subtune','_audio_generate','_audio_set_model','_audio_set_sampling_method','_audio_get_title','_audio_get_author','_audio_get_copyright','_audio_get_subtune_count','_audio_get_default_subtune','_audio_get_sid_model','_audio_get_sid_count','_audio_get_play_time','_audio_get_is_ntsc','_audio_cleanup','_allocate_memory','_free_memory','_malloc','_free']" ^
    -s EXPORTED_RUNTIME_METHODS="['ccall','cwrap','getValue','setValue','HEAP8','HEAP16','HEAP32','HEAPU8','HEAPU16','HEAPU32','HEAPF32','HEAPF64']" ^
    -s MODULARIZE=1 ^
    -s EXPORT_NAME="SIDwinderModule" ^
    -s ALLOW_MEMORY_GROWTH=1 ^
    -s INITIAL_MEMORY=33554432 ^
    -s MAXIMUM_MEMORY=67108864 ^
    -s NO_EXIT_RUNTIME=1 ^
    -s ENVIRONMENT="web" ^
    -s SINGLE_FILE=0 ^
    -o "..\public\sidwinder.js"
popd

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo WASM build FAILED! See errors above.
    goto :error
)

echo.
echo WASM modules built successfully:
echo   - public\sidwinder.js
echo   - public\sidwinder.wasm
echo.

:done
echo.
echo ========================================
echo Build complete!
echo ========================================
echo.
pause
exit /b 0

:error
echo.
echo ========================================
echo Build FAILED! See errors above.
echo ========================================
echo.
pause
exit /b 1
