// compressor-manager.js - Unified compression manager for SIDwinder
class CompressorManager {
    constructor() {
        this.compressors = {
            'none': null,
            'rle': null,
            'tscrunch': null
        };

        this.initialized = false;
        this.initPromise = this.initializeCompressors();
    }

    async initializeCompressors() {
        // RLE Compressor (from WASM)
        if (window.SIDwinderModule) {
            try {
                this.compressors.rle = new RLECompressor(window.SIDwinderModule);
            } catch (error) {
                console.warn('RLE compressor initialization failed:', error);
            }
        }

        // Wait for TSCrunch to be ready
        if (!window.TSCrunch) {
            await new Promise(resolve => {
                if (window.TSCrunch) {
                    resolve();
                } else {
                    window.addEventListener('tscrunch-ready', resolve, { once: true });
                }
            });
        }

        // TSCrunch Compressor
        if (window.TSCrunch) {
            try {
                this.compressors.tscrunch = new TSCrunchCompressor();
            } catch (error) {
                console.warn('TSCrunch initialization failed:', error);
            }
        }

        this.initialized = true;
    }

    async waitForInit() {
        if (!this.initialized) {
            await this.initPromise;
        }
    }

    isAvailable(type) {
        if (type === 'none') return true;
        return this.compressors[type] !== null;
    }

    async compress(data, type, uncompressedStart, executeAddress) {
        // Ensure compressors are initialized
        await this.waitForInit();

        if (type === 'none') {
            return {
                data: data,
                type: 'none',
                originalSize: data.length,
                compressedSize: data.length,
                ratio: 1.0
            };
        }

        const compressor = this.compressors[type];
        if (!compressor) {
            throw new Error(`Compressor '${type}' not available`);
        }

        // Remove load address for compression
        const hasLoadAddress = data.length >= 2 &&
            (data[0] | (data[1] << 8)) === uncompressedStart;

        const dataToCompress = hasLoadAddress ? data.slice(2) : data;

        let result = await compressor.compressPRG(
            dataToCompress,
            uncompressedStart,
            executeAddress
        );

        return {
            data: result.data || result,
            type: type,
            originalSize: result.originalSize || data.length,
            compressedSize: result.compressedSize || (result.data ? result.data.length : result.length)
        };
    }
}

// TSCrunch wrapper
class TSCrunchCompressor {
    constructor() {
        this.originalSize = 0;
        this.compressedSize = 0;
    }

    async compressPRG(data, uncompressedStart, executeAddress) {
        try {
            this.originalSize = data.length;

            // TSCrunch expects PRG format, so we need to add the load address
            // BUT - check if data already has a load address
            let prgData;

            // Check if the data already starts with the expected load address
            if (data.length >= 2 && (data[0] | (data[1] << 8)) === uncompressedStart) {
                // Data already has load address, use as-is
                prgData = data;
            } else {
                // Need to add load address
                prgData = new Uint8Array(data.length + 2);
                prgData[0] = uncompressedStart & 0xFF;
                prgData[1] = (uncompressedStart >> 8) & 0xFF;
                prgData.set(data, 2);
            }

            // TSCrunch options
            const options = {
                prg: true,           // Input is PRG format
                sfx: true,           // Create self-extracting
                sfxMode: 0,          // Normal SFX mode
                jumpAddress: executeAddress,
                blank: false,        // Don't blank screen
                inplace: false       // Not in-place compression
            };

            // Compress with TSCrunch
            const compressed = TSCrunch.compress(prgData, options);

            this.compressedSize = compressed.length;

            return {
                data: compressed,
                originalSize: this.originalSize,
                compressedSize: this.compressedSize,
                ratio: this.compressedSize / this.originalSize
            };

        } catch (error) {
            console.error('TSCrunch compression failed:', error);
            throw error;
        }
    }
}

// Export globally
window.CompressorManager = CompressorManager;