/**
 * Optional global shim for projects that don't use ES module imports directly.
 *
 * Importing this module (statically or via dynamic import) attaches a
 * `TSCrunch` object to the global scope (window in browsers, globalThis in
 * Node) exposing the high-level API, mirroring the original SIDwinder usage:
 *
 *   <script type="module" src="path/to/tscrunch-js/src/global.js"></script>
 *   <script>
 *     const sfx = TSCrunch.compress(prgBytes, { jumpAddress: 0x1000 });
 *   </script>
 *
 * Or lazy-load it on first use:
 *
 *   window.loadTSCrunch = async () => {
 *     if (!window.TSCrunch) await import('./tscrunch-js/src/global.js');
 *   };
 */

import { compress, decompress, Cruncher, Decruncher, createSFX } from './index.js';

const TSCrunch = { compress, decompress, Cruncher, Decruncher, createSFX };

const globalScope = typeof window !== 'undefined' ? window
    : typeof globalThis !== 'undefined' ? globalThis
        : this;

if (globalScope) {
    globalScope.TSCrunch = TSCrunch;
    if (typeof globalScope.dispatchEvent === 'function' && typeof Event !== 'undefined') {
        globalScope.dispatchEvent(new Event('tscrunch-ready'));
    }
}

export default TSCrunch;
export { TSCrunch };
