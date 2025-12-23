@echo off
REM Build script for SIDwinder WASM modules on Windows
REM Requires Emscripten SDK (emsdk) to be installed
REM Assumes this script is in a "wasm" folder and outputs to "../public"

echo Building SIDwinder WASM modules with PNG converter for Windows...
echo.

REM Set up paths
set OUTPUT_DIR=..\public
set CURRENT_DIR=%cd%

REM Set up Emscripten environment
REM Adjust this path to where you installed emsdk
set EMSDK_PATH=D:\git\emsdk

if not exist "%EMSDK_PATH%" (
    echo ERROR: EMSDK not found at %EMSDK_PATH%
    echo Please install Emscripten or update EMSDK_PATH in this script
    pause
    exit /b 1
)

REM Check if output directory exists, create if not
if not exist "%OUTPUT_DIR%" (
    echo Creating output directory: %OUTPUT_DIR%
    mkdir "%OUTPUT_DIR%"
)

REM Activate Emscripten environment
echo Activating Emscripten environment...
call "%EMSDK_PATH%\emsdk_env.bat"

echo.
echo Compiling SIDwinder WASM module with CPU emulator, SID processor, and PNG converter...
echo Output directory: %OUTPUT_DIR%
echo.

REM Compile all C++ files together
REM This creates a single WASM module with all functionality including PNG conversion
call emcc cpu6510_wasm.cpp sid_processor.cpp png_converter.cpp ^
    -O3 ^
    -s WASM=1 ^
    -s EXPORTED_FUNCTIONS="['_cpu_init','_cpu_load_memory','_cpu_read_memory','_cpu_write_memory','_cpu_step','_cpu_execute_function','_cpu_get_pc','_cpu_set_pc','_cpu_get_sp','_cpu_get_a','_cpu_get_x','_cpu_get_y','_cpu_get_cycles','_cpu_get_memory_access','_cpu_get_sid_writes','_cpu_get_total_sid_writes','_cpu_get_sid_chip_count','_cpu_get_sid_chip_address','_cpu_get_zp_writes','_cpu_get_total_zp_writes','_cpu_set_record_writes','_cpu_set_tracking','_cpu_get_write_sequence_length','_cpu_get_write_sequence_item','_cpu_analyze_memory','_cpu_get_last_write_pc','_sid_init','_sid_load','_sid_analyze','_sid_get_header_string','_sid_get_header_value','_sid_set_header_string','_sid_create_modified','_sid_get_modified_count','_sid_get_modified_address','_sid_get_zp_count','_sid_get_zp_address','_sid_get_code_bytes','_sid_get_data_bytes','_sid_get_sid_writes','_sid_get_sid_chip_count','_sid_get_sid_chip_address','_sid_get_clock_type','_sid_get_sid_model','_sid_cleanup','_png_converter_init','_png_converter_set_image','_png_converter_convert','_png_converter_create_c64_bitmap','_png_converter_get_background_color','_png_converter_get_color_stats','_png_converter_get_map_data','_png_converter_get_scr_data','_png_converter_get_col_data','_png_converter_set_palette','_png_converter_get_palette_count','_png_converter_get_palette_name','_png_converter_get_current_palette','_png_converter_get_palette_color','_png_converter_cleanup','_allocate_memory','_free_memory','_malloc','_free']" ^    -s EXPORTED_RUNTIME_METHODS="['ccall','cwrap','getValue','setValue','HEAP8','HEAP16','HEAP32','HEAPU8','HEAPU16','HEAPU32','HEAPF32','HEAPF64']" ^
    -s MODULARIZE=1 ^
    -s EXPORT_NAME="SIDwinderModule" ^
    -s ALLOW_MEMORY_GROWTH=1 ^
    -s INITIAL_MEMORY=16777216 ^
    -s MAXIMUM_MEMORY=67108864 ^
    -s NO_EXIT_RUNTIME=1 ^
    -s ENVIRONMENT="web" ^
    -s SINGLE_FILE=0 ^
    -o "%OUTPUT_DIR%\sidwinder.js"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo Build FAILED!
    echo ========================================
    echo Please check the error messages above.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Build successful!
echo ========================================
echo.
echo Generated files in %OUTPUT_DIR%:
echo   - sidwinder.js   (JavaScript glue code)
echo   - sidwinder.wasm (WebAssembly module with PNG converter)
echo.

REM List the actual files with sizes
echo File details:
dir /B "%OUTPUT_DIR%\sidwinder.*"
echo.

REM Copy web files to public folder if they exist in wasm folder
if exist "index.html" (
    echo Copying index.html to public folder...
    copy /Y "index.html" "%OUTPUT_DIR%\" >nul
    if %ERRORLEVEL% EQU 0 (
        echo   - index.html copied successfully
    )
)

if exist "styles.css" (
    echo Copying styles.css to public folder...
    copy /Y "styles.css" "%OUTPUT_DIR%\" >nul
    if %ERRORLEVEL% EQU 0 (
        echo   - styles.css copied successfully
    )
)

if exist "sidwinder-core.js" (
    echo Copying sidwinder-core.js to public folder...
    copy /Y "sidwinder-core.js" "%OUTPUT_DIR%\" >nul
    if %ERRORLEVEL% EQU 0 (
        echo   - sidwinder-core.js copied successfully
    )
)

if exist "ui.js" (
    echo Copying ui.js to public folder...
    copy /Y "ui.js" "%OUTPUT_DIR%\" >nul
    if %ERRORLEVEL% EQU 0 (
        echo   - ui.js copied successfully
    )
)

if exist "png-converter.js" (
    echo Copying png-converter.js to public folder...
    copy /Y "png-converter.js" "%OUTPUT_DIR%\" >nul
    if %ERRORLEVEL% EQU 0 (
        echo   - png-converter.js copied successfully
    )
)

echo Build process completed!
echo You can now test the application by serving the %OUTPUT_DIR% folder
echo.

pause