# SIDwinder Codebase Optimization Analysis

## Project Overview

SIDwinder is a web-based C64 SID music player/visualizer with WASM-compiled 6510 CPU emulation. The native C++ CLI tool has been removed (see below); the project now consists of the web frontend (`public/`), WASM C++ sources (`wasm/`), and C64 assembly player routines (`SIDPlayers/`).

### What Was Removed

The native C++ codebase (`src/`, CMakeLists.txt, build scripts, external tools) has been removed. It contained a duplicate 6510 CPU emulator, disassembler, relocator, and player builder - all of which are now web-only features (or documented for future reimplementation). The relocation suite is documented in [RELOCATION.md](RELOCATION.md).

---

## Remaining Optimizations (WASM / Web)

### 1. WASM Emulator - `std::set` for analysis results (HIGH)

In `wasm/sid_processor.cpp`:

```cpp
std::set<uint16_t> modifiedAddresses;
std::set<uint8_t> zeroPageUsed;
```

`std::set` is a red-black tree with per-element heap allocation.

**Recommendation**: Use `bool usedAddresses[65536]` and `bool zpUsed[256]` instead.

### 2. O(n²) address access (HIGH)

In `wasm/sid_processor.cpp`:

```cpp
auto it = sidState.analysis.modifiedAddresses.begin();
std::advance(it, index);  // O(n) per call!
```

Called N times = O(n²) total.

**Recommendation**: Replace set with sorted vector or pre-compute the list.

### 3. Memory loading byte-by-byte (MEDIUM)

In `wasm/sid_processor.cpp`:

```cpp
for (uint32_t i = 0; i < musicSize; i++) {
    cpu_write_memory(sidState.header.loadAddress + i, musicData[i]);
}
```

**Recommendation**: Use `memcpy` directly into `cpu.memory`.

### 4. Additional WASM build flags (MEDIUM)

Consider adding to the Emscripten build:
- `-flto` - Link-time optimization
- `-s ASSERTIONS=0` - Disable runtime assertions for production
- `--closure 1` - Minify JS glue code

### 5. WASM build is Windows-only (LOW)

`wasm/build.bat` is a Windows batch file. A cross-platform build script (shell script or Makefile) would improve developer experience.

### 6. Function pointer dispatch table (LOW)

Replace opcode switch/case with a 256-entry function pointer table for potentially faster dispatch.

### 7. Configurable emulation frames (LOW)

`DEFAULT_SID_EMULATION_FRAMES = 30000` (10 minutes at 50fps) may be excessive for web use. Consider a lower default with user-configurable override.

### 8. `opcodes.h` static table

The WASM emulator has its own inline opcode handling and only uses `opcodeTable` from `opcodes.h` for `cpu_analyze_memory()`. Consider if this can be simplified.

---

## Summary (Prioritized)

| Priority | Change | Impact |
|----------|--------|--------|
| **HIGH** | Replace `std::set` with arrays in WASM analysis | Significant speedup for web analysis |
| **HIGH** | Fix O(n²) `sid_get_modified_address()` | Faster web UI response |
| **MEDIUM** | Use `memcpy` for WASM music loading | Minor but easy win |
| **MEDIUM** | Add WASM build optimization flags | Smaller/faster WASM output |
| **LOW** | Cross-platform WASM build script | Developer experience |
| **LOW** | Function pointer dispatch table | Cleaner, slightly faster dispatch |
| **LOW** | Configurable emulation frame count | Better UX for web |
