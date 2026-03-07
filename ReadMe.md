# SIDwinder

*SIDwinder - C64 SID Music Visualizer & Player Builder*

<p align="center"><img src="SIDwinder.png" alt="SIDwinder Logo" width="1600"/></p>

Developed by Robert Troughton (Raistlin of Genesis Project)

## Overview

SIDwinder is a web-based tool for C64 SID music. It provides:

- **SID Playback**: Play SID files directly in the browser via 6510 CPU emulation in WebAssembly
- **Visualizers**: Multiple real-time visualizer styles for SID register activity
- **PRG Builder**: Convert SID files to executable C64 PRG files with player routines
- **HVSC Browser**: Browse and play tunes from the High Voltage SID Collection
- **PETSCII Support**: Convert text to C64 PETSCII character encoding

## Screenshots

<p align="center">
<img src="Screens/ScreensAnim.gif" alt="SIDwinder Visualizers in Action" width="800"/>
</p>

### Visualizer Types

<table>
<tr>
<td><img src="Screens/RaistlinBars.png" alt="RaistlinBars" width="400"/><br/><center>RaistlinBars</center></td>
<td><img src="Screens/RaistlinBarsWithDefaultLogo.png" alt="RaistlinBarsWithLogo (Default)" width="400"/><br/><center>RaistlinBarsWithLogo (Default Logo)</center></td>
</tr>
<tr>
<td><img src="Screens/RaistlinBarsWithLogo.png" alt="RaistlinBarsWithLogo (Custom)" width="400"/><br/><center>RaistlinBarsWithLogo (Custom Logo)</center></td>
<td><img src="Screens/RaistlinMirrorBars.png" alt="RaistlinMirrorBars" width="400"/><br/><center>RaistlinMirrorBars</center></td>
</tr>
<tr>
<td><img src="Screens/RaistlinMirrorBarsWithLogo.png" alt="RaistlinMirrorBarsWithLogo" width="400"/><br/><center>RaistlinMirrorBarsWithLogo</center></td>
<td><img src="Screens/SimpleRaster.png" alt="SimpleRaster" width="400"/><br/><center>SimpleRaster</center></td>
</tr>
<tr>
<td><img src="Screens/SimpleBitmap.png" alt="SimpleBitmap" width="400"/><br/><center>SimpleBitmap</center></td>
</tr>
</table>

## Architecture

```
public/          Web frontend (HTML/CSS/JS)
  ├── index.html          Main SID player/visualizer
  ├── hvsc.html           HVSC browser interface
  ├── sidwinder-core.js   Core SID processing logic
  ├── cpu6510.js          6510 CPU emulator (JS)
  ├── cpu6510.wasm        6510 CPU emulator (WASM)
  ├── sidwinder.wasm      SID processor (WASM)
  └── ...

wasm/            WASM C++ sources (compiled to .wasm)
  ├── cpu6510_wasm.cpp    6510 CPU emulator
  ├── sid_processor.cpp   SID file processing
  ├── png_converter.cpp   PNG image conversion
  └── opcodes.h           6502 opcode definitions

SIDPlayers/      C64 assembly player routines
netlify/         Serverless functions for deployment
```

## Development

### Prerequisites

- Node.js (for dev dependencies)
- Emscripten SDK (for rebuilding WASM modules)

### Local Development

```bash
npm install
# Serve the public/ directory with any static file server
npx serve public
```

### Rebuilding WASM Modules

```bash
cd wasm
# Requires Emscripten SDK (emcc)
./build.bat   # or equivalent emcc commands
```

## Future Plans

- **SID Relocation**: Moving SID tunes to different memory addresses (see [RELOCATION.md](RELOCATION.md) for design notes)

## Acknowledgements

- Zagon for Exomizer
- Mads Nielsen for KickAss assembler
- Adam Dunkels (Trident), Andy Zeidler (Shine), Burglar and Magnar Harestad for help
