@echo off
REM Build script for CPU6510 WASM module on Windows
REM Requires Emscripten SDK (emsdk) to be installed
REM Assumes this script is in a "wasm" folder and outputs to "../public"

echo Building CPU6510 WASM module for Windows...
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
echo Compiling WASM module...
echo Output directory: %OUTPUT_DIR%
echo.

REM Compile with optimizations and export necessary functions
REM Output directly to the public folder
call emcc cpu6510_wasm.cpp ^
    -O3 ^
    -s WASM=1 ^
    -s EXPORTED_FUNCTIONS="['_cpu_init','_cpu_load_memory','_cpu_read_memory','_cpu_write_memory','_cpu_step','_cpu_execute_function','_cpu_get_pc','_cpu_set_pc','_cpu_get_sp','_cpu_get_a','_cpu_get_x','_cpu_get_y','_cpu_get_cycles','_cpu_get_memory_access','_cpu_get_sid_writes','_cpu_get_total_sid_writes','_cpu_get_zp_writes','_cpu_get_total_zp_writes','_cpu_set_record_writes','_cpu_set_tracking','_cpu_get_write_sequence_length','_cpu_get_write_sequence_item','_cpu_analyze_memory','_cpu_get_last_write_pc','_allocate_memory','_free_memory','_malloc','_free']" ^
    -s EXPORTED_RUNTIME_METHODS="['ccall','cwrap','getValue','setValue']" ^
    -s MODULARIZE=1 ^
    -s EXPORT_NAME="CPU6510Module" ^
    -s ALLOW_MEMORY_GROWTH=1 ^
    -s TOTAL_MEMORY=16777216 ^
    -o "%OUTPUT_DIR%\cpu6510.js"

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
echo   - cpu6510.js   (JavaScript glue code)
echo   - cpu6510.wasm (WebAssembly module)
echo.

REM Optional: List the actual files with sizes
echo File details:
dir /B "%OUTPUT_DIR%\cpu6510.*"
echo.

REM Optional: Copy any additional files needed
REM For example, if you have the HTML file in the wasm folder:
if exist "index.html" (
    echo Copying index.html to public folder...
    copy /Y "index.html" "%OUTPUT_DIR%\" >nul
    if %ERRORLEVEL% EQU 0 (
        echo   - index.html copied successfully
    )
)

REM Optional: Copy opcodes.h if needed for reference
if exist "opcodes.h" (
    REM echo Copying opcodes.h to public folder...
    REM copy /Y "opcodes.h" "%OUTPUT_DIR%\" >nul
    echo   - opcodes.h (kept in wasm folder)
)

echo.
echo Build process completed!
echo You can now test the application by opening %OUTPUT_DIR%\index.html
echo.

pause