// font-data.js - Font selection, PNG loading, and conversion to C64 charset.
//
// PNG layouts:
//   1x2 (doubled-height): 256×48 px, 8×16 per glyph, 32 cols × 3 rows = 96 glyphs
//                          mapped to screen codes 32-127
//   1x1 single-case:      128×56 px, 8×8 per glyph, 16 cols × 4 rows = 64 glyphs
//                          mapped to screen codes 0-63 (8px gap between glyph rows)
//   1x1 mixed-case:       128×88 px, 8×8 per glyph, 16 cols × 6 rows = 96 glyphs
//                          mapped to screen codes 0-95 (8px gap between glyph rows)
//
// C64 charset format is 8 bytes per char, 1 bit per pixel. 1x2 charsets reserve
// 1792 bytes (96 top halves at 0-95 + 96 bottom halves at 128-223). 1x1 charsets
// reserve 768 bytes (96 chars × 8 bytes), enough for either case layout.

const FONT_CASE_MIXED = 0;
const FONT_CASE_UPPER_ONLY = 1;
const FONT_CASE_LOWER_ONLY = 2;

// Sentinel font ID — selecting this skips charset injection so the player keeps
// using the C64 character ROM. Recognised by prg-builder and asm players.
const FONT_ID_ROM = 'rom';

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
        charsetSize: 1792,
        folder: 'PNG/Fonts/1x2'
    },
    '1x1': {
        name: '1×1 (Single Height)',
        description: 'Standard single-height font',
        // Two valid PNG sizes are accepted: 128×56 (single-case, 4 glyph rows)
        // and 128×88 (mixed-case, 6 glyph rows). The conversion function picks
        // the layout based on actual image height.
        pngWidth: 128,
        pngHeight: 56,
        glyphWidth: 8,
        glyphHeight: 8,
        glyphsPerRow: 16,
        glyphRows: 4,
        glyphRowStride: 16, // 8px glyph + 8px gap between rows
        totalGlyphs: 64,
        charsetSize: 768, // sized for the larger 96-glyph mixed-case layout
        folder: 'PNG/Fonts/1x1'
    }
};

// PNG files follow the naming convention font-{dimension}-{id}.png.
// The 'rom' entry is a sentinel — no PNG is loaded; the asm player stays in
// ROM-charset mode (prg-builder skips charset injection).
const KNOWN_FONTS = {
    '1x2': [
        { id: 'classic', name: 'Classic', caseType: FONT_CASE_MIXED, hasBinaryFallback: true },
        { id: 'syndrom', name: 'Syndrom', caseType: FONT_CASE_MIXED },
        { id: 'cupid', name: 'Cupid', caseType: FONT_CASE_MIXED },
        { id: 'mermaid', name: 'Mermaid', caseType: FONT_CASE_UPPER_ONLY },
        { id: 'yazoo', name: 'Yazoo', caseType: FONT_CASE_UPPER_ONLY },
        { id: 'compyx', name: 'Compyx', caseType: FONT_CASE_MIXED },
        { id: 'flex', name: 'Flex', caseType: FONT_CASE_UPPER_ONLY }
    ],
    '1x1': [
        { id: FONT_ID_ROM, name: 'C64 ROM', caseType: FONT_CASE_MIXED, isROM: true },
        { id: 'bizzmo-mixed', name: 'Bizzmo', caseType: FONT_CASE_MIXED },
        { id: 'flex-mixed', name: 'Flex (Mixed)', caseType: FONT_CASE_MIXED },
        { id: 'isildur-mixed', name: 'Isildur', caseType: FONT_CASE_MIXED },
        { id: 'rowdy-mixed', name: 'Rowdy', caseType: FONT_CASE_MIXED },
        { id: 'flex', name: 'Flex', caseType: FONT_CASE_UPPER_ONLY },
        { id: 'grass', name: 'Grass', caseType: FONT_CASE_UPPER_ONLY },
        { id: 'hammerfist', name: 'Hammerfist', caseType: FONT_CASE_UPPER_ONLY },
        { id: 'hedning', name: 'Hedning', caseType: FONT_CASE_UPPER_ONLY },
        { id: 'mikael', name: 'Mikael', caseType: FONT_CASE_UPPER_ONLY },
        { id: 'mirage', name: 'Mirage', caseType: FONT_CASE_UPPER_ONLY },
        { id: 'scooby', name: 'Scooby', caseType: FONT_CASE_UPPER_ONLY },
        { id: 'zscs', name: 'zscs', caseType: FONT_CASE_UPPER_ONLY }
    ]
};

// Increment when font assets change to bust the browser cache.
const FONT_ASSET_VERSION = 1;

// Prefixed to avoid collision with bar-styles-data.js's BYTES_PER_CHAR.
const FONT_BYTES_PER_CHAR = 8;

const fontDataCache = new Map();
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
    return `${dim.folder}/font-${fontType}-${fontId}.png?v=${FONT_ASSET_VERSION}`;
}

/**
 * Scan a font folder and return available fonts
 * @param {string} fontType - Font dimension type (e.g., '1x2')
 * @returns {Promise<Array>} - Array of font info objects
 */
async function discoverFonts(fontType) {
    if (fontListCache.has(fontType)) {
        return fontListCache.get(fontType);
    }

    const dimension = FONT_DIMENSIONS[fontType];
    if (!dimension) {
        console.warn(`Unknown font type: ${fontType}`);
        return [];
    }

    const knownFonts = KNOWN_FONTS[fontType] || [];
    const fonts = knownFonts.map((font, index) => {
        // ROM sentinel has no PNG to load.
        const imagePath = font.isROM ? null : getFontPath(fontType, font.id);
        return {
            value: index,
            id: font.id,
            label: font.name,
            shortLabel: font.id,
            caseType: font.caseType,
            hasBinaryFallback: font.hasBinaryFallback || false,
            isROM: !!font.isROM,
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

    for (let glyphIndex = 0; glyphIndex < dim.totalGlyphs; glyphIndex++) {
        const glyphRow = Math.floor(glyphIndex / dim.glyphsPerRow);
        const glyphCol = glyphIndex % dim.glyphsPerRow;

        const startX = glyphCol * dim.glyphWidth;
        const startY = glyphRow * dim.glyphHeight;

        // Top half goes to chars 0-95, bottom half to chars 128-223.
        const charIndexTop = glyphIndex;
        const charIndexBottom = 128 + glyphIndex;

        if (charIndexTop < 96) {
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
        if (charIndexBottom < 224) {  // chars 128-223
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
 * Convert a 1x1 PNG font image to C64 charset bytes.
 *
 * Two PNG sizes are accepted:
 *   128×56 : 16 cols × 4 rows = 64 glyphs, mapped to screen codes 0-63
 *            (single-case; the rendered glyph is replicated into the lowercase-ROM
 *            uppercase positions 65-90 so KickAss-encoded mixed-case strings
 *            still display).
 *   128×88 : 16 cols × 6 rows = 96 glyphs, mapped to screen codes 0-95.
 *
 * In both layouts, glyph rows are separated by an 8px gap so the row stride is
 * 16px (8px glyph + 8px gap). The output is always 768 bytes (96 chars × 8).
 */
function convertPNG1x1ToCharset(imageData, threshold = 128) {
    const { data, width, height } = imageData;

    if (width !== 128 || (height !== 56 && height !== 88)) {
        throw new Error(`Invalid 1x1 font PNG size: ${width}x${height}. Expected 128x56 or 128x88`);
    }

    const glyphsPerRow = 16;
    const glyphRows = height === 56 ? 4 : 6;
    const totalGlyphs = glyphsPerRow * glyphRows;
    const isSingleCase = glyphRows === 4;

    const charset = new Uint8Array(768);
    charset.fill(0);

    for (let glyphIndex = 0; glyphIndex < totalGlyphs; glyphIndex++) {
        const gRow = Math.floor(glyphIndex / glyphsPerRow);
        const gCol = glyphIndex % glyphsPerRow;
        const startX = gCol * 8;
        const startY = gRow * 16; // 8px glyph + 8px gap stride

        for (let row = 0; row < 8; row++) {
            let byte = 0;
            for (let col = 0; col < 8; col++) {
                const pixelIndex = ((startY + row) * width + (startX + col)) * 4;
                const r = data[pixelIndex];
                const g = data[pixelIndex + 1];
                const b = data[pixelIndex + 2];
                const a = data[pixelIndex + 3];
                const brightness = (r + g + b) / 3;
                if (a > 128 && brightness >= threshold) {
                    byte |= (0x80 >> col);
                }
            }
            charset[glyphIndex * FONT_BYTES_PER_CHAR + row] = byte;
        }
    }

    // Single-case fonts only define codes 0-63. Mirror the @+A-Z glyphs (codes
    // 0-26) into the lowercase-ROM uppercase positions (codes 64-90) so static
    // KickAss `.text` strings — which encode 'A'-'Z' as screen codes 65-90 in
    // the lowercase-ROM convention — still render correctly.
    if (isSingleCase) {
        for (let src = 0; src <= 26; src++) {
            const dst = 64 + src;
            const srcOff = src * FONT_BYTES_PER_CHAR;
            const dstOff = dst * FONT_BYTES_PER_CHAR;
            for (let i = 0; i < FONT_BYTES_PER_CHAR; i++) {
                charset[dstOff + i] = charset[srcOff + i];
            }
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

// Cache for font thumbnails
const fontThumbnailCache = new Map();

/**
 * Generate a 64x64 thumbnail from a font PNG (top-left corner)
 * @param {string} url - URL of the font PNG
 * @returns {Promise<string>} - Data URL of the thumbnail
 */
async function generateFontThumbnail(url) {
    const cacheKey = `thumb:${url}`;
    if (fontThumbnailCache.has(cacheKey)) {
        return fontThumbnailCache.get(cacheKey);
    }

    return new Promise((resolve, reject) => {
        const img = new Image();
        img.crossOrigin = 'anonymous';

        img.onload = () => {
            try {
                // Create a 64x64 canvas for the thumbnail
                const canvas = document.createElement('canvas');
                canvas.width = 64;
                canvas.height = 64;
                const ctx = canvas.getContext('2d');

                // Fill with black background
                ctx.fillStyle = '#000000';
                ctx.fillRect(0, 0, 64, 64);

                // Draw the top-left 64x64 pixels of the font PNG
                // Scale if needed (font is 256x48, we want top-left 64x64)
                const srcWidth = Math.min(64, img.width);
                const srcHeight = Math.min(64, img.height);
                ctx.drawImage(img, 0, 0, srcWidth, srcHeight, 0, 0, srcWidth, srcHeight);

                const dataUrl = canvas.toDataURL('image/png');
                fontThumbnailCache.set(cacheKey, dataUrl);
                resolve(dataUrl);
            } catch (error) {
                reject(error);
            }
        };

        img.onerror = () => {
            reject(new Error(`Failed to load font image for thumbnail: ${url}`));
        };

        img.src = url;
    });
}

/**
 * Get thumbnails for all fonts of a given type
 * @param {string} fontType - Font dimension type (e.g., '1x2')
 * @returns {Promise<Map<string, string>>} - Map of font ID to thumbnail data URL
 */
async function getFontThumbnails(fontType) {
    const fonts = await discoverFonts(fontType);
    const thumbnails = new Map();

    await Promise.all(fonts.map(async (font) => {
        if (font.source) {
            try {
                const thumbnail = await generateFontThumbnail(font.source);
                thumbnails.set(font.id, thumbnail);
            } catch (e) {
                console.warn(`Failed to generate thumbnail for font ${font.id}:`, e);
            }
        }
    }));

    return thumbnails;
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
    // ROM sentinel — caller should skip charset injection entirely so the
    // player keeps its baked-in $d018 ROM-charset path.
    if (font && font.id === FONT_ID_ROM) {
        return null;
    }
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

    // Thumbnail functions
    generateFontThumbnail: generateFontThumbnail,
    getFontThumbnails: getFontThumbnails,

    // UI/info functions
    getFontCaseType: getFontCaseType,
    convertTextForFont: convertTextForFont,
    getFontDimension: getFontDimension,

    // Constants
    FONT_CASE_MIXED: FONT_CASE_MIXED,
    FONT_CASE_UPPER_ONLY: FONT_CASE_UPPER_ONLY,
    FONT_CASE_LOWER_ONLY: FONT_CASE_LOWER_ONLY,
    FONT_ID_ROM: FONT_ID_ROM,
    FONT_DIMENSIONS: FONT_DIMENSIONS,
    KNOWN_FONTS: KNOWN_FONTS
};
