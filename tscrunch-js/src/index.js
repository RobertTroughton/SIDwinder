/**
 * TSCrunch (JavaScript) - C64 binary cruncher / self-extracting executable generator
 *
 * JavaScript port by Claude. Original by Antonio Savona (https://github.com/tonysavon/TSCrunch).
 *
 * This is the public entry point. Import the high-level `compress()` helper for
 * the common case (crunch a PRG into a self-extracting .prg), or import the
 * lower-level building blocks (Cruncher, Decruncher, createSFX, token classes)
 * for custom pipelines.
 *
 * Usage (ES module, browser or Node):
 *
 *   import { compress } from 'tscrunch-js';
 *   const sfx = compress(prgBytes, { sfx: true, jumpAddress: 0x1000 });
 *   // sfx is a Uint8Array ready to write out as a .prg
 */

import { Cruncher } from './cruncher.js';
import {
    Decruncher, createSFX,
    boot, blankBoot, boot2
} from './sfx.js';
import {
    Token, ZERORUN, RLE, LZ, LZ2, LIT,
    findall, findOptimalZero,
    LONGESTRLE, LONGESTLONGLZ, LONGESTLZ, LONGESTLITERAL,
    MINRLE, MINLZ, TERMINATOR
} from './tokens.js';

/**
 * Normalize input to a plain Array<number> of bytes.
 * Accepts Uint8Array, Array, or ArrayBuffer.
 */
function toByteArray(data) {
    if (data instanceof Uint8Array) return Array.from(data);
    if (data instanceof ArrayBuffer) return Array.from(new Uint8Array(data));
    if (Array.isArray(data)) return data;
    throw new TypeError('compress() expects a Uint8Array, ArrayBuffer, or Array of bytes');
}

/**
 * High-level one-shot compression.
 *
 * @param {Uint8Array|ArrayBuffer|number[]} data - Input bytes. When `prg` is
 *   true (default) the first two bytes are treated as the C64 load address.
 * @param {Object} [options]
 * @param {boolean} [options.prg=true]   - Input is in PRG format (2-byte load address header).
 * @param {boolean} [options.sfx=true]   - Wrap the crunched data in a self-extracting C64 executable.
 * @param {number}  [options.sfxMode=0]  - SFX boot loader variant (0 = standard, 1 = stack-based).
 * @param {number}  [options.jumpAddress=0x1000] - Address to JMP to after decompression (SFX only).
 * @param {boolean} [options.blank=false] - Use the blank-screen boot loader (SFX mode 0 only).
 * @param {boolean} [options.inplace=false] - Use in-place compression.
 * @param {Function} [options.progressCallback] - (description, current, total) progress reporter.
 * @returns {Uint8Array} The crunched data, or a self-extracting .prg when `sfx` is true.
 */
function compress(data, options = {}) {
    const {
        prg = true,
        sfx = true,
        sfxMode = 0,
        jumpAddress = 0x1000,
        blank = false,
        inplace = false,
        progressCallback
    } = options;

    const dataArray = toByteArray(data);

    let sourceData = dataArray;
    let loadAddress = 0x0801;

    if (prg && dataArray.length >= 2) {
        loadAddress = dataArray[0] | (dataArray[1] << 8);
        sourceData = dataArray.slice(2);
    }

    const cruncher = new Cruncher(sourceData);
    cruncher.ocrunch({ inplace, verbose: false, sfxMode: sfx, progressCallback });

    let crunched = cruncher.crunched;

    if (sfx) {
        crunched = Array.from(createSFX(Uint8Array.from(crunched), {
            jumpAddress,
            decrunchAddress: loadAddress,
            optimalRun: cruncher.optimalRun,
            sfxMode,
            blank
        }));
    }

    return Uint8Array.from(crunched);
}

/**
 * Decompress a crunched stream (the inverse of a non-SFX `compress`).
 * Expects the raw crunched bytes (optimal-run byte first), NOT an SFX wrapper.
 *
 * @param {Uint8Array|ArrayBuffer|number[]} data
 * @returns {Uint8Array}
 */
function decompress(data) {
    const dec = new Decruncher(toByteArray(data));
    return Uint8Array.from(dec.decrunched);
}

export {
    // High-level API
    compress,
    decompress,

    // Core classes
    Cruncher,
    Decruncher,

    // SFX helpers + boot loaders
    createSFX,
    boot,
    blankBoot,
    boot2,

    // Token classes (advanced)
    Token,
    ZERORUN,
    RLE,
    LZ,
    LZ2,
    LIT,
    findall,
    findOptimalZero,

    // Constants
    LONGESTRLE,
    LONGESTLONGLZ,
    LONGESTLZ,
    LONGESTLITERAL,
    MINRLE,
    MINLZ,
    TERMINATOR
};

export default { compress, decompress, Cruncher, Decruncher, createSFX };
