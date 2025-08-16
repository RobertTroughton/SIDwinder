/**
 * TSCrunch 1.3.1 - binary cruncher library
 * JavaScript port by Claude
 * Original by Antonio Savona
 */

import {
    Token, ZERORUN, RLE, LZ, LZ2, LIT,
    findOptimalZero,
    LONGESTRLE, LONGESTLONGLZ, LONGESTLZ, LONGESTLITERAL,
    MINRLE, MINLZ, LZ2SIZE, TERMINATOR
} from './tokens.js';
import { dijkstra, getPath, buildDijkstraGraph } from './graph.js';
import { Decruncher, createSFX, boot, blankBoot, boot2 } from './sfx.js';

// Browser polyfills
const Buffer = {
    from: function (data) {
        if (data instanceof Uint8Array) return data;
        if (Array.isArray(data)) return new Uint8Array(data);
        return new Uint8Array(0);
    }
};

// File operations not available in browser
function loadRaw(filename) {
    throw new Error('File operations not available in browser');
}

function saveRaw(filename, data) {
    throw new Error('File operations not available in browser');
}

/**
 * Main compression class
 */
class Cruncher {
    constructor(src = null) {
        this.crunched = [];
        this.tokenList = [];
        this.src = src;
        this.graph = {};
        this.crunchedSize = 0;
        this.optimalRun = LONGESTRLE;
    }
    
    /**
     * Compress the source data
     * @param {Object} options - Compression options
     * @param {boolean} options.inplace - Use inplace compression
     * @param {boolean} options.verbose - Show progress output
     * @param {boolean} options.sfxMode - True if creating SFX (omits optimal run from output)
     * @param {Function} options.progressCallback - Callback for progress updates (description, current, total)
     */
    ocrunch(options = {}) {
        const { inplace = false, verbose = false, sfxMode = false, progressCallback } = options;
        
        const progress = (description, current, total) => {
            if (progressCallback) {
                progressCallback(description, current, total);
            } else if (verbose) {
                const percentage = Math.floor(100 * current / total);
                const tchars = Math.floor(16 * current / total);
                const bar = '*'.repeat(tchars) + ' '.repeat(16 - tchars);
                process.stdout.write(`\r${description} [${bar}]${percentage.toString().padStart(2, '0')}%`);
            }
        };
        
        let src;
        let remainder = [];
        
        if (inplace) {
            remainder = Array.from(this.src.slice(-1));
            src = this.src.slice(0, -1);
        } else {
            src = this.src;
        }
        
        this.optimalRun = findOptimalZero(src);
        
        if (verbose || progressCallback) {
            progress("Populating LZ layer", 0, 1);
        }
        
        // Build compression token graph
        const tokenGraph = {};
        
        for (let i = 0; i < src.length; i++) {
            const rle = new RLE(src, i);
            let rlesize = Math.min(rle.size, LONGESTRLE);
            
            let lz;
            if (rlesize < LONGESTLONGLZ - 1) {
                lz = new LZ(src, i, null, null, Math.max(rlesize + 1, MINLZ));
            } else {
                lz = new LZ(src, i, 1);
            }
            
            // Add LZ tokens
            while (lz.size >= MINLZ && lz.size > rlesize) {
                const key = `${i},${i + lz.size}`;
                if (!tokenGraph[key] || tokenGraph[key].getCost() > lz.getCost()) {
                    tokenGraph[key] = lz;
                }
                lz = new LZ(src, i, lz.size - 1, lz.offset);
            }
            
            // Add RLE tokens
            if (rle.size > LONGESTRLE) {
                const rleToken = new RLE(src, i, LONGESTRLE);
                const key = `${i},${i + LONGESTRLE}`;
                if (!tokenGraph[key] || tokenGraph[key].getCost() > rleToken.getCost()) {
                    tokenGraph[key] = rleToken;
                }
            } else {
                for (let size = rle.size; size >= MINRLE; size--) {
                    const rleToken = new RLE(src, i, size);
                    const key = `${i},${i + size}`;
                    if (!tokenGraph[key] || tokenGraph[key].getCost() > rleToken.getCost()) {
                        tokenGraph[key] = rleToken;
                    }
                }
            }
            
            // Add LZ2 token
            const lz2 = new LZ2(src, i);
            if (lz2.offset > 0) {
                const key = `${i},${i + LZ2SIZE}`;
                if (!tokenGraph[key] || tokenGraph[key].getCost() > lz2.getCost()) {
                    tokenGraph[key] = lz2;
                }
            }
            
            // Add zero run token
            const zero = new ZERORUN(src, i, this.optimalRun);
            if (zero.size > 0) {
                const key = `${i},${i + this.optimalRun}`;
                if (!tokenGraph[key] || tokenGraph[key].getCost() > zero.getCost()) {
                    tokenGraph[key] = zero;
                }
            }
        }
        
        if (verbose || progressCallback) {
            progress("Populating LZ layer", 1, 1);
            if (verbose) process.stdout.write('\n');
        }
        
        // Fill gaps with literals
        if (verbose || progressCallback) {
            progress("Closing gaps", 0, 1);
        }
        
        for (let i = 0; i < src.length; i++) {
            for (let j = 1; j <= Math.min(LONGESTLITERAL, src.length - i); j++) {
                const key = `${i},${i + j}`;
                if (!tokenGraph[key]) {
                    const lit = new LIT(src, i);
                    lit.size = j;
                    tokenGraph[key] = lit;
                }
            }
        }
        
        if (verbose || progressCallback) {
            progress("Closing gaps", 1, 1);
            if (verbose) process.stdout.write('\n');
        }
        
        // Build Dijkstra graph
        if (verbose || progressCallback) {
            progress("Populating graph", 0, 3);
        }
        
        const dijkstraGraph = buildDijkstraGraph(tokenGraph);
        
        if (verbose || progressCallback) {
            progress("Populating graph", 3, 3);
            if (verbose) process.stdout.write('\ncomputing shortest path\n');
        }
        
        // Find shortest path
        const {distances, predecessors} = dijkstra(dijkstraGraph, 0);
        const path = getPath(predecessors, src.length);
        
        // Build token list from path
        for (const [start, end] of path) {
            const key = `${start},${end}`;
            if (tokenGraph[key]) {
                this.tokenList.push(tokenGraph[key]);
            }
        }
        
        // Build final compressed data
        if (inplace) {
            // Handle inplace compression logic
            for (const token of this.tokenList) {
                this.crunched = this.crunched.concat(token.getPayload());
            }
            this.crunched = this.crunched.concat([TERMINATOR]).concat(remainder.slice(1));
            // Add address and optimal run
            const addr = [0, 0]; // Placeholder
            this.crunched = addr.concat([this.optimalRun - 1]).concat(remainder.slice(0, 1)).concat(this.crunched);
        } else {
            // Standard compression
            if (!sfxMode) {
                // Include optimal run for non-SFX mode (Python: "if not SFX")
                this.crunched = this.crunched.concat([this.optimalRun - 1]);
            }
            for (const token of this.tokenList) {
                this.crunched = this.crunched.concat(token.getPayload());
            }
            this.crunched.push(TERMINATOR);
        }
        
        this.crunchedSize = this.crunched.length;
    }
}

// Export public API
export {
    // Core classes
    Cruncher,
    Decruncher,
    
    // Token classes (for advanced usage)
    Token,
    ZERORUN,
    RLE,
    LZ,
    LZ2,
    LIT,
    
    // Utility functions
    loadRaw,
    saveRaw,
    createSFX,
    
    // Boot loaders (for custom SFX creation)
    boot,
    blankBoot,
    boot2,
    
    // Constants
        LONGESTRLE,
        LONGESTLONGLZ,
        LONGESTLZ,
        LONGESTLITERAL,
        MINRLE,
        MINLZ,
        TERMINATOR
};