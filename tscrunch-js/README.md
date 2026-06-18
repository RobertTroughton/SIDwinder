# tscrunch-js

A self-contained JavaScript port of **TSCrunch**, the C64 binary cruncher and
self-extracting (SFX) executable generator. Zero dependencies, no build step —
it's a set of plain ES modules that run directly in the browser or in Node.

This is the compression engine extracted from
[SIDwinder](https://github.com/RobertTroughton/SIDwinder), packaged for reuse in
other web projects.

- **Original C64 cruncher:** Antonio Savona — <https://github.com/tonysavon/TSCrunch>
- **JavaScript port:** Claude

## What it does

Given a Commodore 64 program in PRG format (a load address followed by data),
TSCrunch produces either:

1. a **crunched stream** (just the compressed bytes), or
2. a **self-extracting `.prg`** — a runnable C64 executable that decompresses
   itself in memory and jumps to your entry point.

It implements LZ, short-LZ (LZ2), RLE, and zero-run tokens, and uses Dijkstra's
shortest-path algorithm over a token graph to pick the optimal encoding.

## Install / drop in

There's no npm publish required — copy the `tscrunch-js/` folder into your
project and import from `src/index.js`. (It's also a valid npm package if you
prefer `npm install` from a git URL or a local path.)

```
your-project/
  vendor/tscrunch-js/
    src/
      index.js      <- main entry
      cruncher.js
      sfx.js
      tokens.js
      graph.js
      global.js     <- optional window.TSCrunch shim
```

## Usage

### ES modules (recommended)

```js
import { compress } from './vendor/tscrunch-js/src/index.js';

// `prg` is a Uint8Array whose first two bytes are the C64 load address.
const sfx = compress(prg, {
    sfx: true,          // wrap in a self-extracting executable (default)
    jumpAddress: 0x1000 // where to JMP after decompression
});

// sfx is a Uint8Array ready to be written out as a .prg file
const blob = new Blob([sfx], { type: 'application/octet-stream' });
```

### Just the crunched bytes (no SFX wrapper)

```js
import { compress, decompress } from './vendor/tscrunch-js/src/index.js';

const crunched = compress(prg, { sfx: false });
const original = decompress(crunched); // inverse of a non-SFX compress
```

### Global / non-module projects

If you can't use `import` directly, load the global shim once and use
`window.TSCrunch`:

```html
<script type="module" src="./vendor/tscrunch-js/src/global.js"></script>
<script>
  window.addEventListener('tscrunch-ready', () => {
    const sfx = TSCrunch.compress(prg, { jumpAddress: 0x1000 });
  });
</script>
```

Or lazy-load it on first use (mirrors how SIDwinder did it):

```js
window.loadTSCrunch = async () => {
    if (!window.TSCrunch) await import('./vendor/tscrunch-js/src/global.js');
};
```

## `compress(data, options)` options

| Option             | Default  | Description                                                        |
| ------------------ | -------- | ------------------------------------------------------------------ |
| `prg`              | `true`   | Input has a 2-byte load-address header (PRG format).               |
| `sfx`              | `true`   | Wrap output in a self-extracting C64 executable.                   |
| `sfxMode`          | `0`      | Boot loader variant: `0` = standard, `1` = stack-based.            |
| `jumpAddress`      | `0x1000` | Address to `JMP` to after decompression (SFX only).                |
| `blank`            | `false`  | Use the blank-screen boot loader (SFX mode 0 only).                |
| `inplace`          | `false`  | Use in-place compression.                                          |
| `progressCallback` | —        | `(description, current, total)` callback for progress reporting.   |

Returns a `Uint8Array`.

## Lower-level API

`index.js` also re-exports the building blocks if you need a custom pipeline:

- `Cruncher` — the core compressor (`new Cruncher(srcBytes).ocrunch(opts)`)
- `Decruncher` — the decompressor
- `createSFX(crunched, { jumpAddress, decrunchAddress, optimalRun, sfxMode, blank })`
- `boot`, `blankBoot`, `boot2` — raw boot loader byte arrays
- Token classes: `Token`, `ZERORUN`, `RLE`, `LZ`, `LZ2`, `LIT`
- Helpers/constants: `findall`, `findOptimalZero`, `LONGESTRLE`, `MINLZ`, `TERMINATOR`, …

## Module layout

| File          | Responsibility                                                |
| ------------- | ------------------------------------------------------------- |
| `index.js`    | Public entry: high-level `compress`/`decompress` + re-exports |
| `cruncher.js` | `Cruncher` — token-graph build + optimal-path crunch          |
| `sfx.js`      | `Decruncher`, `createSFX`, and the C64 boot loaders           |
| `tokens.js`   | Token classes (LZ, LZ2, RLE, zero-run, literal) + constants   |
| `graph.js`    | Priority queue + Dijkstra shortest path                       |
| `global.js`   | Optional `window.TSCrunch` global shim                        |

## License

MIT. Please retain attribution to Antonio Savona for the original TSCrunch.
