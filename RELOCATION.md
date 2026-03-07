# SID Relocation Suite - Design Document

## Overview

SIDwinder's native C++ build included a SID file relocation feature that could move a SID tune from its original memory address to a different location while preserving correct execution. This document captures the design and algorithms for potential reimplementation as a web feature.

## What Relocation Does

C64 SID music files are typically hardcoded to load and execute at specific memory addresses. Relocation allows moving a tune to a different address range - essential for demos, intros, and other productions where memory layout matters.

The process: **Load SID -> Emulate to discover code/data boundaries -> Disassemble with address translation -> Reassemble at new address -> Verify correctness**

## Core Data Structures

### RelocationEntry
Represents a single memory location requiring address adjustment:
```
- targetAddress (u16): The address being pointed to
- type: Low | High (which byte of a 16-bit address this represents)
```

### RelocationTable
A map of `address -> RelocationEntry` tracking every memory location that contains an address reference needing adjustment. During disassembly, any instruction operand or data byte that references an address within the relocated range gets an entry.

### RelocationParams
```
- inputFile: Source .sid file
- outputFile: Destination .sid file
- tempDir: Working directory for intermediate files
- relocationAddress (u16): Target base address
- kickAssPath: Path to KickAss assembler (external dependency)
- verbose: Logging flag
```

### RelocationResult
```
- success: bool
- originalLoad/Init/Play: Original SID addresses
- newLoad/Init/Play: Relocated SID addresses
- message: Status/error text
```

## Algorithm

### Step 1: Load and Analyze
1. Load the SID file, capture original load/init/play addresses
2. Preserve SID header metadata (flags, second/third SID addresses, version, speed)

### Step 2: Calculate New Addresses
Relative offsets are preserved:
```
newLoad = relocationAddress
newInit = newLoad + (originalInit - originalLoad)
newPlay = newLoad + (originalPlay - originalLoad)
```

### Step 3: Emulate for Memory Analysis
Run the 6510 CPU emulator for ~300,000 frames (10 minutes at 50Hz PAL) to discover:
- Which memory addresses are executed as code
- Which are accessed as data
- Memory access patterns that reveal address references

This emulation-based analysis is critical because static disassembly alone cannot reliably distinguish code from data in 6510 programs, nor can it find all address references (especially computed ones).

### Step 4: Generate Relocated Assembly
The Disassembler generates an assembly source file with:
- All addresses translated to the new base
- The RelocationTable tracking which operands need address adjustment
- Proper label generation for internal references

### Step 5: Assemble
The generated assembly is assembled back to a PRG using KickAss (an external 6502/6510 assembler). This round-trip through assembly ensures correct encoding of all instructions at their new addresses.

### Step 6: Build Output SID
A new SID file is created from the assembled PRG:
- New load/init/play addresses in the header
- All original metadata preserved (title, author, copyright, flags)
- Multi-SID chip addresses preserved

### Step 7: Verify (Optional)
The verification process:
1. Load original SID, emulate for N frames, capture a trace log of all SID register writes
2. Load relocated SID, emulate for same N frames, capture trace log
3. Compare the two traces - they should produce identical SID register write sequences
4. Generate a diff report if they don't match

## Known Limitations and Challenges

1. **Self-modifying code**: The emulation-based approach handles many cases of self-modifying code since it observes actual execution, but code paths not exercised during the emulation window will be missed.

2. **Timing-dependent code**: Some tunes use precise cycle counting. The trace comparison verifies SID register writes match, but subtle timing differences may not be caught.

3. **Data tables containing addresses**: Lookup tables with embedded addresses (jump tables, pointer arrays) are the hardest to relocate correctly. The emulator tries to identify these through memory access pattern analysis, but can miss entries that aren't accessed during the emulation window.

4. **External assembler dependency**: The original implementation required KickAss.jar (Java). A web implementation would need either a JavaScript 6502 assembler or a different approach (direct binary patching).

5. **Incomplete code coverage**: 10 minutes of emulation covers most tunes but some multi-song SIDs have code paths only reached by specific song selections.

## Considerations for Web Reimplementation

### Approach A: Binary Patching (Simpler)
Instead of disassemble-reassemble, directly patch the binary:
1. Emulate to identify all code regions and address references
2. Build a relocation table of bytes that need adjustment
3. Copy the binary to new address, adjusting only the identified bytes
4. This avoids needing an assembler but may be less robust

### Approach B: Full Disassemble-Reassemble (More Robust)
Port the full pipeline to JavaScript/WASM:
1. The CPU emulator already exists in WASM (`cpu6510_wasm.cpp`)
2. Would need a JavaScript disassembler (new code)
3. Would need a JavaScript 6502 assembler (or use an existing one)
4. More code but handles edge cases better

### Approach C: Hybrid
Use the existing WASM emulator for analysis, then do binary patching for simple cases and flag complex ones (self-modifying code, computed jumps) for manual review.

### Verification in the Browser
The WASM CPU emulator could run the same trace-comparison verification. Emulating 300K frames is fast enough in WASM for interactive use.

## File References (Removed Native Code)

These files contained the original implementation:
- `src/RelocationStructs.h` - RelocationEntry, RelocationTable classes
- `src/RelocationUtils.h/.cpp` - Core relocation functions
- `src/Disassembler.h/.cpp` - Disassembly with relocation support
- `src/app/CommandProcessor.cpp` - Integration with file processing pipeline
- `src/app/SIDwinderApp.cpp` - CLI interface (`-relocate=<addr>`, `-noverify`)
