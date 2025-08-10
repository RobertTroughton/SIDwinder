@echo off
REM Build script for CPU6510 WASM module on Windows
REM Requires Emscripten SDK (emsdk) to be installed

echo Building CPU6510 WASM module for Windows...

REM Set up Emscripten environment
REM Adjust this path to where you installed emsdk
set EMSDK_PATH=D:\git\emsdk

if not exist "%EMSDK_PATH%" (
    echo ERROR: EMSDK not found at %EMSDK_PATH%
    echo Please install Emscripten or update EMSDK_PATH in this script
    pause
    exit /b 1
)

REM Activate Emscripten environment
call "%EMSDK_PATH%\emsdk_env.bat"

REM Compile with optimizations and export necessary functions
call emcc cpu6510_wasm.cpp ^
    -O3 ^
    -s WASM=1 ^
    -s EXPORTED_FUNCTIONS="['_cpu_init','_cpu_load_memory','_cpu_read_memory','_cpu_write_memory','_cpu_step','_cpu_execute_function','_cpu_get_pc','_cpu_set_pc','_cpu_get_sp','_cpu_get_a','_cpu_get_x','_cpu_get_y','_cpu_get_cycles','_cpu_get_memory_access','_cpu_get_sid_writes','_cpu_get_total_sid_writes','_cpu_set_record_writes','_cpu_get_write_sequence_length','_cpu_get_write_sequence_item','_cpu_analyze_memory','_cpu_get_last_write_pc','_allocate_memory','_free_memory','_malloc','_free']" ^
    -s EXPORTED_RUNTIME_METHODS="['ccall','cwrap','getValue','setValue']" ^
    -s MODULARIZE=1 ^
    -s EXPORT_NAME="CPU6510Module" ^
    -s ALLOW_MEMORY_GROWTH=1 ^
    -s TOTAL_MEMORY=16777216 ^
    -o cpu6510.js

if %ERRORLEVEL% EQU 0 (
    echo Build successful!
    echo Generated files:
    echo   - cpu6510.js - JavaScript glue code
    echo   - cpu6510.wasm - WebAssembly module
) else (
    echo Build failed!
    pause
    exit /b 1
)

pause