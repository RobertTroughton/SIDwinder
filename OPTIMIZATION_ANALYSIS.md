# SIDwinder Codebase Optimization Analysis

## Project Overview

SIDwinder is a C64 SID music analysis/manipulation tool (v0.2.6) written in C++20, with a WASM web frontend. It emulates the 6510 CPU to analyze SID files, disassemble them, relocate them, and build C64 SID players. ~13,770 lines of code total.

---

## 1. DUPLICATED CPU EMULATOR (Highest Priority)

The most significant issue: there are **two completely separate 6510 CPU emulators** that do the same thing:

| | Native (`src/6510/`) | WASM (`wasm/cpu6510_wasm.cpp`) |
|---|---|---|
| Lines | ~2,900 across 10 files | ~1,571 in one monolithic file |
| Architecture | pImpl pattern, 4 classes, `std::function` callbacks | Single flat `extern "C"` with globals |
| Memory tracking | `std::array`, `std::vector<RegisterSourceInfo>` | Raw arrays, `std::vector<uint16_t>` |

These two implementations must be kept in sync manually. Any bug fixed in one is likely unfixed in the other.

**Recommendation**: Unify into a **single core emulator** with compile-time `#ifdef __EMSCRIPTEN__` guards for the thin WASM export layer. The core 6510 logic (opcode execution, addressing modes, flag setting) should be shared code. The native build adds the richer tracking (pImpl, callbacks, RegisterSourceInfo), while the WASM build wraps it with `EMSCRIPTEN_KEEPALIVE` exports.

---

## 2. Native CPU Emulator - Over-Abstraction & Performance

### 2a. Excessive pImpl indirection

The native emulator has **4 layers of indirection** for every operation:

```
CPU6510 (public API, pImpl)
  -> CPU6510Impl (delegates to sub-objects)
    -> InstructionExecutor (executes instructions)
    -> MemorySubsystem (handles memory)
    -> AddressingModes (resolves addresses)
    -> CPUState (manages registers)
```

Every `step()` call involves multiple pointer dereferences and function calls through getters/setters.

**Recommendations**:
- **Flatten the hot path**: Make `CPUState` fields directly accessible rather than getter/setter calls
- **Enable LTO** in CMake for Release builds: `set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)`
- Consider inlining hot-path functions or moving them to headers

### 2b. `std::function` callbacks on the hot path

In `CPU6510Impl::writeMemory()` (line 205-223), every single memory write checks **four** `std::function` callbacks. `std::function` has significant overhead (heap allocation, type erasure).

**Recommendation**: Use raw function pointers or consolidate into a single callback.

### 2c. Heap-allocated tracking vectors

```cpp
lastWriteToAddr_.resize(65536, 0);   // vector<u32> = 256KB on heap
writeSourceInfo_.resize(65536);       // vector<RegisterSourceInfo> = much larger
```

**Recommendation**: Use `std::array` like `memory_` and `memoryAccess_` already are, or lazy-allocate only when needed.

---

## 3. WASM Emulator - Specific Optimizations

### 3a. `std::set` for analysis results (sid_processor.cpp:65-66)

```cpp
std::set<uint16_t> modifiedAddresses;
std::set<uint8_t> zeroPageUsed;
```

`std::set` is a red-black tree with per-element heap allocation.

**Recommendation**: Use `bool usedAddresses[65536]` and `bool zpUsed[256]` instead.

### 3b. O(n²) address access (sid_processor.cpp:524-532)

```cpp
auto it = sidState.analysis.modifiedAddresses.begin();
std::advance(it, index);  // O(n) per call!
```

Called N times = O(n²) total.

**Recommendation**: Replace set with sorted vector or pre-compute the list.

### 3c. Memory loading byte-by-byte (sid_processor.cpp:245-247)

```cpp
for (uint32_t i = 0; i < musicSize; i++) {
    cpu_write_memory(sidState.header.loadAddress + i, musicData[i]);
}
```

**Recommendation**: Use `memcpy` directly into `cpu.memory`.

### 3d. Additional WASM build flags to consider

- `-flto` - Link-time optimization
- `-s ASSERTIONS=0` - Disable runtime assertions for production
- `--closure 1` - Minify JS glue code

---

## 4. Language Choice for WASM

C++ compiled with Emscripten is already near-optimal for WASM performance. The ranking:

**C/C++ ≈ Rust > Zig > AssemblyScript >> Go**

Go's WASM output is significantly larger and slower due to GC overhead. The current C++ approach is the right choice. Gains come from algorithmic improvements, not language switching.

---

## 5. Potentially Unused / Dead Code

### 5a. `opcodes.h` static table in WASM
The WASM emulator has its own inline opcode handling and only uses `opcodeTable` from `opcodes.h` for `cpu_analyze_memory()`. Consider if this can be eliminated.

### 5b. `cpu_load_memory()` vs `cpu_write_memory()`
Both load data into memory. `cpu_load_memory` uses `memcpy` (efficient) but `sid_processor.cpp` uses the slow `cpu_write_memory` loop instead.

### 5c. `MemoryDataFlow` tracking
`MemorySubsystem::dataFlow_` tracks memory-to-memory copy chains. Verify if anything actually consumes this data.

### 5d. `dumpMemoryAccess()`
Debug/diagnostic function - consider guarding behind `#ifndef NDEBUG`.

### 5e. `export_for_claude.py`
One-off utility script at project root, not part of the build.

### 5f. PC history buffer never checked
In `CPU6510Impl::executeFunction()`, `pcHistory[8]` is written to but never actually checked for repeated patterns. The loop detection only triggers on MAX_STEPS timeout.

---

## 6. Architecture Improvements

### 6a. Function pointer dispatch table
Replace two-level switch cascade with a 256-entry function pointer table indexed by opcode for faster dispatch.

### 6b. Configurable emulation frames
`DEFAULT_SID_EMULATION_FRAMES = 30000` (10 minutes at 50fps) is used as both default frame count and max steps limit. The web version may benefit from a lower default.

---

## 7. Build System Issues

### 7a. Missing LTO
Add to CMakeLists.txt: `set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)` for Release.

### 7b. WASM build is Windows-only
`wasm/build.bat` is a Windows batch file. A cross-platform script would be better.

### 7c. Binary in repo
`SIDwinder.exe` at the repo root shouldn't be in version control.

---

## Summary (Prioritized)

| Priority | Change | Impact |
|----------|--------|--------|
| **HIGH** | Unify the two CPU emulators | Eliminate maintenance burden, reduce bugs |
| **HIGH** | Replace `std::set` with arrays in WASM analysis | Significant speedup for web analysis |
| **HIGH** | Enable LTO in CMake | Free 5-15% performance boost |
| **MEDIUM** | Fix O(n²) `sid_get_modified_address()` | Faster web UI response |
| **MEDIUM** | Use `memcpy` for WASM music loading | Minor but easy win |
| **MEDIUM** | Flatten CPU state access in hot path | Faster emulation |
| **MEDIUM** | Replace `std::function` callbacks with function pointers | Faster memory writes |
| **LOW** | Function pointer dispatch table | Cleaner, slightly faster dispatch |
| **LOW** | Remove/guard debug functions | Smaller binary |
| **LOW** | Cross-platform WASM build | Developer experience |
