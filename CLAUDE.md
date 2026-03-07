# CLAUDE.md - SIDwinder Project Guide

## What is SIDwinder?

A web-based C64 SID music tool. Users load SID files, analyze them, browse HVSC, and export executable C64 PRG files with visualizer effects. Built with vanilla JS + WASM (Emscripten-compiled C++).

## Project Structure

```
public/           Web frontend (vanilla JS, no framework)
wasm/             C++ sources compiled to WASM via Emscripten
SIDPlayers/       C64 assembly (KickAss) player/visualizer routines
netlify/          Serverless function for HVSC proxy
```

See ARCHITECTURE.md for detailed component documentation.

## Build

Run `build.bat` (Windows). It does two things:
1. Builds SID player .bin files from KickAss assembly (fast)
2. Optionally rebuilds WASM modules via Emscripten (slow, 15s auto-yes prompt)

### Prerequisites
- Java (for KickAss.jar assembler)
- Emscripten SDK (only if rebuilding WASM - set EMSDK_PATH in build.bat)
- Node.js (for dev dependencies only)

### Local dev server
```
0-runserver.bat          # or: python -m http.server 8000 -d public
npx serve public         # alternative
```

## Key Technical Concepts

### WASM Modules
Two compiled WASM modules in `public/`:
- **sidwinder.wasm** - SID file processing + PNG converter (from `wasm/sid_processor.cpp` + `wasm/png_converter.cpp` + `wasm/cpu6510_wasm.cpp`)
- **cpu6510.wasm** - Standalone 6510 CPU emulator (from `wasm/cpu6510_wasm.cpp`)

JS talks to WASM via `cwrap()` bindings in `sidwinder-core.js`.

### PRG Export Pipeline
SID file → WASM analysis → memory layout planning → player .bin overlay → optional compression (TSCrunch) → downloadable .prg

### SIDPlayers Assembly
KickAss assembly files in `SIDPlayers/`. Pre-compiled to `.bin` at three load addresses ($4000, $8000, $C000) and stored in `public/prg/`. Each player has a JSON config defining its options, galleries, and capabilities.

### HVSC Integration
`netlify/functions/hvsc.js` proxies requests to hvsc.etv.cx. The browser-side `hvsc-browser.js` parses directory HTML responses to navigate the collection.

## Code Conventions

- Vanilla JavaScript with ES6 classes (no build step, no bundler, no framework)
- WASM C++ uses `extern "C"` with `EMSCRIPTEN_KEEPALIVE` exports
- C64 addresses written as hex with $ prefix in comments/docs (e.g., $D400)
- File naming: kebab-case for JS files, PascalCase for SIDPlayers directories

## Common Tasks

### Adding a new visualizer
1. Create assembly in `SIDPlayers/NewName/`
2. Add KickAss build lines to `build.bat` for each load address
3. Add entry to `public/visualizer-registry.js`
4. Create config JSON + preview PNG in `public/prg/NewName/`

### Modifying WASM emulation
1. Edit C++ in `wasm/` (cpu6510_wasm.cpp, sid_processor.cpp, or png_converter.cpp)
2. Run `build.bat` and answer Y to WASM rebuild
3. New .wasm + .js files land in `public/`

### Modifying the web UI
Edit files directly in `public/`. No build step needed - just refresh the browser.

## Testing
- `public/tests/` contains test files
- No automated test runner currently; testing is manual via browser

## Deployment
Deployed via Netlify. The `public/` directory is the publish directory. Netlify functions are in `netlify/functions/`.
