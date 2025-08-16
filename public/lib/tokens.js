/**
 * TSCrunch Token Classes
 * JavaScript port by Claude
 * Original by Antonio Savona
 */

// Token Constants
const LONGESTRLE = 64;
const LONGESTLONGLZ = 64;
const LONGESTLZ = 32;
const LONGESTLITERAL = 31;
const MINRLE = 2;
const MINLZ = 3;
const LZOFFSET = 256;
const LONGLZOFFSET = 32767;
const LZ2OFFSET = 94;
const LZ2SIZE = 2;

// Bitmasks
const RLEMASK = 0x81;
const LZMASK = 0x80;
const LITERALMASK = 0x00;
const LZ2MASK = 0x00;

const TERMINATOR = LONGESTLITERAL + 1;

// Token IDs
const ZERORUNID = 4;
const LZ2ID = 3;
const LZID = 2;
const RLEID = 1;
const LITERALID = 0;

// Base token class
class Token {
    constructor() {
        this.type = null;
    }
}

// Zero run token (special RLE for zeros)
class ZERORUN extends Token {
    constructor(src, i, size = LONGESTRLE) {
        super();
        this.type = ZERORUNID;
        this.size = size;
        
        if (!(i + size < src.length && src.slice(i, i + size).every(b => b === 0))) {
            this.size = 0;
        }
    }
    
    getCost() {
        return 1;
    }
    
    getPayload() {
        return [RLEMASK];
    }
}

// Run-length encoding token
class RLE extends Token {
    constructor(src, i, size = null) {
        super();
        this.type = RLEID;
        this.rleByte = src[i];
        
        if (size === null) {
            let x = 0;
            while (i + x < src.length && x < LONGESTRLE + 1 && src[i + x] === src[i]) {
                x++;
            }
            this.size = x;
        } else {
            this.size = size;
        }
    }
    
    getCost() {
        return 2 + 0.00128 - 0.00001 * this.size;
    }
    
    getPayload() {
        return [RLEMASK | (((this.size - 1) << 1) & 0x7f), this.rleByte];
    }
}

// LZ compression token
class LZ extends Token {
    constructor(src, i, size = null, offset = null, minlz = MINLZ) {
        super();
        this.type = LZID;
        
        if (size === null) {
            let bestpos = i - 1;
            let bestlen = 0;
            
            if (src.length - i >= minlz) {
                const prefix = src.slice(i, i + minlz);
                const positions = findall(src, prefix, i, minlz);
                
                for (const j of positions) {
                    let l = minlz;
                    while (i + l < src.length && l < LONGESTLONGLZ && src[j + l] === src[i + l]) {
                        l++;
                    }
                    if ((l > bestlen && (i - j < LZOFFSET || i - bestpos >= LZOFFSET || l > LONGESTLZ)) || (l > bestlen + 1)) {
                        bestpos = j;
                        bestlen = l;
                    }
                }
            }
            
            this.size = bestlen;
            this.offset = i - bestpos;
        } else {
            this.size = size;
            if (offset !== null) {
                this.offset = offset;
            }
        }
    }
    
    getCost() {
        if (this.offset < LZOFFSET && this.size <= LONGESTLZ) {
            return 2 + 0.00134 - 0.00001 * this.size;
        } else {
            return 3 + 0.00138 - 0.00001 * this.size;
        }
    }
    
    getPayload() {
        if (this.offset >= LZOFFSET || this.size > LONGESTLZ) {
            const negoffset = (0 - this.offset);
            return [
                LZMASK | ((((this.size - 1) >> 1) << 2) & 0x7f) | 0,
                (negoffset & 0xff),
                ((negoffset >> 8) & 0x7f) | (((this.size - 1) & 1) << 7)
            ];
        } else {
            return [
                LZMASK | (((this.size - 1) << 2) & 0x7f) | 2,
                (this.offset & 0xff)
            ];
        }
    }
}

// Short LZ compression token (2 bytes)
class LZ2 extends Token {
    constructor(src, i, offset = null) {
        super();
        this.type = LZ2ID;
        this.size = 2;
        
        if (offset === null) {
            if (i + 2 < src.length) {
                const pattern = src.slice(i, i + LZ2SIZE);
                const searchStart = Math.max(0, i - LZ2OFFSET);
                const searchEnd = i + 1;
                
                let o = -1;
                for (let pos = searchEnd - LZ2SIZE; pos >= searchStart; pos--) {
                    let match = true;
                    for (let j = 0; j < LZ2SIZE; j++) {
                        if (src[pos + j] !== pattern[j]) {
                            match = false;
                            break;
                        }
                    }
                    if (match) {
                        o = pos;
                        break;
                    }
                }
                
                this.offset = o >= 0 ? i - o : -1;
            } else {
                this.offset = -1;
            }
        } else {
            this.offset = offset;
        }
    }
    
    getCost() {
        return 1 + 0.00132 - 0.00001 * this.size;
    }
    
    getPayload() {
        return [LZ2MASK | (127 - this.offset)];
    }
}

// Literal token (uncompressed bytes)
class LIT extends Token {
    constructor(src, i) {
        super();
        this.type = LITERALID;
        this.size = 1;
        this.start = i;
        this.src = src;
    }
    
    getCost() {
        return this.size + 1 + 0.00130 - 0.00001 * this.size;
    }
    
    getPayload() {
        return [LITERALMASK | this.size].concat(Array.from(this.src.slice(this.start, this.start + this.size)));
    }
}

// Helper function to find pattern matches
function findall(data, prefix, i, minlz = MINLZ) {
    const results = [];
    const x0 = Math.max(0, i - LONGLZOFFSET);
    let x1 = Math.min(i + minlz - 1, data.length);
    
    while (true) {
        let f = -1;
        // Search backwards from x1 to x0 for the pattern
        for (let pos = x1 - prefix.length; pos >= x0; pos--) {
            let match = true;
            for (let j = 0; j < prefix.length; j++) {
                if (pos + j >= data.length || data[pos + j] !== prefix[j]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                f = pos;
                break;
            }
        }
        
        if (f >= 0) {
            results.push(f);
            x1 = f + minlz - 1;
        } else {
            break;
        }
    }
    
    return results;
}

// Helper function to find optimal zero run length
function findOptimalZero(src) {
    const zeroruns = {};
    let i = 0;
    
    while (i < src.length - 1) {
        if (src[i] === 0) {
            let j = i + 1;
            while (j < src.length && src[j] === 0 && j - i < 256) {
                j++;
            }
            if (j - i >= MINRLE) {
                const len = j - i;
                zeroruns[len] = (zeroruns[len] || 0) + 1;
            }
            i = j;
        } else {
            i++;
        }
    }
    
    if (Object.keys(zeroruns).length > 0) {
        const items = Object.entries(zeroruns).map(([k, v]) => [parseInt(k), v]);
        return items.reduce((best, [k, v]) => {
            const score = -k * Math.pow(v, 1.1);
            return score < best.score ? {len: k, score} : best;
        }, {len: LONGESTRLE, score: 0}).len;
    } else {
        return LONGESTRLE;
    }
}

export {
    // Token classes
    Token,
    ZERORUN,
    RLE,
    LZ,
    LZ2,
    LIT,
    
    // Helper functions
    findall,
    findOptimalZero,
    
    // Constants
    LONGESTRLE,
    LONGESTLONGLZ,
    LONGESTLZ,
    LONGESTLITERAL,
    MINRLE,
    MINLZ,
    LZOFFSET,
    LONGLZOFFSET,
    LZ2OFFSET,
    LZ2SIZE,
    RLEMASK,
    LZMASK,
    LITERALMASK,
    LZ2MASK,
    TERMINATOR,
    ZERORUNID,
    LZ2ID,
    LZID,
    RLEID,
    LITERALID
};