// compressor-manager.js - Unified compression manager for SIDwinder.
// Wraps optional compressors (currently TSCrunch) behind a single async API
// and lazy-loads them on first use to keep startup cost low.

class CompressorManager {
    constructor() {
        this.compressors = {
            'none': null,
            'tscrunch': null
        };

        this.initialized = false;
    }

    async initializeCompressors() {
        if (this.initialized) return;

        // Lazy-load TSCrunch only when first needed
        if (window.loadTSCrunch) {
            await window.loadTSCrunch();
        }

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
            await this.initializeCompressors();
        }
    }

    isAvailable(type) {
        if (type === 'none') return true;
        return this.compressors[type] !== null;
    }

    async compress(data, type, uncompressedStart, executeAddress) {
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

        // Strip the 2-byte PRG load address before handing data to the compressor;
        // it will be re-added by the SFX wrapper.
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

/**
 * TSCrunch wrapper. TSCrunch expects PRG-format input (load address as first
 * two bytes) and produces a self-extracting executable.
 */
class TSCrunchCompressor {
    constructor() {
        this.originalSize = 0;
        this.compressedSize = 0;
    }

    async compressPRG(data, uncompressedStart, executeAddress) {
        try {
            this.originalSize = data.length;

            // Ensure prgData has the expected load address as its first two bytes.
            let prgData;
            if (data.length >= 2 && (data[0] | (data[1] << 8)) === uncompressedStart) {
                prgData = data;
            } else {
                prgData = new Uint8Array(data.length + 2);
                prgData[0] = uncompressedStart & 0xFF;
                prgData[1] = (uncompressedStart >> 8) & 0xFF;
                prgData.set(data, 2);
            }

            const options = {
                prg: true,
                sfx: true,
                sfxMode: 0,
                jumpAddress: executeAddress,
                blank: false,
                inplace: false
            };

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

window.CompressorManager = CompressorManager;