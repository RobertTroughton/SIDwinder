// font-data.js - Font Data and PNG Conversion for SIDwinder Web
// This module handles font selection, PNG font loading, and conversion to C64 charset format.
//
// Font Organization:
// - Fonts are organized by dimension: 1x2 (doubled-height), 1x1 (single-height), etc.
// - "1x2" means 1 char wide × 2 chars tall (8x16 pixels for doubled-height text)
// - "1x1" means 1 char wide × 1 char tall (8x8 pixels for single-height text)
//
// PNG Font Format (1x2 / doubled-height):
// - 256x48 pixels (32 glyphs across × 3 rows = 96 printable characters)
// - Each glyph is 8x16 pixels (8 wide × 16 tall for doubled-height C64 text)
// - Covers ASCII 32-127 (printable ASCII range)
//
// PNG Font Format (1x1 / single-height):
// - 256x24 pixels (32 glyphs across × 3 rows = 96 printable characters)
// - Each glyph is 8x8 pixels
//
// C64 Charset Format (1x2):
// - 8 bytes per character (8x8 pixels, 1 bit per pixel)
// - Characters 32-127: Top halves of doubled-height glyphs
// - Characters 160-255: Bottom halves of doubled-height glyphs (char + 128)
// - Total: 224 characters × 8 bytes = 1792 bytes

// Case type constants
const FONT_CASE_MIXED = 0;      // Has both upper and lowercase
const FONT_CASE_UPPER_ONLY = 1; // Only uppercase letters
const FONT_CASE_LOWER_ONLY = 2; // Only lowercase letters (rare)

// Font dimension configurations
const FONT_DIMENSIONS = {
    '1x2': {
        name: '1×2 (Doubled Height)',
        description: 'Standard doubled-height font for song/artist names',
        pngWidth: 256,
        pngHeight: 48,
        glyphWidth: 8,
        glyphHeight: 16,
        glyphsPerRow: 32,
        glyphRows: 3,
        totalGlyphs: 96,
        charsetSize: 1792,  // 224 chars × 8 bytes
        folder: 'PNG/Fonts/1x2'  // Fonts are in PNG/Fonts/1x2/ with font-1x2-*.png naming
    },
    '1x1': {
        name: '1×1 (Single Height)',
        description: 'Standard single-height font',
        pngWidth: 256,
        pngHeight: 24,
        glyphWidth: 8,
        glyphHeight: 8,
        glyphsPerRow: 32,
        glyphRows: 3,
        totalGlyphs: 96,
        charsetSize: 768,  // 96 chars × 8 bytes
        folder: 'PNG/Fonts/1x1'
    }
};

// Font registry - defines available fonts for each dimension
// Fonts use naming convention: font-{dimension}-{id}.png (e.g., font-1x2-classic.png)
const KNOWN_FONTS = {
    '1x2': [
        { id: 'classic', name: 'Classic', caseType: FONT_CASE_MIXED, hasBinaryFallback: true },
        { id: 'cupid', name: 'Cupid', caseType: FONT_CASE_MIXED },
        { id: 'mermaid', name: 'Mermaid', caseType: FONT_CASE_UPPER_ONLY },
        { id: 'yazoo', name: 'Yazoo', caseType: FONT_CASE_UPPER_ONLY },
        { id: 'compyx', name: 'Compyx', caseType: FONT_CASE_MIXED },
        { id: 'flex', name: 'Flex', caseType: FONT_CASE_UPPER_ONLY }
    ],
    '1x1': [
        { id: 'classic', name: 'Classic', caseType: FONT_CASE_MIXED }
    ]
};

// Constants (prefixed to avoid collision with bar-styles-data.js)
const FONT_BYTES_PER_CHAR = 8;

// Cache for loaded font data
const fontDataCache = new Map();

// Cache for discovered fonts per dimension
const fontListCache = new Map();

/**
 * Get the PNG path for a font
 * @param {string} fontType - Font dimension type (e.g., '1x2')
 * @param {string} fontId - Font identifier
 * @returns {string} - Path to the font PNG
 */
function getFontPath(fontType, fontId) {
    const dim = FONT_DIMENSIONS[fontType];
    if (!dim) return null;
    return `${dim.folder}/font-${fontType}-${fontId}.png`;
}

/**
 * Scan a font folder and return available fonts
 * @param {string} fontType - Font dimension type (e.g., '1x2')
 * @returns {Promise<Array>} - Array of font info objects
 */
async function discoverFonts(fontType) {
    // Check cache first
    if (fontListCache.has(fontType)) {
        return fontListCache.get(fontType);
    }

    const dimension = FONT_DIMENSIONS[fontType];
    if (!dimension) {
        console.warn(`Unknown font type: ${fontType}`);
        return [];
    }

    // Try to fetch the font index file (optional - for user-defined fonts)
    const indexUrl = `${dimension.folder}/fonts-${fontType}.json`;
    try {
        const response = await fetch(indexUrl);
        if (response.ok) {
            const fonts = await response.json();
            fontListCache.set(fontType, fonts);
            return fonts;
        }
    } catch (e) {
        // Index file doesn't exist, fall back to known fonts
    }

    // Fall back to known fonts for this dimension
    const knownFonts = KNOWN_FONTS[fontType] || [];
    const fonts = knownFonts.map((font, index) => {
        const imagePath = getFontPath(fontType, font.id);
        return {
            value: index,
            id: font.id,
            label: font.name,
            shortLabel: font.id,
            caseType: font.caseType,
            hasBinaryFallback: font.hasBinaryFallback || false,
            image: imagePath,
            source: imagePath
        };
    });

    fontListCache.set(fontType, fonts);
    return fonts;
}

/**
 * Get fonts for UI display
 * @param {string} fontType - Font dimension type (e.g., '1x2')
 * @returns {Promise<Array>} - Array of font preset objects for UI
 */
async function getFontsForType(fontType) {
    return await discoverFonts(fontType);
}

/**
 * Convert a PNG font image to C64 charset format (1x2 doubled-height)
 * @param {ImageData} imageData - The image data from a 256x48 PNG
 * @param {number} threshold - Brightness threshold for pixel detection (0-255)
 * @returns {Uint8Array} - 1792 bytes of C64 charset data
 */
function convertPNG1x2ToCharset(imageData, threshold = 128) {
    const { data, width, height } = imageData;
    const dim = FONT_DIMENSIONS['1x2'];

    if (width !== dim.pngWidth || height !== dim.pngHeight) {
        throw new Error(`Invalid 1x2 font PNG size: ${width}x${height}. Expected ${dim.pngWidth}x${dim.pngHeight}`);
    }

    const charset = new Uint8Array(dim.charsetSize);
    charset.fill(0);

    // Process each glyph in the PNG
    for (let glyphIndex = 0; glyphIndex < dim.totalGlyphs; glyphIndex++) {
        const glyphRow = Math.floor(glyphIndex / dim.glyphsPerRow);
        const glyphCol = glyphIndex % dim.glyphsPerRow;

        const startX = glyphCol * dim.glyphWidth;
        const startY = glyphRow * dim.glyphHeight;

        // C64 character indices
        const charIndexTop = 32 + glyphIndex;     // Characters 32-127
        const charIndexBottom = 160 + glyphIndex; // Characters 160-255

        // Process top half (rows 0-7 of the glyph)
        if (charIndexTop < 224) {
            for (let row = 0; row < 8; row++) {
                let byte = 0;
                for (let col = 0; col < 8; col++) {
                    const px = startX + col;
                    const py = startY + row;
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
                charset[charIndexTop * FONT_BYTES_PER_CHAR + row] = byte;
            }
        }

        // Process bottom half (rows 8-15 of the glyph)
        if (charIndexBottom < 224) {
            for (let row = 0; row < 8; row++) {
                let byte = 0;
                for (let col = 0; col < 8; col++) {
                    const px = startX + col;
                    const py = startY + 8 + row;
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
                charset[charIndexBottom * FONT_BYTES_PER_CHAR + row] = byte;
            }
        }
    }

    return charset;
}

/**
 * Convert a PNG font image to C64 charset format (1x1 single-height)
 * @param {ImageData} imageData - The image data from a 256x24 PNG
 * @param {number} threshold - Brightness threshold for pixel detection (0-255)
 * @returns {Uint8Array} - 768 bytes of C64 charset data
 */
function convertPNG1x1ToCharset(imageData, threshold = 128) {
    const { data, width, height } = imageData;
    const dim = FONT_DIMENSIONS['1x1'];

    if (width !== dim.pngWidth || height !== dim.pngHeight) {
        throw new Error(`Invalid 1x1 font PNG size: ${width}x${height}. Expected ${dim.pngWidth}x${dim.pngHeight}`);
    }

    const charset = new Uint8Array(dim.charsetSize);
    charset.fill(0);

    for (let glyphIndex = 0; glyphIndex < dim.totalGlyphs; glyphIndex++) {
        const glyphRow = Math.floor(glyphIndex / dim.glyphsPerRow);
        const glyphCol = glyphIndex % dim.glyphsPerRow;

        const startX = glyphCol * dim.glyphWidth;
        const startY = glyphRow * dim.glyphHeight;

        const charIndex = 32 + glyphIndex;

        for (let row = 0; row < 8; row++) {
            let byte = 0;
            for (let col = 0; col < 8; col++) {
                const px = startX + col;
                const py = startY + row;
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
            charset[charIndex * FONT_BYTES_PER_CHAR + row] = byte;
        }
    }

    return charset;
}

/**
 * Load and convert a font PNG file to C64 charset format
 * @param {string} url - URL of the PNG file
 * @param {string} fontType - Font dimension type (e.g., '1x2')
 * @returns {Promise<Uint8Array>} - Charset data
 */
async function loadFontPNG(url, fontType = '1x2') {
    const cacheKey = `${url}:${fontType}`;
    if (fontDataCache.has(cacheKey)) {
        return fontDataCache.get(cacheKey);
    }

    return new Promise((resolve, reject) => {
        const img = new Image();
        img.crossOrigin = 'anonymous';

        img.onload = () => {
            try {
                const canvas = document.createElement('canvas');
                canvas.width = img.width;
                canvas.height = img.height;
                const ctx = canvas.getContext('2d');
                ctx.drawImage(img, 0, 0);

                const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);

                let charset;
                if (fontType === '1x2') {
                    charset = convertPNG1x2ToCharset(imageData);
                } else if (fontType === '1x1') {
                    charset = convertPNG1x1ToCharset(imageData);
                } else {
                    throw new Error(`Unknown font type: ${fontType}`);
                }

                fontDataCache.set(cacheKey, charset);
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
 * @param {string} fontType - Font dimension type (e.g., '1x2')
 * @returns {Promise<Uint8Array>} - Charset data
 */
async function loadFontFromFile(file, fontType = '1x2') {
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

                    let charset;
                    if (fontType === '1x2') {
                        charset = convertPNG1x2ToCharset(imageData);
                    } else if (fontType === '1x1') {
                        charset = convertPNG1x1ToCharset(imageData);
                    } else {
                        throw new Error(`Unknown font type: ${fontType}`);
                    }

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
 * Load font data from a binary file (extracts charset at specified offset)
 * @param {string} url - URL of the binary file
 * @param {number} offset - Byte offset to the charset data
 * @param {number} size - Number of bytes to extract
 * @returns {Promise<Uint8Array>} - Charset data
 */
async function loadFontFromBinary(url, offset, size) {
    const cacheKey = `binary:${url}:${offset}:${size}`;
    if (fontDataCache.has(cacheKey)) {
        return fontDataCache.get(cacheKey);
    }

    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`Failed to load binary font from ${url}`);
    }

    const arrayBuffer = await response.arrayBuffer();
    const fullData = new Uint8Array(arrayBuffer);

    if (offset + size > fullData.length) {
        throw new Error(`Binary file too small: need ${offset + size} bytes, got ${fullData.length}`);
    }

    const charsetData = fullData.slice(offset, offset + size);
    fontDataCache.set(cacheKey, charsetData);
    return charsetData;
}

/**
 * Get font data for a specific font
 * @param {string} fontType - Font dimension type (e.g., '1x2')
 * @param {number} fontIndex - Index into the fonts for this type
 * @param {Object} fallbackConfig - Optional fallback configuration {binarySource, binaryOffset}
 * @returns {Promise<Uint8Array>} - Charset data
 */
async function getFontData(fontType, fontIndex, fallbackConfig = null) {
    const fonts = await discoverFonts(fontType);

    if (fontIndex < 0 || fontIndex >= fonts.length) {
        fontIndex = 0;
    }

    const font = fonts[fontIndex];
    if (!font) {
        // No fonts available at all
        if (fallbackConfig && fallbackConfig.binarySource) {
            console.warn('No fonts defined, using binary fallback');
            const dim = FONT_DIMENSIONS[fontType];
            return await loadFontFromBinary(
                fallbackConfig.binarySource,
                fallbackConfig.binaryOffset,
                dim ? dim.charsetSize : 1792
            );
        }
        console.error('No fonts available and no fallback configured');
        return new Uint8Array(FONT_DIMENSIONS[fontType]?.charsetSize || 1792);
    }

    // Try loading the PNG
    if (font.source) {
        try {
            return await loadFontPNG(font.source, fontType);
        } catch (pngError) {
            console.warn(`PNG font "${font.label}" not available:`, pngError.message);
        }
    }

    // If this is font 0 and we have a fallback, use it
    if (fontIndex === 0 && fallbackConfig && fallbackConfig.binarySource) {
        try {
            console.log('Using binary fallback for default font');
            const dim = FONT_DIMENSIONS[fontType];
            return await loadFontFromBinary(
                fallbackConfig.binarySource,
                fallbackConfig.binaryOffset,
                dim ? dim.charsetSize : 1792
            );
        } catch (binaryError) {
            console.warn('Binary fallback failed:', binaryError);
        }
    }

    // For non-zero fonts, try falling back to font 0
    if (fontIndex !== 0) {
        console.warn(`Font "${font.label}" not available, falling back to default`);
        return await getFontData(fontType, 0, fallbackConfig);
    }

    // Nothing worked
    console.error('All font loading attempts failed');
    return new Uint8Array(FONT_DIMENSIONS[fontType]?.charsetSize || 1792);
}

/**
 * Get case type for a font
 * @param {string} fontType - Font dimension type
 * @param {number} fontIndex - Index into the fonts
 * @returns {Promise<number>} - FONT_CASE_* constant
 */
async function getFontCaseType(fontType, fontIndex) {
    const fonts = await discoverFonts(fontType);
    if (fontIndex < 0 || fontIndex >= fonts.length) {
        return FONT_CASE_MIXED;
    }
    return fonts[fontIndex].caseType ?? FONT_CASE_MIXED;
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
 * Get dimension info for a font type
 * @param {string} fontType - Font dimension type
 * @returns {Object} - Dimension configuration
 */
function getFontDimension(fontType) {
    return FONT_DIMENSIONS[fontType] || null;
}

// Export for use in other modules
window.FONT_DATA = {
    // Font loading functions
    getFontData: getFontData,
    getFontsForType: getFontsForType,
    discoverFonts: discoverFonts,
    loadFontPNG: loadFontPNG,
    loadFontFromFile: loadFontFromFile,
    loadFontFromBinary: loadFontFromBinary,
    getFontPath: getFontPath,

    // Conversion functions
    convertPNG1x2ToCharset: convertPNG1x2ToCharset,
    convertPNG1x1ToCharset: convertPNG1x1ToCharset,

    // UI/info functions
    getFontCaseType: getFontCaseType,
    convertTextForFont: convertTextForFont,
    getFontDimension: getFontDimension,

    // Constants
    FONT_CASE_MIXED: FONT_CASE_MIXED,
    FONT_CASE_UPPER_ONLY: FONT_CASE_UPPER_ONLY,
    FONT_CASE_LOWER_ONLY: FONT_CASE_LOWER_ONLY,
    FONT_DIMENSIONS: FONT_DIMENSIONS,
    KNOWN_FONTS: KNOWN_FONTS
};
