// sidwinder-core.js - Core SID analysis functionality using WASM

class SIDAnalyzer {
    constructor() {
        this.wasmModule = null;
        this.wasmReady = false;
        this.api = null;
        this.initPromise = this.initWASM();
    }

    async initWASM() {
        try {
            console.log('Initializing WASM module...');

            // Initialize the WASM module
            this.wasmModule = await SIDwinderModule();

            console.log('WASM module loaded, creating API...');

            // Create API wrapper
            this.api = {
                // SID functions
                sid_init: this.wasmModule.cwrap('sid_init', null, []),
                sid_load: this.wasmModule.cwrap('sid_load', 'number', ['number', 'number']),
                sid_analyze: this.wasmModule.cwrap('sid_analyze', 'number', ['number', 'number']),
                sid_get_header_string: this.wasmModule.cwrap('sid_get_header_string', 'string', ['number']),
                sid_get_header_value: this.wasmModule.cwrap('sid_get_header_value', 'number', ['number']),
                sid_set_header_string: this.wasmModule.cwrap('sid_set_header_string', null, ['number', 'string']),
                sid_create_modified: this.wasmModule.cwrap('sid_create_modified', 'number', ['number']),
                sid_get_modified_count: this.wasmModule.cwrap('sid_get_modified_count', 'number', []),
                sid_get_modified_address: this.wasmModule.cwrap('sid_get_modified_address', 'number', ['number']),
                sid_get_zp_count: this.wasmModule.cwrap('sid_get_zp_count', 'number', []),
                sid_get_zp_address: this.wasmModule.cwrap('sid_get_zp_address', 'number', ['number']),
                sid_get_code_bytes: this.wasmModule.cwrap('sid_get_code_bytes', 'number', []),
                sid_get_data_bytes: this.wasmModule.cwrap('sid_get_data_bytes', 'number', []),
                sid_get_sid_writes: this.wasmModule.cwrap('sid_get_sid_writes', 'number', ['number']),
                sid_get_clock_type: this.wasmModule.cwrap('sid_get_clock_type', 'string', []),
                sid_get_sid_model: this.wasmModule.cwrap('sid_get_sid_model', 'string', []),
                sid_cleanup: this.wasmModule.cwrap('sid_cleanup', null, [])
            };

            // Initialize SID processor
            this.api.sid_init();
            this.wasmReady = true;

            console.log('WASM initialization complete');
            return true;

        } catch (error) {
            console.error('Failed to initialize WASM module:', error);
            this.wasmReady = false;
            throw error;
        }
    }

    async waitForWASM() {
        // Wait for the initialization promise
        try {
            await this.initPromise;
            return this.wasmReady;
        } catch (error) {
            console.error('WASM initialization failed:', error);
            return false;
        }
    }

    async loadSID(arrayBuffer) {
        if (!await this.waitForWASM()) {
            throw new Error('WASM module not ready');
        }

        // Ensure module is fully initialized
        if (!this.wasmModule || !this.wasmModule.HEAPU8) {
            throw new Error('WASM module not properly initialized');
        }

        // Allocate memory in WASM heap
        const data = new Uint8Array(arrayBuffer);
        const ptr = this.wasmModule._malloc(data.length);

        try {
            // Copy data to WASM heap
            this.wasmModule.HEAPU8.set(data, ptr);

            // Load SID file
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

            // Get header information
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

        } finally {
            // Free allocated memory
            this.wasmModule._free(ptr);
        }
    }

    async analyze(frameCount = 30000, progressCallback = null) {
        if (!await this.waitForWASM()) {
            throw new Error('WASM module not ready');
        }

        // Create progress callback wrapper if provided
        let callbackPtr = 0;
        let progressInterval = null;

        if (progressCallback) {
            // Simple progress simulation since direct WASM->JS callbacks are complex
            let currentProgress = 0;
            const progressIncrement = 100 / (frameCount / 1000); // Update every 1000 frames

            progressInterval = setInterval(() => {
                currentProgress = Math.min(currentProgress + progressIncrement, 99);
                progressCallback(Math.floor(currentProgress * frameCount / 100), frameCount);
            }, 50);
        }

        try {
            // Run analysis
            const result = this.api.sid_analyze(frameCount, callbackPtr);

            if (result < 0) {
                throw new Error(`Analysis failed: ${result}`);
            }

            // Gather results
            const modifiedAddresses = [];
            const modifiedCount = this.api.sid_get_modified_count();
            for (let i = 0; i < modifiedCount; i++) {
                const addr = this.api.sid_get_modified_address(i);
                if (addr !== 0xFFFF) { // Skip invalid addresses
                    modifiedAddresses.push(addr);
                }
            }

            const zpAddresses = [];
            const zpCount = this.api.sid_get_zp_count();
            for (let i = 0; i < zpCount; i++) {
                const addr = this.api.sid_get_zp_address(i);
                if (addr !== 0xFF) { // Skip invalid addresses
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

            // Complete progress
            if (progressCallback) {
                progressCallback(frameCount, frameCount);
            }

            return {
                modifiedAddresses,
                zpAddresses,
                sidWrites,
                codeBytes: this.api.sid_get_code_bytes(),
                dataBytes: this.api.sid_get_data_bytes()
            };

        } finally {
            if (progressInterval) {
                clearInterval(progressInterval);
            }
        }
    }

    updateMetadata(field, value) {
        if (!this.wasmReady) {
            console.warn('WASM not ready, cannot update metadata');
            return false;
        }

        const fields = {
            'title': 0,
            'author': 1,
            'copyright': 2
        };

        if (field in fields) {
            this.api.sid_set_header_string(fields[field], value.substring(0, 31));
            return true;
        }

        return false;
    }

    createModifiedSID() {
        if (!this.wasmReady) {
            console.error('WASM not ready, cannot create modified SID');
            return null;
        }

        // Allocate space for size output
        const sizePtr = this.wasmModule._malloc(4);

        try {
            // Create modified SID
            const dataPtr = this.api.sid_create_modified(sizePtr);

            if (!dataPtr) {
                console.error('Failed to create modified SID - null pointer returned');
                return null;
            }

            // Get size
            const size = this.wasmModule.HEAP32[sizePtr >> 2];

            if (size <= 0 || size > 65536) {
                console.error(`Invalid SID size: ${size}`);
                return null;
            }

            // Copy data from WASM heap
            const data = new Uint8Array(size);
            data.set(this.wasmModule.HEAPU8.subarray(dataPtr, dataPtr + size));

            // Free the data pointer (allocated in WASM)
            this.wasmModule._free(dataPtr);

            return data;

        } catch (error) {
            console.error('Error creating modified SID:', error);
            return null;
        } finally {
            // Free size pointer
            this.wasmModule._free(sizePtr);
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