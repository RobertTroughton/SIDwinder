// sidwinder-core.js - Core SID analysis functionality using WASM

class SIDAnalyzer {
    constructor() {
        this.wasmModule = null;
        this.wasmReady = false;
        this.api = null;
        this.Module = null; // Store the module instance
        this.initPromise = this.initWASM();
    }

    async initWASM() {
        try {
            console.log('Initializing WASM module...');

            // Initialize the WASM module - store the actual module instance
            this.Module = await SIDwinderModule();
            this.wasmModule = this.Module;

            console.log('WASM module loaded, checking memory arrays...');
            console.log('Module properties:', Object.keys(this.Module));

            // Check if memory arrays are available
            if (!this.Module.HEAPU8) {
                console.error('HEAPU8 not found in module');
                throw new Error('WASM memory arrays not available');
            }

            console.log('Creating API wrapper...');

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
                sid_cleanup: this.Module.cwrap('sid_cleanup', null, []),

                // Memory management - use direct module references
                malloc: (size) => this.Module._malloc(size),
                free: (ptr) => this.Module._free(ptr)
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

        // Double-check that Module and its memory are available
        if (!this.Module) {
            throw new Error('WASM Module not available');
        }

        if (!this.Module.HEAPU8) {
            console.error('Available Module properties:', Object.keys(this.Module));
            throw new Error('WASM memory (HEAPU8) not available - module may not be properly initialized');
        }

        // Allocate memory in WASM heap
        const data = new Uint8Array(arrayBuffer);
        let ptr = null;

        try {
            // Use the Module's malloc directly
            ptr = this.api.malloc(data.length);

            if (!ptr) {
                throw new Error('Failed to allocate memory in WASM heap');
            }

            // Copy data to WASM heap using the Module's HEAPU8
            this.Module.HEAPU8.set(data, ptr);

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

        } catch (error) {
            console.error('Error in loadSID:', error);
            throw error;
        } finally {
            // Free allocated memory
            if (ptr !== null) {
                this.api.free(ptr);
            }
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
        if (!this.wasmReady || !this.Module) {
            console.error('WASM not ready, cannot create modified SID');
            return null;
        }

        // Allocate space for size output
        const sizePtr = this.api.malloc(4);

        try {
            // Create modified SID
            const dataPtr = this.api.sid_create_modified(sizePtr);

            if (!dataPtr) {
                console.error('Failed to create modified SID - null pointer returned');
                return null;
            }

            // Get size using Module's HEAP32
            const size = this.Module.HEAP32[sizePtr >> 2];

            if (size <= 0 || size > 65536) {
                console.error(`Invalid SID size: ${size}`);
                return null;
            }

            // Copy data from WASM heap using Module's HEAPU8
            const data = new Uint8Array(size);
            data.set(this.Module.HEAPU8.subarray(dataPtr, dataPtr + size));

            // Free the data pointer (allocated in WASM)
            this.api.free(dataPtr);

            return data;

        } catch (error) {
            console.error('Error creating modified SID:', error);
            return null;
        } finally {
            // Free size pointer
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