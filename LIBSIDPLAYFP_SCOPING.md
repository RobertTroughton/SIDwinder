# Scoping: move HVSC playback to libsidplayfp (reSIDfp + a real C64)

Status: **planning** (no code changed yet). This documents the plan agreed in
the "option 3 (c)" discussion: replace the lightweight playback engine with
**libsidplayfp**, using **real C64 ROMs**, so RSID/digi/raster-timed tunes play
correctly and the SID filter is more accurate.

## 1. What this fixes / why

Our current playback (`wasm/sid_audio.cpp`) is a lightweight 6510 CPU that calls
init once and `JSR play` once per frame, driving **reSID**. That's fine for most
tunes, but it can't run tunes that need a *real* machine:

- **Digi / sample players** driven from a main loop or NMI (e.g. Steel's
  "50 Cent – In Da Club" cover) → currently corrupt.
- **Raster-timed** code that reads `$D011/$D012`.
- **Multiple IRQs per frame**, NMI+IRQ splits, ROM routines.
- The **6581 filter** is only linearly modelled by reSID (dull/off on some tunes).

**libsidplayfp** bundles **reSIDfp** (nonlinear 6581 filter, better combined
waveforms, shift-register envelope, high-quality resampling) *and* a full C64
environment (cycle-accurate CPU, CIA, VIC/raster, IRQ/NMI, real ROMs). It's what
sidplayfp / DeepSID-class players use, and it's the definitive fix.

> Note: the earlier "Kernal-region loader corruption" fix (Magnar
> "We Are New (tune 4)") is a *separate* bug already fixed in `sid_audio.cpp`.
> This work targets the class libsidplayfp is actually needed for.

## 2. Scope boundaries (what does NOT change)

- **Export / analysis** stays on `wasm/sid_processor.cpp` + `cpu6510_wasm.cpp`.
  libsidplayfp is for *playback* only. The SIDquake tool still can't export RSID,
  so the browser's RSID marking/blocking (`isUnsupported`, tool-mode only) is
  unchanged and still correct.
- **The visualizer** taps the Web Audio graph (AnalyserNode), not the engine
  internals, so it keeps working with zero changes.
- **The HVSC mirror, index, embed, token gate, SEO** are all unaffected.

## 3. Architecture

Build libsidplayfp into a **separate** WASM module (`public/sidplayfp.wasm` +
`.js`) rather than folding it into `sidwinder.wasm`. Benefits: isolates the big
GPL engine, keeps analysis/PNG/export builds fast, and lets us **A/B against the
current engine behind a flag** during rollout.

A thin C wrapper (`wasm/sidplayfp_audio.cpp`) exposes the *same* function names
the JS already calls, so `sid-playback.js` barely changes:

```
audio_init(sampleRate)                 -> also receives ROM pointers (see below)
audio_load_sid(dataPtr, len)
audio_set_subtune(n)
audio_generate(bufPtr, numSamples)     -> pulls PCM from sidplayfp
audio_set_model(6581|8580)             -> forceC64Model / default model
audio_set_sampling_method(0|1|2)       -> map to residfp fast/interpolate/resample
audio_get_* (title/author/subtunes/model/ntsc/playtime...)  from SidTuneInfo
```

Internally the wrapper: creates `sidplayfp`, a `ReSIDfpBuilder`, loads the tune
via `SidTune`, calls `setRoms(kernal, basic, chargen)`, configures model/clock,
and `play()`s into a buffer for `audio_generate`.

## 4. ROMs — the one thing to decide

Clarification on your question: **6581 vs 8580 is the SID *chip*, not a ROM.**
It's read per-tune from the PSID header flags (bits 4–5) and set on the SID
emulation at load time — the *system* ROMs (KERNAL / BASIC / CHARGEN) are the
same regardless of chip. So we need **one ROM set**, not two.

Which ROMs libsidplayfp needs:
- **KERNAL (8 KB) — required** for RSID and most real-environment tunes.
- **BASIC (8 KB)** — needed for tunes launched from BASIC (`SYS ...`).
- **CHARGEN (4 KB)** — rarely used by music; include for completeness (tiny).

Total ~20 KB — embed directly in the WASM (or ship alongside and pass pointers).

Sources:
- **VICE / zimmers.net** — the real Commodore ROMs the community has used for
  decades (Commodore gave blanket permission for emulators; Cloanto now holds
  the rights). Max compatibility. Consistent with our HVSC-hosting stance.
- **MEGA65 open-source KERNAL/BASIC replacements** — cleanest licensing, but a
  few exotic ROM-dependent tunes may differ.

You chose the real ROMs → recommend the **VICE KERNAL + BASIC (+ CHARGEN)** set.
`hvsc-data/`-style: keep them in a `roms/` dir, embed at build. (These are *not*
under SIDquake's own license — document their origin.)

## 5. Build integration

Today `0-build.bat` produces `sidwinder.wasm` from one `emcc` command. Add a
second `emcc` command for the player:

```
emcc wasm/sidplayfp_audio.cpp <libsidplayfp sources...> <residfp sources...> \
     -I libsidplayfp -O3 -s WASM=1 -s MODULARIZE=1 -s EXPORT_NAME="SIDPlayfpModule" \
     -s EXPORTED_FUNCTIONS="[_audio_init,_audio_load_sid,...]" \
     -s ALLOW_MEMORY_GROWTH=1 --embed-file roms/... \
     -o public/sidplayfp.js
```

Effort here is real: libsidplayfp uses autotools; for emcc we compile its
sources directly and supply a hand-written `config.h` (disable file I/O, HardSID,
external drivers; keep CPU + CIA + VIC + residfp). **Step 1 is a build spike** to
enumerate the source list and get it compiling under emcc.

WASM size: bigger than reSID (full CPU/CIA/VIC + residfp tables), likely a few
hundred KB gzipped — acceptable, loaded lazily only when previewing.

## 6. Licensing

- **libsidplayfp and reSIDfp are GPLv2+.** You already ship **reSID (also GPL)**
  inside `sidwinder.wasm`, so this is the same obligation you already meet:
  publish corresponding source (already public on GitHub) and preserve notices.
- **C64 ROMs** are Commodore/Cloanto copyright — redistributed by convention in
  emulators; document their origin. (Or use the MEGA65 open replacements.)

## 7. Risks & unknowns

| Risk | Mitigation |
|------|------------|
| emcc build of libsidplayfp is fiddly | Timeboxed spike first; fall back to evaluating an existing WASM SID engine if it stalls |
| Realtime performance in WASM | residfp runs in browsers already; use INTERPOLATE by default, RESAMPLE opt-in |
| WASM size | separate lazy-loaded module; gzip; embed only needed ROMs |
| API differences vs current | thin wrapper keeps `audio_*` names → minimal JS change |
| Two engines drifting | keep old engine only during A/B, then remove |

## 8. Rollout plan

1. **Spike:** compile libsidplayfp+residfp under emcc; play one tune to PCM
   natively/in a test page. (Go/no-go.)
2. **Wrapper:** `sidplayfp_audio.cpp` exposing the `audio_*` API; embed ROMs.
3. **Build:** second `emcc` step in `0-build.bat` → `public/sidplayfp.js/.wasm`.
4. **JS:** `sid-playback.js` loads the new module behind a flag
   (`?engine=fp` / a setting), same graph → visualizer unaffected.
5. **Validate** against a test set:
   - Steel – 50 Cent in da club (digi) — the motivating case
   - Magnar – We Are New (tune 4) (regression; already fixed in old engine)
   - a 2SID and a 3SID tune (multi-SID)
   - an RSID tune (real environment)
   - an NTSC tune; a filter-heavy 6581 tune (reSIDfp accuracy)
6. **Default swap** to libsidplayfp once the set passes; keep old engine one
   release as fallback, then remove `sid_audio.cpp` from the build.

## 9. Rough effort

- Spike (build compiles + plays a tune): **~1–2 days**, highest uncertainty.
- Wrapper + build wiring + JS + ROMs: **~2–3 days**.
- Validation + polish: **~1–2 days**.
Sequential, gated on the spike.

## 10. Open decisions

- **ROM set:** real VICE KERNAL+BASIC(+CHARGEN) *(recommended)* vs MEGA65 open
  replacements?
- **Rollout:** ship behind an A/B flag first *(recommended)*, or straight swap?
- **Where I build it:** I can author the wrapper, `config.h`, source list, build
  step, and JS integration here, but I **can't run emcc or hear audio in this
  environment** — the spike + audio validation must run on your machine (or a
  CI job with emsdk). Do you want me to produce the wrapper + build files for you
  to compile, or wait until you can give me an emsdk-capable environment?

---

Sources: [libsidplayfp API](https://libsidplayfp.github.io/libsidplayfp/html/classsidplayfp.html),
[demo.cpp](https://libsidplayfp.github.io/libsidplayfp/html/demo_8cpp-example.html),
[reSIDfp 6581 filter](https://sidplay-residfp.sourceforge.io/docs/classreSIDfp_1_1Filter6581.html),
[C64 ROMs (zimmers)](https://www.zimmers.net/anonftp/pub/cbm/firmware/computers/c64/),
[MEGA65 open ROMs](https://c65gs.blogspot.com/2019/05/free-and-open-source-replacement-roms.html).
