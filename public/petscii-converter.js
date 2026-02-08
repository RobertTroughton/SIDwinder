/**
 * PETSCII Converter Module
 * Converts PNG images to PETSCII art by matching against C64 character ROM data.
 *
 * The converter loads uppercase and lowercase PETSCII charset BIN files (2048 bytes each,
 * 256 chars x 8 bytes), then for each 8x8 cell of the input image finds the best
 * matching character + foreground color combination.
 *
 * Output format (721 bytes):
 *   Bytes 0x000-0x167: Screen codes (40 x 9 = 360 bytes)
 *   Bytes 0x168-0x2CF: Color RAM values (40 x 9 = 360 bytes)
 *   Byte  0x2D0:       Charset type (0 = uppercase, 1 = lowercase)
 */

class PETSCIIConverter {
    constructor() {
        this.uppercaseCharset = null;
        this.lowercaseCharset = null;
        this.charsetPaths = {
            uppercase: 'PNG/PETSCIICharsets/petscii-uppercase.bin',
            lowercase: 'PNG/PETSCIICharsets/petscii-lowercase.bin'
        };

        // C64 color palette (VICE PAL values)
        this.C64_PALETTE = [
            [0x00, 0x00, 0x00], // 0: Black
            [0xFF, 0xFF, 0xFF], // 1: White
            [0x81, 0x33, 0x38], // 2: Red
            [0x75, 0xCE, 0xC8], // 3: Cyan
            [0x8E, 0x3C, 0x97], // 4: Purple
            [0x56, 0xAC, 0x4D], // 5: Green
            [0x2E, 0x2C, 0x9B], // 6: Blue
            [0xED, 0xF1, 0x71], // 7: Yellow
            [0x8E, 0x50, 0x29], // 8: Orange
            [0x55, 0x38, 0x00], // 9: Brown
            [0xC4, 0x6C, 0x71], // 10: Light Red
            [0x4A, 0x4A, 0x4A], // 11: Dark Grey
            [0x7B, 0x7B, 0x7B], // 12: Grey
            [0xA9, 0xFF, 0x9F], // 13: Light Green
            [0x70, 0x6D, 0xEB], // 14: Light Blue
            [0xB2, 0xB2, 0xB2]  // 15: Light Grey
        ];

        this.LOGO_COLS = 40;
        this.LOGO_ROWS = 9;
        this.CELL_WIDTH = 8;
        this.CELL_HEIGHT = 8;
    }

    /**
     * Load a charset BIN file
     * @param {string} url - Path to the BIN file
     * @returns {Promise<Uint8Array>} - 2048 bytes of charset data
     */
    async loadCharset(url) {
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`Failed to load charset from ${url}: HTTP ${response.status}`);
        }
        const arrayBuffer = await response.arrayBuffer();
        const data = new Uint8Array(arrayBuffer);
        if (data.length < 2048) {
            throw new Error(`Charset file too small: ${data.length} bytes (expected 2048)`);
        }
        return data;
    }

    /**
     * Initialize - load both charset BIN files
     */
    async init() {
        try {
            this.uppercaseCharset = await this.loadCharset(this.charsetPaths.uppercase);
        } catch (e) {
            console.warn('Failed to load uppercase charset:', e.message);
            this.uppercaseCharset = null;
        }

        try {
            this.lowercaseCharset = await this.loadCharset(this.charsetPaths.lowercase);
        } catch (e) {
            console.warn('Failed to load lowercase charset:', e.message);
            this.lowercaseCharset = null;
        }

        if (!this.uppercaseCharset && !this.lowercaseCharset) {
            throw new Error('No PETSCII charset BIN files available. Place petscii-uppercase.bin and/or petscii-lowercase.bin in PNG/PETSCIICharsets/');
        }
    }

    /**
     * Set charset data directly (e.g., from user-uploaded BIN files)
     * @param {Uint8Array} uppercase - Uppercase charset (2048 bytes)
     * @param {Uint8Array} lowercase - Lowercase charset (2048 bytes)
     */
    setCharsets(uppercase, lowercase) {
        if (uppercase && uppercase.length >= 2048) this.uppercaseCharset = uppercase;
        if (lowercase && lowercase.length >= 2048) this.lowercaseCharset = lowercase;
    }

    /**
     * Get the 8-byte bitmap pattern for a character from a charset
     * @param {Uint8Array} charset - The charset data (2048 bytes)
     * @param {number} charIndex - Character index (0-255)
     * @returns {Uint8Array} - 8 bytes of character bitmap data
     */
    getCharBitmap(charset, charIndex) {
        const offset = (charIndex & 0xFF) * 8;
        return charset.slice(offset, offset + 8);
    }

    /**
     * Calculate the squared color distance between two RGB colors
     */
    colorDistanceSq(r1, g1, b1, r2, g2, b2) {
        const dr = r1 - r2;
        const dg = g1 - g2;
        const db = b1 - b2;
        return dr * dr + dg * dg + db * db;
    }

    /**
     * Find the best matching character + color for an 8x8 cell
     * @param {ImageData} imageData - Source image data
     * @param {number} cellX - Cell column (0-39)
     * @param {number} cellY - Cell row (0-8)
     * @param {Uint8Array} charset - Character set data
     * @param {number} bgColorIndex - Background color index (0-15)
     * @returns {{charIndex: number, colorIndex: number, error: number}}
     */
    matchCell(imageData, cellX, cellY, charset, bgColorIndex) {
        const { data, width } = imageData;
        const bgColor = this.C64_PALETTE[bgColorIndex];
        const startX = cellX * this.CELL_WIDTH;
        const startY = cellY * this.CELL_HEIGHT;

        // Pre-extract the 8x8 pixel RGB values from the source image
        const cellPixels = new Array(64);
        for (let row = 0; row < 8; row++) {
            for (let col = 0; col < 8; col++) {
                const px = startX + col;
                const py = startY + row;
                if (px < width && py < imageData.height) {
                    const idx = (py * width + px) * 4;
                    cellPixels[row * 8 + col] = [data[idx], data[idx + 1], data[idx + 2]];
                } else {
                    cellPixels[row * 8 + col] = [bgColor[0], bgColor[1], bgColor[2]];
                }
            }
        }

        let bestChar = 32; // space
        let bestColor = 0;
        let bestError = Infinity;

        // Try all 256 characters
        for (let ch = 0; ch < 256; ch++) {
            const charBitmap = this.getCharBitmap(charset, ch);

            // Count set and clear pixels for early optimization
            let setBits = 0;
            for (let b = 0; b < 8; b++) {
                let byte = charBitmap[b];
                while (byte) { setBits += byte & 1; byte >>= 1; }
            }

            if (setBits === 0) {
                // All pixels are background - only one option, check it
                let error = 0;
                for (let i = 0; i < 64; i++) {
                    const [sr, sg, sb] = cellPixels[i];
                    error += this.colorDistanceSq(sr, sg, sb, bgColor[0], bgColor[1], bgColor[2]);
                }
                if (error < bestError) {
                    bestError = error;
                    bestChar = ch;
                    bestColor = 0;
                }
                continue;
            }

            // For non-empty characters, try all 16 foreground colors
            for (let fg = 0; fg < 16; fg++) {
                // Skip if fg == bg for non-empty chars (result identical to space)
                if (fg === bgColorIndex && setBits > 0 && setBits < 64) continue;

                const fgColor = this.C64_PALETTE[fg];
                let error = 0;

                for (let row = 0; row < 8; row++) {
                    let bits = charBitmap[row];
                    for (let col = 0; col < 8; col++) {
                        const pixel = cellPixels[row * 8 + col];
                        const isSet = (bits & 0x80) !== 0;
                        bits <<= 1;

                        const dispColor = isSet ? fgColor : bgColor;
                        error += this.colorDistanceSq(
                            pixel[0], pixel[1], pixel[2],
                            dispColor[0], dispColor[1], dispColor[2]
                        );

                        // Early exit if already worse than best
                        if (error >= bestError) break;
                    }
                    if (error >= bestError) break;
                }

                if (error < bestError) {
                    bestError = error;
                    bestChar = ch;
                    bestColor = fg;
                }
            }
        }

        return { charIndex: bestChar, colorIndex: bestColor, error: bestError };
    }

    /**
     * Convert a PNG image to PETSCII logo data
     * @param {File|Blob} pngFile - The PNG file to convert
     * @param {number} bgColorIndex - Background color index (0-15), default 0 (black)
     * @returns {Promise<Uint8Array>} - 721 bytes: 360 screen codes + 360 colors + 1 charset type
     */
    async convertPNGToPETSCII(pngFile, bgColorIndex = 0) {
        if (!this.uppercaseCharset && !this.lowercaseCharset) {
            await this.init();
        }

        // Load the PNG image
        const imageData = await this.loadPNGImageData(pngFile);

        // Try both charsets and pick the one with lower total error
        const charsets = [];
        if (this.uppercaseCharset) charsets.push({ data: this.uppercaseCharset, type: 0, name: 'uppercase' });
        if (this.lowercaseCharset) charsets.push({ data: this.lowercaseCharset, type: 1, name: 'lowercase' });

        let bestResult = null;
        let bestTotalError = Infinity;
        let bestCharsetType = 0;

        for (const charset of charsets) {
            const screenCodes = new Uint8Array(this.LOGO_COLS * this.LOGO_ROWS);
            const colorData = new Uint8Array(this.LOGO_COLS * this.LOGO_ROWS);
            let totalError = 0;

            for (let row = 0; row < this.LOGO_ROWS; row++) {
                for (let col = 0; col < this.LOGO_COLS; col++) {
                    const match = this.matchCell(imageData, col, row, charset.data, bgColorIndex);
                    const idx = row * this.LOGO_COLS + col;
                    screenCodes[idx] = match.charIndex;
                    colorData[idx] = match.colorIndex;
                    totalError += match.error;
                }
            }

            if (totalError < bestTotalError) {
                bestTotalError = totalError;
                bestResult = { screenCodes, colorData };
                bestCharsetType = charset.type;
            }

            console.log(`PETSCII match with ${charset.name} charset: total error = ${totalError}`);
        }

        // Pack result: screen codes + color data + charset type
        const totalSize = (this.LOGO_COLS * this.LOGO_ROWS * 2) + 1; // 721 bytes
        const result = new Uint8Array(totalSize);
        result.set(bestResult.screenCodes, 0);
        result.set(bestResult.colorData, this.LOGO_COLS * this.LOGO_ROWS);
        result[totalSize - 1] = bestCharsetType;

        return result;
    }

    /**
     * Load a PNG file and get its ImageData, scaled to 320x72
     * @param {File|Blob} pngFile - The PNG file
     * @returns {Promise<ImageData>} - 320x72 ImageData
     */
    loadPNGImageData(pngFile) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();

            reader.onload = (e) => {
                const img = new Image();

                img.onload = () => {
                    const targetWidth = this.LOGO_COLS * this.CELL_WIDTH;   // 320
                    const targetHeight = this.LOGO_ROWS * this.CELL_HEIGHT; // 72

                    const canvas = document.createElement('canvas');
                    canvas.width = targetWidth;
                    canvas.height = targetHeight;
                    const ctx = canvas.getContext('2d');

                    // Fill with black first
                    ctx.fillStyle = '#000000';
                    ctx.fillRect(0, 0, targetWidth, targetHeight);

                    // Scale the image to fit the target area, maintaining aspect ratio
                    const scaleX = targetWidth / img.width;
                    const scaleY = targetHeight / img.height;
                    const scale = Math.min(scaleX, scaleY);

                    const scaledWidth = Math.round(img.width * scale);
                    const scaledHeight = Math.round(img.height * scale);
                    const offsetX = Math.round((targetWidth - scaledWidth) / 2);
                    const offsetY = Math.round((targetHeight - scaledHeight) / 2);

                    // Use nearest-neighbor scaling for pixel art
                    ctx.imageSmoothingEnabled = false;
                    ctx.drawImage(img, offsetX, offsetY, scaledWidth, scaledHeight);

                    const imageData = ctx.getImageData(0, 0, targetWidth, targetHeight);
                    resolve(imageData);
                };

                img.onerror = () => {
                    reject(new Error('Failed to load PNG image'));
                };

                img.src = e.target.result;
            };

            reader.onerror = () => {
                reject(new Error('Failed to read PNG file'));
            };

            reader.readAsDataURL(pngFile);
        });
    }
}

// Export for use in other modules
window.PETSCIIConverter = PETSCIIConverter;
