# SIDwinder Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Browser (public/)                      │
│                                                           │
│  index.html ──► ui.js (orchestrator)                     │
│                  ├── sidwinder-core.js ──► sidwinder.wasm │
│                  ├── prg-builder.js                       │
│                  │    └── compressor-manager.js (TSCrunch) │
│                  ├── png-converter.js ──► sidwinder.wasm  │
│                  ├── petscii-converter.js                 │
│                  ├── hvsc-browser.js ──► hvsc-index.json  │
│                  ├── visualizer-registry.js               │
│                  └── image-preview-manager.js             │
│                                                           │
├───────────────────────────────────────────────────────────┤
│  Self-hosted HVSC (public/HVSC/, static files)           │
│  ├── C64Music/... raw .sid files served directly         │
│  └── hvsc-index.json: tree + title/author/STIL for search │
└───────────────────────────────────────────────────────────┘
```

## Core Components

### WASM Layer (`wasm/`)

Three C++ files compiled together into `sidwinder.wasm`:

**`cpu6510_wasm.cpp`** - 6510 CPU emulator
- Complete MOS 6510 instruction set (legal + illegal opcodes)
- Memory access tracking (execute/read/write/jump-target flags per address)
- SID register write capture (supports up to 32 SID chips)
- Zero-page write tracking
- CIA timer detection
- Key exports: `cpu_init`, `cpu_step`, `cpu_execute_function`, `cpu_get_*`

**`sid_processor.cpp`** - SID file format handler
- Parses PSID/RSID headers (v1-v4)
- Runs emulation analysis: loads SID, calls init, runs play for N frames
- Extracts: modified addresses, zero-page usage, SID writes, clock type, SID model
- Metadata editing and modified SID export
- Key exports: `sid_init`, `sid_load`, `sid_analyze`, `sid_get_*`, `sid_set_*`

**`png_converter.cpp`** - Image format converter
- Converts 320x200 PNG to C64 multicolor or hires bitmap
- 60+ pre-defined C64 color palettes (VICE, Pepto, Colodore, etc.)
- Color quantization with palette matching
- Outputs: bitmap data, screen RAM, color RAM
- Key exports: `png_converter_init`, `png_converter_convert`, `png_converter_get_*`

**`opcodes.h`** - Shared opcode table (256 entries with mnemonic, addressing mode, size, cycles)

### JavaScript Application (`public/`)

**`sidwinder-core.js`** (320 lines) - WASM bridge
- `SIDAnalyzer` class wrapping all WASM calls via `cwrap()`
- Manages WASM heap memory allocation for file transfers
- Provides clean JS API: `loadSID()`, `analyze()`, `updateMetadata()`, `createModifiedSID()`

**`ui.js`** (2054 lines) - Main application controller
- `UIController` class orchestrating the entire UI
- SID file loading (drag-drop, file picker, HVSC, random)
- Header display and metadata editing
- Visualizer grid with selection
- PRG export workflow with progress feedback
- C64 color palette constants

**`prg-builder.js`** (1444 lines) - PRG file assembly
- `PRGBuilder`: Low-level binary PRG construction
- `SIDwinderPRGExporter`: High-level export combining SID + visualizer
- Memory layout engine: calculates non-overlapping placement of music data, player code, and visualizer assets
- Multi-SID support, save/restore routines
- Compression integration via CompressorManager

**`compressor-manager.js`** (144 lines) - Compression abstraction
- `CompressorManager`: Unified interface for compression options
- Currently supports: none, TSCrunch (self-extracting 6502 format)
- TSCrunch library loaded from `lib/index.js`

**`png-converter.js`** (244 lines) - WASM bridge for image conversion
- `PNGConverter` class wrapping PNG converter WASM functions
- Handles RGBA pixel data transfer to/from WASM heap

**`image-preview-manager.js`** (615 lines) - Image selection UI
- `ImageSelectorModal`: Modal dialog for choosing visualizer images
- Supports: drag-drop, file browse, gallery selection
- PETSCII and bitmap mode support
- Gallery loading from visualizer config JSON files

**`petscii-converter.js`** (332 lines) - PETSCII art generator
- `PETSCIIConverter`: Converts PNG images to C64 PETSCII character art
- Loads charset .bin files, matches 8x8 tiles to best PETSCII characters
- Output: 721 bytes (360 screen codes + 360 color bytes + charset flag)

**`petscii-sanitizer.js`** (266 lines) - Unicode to PETSCII text
- `PETSCIISanitizer`: Converts Unicode text (smart quotes, dashes, etc.) to PETSCII-safe ASCII
- Text padding and centering for SID metadata fields

**`visualizer-registry.js`** (68 lines) - Template catalog
- Static list of 9 visualizer types with name, description, preview image path
- Each references a config JSON in `public/prg/<VisualizerName>/`

**`visualizer-configs.js`** (149 lines) - Config loader
- `VisualizerConfig`: Fetches and caches JSON configs per visualizer
- Merges external gallery definitions
- Provides option schemas for the UI

### HVSC Integration (self-hosted)

HVSC is hosted directly by the site. The raw `.sid` files live under
`public/HVSC/C64Music/...` and are served as static assets; the whole
collection tree and per-tune metadata come from a single committed index,
`public/hvsc-index.json`. There is no serverless proxy and no dependency on an
external mirror — so browsing is instant (no per-folder network calls) and the
version is whatever we ship.

**`hvsc-browser.js`** - Collection browser
- `window.hvscBrowser`: Navigate HVSC directory structure
- Builds the directory tree in-memory from `hvsc-index.json`; no network per folder
- Plays/downloads SIDs directly from `/HVSC/<path>`
- Search matches title, author, path AND folded STIL comment text

**`hvsc-random.js`** - Random SID picker
- `window.hvscRandom`: Picks a random tune from the index
- Optional `hvsc-random.json` (path prefixes) biases the pick to curated areas

**Data & tooling (not served / built ahead of time):**
- `hvsc-data/*.7z` - committed HVSC archive (the raw files aren't committed)
- `scripts/extract-hvsc.js` - extracts the archive into `public/HVSC/`
  (run locally once, and by the Netlify build via `netlify.toml`)
- `tools/build-hvsc-index.js` - reads `public/HVSC/` + `DOCUMENTS/STIL.txt`
  and writes `public/hvsc-index.json` (seconds; run after each HVSC update)
- Returns HTML for directories, base64 for binary SID files
- CORS headers for browser access

### Data Files (`public/`)

**`bar-styles-data.js`** - 8 spectrometer bar character styles (bitmap data)
**`color-palettes-data.js`** - 16+ C64 color palettes with RGB values
**`font-data.js`** - PETSCII font bitmaps (uppercase + lowercase, 256 chars x 8 bytes)

### Compression Library (`public/lib/`)

JavaScript port of TSCrunch 1.3.1:
- `index.js` - Main `Cruncher` class
- `tokens.js` - Compression token types (ZERORUN, RLE, LZ, LIT)
- `graph.js` - Dijkstra optimal path for encoding decisions
- `sfx.js` - Self-extracting format with 6502 boot loader

### Pre-built Players (`public/prg/`)

9 visualizer directories, each containing:
- `.bin` files at 3 load addresses ($4000, $8000, $C000)
- `.json` config (options, galleries, font availability)
- `.png` preview image
- Gallery JSON files referencing assets in `public/PNG/`

Built from KickAss assembly in `SIDPlayers/` via `0-build.bat`.

### C64 Assembly Players (`SIDPlayers/`)

KickAss assembly source for each visualizer type:
- Main file (e.g., `RaistlinBars.asm`)
- Shared includes in `INC/` (lowercase filenames): common.asm, spectrometer.asm, musicplayback.asm, keyboard.asm, stablerastersetup.asm, barstyles.asm
- Binary data: FreqTable.bin, SoundbarSine.bin, character sets
- Compiled by `0-build.bat` using KickAss.jar

## Data Flow

### Loading a SID file
```
User drops .sid file
  → ui.js reads ArrayBuffer
  → sidwinder-core.js allocates WASM heap, copies data
  → sid_load() parses header
  → sid_analyze() runs N frames of 6510 emulation
  → Results returned: addresses, SID writes, memory map
  → ui.js displays header info, enables export
```

### Exporting a PRG
```
User selects visualizer + options
  → prg-builder.js calculates memory layout
  → Loads player .bin from public/prg/
  → Patches SID data + metadata into player template
  → Optional: image conversion (PNG → C64 bitmap via WASM)
  → Optional: PETSCII conversion for text logos
  → Optional: TSCrunch compression (self-extracting)
  → Downloads .prg file
```

### HVSC browsing
```
User clicks Browse HVSC
  → hvsc-browser.js loads hvsc-index.json once (cached, gzipped)
  → Builds the directory tree in-memory → folder navigation is instant
  → User clicks .sid file → fetched directly from /HVSC/<path> → loaded as SID
  → Search filters the index over title/author/path/STIL client-side
```

## C64 Memory Map Context

```
$0000-$00FF  Zero page (CPU registers, pointers)
$0100-$01FF  Stack
$0400-$07FF  Screen RAM (default)
$0800-$0FFF  BASIC start area
$1000-$3FFF  Common SID music location
$4000-$7FFF  Player load address (default)
$8000-$BFFF  Player load address (alternate)
$C000-$CFFF  Player load address (high)
$D000-$D3FF  VIC-II registers
$D400-$D7FF  SID registers (voice 1-3, filter, volume)
$D800-$DBFF  Color RAM
$DC00-$DCFF  CIA 1
$DD00-$DDFF  CIA 2
```

The PRG builder must place music data and player code in non-overlapping regions, avoiding I/O space ($D000-$DFFF) and other reserved areas.
