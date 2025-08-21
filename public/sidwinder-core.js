// sidwinder-core.js - Core SID analysis functionality using WASM

class SIDAnalyzer {
    constructor() {
        this.wasmModule = null;
        this.wasmReady = false;
        this.api = null;
        this.Module = null;
        this.initPromise = this.initWASM();

        // PETSCII to Unicode mapping for European characters
        this.PETSCII_TO_UNICODE = {
            // Latin-1 Supplement characters that appear in SID files
            0x80: 0x00C7, // Ç
            0x81: 0x00FC, // ü
            0x82: 0x00E9, // é
            0x83: 0x00E2, // â
            0x84: 0x00E4, // ä
            0x85: 0x00E0, // à
            0x86: 0x00E5, // å
            0x87: 0x00E7, // ç
            0x88: 0x00EA, // ê
            0x89: 0x00EB, // ë
            0x8A: 0x00E8, // è
            0x8B: 0x00EF, // ï
            0x8C: 0x00EE, // î
            0x8D: 0x00EC, // ì
            0x8E: 0x00C4, // Ä
            0x8F: 0x00C5, // Å
            0x90: 0x00C9, // É
            0x91: 0x00E6, // æ
            0x92: 0x00C6, // Æ
            0x93: 0x00F4, // ô
            0x94: 0x00F6, // ö
            0x95: 0x00F2, // ò
            0x96: 0x00FB, // û
            0x97: 0x00F9, // ù
            0x98: 0x00FF, // ÿ
            0x99: 0x00D6, // Ö
            0x9A: 0x00DC, // Ü
            0x9B: 0x00A2, // ¢
            0x9C: 0x00A3, // £
            0x9D: 0x00A5, // ¥
            0x9E: 0x00DF, // ß
            0x9F: 0x0192, // ƒ
            0xA0: 0x00E1, // á
            0xA1: 0x00ED, // í
            0xA2: 0x00F3, // ó
            0xA3: 0x00FA, // ú
            0xA4: 0x00F1, // ñ
            0xA5: 0x00D1, // Ñ
            0xA6: 0x00AA, // ª
            0xA7: 0x00BA, // º
            0xA8: 0x00BF, // ¿
            0xA9: 0x2310, // ⌐
            0xAA: 0x00AC, // ¬
            0xAB: 0x00BD, // ½
            0xAC: 0x00BC, // ¼
            0xAD: 0x00A1, // ¡
            0xAE: 0x00AB, // «
            0xAF: 0x00BB, // »
        };

        // Create reverse mapping
        this.UNICODE_TO_PETSCII = {};
        for (const [petscii, unicode] of Object.entries(this.PETSCII_TO_UNICODE)) {
            this.UNICODE_TO_PETSCII[unicode] = parseInt(petscii);
        }
    }

    // Convert PETSCII bytes to Unicode string
    petsciiToUnicode(bytes) {
        let result = '';
        for (let i = 0; i < bytes.length && bytes[i] !== 0; i++) {
            const byte = bytes[i];

            // Check if it's in our conversion table
            if (this.PETSCII_TO_UNICODE[byte]) {
                result += String.fromCharCode(this.PETSCII_TO_UNICODE[byte]);
            } else if (byte >= 0x20 && byte <= 0x7E) {
                // Regular ASCII printable characters
                result += String.fromCharCode(byte);
            } else if (byte === 0xA0) {
                // Non-breaking space
                result += '\u00A0';
            } else if (byte < 0x20) {
                // Control characters - skip
                continue;
            } else {
                // Unknown character - use replacement
                result += '?';
            }
        }
        return result.trim();
    }

    // Convert Unicode string to PETSCII bytes
    unicodeToPETSCII(str, maxLength = 31) {
        const bytes = new Uint8Array(maxLength + 1); // +1 for null terminator
        bytes.fill(0x20); // Fill with spaces

        const trimmed = str.substring(0, maxLength);

        for (let i = 0; i < trimmed.length; i++) {
            const code = trimmed.charCodeAt(i);

            // Check if it's in our reverse mapping
            if (this.UNICODE_TO_PETSCII[code] !== undefined) {
                bytes[i] = this.UNICODE_TO_PETSCII[code];
            } else if (code >= 0x20 && code <= 0x7E) {
                // Regular ASCII
                bytes[i] = code;
            } else {
                // Try to find a close match
                bytes[i] = this.findClosestPETSCII(code);
            }
        }

        bytes[maxLength] = 0; // Null terminator
        return bytes;
    }

    // Find closest PETSCII character for unmapped Unicode
    findClosestPETSCII(unicode) {
        // Common substitutions
        const substitutions = {
            0x2018: 0x27, // ' → '
            0x2019: 0x27, // ' → '
            0x201C: 0x22, // " → "
            0x201D: 0x22, // " → "
            0x2013: 0x2D, // – → -
            0x2014: 0x2D, // — → -
            0x2026: 0x2E, // … → .
            0x00D7: 0x78, // × → x
            0x00F7: 0x2F, // ÷ → /
        };

        if (substitutions[unicode]) {
            return substitutions[unicode];
        }

        // Default to question mark for unknown
        return 0x3F;
    }

    async initWASM() {
        try {
            this.Module = await SIDwinderModule();
            this.wasmModule = this.Module;
            window.SIDwinderModule = this.Module;

            if (!this.Module.HEAPU8) {
                console.error('HEAPU8 not found in module');
                throw new Error('WASM memory arrays not available');
            }

            // Create API wrapper using the Module instance
            this.api = {
                // SID functions
                sid_init: this.Module.cwrap('sid_init', null, []),
                sid_load: this.Module.cwrap('sid_load', 'number', ['number', 'number']),
                sid_analyze: this.Module.cwrap('sid_analyze', 'number', ['number', 'number']),
                sid_get_header_string: this.Module.cwrap('sid_get_header_string', 'string', ['number']),
                sid_get_header_value: this.Module.cwrap('sid_get_header_value', 'number', ['number']),
                sid_set_header_string: this.Module.cwrap('sid_set_header_string', null, ['number', 'string']),
                sid_create_modified: this.Module.cwrap('sid_create_modified', 'number', ['number']),
                sid_get_modified_count: this.Module.cwrap('sid_get_modified_count', 'number', []),
                sid_get_modified_address: this.Module.cwrap('sid_get_modified_address', 'number', ['number']),
                sid_get_zp_count: this.Module.cwrap('sid_get_zp_count', 'number', []),
                sid_get_zp_address: this.Module.cwrap('sid_get_zp_address', 'number', ['number']),
                sid_get_code_bytes: this.Module.cwrap('sid_get_code_bytes', 'number', []),
                sid_get_data_bytes: this.Module.cwrap('sid_get_data_bytes', 'number', []),
                sid_get_sid_writes: this.Module.cwrap('sid_get_sid_writes', 'number', ['number']),
                sid_get_clock_type: this.Module.cwrap('sid_get_clock_type', 'string', []),
                sid_get_sid_model: this.Module.cwrap('sid_get_sid_model', 'string', []),
                sid_get_num_calls_per_frame: this.Module.cwrap('sid_get_num_calls_per_frame', 'number', []),
                sid_get_cia_timer_detected: this.Module.cwrap('sid_get_cia_timer_detected', 'number', []),
                sid_get_cia_timer_value: this.Module.cwrap('sid_get_cia_timer_value', 'number', []),
                sid_cleanup: this.Module.cwrap('sid_cleanup', null, []),

                // Add raw header access for proper PETSCII handling
                sid_get_header_bytes: this.Module.cwrap('sid_get_header_bytes', 'number', ['number', 'number']),

                // Memory management
                malloc: (size) => this.Module._malloc(size),
                free: (ptr) => this.Module._free(ptr)
            };

            // Initialize SID processor
            this.api.sid_init();
            this.wasmReady = true;

            return true;

        } catch (error) {
            console.error('Failed to initialize WASM module:', error);
            this.wasmReady = false;
            throw error;
        }
    }

    // Get raw header bytes for PETSCII conversion
    getHeaderBytes(field, length = 32) {
        if (!this.wasmReady || !this.api.sid_get_header_bytes) {
            // Fallback to string API if raw bytes not available
            return null;
        }

        const ptr = this.api.malloc(length);
        try {
            const result = this.api.sid_get_header_bytes(field, ptr);
            if (result > 0) {
                const bytes = new Uint8Array(length);
                bytes.set(this.Module.HEAPU8.subarray(ptr, ptr + length));
                return bytes;
            }
        } finally {
            this.api.free(ptr);
        }
        return null;
    }

    async loadSID(arrayBuffer) {
        if (!await this.waitForWASM()) {
            throw new Error('WASM module not ready');
        }

        if (!this.Module || !this.Module.HEAPU8) {
            throw new Error('WASM memory not available');
        }

        const data = new Uint8Array(arrayBuffer);
        let ptr = null;

        try {
            ptr = this.api.malloc(data.length);
            if (!ptr) {
                throw new Error('Failed to allocate memory in WASM heap');
            }

            this.Module.HEAPU8.set(data, ptr);
            const result = this.api.sid_load(ptr, data.length);

            if (result < 0) {
                const errors = {
                    '-1': 'File too small',
                    '-2': 'Invalid SID file format',
                    '-3': 'RSID format not supported',
                    '-4': 'Unsupported SID version',
                    '-5': 'Missing load address'
                };
                throw new Error(errors[result] || `Unknown error: ${result}`);
            }

            // Try to get raw bytes first for proper PETSCII conversion
            let name, author, copyright;

            // Check if we can get raw bytes
            const nameBytes = this.getHeaderBytes(0);
            const authorBytes = this.getHeaderBytes(1);
            const copyrightBytes = this.getHeaderBytes(2);

            if (nameBytes && authorBytes && copyrightBytes) {
                // Convert from PETSCII
                name = this.petsciiToUnicode(nameBytes);
                author = this.petsciiToUnicode(authorBytes);
                copyright = this.petsciiToUnicode(copyrightBytes);
            } else {
                // Fallback to string API
                name = this.api.sid_get_header_string(0);
                author = this.api.sid_get_header_string(1);
                copyright = this.api.sid_get_header_string(2);

                // Try to fix common encoding issues
                name = this.fixEncoding(name);
                author = this.fixEncoding(author);
                copyright = this.fixEncoding(copyright);
            }

            return {
                name,
                author,
                copyright,
                format: this.api.sid_get_header_string(3),
                version: this.api.sid_get_header_value(0),
                loadAddress: this.api.sid_get_header_value(1),
                initAddress: this.api.sid_get_header_value(2),
                playAddress: this.api.sid_get_header_value(3),
                songs: this.api.sid_get_header_value(4),
                startSong: this.api.sid_get_header_value(5),
                flags: this.api.sid_get_header_value(6),
                fileSize: this.api.sid_get_header_value(7),
                clockType: this.api.sid_get_clock_type(),
                sidModel: this.api.sid_get_sid_model()
            };

        } finally {
            if (ptr !== null) {
                this.api.free(ptr);
            }
        }
    }

    // Try to fix common encoding issues in strings
    fixEncoding(str) {
        if (!str) return str;

        // Common PETSCII/Latin-1 characters that get misinterpreted
        const replacements = {
            'Ã¤': 'ä', 'Ã¶': 'ö', 'Ã¼': 'ü', 'Ã': 'Ä', 'Ã': 'Ö', 'Ã': 'Ü',
            'Ã©': 'é', 'Ã¨': 'è', 'Ã ': 'à', 'Ã¢': 'â', 'Ãª': 'ê', 'Ã®': 'î',
            'Ã§': 'ç', 'Ã±': 'ñ', 'Ã': 'ß', 'Ã¸': 'ø', 'Ã¥': 'å', 'Ã¦': 'æ'
        };

        let fixed = str;
        for (const [bad, good] of Object.entries(replacements)) {
            fixed = fixed.replace(new RegExp(bad, 'g'), good);
        }

        return fixed;
    }

    updateMetadata(field, value) {
        if (!this.wasmReady) {
            console.warn('WASM not ready, cannot update metadata');
            return false;
        }

        const fields = {
            'name': 0,
            'author': 1,
            'copyright': 2
        };

        if (field in fields) {
            // Convert Unicode to PETSCII before sending to WASM
            const petsciiBytes = this.unicodeToPETSCII(value, 31);

            // Convert back to string for the API
            // This assumes the WASM module expects UTF-8
            let petsciiString = '';
            for (let i = 0; i < petsciiBytes.length && petsciiBytes[i] !== 0; i++) {
                petsciiString += String.fromCharCode(petsciiBytes[i]);
            }

            this.api.sid_set_header_string(fields[field], petsciiString);
            return true;
        }

        return false;
    }

    async waitForWASM() {
        try {
            await this.initPromise;
            return this.wasmReady;
        } catch (error) {
            console.error('WASM initialization failed:', error);
            return false;
        }
    }

    async analyze(frameCount = 30000, progressCallback = null) {
        // ... rest of the analyze method remains the same ...
        if (!await this.waitForWASM()) {
            throw new Error('WASM module not ready');
        }

        let callbackPtr = 0;
        let progressInterval = null;

        if (progressCallback) {
            let currentProgress = 0;
            const progressIncrement = 100 / (frameCount / 1000);

            progressInterval = setInterval(() => {
                currentProgress = Math.min(currentProgress + progressIncrement, 99);
                progressCallback(Math.floor(currentProgress * frameCount / 100), frameCount);
            }, 50);
        }

        try {
            const result = this.api.sid_analyze(frameCount, callbackPtr);

            if (result < 0) {
                throw new Error(`Analysis failed: ${result}`);
            }

            const modifiedAddresses = [];
            const modifiedCount = this.api.sid_get_modified_count();
            for (let i = 0; i < modifiedCount; i++) {
                const addr = this.api.sid_get_modified_address(i);
                if (addr !== 0xFFFF) {
                    modifiedAddresses.push(addr);
                }
            }

            const zpAddresses = [];
            const zpCount = this.api.sid_get_zp_count();
            for (let i = 0; i < zpCount; i++) {
                const addr = this.api.sid_get_zp_address(i);
                if (addr !== 0xFF) {
                    zpAddresses.push(addr);
                }
            }

            const sidWrites = new Map();
            for (let reg = 0; reg < 0x20; reg++) {
                const count = this.api.sid_get_sid_writes(reg);
                if (count > 0) {
                    sidWrites.set(reg, count);
                }
            }

            if (progressCallback) {
                progressCallback(frameCount, frameCount);
            }

            const numCallsPerFrame = this.api.sid_get_num_calls_per_frame();
            const ciaTimerDetected = this.api.sid_get_cia_timer_detected() ? true : false;
            const ciaTimerValue = this.api.sid_get_cia_timer_value();

            return {
                modifiedAddresses,
                zpAddresses,
                sidWrites,
                codeBytes: this.api.sid_get_code_bytes(),
                dataBytes: this.api.sid_get_data_bytes(),
                numCallsPerFrame,
                ciaTimerDetected,
                ciaTimerValue
            };
        } finally {
            if (progressInterval) {
                clearInterval(progressInterval);
            }
        }
    }

    createModifiedSID() {
        if (!this.wasmReady || !this.Module) {
            console.error('WASM not ready, cannot create modified SID');
            return null;
        }

        const sizePtr = this.api.malloc(4);

        try {
            const dataPtr = this.api.sid_create_modified(sizePtr);

            if (!dataPtr) {
                console.error('Failed to create modified SID - null pointer returned');
                return null;
            }

            const size = this.Module.HEAP32[sizePtr >> 2];

            if (size <= 0 || size > 65536) {
                console.error(`Invalid SID size: ${size}`);
                return null;
            }

            const data = new Uint8Array(size);
            data.set(this.Module.HEAPU8.subarray(dataPtr, dataPtr + size));

            this.api.free(dataPtr);

            return data;

        } catch (error) {
            console.error('Error creating modified SID:', error);
            return null;
        } finally {
            this.api.free(sizePtr);
        }
    }

    cleanup() {
        if (this.wasmReady && this.api) {
            this.api.sid_cleanup();
        }
    }
}

// Export for use in other modules
window.SIDAnalyzer = SIDAnalyzer;