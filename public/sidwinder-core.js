// sidwinder-core.js - Core SID analysis functionality using WASM

/**
 * SIDAnalyzer wraps the SIDwinder WASM module and exposes a JS-friendly API
 * for loading SID files, running emulation-based analysis, and producing a
 * modified SID for export. WASM heap allocations are managed here; callers
 * never touch raw pointers.
 */
class SIDAnalyzer {
    constructor() {
        this.wasmModule = null;
        this.wasmReady = false;
        this.api = null;
        this.Module = null;
        this.initPromise = this.initWASM();
    }

    async initWASM() {
        try {
            this.Module = await SIDwinderModule();
            this.wasmModule = this.Module;
            // Expose globally so PNGConverter and other consumers can share the same instance
            window.SIDwinderModule = this.Module;

            if (!this.Module.HEAPU8) {
                console.error('HEAPU8 not found in module');
                throw new Error('WASM memory arrays not available');
            }

            // cwrap bindings to the C exports in wasm/sid_processor.cpp
            this.api = {
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
                sid_get_sid_chip_count: this.Module.cwrap('sid_get_sid_chip_count', 'number', []),
                sid_get_sid_chip_address: this.Module.cwrap('sid_get_sid_chip_address', 'number', ['number']),
                sid_get_clock_type: this.Module.cwrap('sid_get_clock_type', 'string', []),
                sid_get_sid_model: this.Module.cwrap('sid_get_sid_model', 'string', []),
                sid_get_num_calls_per_frame: this.Module.cwrap('sid_get_num_calls_per_frame', 'number', []),
                sid_get_cia_timer_detected: this.Module.cwrap('sid_get_cia_timer_detected', 'number', []),
                sid_get_cia_timer_value: this.Module.cwrap('sid_get_cia_timer_value', 'number', []),
                sid_get_max_cycles: this.Module.cwrap('sid_get_max_cycles', 'number', []),
                sid_cleanup: this.Module.cwrap('sid_cleanup', null, []),

                malloc: (size) => this.Module._malloc(size),
                free: (ptr) => this.Module._free(ptr)
            };

            this.api.sid_init();
            this.wasmReady = true;

            return true;

        } catch (error) {
            console.error('Failed to initialize WASM module:', error);
            this.wasmReady = false;
            throw error;
        }
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

    /**
     * Load a SID file from an ArrayBuffer and return its parsed header.
     * @param {ArrayBuffer} arrayBuffer - Raw SID file bytes
     * @returns {Promise<Object>} Header info (name, author, addresses, flags, etc.)
     */
    async loadSID(arrayBuffer) {
        if (!await this.waitForWASM()) {
            throw new Error('WASM module not ready');
        }

        if (!this.Module) {
            throw new Error('WASM Module not available');
        }

        if (!this.Module.HEAPU8) {
            console.error('Available Module properties:', Object.keys(this.Module));
            throw new Error('WASM memory (HEAPU8) not available - module may not be properly initialized');
        }

        const data = new Uint8Array(arrayBuffer);
        let ptr = null;

        try {
            ptr = this.api.malloc(data.length);

            if (!ptr) {
                throw new Error('Failed to allocate memory in WASM heap');
            }

            // Copy file contents into the WASM heap before invoking the loader
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

            return {
                name: this.api.sid_get_header_string(0),
                author: this.api.sid_get_header_string(1),
                copyright: this.api.sid_get_header_string(2),
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

        } catch (error) {
            console.error('Error in loadSID:', error);
            throw error;
        } finally {
            if (ptr !== null) {
                this.api.free(ptr);
            }
        }
    }

    /**
     * Run the SID through the 6510 emulator for the given number of frames and
     * collect the addresses written to, the zero-page locations used, and per-
     * register SID write counts.
     * @param {number} frameCount - Number of frames to emulate
     * @param {Function|null} progressCallback - Called as (current, total)
     */
    async analyze(frameCount = 30000, progressCallback = null) {
        if (!await this.waitForWASM()) {
            throw new Error('WASM module not ready');
        }

        let callbackPtr = 0;
        let progressInterval = null;

        if (progressCallback) {
            // Direct WASM->JS callbacks are awkward to wire through cwrap, so we
            // simulate progress on a timer while the synchronous analyze() runs.
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
                if (addr !== 0xFFFF) {  // 0xFFFF is the sentinel for an empty slot
                    modifiedAddresses.push(addr);
                }
            }

            const zpAddresses = [];
            const zpCount = this.api.sid_get_zp_count();
            for (let i = 0; i < zpCount; i++) {
                const addr = this.api.sid_get_zp_address(i);
                if (addr !== 0xFF) {  // 0xFF is the sentinel for an empty slot
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
            const maxCycles = this.api.sid_get_max_cycles();
            const sidChipCount = this.api.sid_get_sid_chip_count();

            const sidChipAddresses = [];
            for (let i = 0; i < sidChipCount; i++) {
                const addr = this.api.sid_get_sid_chip_address(i);
                if (addr > 0) {
                    sidChipAddresses.push(addr);
                }
            }

            return {
                modifiedAddresses,
                zpAddresses,
                sidWrites,
                codeBytes: this.api.sid_get_code_bytes(),
                dataBytes: this.api.sid_get_data_bytes(),
                numCallsPerFrame,
                ciaTimerDetected,
                ciaTimerValue,
                maxCycles,
                sidChipCount,
                sidChipAddresses
            };
        } finally {
            if (progressInterval) {
                clearInterval(progressInterval);
            }
        }
    }

    /**
     * Update an editable header string (name/author/copyright).
     * SID header strings are limited to 31 characters plus a null terminator.
     */
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
            this.api.sid_set_header_string(fields[field], value.substring(0, 31));
            return true;
        }

        return false;
    }

    /**
     * Build a SID file reflecting any header edits and return its bytes.
     * The WASM side allocates the result; this method copies it out and frees it.
     */
    createModifiedSID() {
        if (!this.wasmReady || !this.Module) {
            console.error('WASM not ready, cannot create modified SID');
            return null;
        }

        // 4-byte slot for the WASM side to write the result length into
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

            // Free the buffer the WASM side malloc'd for us
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

window.SIDAnalyzer = SIDAnalyzer;
