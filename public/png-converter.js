// png-converter.js - JavaScript interface for PNG to C64 conversion

class PNGConverter {
    constructor(wasmModule) {
        this.Module = wasmModule;
        this.initialized = false;
    }

    init() {
        if (!this.Module) {
            throw new Error('WASM module not available');
        }

        const result = this.Module.ccall(
            'png_converter_init',
            'number',
            [],
            []
        );

        this.initialized = (result === 1);
        return this.initialized;
    }

    async convertPNGToC64(file) {
        if (!this.initialized) {
            throw new Error('PNG converter not initialized');
        }

        // Validate file type
        if (!file.type.startsWith('image/png')) {
            throw new Error('File must be a PNG image');
        }

        try {
            // Load and decode PNG using Canvas API
            const imageData = await this.loadPNGImageData(file);

            // Validate dimensions
            if (imageData.width !== 320 || imageData.height !== 200) {
                throw new Error(`Image must be 320x200 pixels (got ${imageData.width}x${imageData.height})`);
            }

            // Allocate memory for image data
            const dataSize = imageData.width * imageData.height * 4; // RGBA
            const dataPtr = this.Module._malloc(dataSize);

            try {
                // Copy image data to WASM memory
                this.Module.HEAPU8.set(imageData.data, dataPtr);

                // Set image data in converter
                const setResult = this.Module.ccall(
                    'png_converter_set_image',
                    'number',
                    ['number', 'number', 'number'],
                    [dataPtr, imageData.width, imageData.height]
                );

                if (setResult !== 1) {
                    throw new Error('Failed to set image data in converter');
                }

                // Convert the image
                const convertResult = this.Module.ccall(
                    'png_converter_convert',
                    'number',
                    [],
                    []
                );

                if (convertResult !== 1) {
                    throw new Error('Image contains too many colors per 8x8 character cell (max 4 colors allowed)');
                }

                // Get the selected background color
                const backgroundColor = this.Module.ccall(
                    'png_converter_get_background_color',
                    'number',
                    [],
                    []
                );

                // Get color matching statistics
                const exactPtr = this.Module._malloc(4);
                const distancePtr = this.Module._malloc(4);

                try {
                    this.Module.ccall(
                        'png_converter_get_color_stats',
                        'null',
                        ['number', 'number'],
                        [exactPtr, distancePtr]
                    );
                } finally {
                    this.Module._free(exactPtr);
                    this.Module._free(distancePtr);
                }
                const koalaSize = 10003; // Standard KOA file size
                const koalaPtr = this.Module._malloc(koalaSize);

                try {
                    const actualSize = this.Module.ccall(
                        'png_converter_create_koala',
                        'number',
                        ['number'],
                        [koalaPtr]
                    );

                    // Copy result to JavaScript array
                    const koalaData = new Uint8Array(actualSize);
                    koalaData.set(this.Module.HEAPU8.subarray(koalaPtr, koalaPtr + actualSize));

                    // Verify structure
                    if (actualSize !== 10003) {
                        console.warn(`Unexpected KOA file size: ${actualSize} (should be 10003)`);
                    }
                    if (koalaData[0] !== 0x00 || koalaData[1] !== 0x60) {
                        console.warn(`Unexpected load address: ${koalaData[1].toString(16)}${koalaData[0].toString(16)} (should be $6000)`);
                    }

                    return {
                        success: true,
                        data: koalaData,
                        backgroundColor: backgroundColor,
                        backgroundColorName: this.getColorName(backgroundColor),
                        format: 'KOA',
                        width: 320,
                        height: 200
                    };

                } finally {
                    this.Module._free(koalaPtr);
                }

            } finally {
                this.Module._free(dataPtr);
            }

        } catch (error) {
            console.error('PNG conversion error:', error);
            throw error;
        }
    }

    async loadPNGImageData(file) {
        return new Promise((resolve, reject) => {
            const img = new Image();

            img.onload = () => {
                try {
                    // Create canvas to get image data
                    const canvas = document.createElement('canvas');
                    const ctx = canvas.getContext('2d');

                    canvas.width = img.width;
                    canvas.height = img.height;

                    // Draw image to canvas
                    ctx.drawImage(img, 0, 0);

                    // Get image data (RGBA)
                    const imageData = ctx.getImageData(0, 0, img.width, img.height);

                    resolve(imageData);

                } catch (error) {
                    reject(new Error(`Failed to process image: ${error.message}`));
                }
            };

            img.onerror = () => {
                reject(new Error('Failed to load PNG image'));
            };

            // Create object URL and load image
            const url = URL.createObjectURL(file);
            img.src = url;

            // Clean up URL when done
            img.onload = (originalOnLoad => function (...args) {
                URL.revokeObjectURL(url);
                return originalOnLoad.apply(this, args);
            })(img.onload);

            img.onerror = (originalOnError => function (...args) {
                URL.revokeObjectURL(url);
                return originalOnError.apply(this, args);
            })(img.onerror);
        });
    }

    getColorName(colorIndex) {
        const colorNames = [
            'Black', 'White', 'Red', 'Cyan', 'Purple', 'Green', 'Blue', 'Yellow',
            'Orange', 'Brown', 'Light Red', 'Dark Grey', 'Grey', 'Light Green',
            'Light Blue', 'Light Grey'
        ];

        return colorNames[colorIndex] || 'Unknown';
    }

    // Get individual component data (for advanced users)
    async getComponentData() {
        if (!this.initialized) {
            throw new Error('PNG converter not initialized');
        }

        const mapPtr = this.Module._malloc(8000);
        const scrPtr = this.Module._malloc(1000);
        const colPtr = this.Module._malloc(1000);

        try {
            // Get bitmap data
            this.Module.ccall('png_converter_get_map_data', 'number', ['number'], [mapPtr]);
            const mapData = new Uint8Array(8000);
            mapData.set(this.Module.HEAPU8.subarray(mapPtr, mapPtr + 8000));

            // Get screen memory
            this.Module.ccall('png_converter_get_scr_data', 'number', ['number'], [scrPtr]);
            const scrData = new Uint8Array(1000);
            scrData.set(this.Module.HEAPU8.subarray(scrPtr, scrPtr + 1000));

            // Get color memory
            this.Module.ccall('png_converter_get_col_data', 'number', ['number'], [colPtr]);
            const colData = new Uint8Array(1000);
            colData.set(this.Module.HEAPU8.subarray(colPtr, colPtr + 1000));

            return {
                bitmap: mapData,    // 8000 bytes - bitmap data
                screen: scrData,    // 1000 bytes - screen memory
                color: colData,     // 1000 bytes - color memory
                background: this.Module.ccall('png_converter_get_background_color', 'number', [], [])
            };

        } finally {
            this.Module._free(mapPtr);
            this.Module._free(scrPtr);
            this.Module._free(colPtr);
        }
    }

    cleanup() {
        if (this.initialized) {
            this.Module.ccall('png_converter_cleanup', 'null', [], []);
            this.initialized = false;
        }
    }
}

// Enhanced file handler that supports both KOA/KLA and PNG
class EnhancedImageLoader {
    constructor(wasmModule) {
        this.pngConverter = new PNGConverter(wasmModule);
        this.pngConverter.init();
    }

    async loadImageFile(file) {
        const fileName = file.name.toLowerCase();

        if (fileName.endsWith('.png')) {
            return await this.loadPNG(file);
        } else if (fileName.endsWith('.koa') || fileName.endsWith('.kla')) {
            return await this.loadKoala(file);
        } else {
            throw new Error('Unsupported file format. Please use PNG, KOA, or KLA files.');
        }
    }

    async loadPNG(file) {
        try {
            const result = await this.pngConverter.convertPNGToC64(file);
            return result;

        } catch (error) {
            console.error('PNG loading failed:', error.message);
            throw new Error(`PNG conversion failed: ${error.message}`);
        }
    }

    async loadKoala(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();

            reader.onload = (e) => {
                try {
                    const data = new Uint8Array(e.target.result);

                    // Validate Koala file structure
                    if (data.length < 10003) {
                        throw new Error('Invalid Koala file: too small');
                    }

                    // Check load address (should be 0x6000)
                    const loadAddr = data[0] | (data[1] << 8);
                    if (loadAddr !== 0x6000) {
                        console.warn(`Unusual Koala load address: $${loadAddr.toString(16).toUpperCase()}`);
                    }

                    resolve({
                        success: true,
                        data: data,
                        format: file.name.toLowerCase().endsWith('.koa') ? 'KOA' : 'KLA',
                        width: 320,
                        height: 200
                    });

                } catch (error) {
                    reject(new Error(`Failed to load Koala file: ${error.message}`));
                }
            };

            reader.onerror = () => {
                reject(new Error('Failed to read file'));
            };

            reader.readAsArrayBuffer(file);
        });
    }

    cleanup() {
        this.pngConverter.cleanup();
    }
}

// Export for global use
window.PNGConverter = PNGConverter;
window.EnhancedImageLoader = EnhancedImageLoader;