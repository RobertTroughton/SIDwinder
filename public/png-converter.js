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

        if (!file.type.startsWith('image/png')) {
            throw new Error('File must be a PNG image');
        }

        try {
            const imageData = await this.loadPNGImageData(file);

            if (!((imageData.width === 320 && imageData.height === 200) || (imageData.width === 384 && imageData.height === 272))) {
                throw new Error(`Image must be 320x200 pixels (got ${imageData.width}x${imageData.height})`);
            }

            const dataSize = imageData.width * imageData.height * 4;
            const dataPtr = this.Module._malloc(dataSize);

            try {
                this.Module.HEAPU8.set(imageData.data, dataPtr);

                const setResult = this.Module.ccall(
                    'png_converter_set_image',
                    'number',
                    ['number', 'number', 'number'],
                    [dataPtr, imageData.width, imageData.height]
                );

                if (setResult !== 1) {
                    throw new Error('Failed to set image data in converter');
                }

                const convertResult = this.Module.ccall(
                    'png_converter_convert',
                    'number',
                    [],
                    []
                );

                if (convertResult !== 1) {
                    throw new Error('Image cannot be converted: too many colors per 8x8 character cell (max 4 for multicolor, max 2 for hires)');
                }

                const backgroundColor = this.Module.ccall(
                    'png_converter_get_background_color',
                    'number',
                    [],
                    []
                );

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
                const bitmapMode = this.Module.ccall(
                    'png_converter_get_bitmap_mode',
                    'number',
                    [],
                    []
                );

                const c64BitmapSize = 10004;
                const bitmapPtr = this.Module._malloc(c64BitmapSize);

                try {
                    const actualSize = this.Module.ccall(
                        'png_converter_create_c64_bitmap',
                        'number',
                        ['number'],
                        [bitmapPtr]
                    );

                    const bitmapData = new Uint8Array(actualSize);
                    bitmapData.set(this.Module.HEAPU8.subarray(bitmapPtr, bitmapPtr + actualSize));

                    if (actualSize !== 10004) {
                        console.warn(`Unexpected bitmap output size: ${actualSize} (should be 10004)`);
                    }
                    if (bitmapData[0] !== 0x00 || bitmapData[1] !== 0x60) {
                        console.warn(`Unexpected load address: ${bitmapData[1].toString(16)}${bitmapData[0].toString(16)} (should be $6000)`);
                    }

                    return {
                        success: true,
                        data: bitmapData,
                        backgroundColor: backgroundColor,
                        backgroundColorName: this.getColorName(backgroundColor),
                        bitmapMode: bitmapMode, // 0 = multicolor, 1 = hires
                        format: bitmapMode === 1 ? 'C64_HIRES_BITMAP' : 'C64_BITMAP',
                        width: 320,
                        height: 200
                    };

                } finally {
                    this.Module._free(bitmapPtr);
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
                    const canvas = document.createElement('canvas');
                    const ctx = canvas.getContext('2d');

                    canvas.width = img.width;
                    canvas.height = img.height;

                    ctx.drawImage(img, 0, 0);

                    const imageData = ctx.getImageData(0, 0, img.width, img.height);

                    resolve(imageData);

                } catch (error) {
                    reject(new Error(`Failed to process image: ${error.message}`));
                }
            };

            img.onerror = () => {
                reject(new Error('Failed to load PNG image'));
            };

            const url = URL.createObjectURL(file);
            img.src = url;

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

    async getComponentData() {
        if (!this.initialized) {
            throw new Error('PNG converter not initialized');
        }

        const mapPtr = this.Module._malloc(8000);
        const scrPtr = this.Module._malloc(1000);
        const colPtr = this.Module._malloc(1000);

        try {
            this.Module.ccall('png_converter_get_map_data', 'number', ['number'], [mapPtr]);
            const mapData = new Uint8Array(8000);
            mapData.set(this.Module.HEAPU8.subarray(mapPtr, mapPtr + 8000));

            this.Module.ccall('png_converter_get_scr_data', 'number', ['number'], [scrPtr]);
            const scrData = new Uint8Array(1000);
            scrData.set(this.Module.HEAPU8.subarray(scrPtr, scrPtr + 1000));

            this.Module.ccall('png_converter_get_col_data', 'number', ['number'], [colPtr]);
            const colData = new Uint8Array(1000);
            colData.set(this.Module.HEAPU8.subarray(colPtr, colPtr + 1000));

            return {
                bitmap: mapData,
                screen: scrData,
                color: colData,
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

window.PNGConverter = PNGConverter;