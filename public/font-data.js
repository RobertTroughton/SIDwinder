// font-data.js - Font Data and PNG Conversion for SIDwinder Web
// This module handles font selection, PNG font loading, and conversion to C64 charset format.
//
// PNG Font Format:
// - 256x48 pixels (32 glyphs across × 3 rows = 96 printable characters)
// - Each glyph is 8x16 pixels (8 wide × 16 tall for doubled-height C64 text)
// - Covers ASCII 32-127 (printable ASCII range)
// - Foreground pixels are non-black, background pixels are black (or near-black)
//
// C64 Charset Format:
// - 8 bytes per character (8x8 pixels, 1 bit per pixel)
// - Characters 32-127: Top halves of doubled-height glyphs
// - Characters 160-255: Bottom halves of doubled-height glyphs (char + 128)
// - Total: 224 characters × 8 bytes = 1792 bytes

// Case type constants
const FONT_CASE_MIXED = 0;      // Has both upper and lowercase
const FONT_CASE_UPPER_ONLY = 1; // Only uppercase letters
const FONT_CASE_LOWER_ONLY = 2; // Only lowercase letters (rare)

// Font definitions
// Each font can have either a 'source' (PNG file) or 'binarySource' (binary .map file)
// If source is not available, binarySource is used as fallback
const FONT_PRESETS = [
    {
        id: 'default',
        name: 'Classic',
        description: 'Default SIDwinder font',
        caseType: FONT_CASE_MIXED,
        preview: 'PNG/Fonts/font-classic.png',
        source: 'PNG/Fonts/font-classic.png',
        binarySource: 'prg/RaistlinBars-4000.bin',  // Fallback: extract from binary
        binaryOffset: 0x3800,                        // Offset to charset in binary (0x7800 - 0x4000)
        binarySize: CHARSET_SIZE
    },
    {
        id: 'bold',
        name: 'Bold',
        description: 'Bold blocky font',
        caseType: FONT_CASE_UPPER_ONLY,
        preview: 'PNG/Fonts/font-bold.png',
        source: 'PNG/Fonts/font-bold.png'
    },
    {
        id: 'thin',
        name: 'Thin',
        description: 'Thin elegant font',
        caseType: FONT_CASE_MIXED,
        preview: 'PNG/Fonts/font-thin.png',
        source: 'PNG/Fonts/font-thin.png'
    },
    {
        id: 'retro',
        name: 'Retro',
        description: 'Retro computer style',
        caseType: FONT_CASE_UPPER_ONLY,
        preview: 'PNG/Fonts/font-retro.png',
        source: 'PNG/Fonts/font-retro.png'
    },
    {
        id: 'pixel',
        name: 'Pixel',
        description: 'Pixel art style',
        caseType: FONT_CASE_UPPER_ONLY,
        preview: 'PNG/Fonts/font-pixel.png',
        source: 'PNG/Fonts/font-pixel.png'
    },
    {
        id: 'rounded',
        name: 'Rounded',
        description: 'Soft rounded characters',
        caseType: FONT_CASE_MIXED,
        preview: 'PNG/Fonts/font-rounded.png',
        source: 'PNG/Fonts/font-rounded.png'
    }
];

// Constants
const FONT_PNG_WIDTH = 256;
const FONT_PNG_HEIGHT = 48;
const GLYPH_WIDTH = 8;
const GLYPH_HEIGHT = 16;
const GLYPHS_PER_ROW = 32;
const GLYPH_ROWS = 3;
const TOTAL_GLYPHS = 96;  // Printable ASCII (32-127)
const BYTES_PER_CHAR = 8;
const CHARSET_SIZE = 1792;  // 224 chars × 8 bytes

// Cache for loaded font data
const fontDataCache = new Map();

/**
 * Convert a PNG font image to C64 charset format
 * @param {ImageData} imageData - The image data from a 256x48 PNG
 * @param {number} threshold - Brightness threshold for pixel detection (0-255)
 * @returns {Uint8Array} - 1792 bytes of C64 charset data
 */
function convertPNGToCharset(imageData, threshold = 128) {
    const { data, width, height } = imageData;

    if (width !== FONT_PNG_WIDTH || height !== FONT_PNG_HEIGHT) {
        throw new Error(`Invalid font PNG size: ${width}x${height}. Expected ${FONT_PNG_WIDTH}x${FONT_PNG_HEIGHT}`);
    }

    // Output charset: 224 characters × 8 bytes
    const charset = new Uint8Array(CHARSET_SIZE);
    charset.fill(0);

    // Process each glyph in the PNG
    for (let glyphIndex = 0; glyphIndex < TOTAL_GLYPHS; glyphIndex++) {
        const glyphRow = Math.floor(glyphIndex / GLYPHS_PER_ROW);
        const glyphCol = glyphIndex % GLYPHS_PER_ROW;

        // Position in the PNG
        const startX = glyphCol * GLYPH_WIDTH;
        const startY = glyphRow * GLYPH_HEIGHT;

        // C64 character indices (ASCII 32 + glyphIndex)
        // Top half goes to char index, bottom half goes to char index + 128
        const charIndexTop = 32 + glyphIndex;     // Characters 32-127
        const charIndexBottom = 160 + glyphIndex; // Characters 160-255

        // But we only have 224 characters (0-223 used)
        // Top halves: 32-127 (96 chars)
        // Bottom halves: need to be at char 32+128=160, but we only have up to 223
        // Actually looking at the ASM: chars 0-223 for font, 224-255 for bar styles
        // So bottom halves should be at 128-223 (96 chars)

        // Let me re-check the code:
        // SongName char goes to screen directly (chars 32-127 for text)
        // Then OR with $80 to get chars 160-255 for bottom half
        // But charset only has 224 characters (0-223)
        // This means bottom halves are at 160-223 (64 chars) and we lose some

        // Actually, looking more carefully:
        // - Chars 32-95 (64) for text like space, numbers, uppercase
        // - Chars 160-223 (64) for their bottom halves
        // Lowercase (96-127) would map to 224-255 which are bar style chars!

        // For safety, let's only handle chars 32-95 (top) and 160-223 (bottom)
        // This covers space, numbers, uppercase, and common punctuation

        if (charIndexTop > 127) continue;  // Skip if would exceed charset

        // Process top half (8x8 pixels, rows 0-7 of the glyph)
        if (charIndexTop < 224) {
            for (let row = 0; row < 8; row++) {
                let byte = 0;
                for (let col = 0; col < 8; col++) {
                    const px = startX + col;
                    const py = startY + row;
                    const pixelIndex = (py * width + px) * 4;

                    // Calculate brightness from RGB
                    const r = data[pixelIndex];
                    const g = data[pixelIndex + 1];
                    const b = data[pixelIndex + 2];
                    const a = data[pixelIndex + 3];
                    const brightness = (r + g + b) / 3;

                    // Set bit if pixel is bright enough and not transparent
                    if (a > 128 && brightness >= threshold) {
                        byte |= (0x80 >> col);
                    }
                }
                charset[charIndexTop * BYTES_PER_CHAR + row] = byte;
            }
        }

        // Process bottom half (8x8 pixels, rows 8-15 of the glyph)
        if (charIndexBottom < 224) {
            for (let row = 0; row < 8; row++) {
                let byte = 0;
                for (let col = 0; col < 8; col++) {
                    const px = startX + col;
                    const py = startY + 8 + row;  // Bottom half starts at row 8
                    const pixelIndex = (py * width + px) * 4;

                    const r = data[pixelIndex];
                    const g = data[pixelIndex + 1];
                    const b = data[pixelIndex + 2];
                    const a = data[pixelIndex + 3];
                    const brightness = (r + g + b) / 3;

                    if (a > 128 && brightness >= threshold) {
                        byte |= (0x80 >> col);
                    }
                }
                charset[charIndexBottom * BYTES_PER_CHAR + row] = byte;
            }
        }
    }

    return charset;
}

/**
 * Load and convert a font PNG file to C64 charset format
 * @param {string} url - URL of the PNG file
 * @returns {Promise<Uint8Array>} - 1792 bytes of C64 charset data
 */
async function loadFontPNG(url) {
    // Check cache first
    if (fontDataCache.has(url)) {
        return fontDataCache.get(url);
    }

    return new Promise((resolve, reject) => {
        const img = new Image();
        img.crossOrigin = 'anonymous';

        img.onload = () => {
            try {
                // Create canvas to extract pixel data
                const canvas = document.createElement('canvas');
                canvas.width = img.width;
                canvas.height = img.height;
                const ctx = canvas.getContext('2d');
                ctx.drawImage(img, 0, 0);

                const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
                const charset = convertPNGToCharset(imageData);

                // Cache the result
                fontDataCache.set(url, charset);
                resolve(charset);
            } catch (error) {
                reject(error);
            }
        };

        img.onerror = () => {
            reject(new Error(`Failed to load font image: ${url}`));
        };

        img.src = url;
    });
}

/**
 * Load font data from a File object (user-uploaded PNG)
 * @param {File} file - The PNG file
 * @returns {Promise<Uint8Array>} - 1792 bytes of C64 charset data
 */
async function loadFontFromFile(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();

        reader.onload = (e) => {
            const img = new Image();

            img.onload = () => {
                try {
                    const canvas = document.createElement('canvas');
                    canvas.width = img.width;
                    canvas.height = img.height;
                    const ctx = canvas.getContext('2d');
                    ctx.drawImage(img, 0, 0);

                    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
                    const charset = convertPNGToCharset(imageData);
                    resolve(charset);
                } catch (error) {
                    reject(error);
                }
            };

            img.onerror = () => {
                reject(new Error('Failed to load font image'));
            };

            img.src = e.target.result;
        };

        reader.onerror = () => {
            reject(new Error('Failed to read font file'));
        };

        reader.readAsDataURL(file);
    });
}

/**
 * Get font data for a preset font
 * @param {number} fontIndex - Index into FONT_PRESETS
 * @returns {Promise<Uint8Array>} - 1792 bytes of C64 charset data
 */
async function getFontData(fontIndex) {
    if (fontIndex < 0 || fontIndex >= FONT_PRESETS.length) {
        fontIndex = 0;  // Default to first font
    }

    const preset = FONT_PRESETS[fontIndex];

    // Try loading PNG source first
    if (preset.source) {
        try {
            return await loadFontPNG(preset.source);
        } catch (pngError) {
            console.warn(`PNG font not available for "${preset.name}", trying fallback...`);
        }
    }

    // Fallback to binary source if available
    if (preset.binarySource) {
        try {
            return await loadFontFromBinary(preset.binarySource, preset.binaryOffset, preset.binarySize);
        } catch (binaryError) {
            console.warn(`Binary fallback failed for "${preset.name}":`, binaryError);
        }
    }

    // If font 0 failed completely, we have a problem - return empty charset
    if (fontIndex === 0) {
        console.error('Default font not available, returning empty charset');
        return new Uint8Array(CHARSET_SIZE);
    }

    // For other fonts, try to fall back to font 0
    console.warn(`Font "${preset.name}" not available, falling back to default`);
    return await getFontData(0);
}

/**
 * Load font data from a binary file (extracts charset at specified offset)
 * @param {string} url - URL of the binary file
 * @param {number} offset - Byte offset to the charset data
 * @param {number} size - Number of bytes to extract
 * @returns {Promise<Uint8Array>} - Charset data
 */
async function loadFontFromBinary(url, offset, size) {
    // Check cache first
    const cacheKey = `${url}:${offset}:${size}`;
    if (fontDataCache.has(cacheKey)) {
        return fontDataCache.get(cacheKey);
    }

    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`Failed to load binary font from ${url}`);
    }

    const arrayBuffer = await response.arrayBuffer();
    const fullData = new Uint8Array(arrayBuffer);

    // Extract the charset portion
    if (offset + size > fullData.length) {
        throw new Error(`Binary file too small: need ${offset + size} bytes, got ${fullData.length}`);
    }

    const charsetData = fullData.slice(offset, offset + size);

    // Cache the result
    fontDataCache.set(cacheKey, charsetData);
    return charsetData;
}

/**
 * Get font preset info for UI display
 * @returns {Array} - Array of font preset objects
 */
function getFontPresetInfo() {
    return FONT_PRESETS.map((preset, index) => ({
        value: index,
        label: preset.name,
        shortLabel: preset.name.toLowerCase(),
        description: preset.description,
        image: preset.preview,
        caseType: preset.caseType
    }));
}

/**
 * Get case type for a font preset
 * @param {number} fontIndex - Index into FONT_PRESETS
 * @returns {number} - FONT_CASE_* constant
 */
function getFontCaseType(fontIndex) {
    if (fontIndex < 0 || fontIndex >= FONT_PRESETS.length) {
        return FONT_CASE_MIXED;
    }
    return FONT_PRESETS[fontIndex].caseType;
}

/**
 * Convert text to match font case capability
 * @param {string} text - Input text
 * @param {number} caseType - FONT_CASE_* constant
 * @returns {string} - Converted text
 */
function convertTextForFont(text, caseType) {
    switch (caseType) {
        case FONT_CASE_UPPER_ONLY:
            return text.toUpperCase();
        case FONT_CASE_LOWER_ONLY:
            return text.toLowerCase();
        case FONT_CASE_MIXED:
        default:
            return text;
    }
}

/**
 * Load the default/fallback font from binary
 * @param {string} url - URL to the binary .map file
 * @returns {Promise<Uint8Array>} - Raw charset bytes
 */
async function loadBinaryFont(url) {
    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`Failed to load font: ${url}`);
    }
    const arrayBuffer = await response.arrayBuffer();
    return new Uint8Array(arrayBuffer);
}

// Export for use in other modules
window.FONT_DATA = {
    // Font loading functions
    getFontData: getFontData,
    loadFontPNG: loadFontPNG,
    loadFontFromFile: loadFontFromFile,
    loadFontFromBinary: loadFontFromBinary,
    loadBinaryFont: loadBinaryFont,
    convertPNGToCharset: convertPNGToCharset,

    // UI info functions
    getFontPresetInfo: getFontPresetInfo,
    getFontCaseType: getFontCaseType,
    convertTextForFont: convertTextForFont,

    // Constants
    FONT_CASE_MIXED: FONT_CASE_MIXED,
    FONT_CASE_UPPER_ONLY: FONT_CASE_UPPER_ONLY,
    FONT_CASE_LOWER_ONLY: FONT_CASE_LOWER_ONLY,
    CHARSET_SIZE: CHARSET_SIZE,
    NUM_FONTS: FONT_PRESETS.length,
    FONT_PRESETS: FONT_PRESETS
};
