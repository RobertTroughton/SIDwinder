/**
 * PETSCII Text Sanitizer Module
 * Converts modern text to C64-compatible PETSCII format
 * Ensures one byte per character output
 */

class PETSCIISanitizer {
    constructor() {
        // Map of Unicode/extended characters to PETSCII equivalents
        // Using Unicode values to avoid quote escaping issues
        this.charMap = {
            // Smart quotes - all convert to standard ASCII quote (34)
            0x201C: 34,  // " Left double quotation mark
            0x201D: 34,  // " Right double quotation mark  
            0x201E: 34,  // „ Double low-9 quotation mark

            // Smart apostrophes - all convert to standard ASCII apostrophe (39)
            0x2018: 39,  // ' Left single quotation mark
            0x2019: 39,  // ' Right single quotation mark
            0x201A: 39,  // ‚ Single low-9 quotation mark

            // Dashes - all convert to standard ASCII hyphen-minus (45)
            0x2010: 45,  // ‐ Hyphen
            0x2011: 45,  // ‑ Non-breaking hyphen
            0x2012: 45,  // ‒ Figure dash
            0x2013: 45,  // – En dash
            0x2014: 45,  // — Em dash
            0x2015: 45,  // ― Horizontal bar
            0x2212: 45,  // − Minus sign

            // Space variants - all convert to standard space (32)
            0x00A0: 32,  // Non-breaking space
            0x2000: 32,  // En quad
            0x2001: 32,  // Em quad
            0x2002: 32,  // En space
            0x2003: 32,  // Em space
            0x2004: 32,  // Three-per-em space
            0x2005: 32,  // Four-per-em space
            0x2006: 32,  // Six-per-em space
            0x2007: 32,  // Figure space
            0x2008: 32,  // Punctuation space
            0x2009: 32,  // Thin space
            0x200A: 32,  // Hair space
            0x202F: 32,  // Narrow no-break space
            0x205F: 32,  // Medium mathematical space

            // Other punctuation - Note: ellipsis handled separately
            0x2022: 42,  // • Bullet to asterisk
            0x00B7: 46,  // · Middle dot to period
        };

        this.warnings = [];
    }

    /**
     * Sanitize text for PETSCII compatibility
     * @param {string} text - Input text to sanitize
     * @param {Object} options - Options for sanitization
     * @returns {Object} - Sanitized text and any warnings
     */
    sanitize(text, options = {}) {
        const {
            maxLength = null,
            padToLength = null,
            center = false,
            reportUnknown = true
        } = options;

        this.warnings = [];
        if (!text) {
            return {
                text: padToLength ? ' '.repeat(padToLength) : '',
                warnings: [],
                hasWarnings: false,
                originalLength: 0,
                sanitizedLength: padToLength || 0
            };
        }

        const unknownChars = new Set();
        const result = [];

        // Process each character
        for (let i = 0; i < text.length; i++) {
            const char = text[i];
            const code = char.charCodeAt(0);

            // Special case: ellipsis becomes three periods
            if (code === 0x2026) {
                result.push(46, 46, 46); // Three periods
            }
            // Check character map for other replacements
            else if (this.charMap[code] !== undefined) {
                result.push(this.charMap[code]);
            }
            // Newlines and carriage returns become spaces
            else if (code === 10 || code === 13) {
                result.push(32); // Space
            }
            // Tab becomes space
            else if (code === 9) {
                result.push(32); // Space
            }
            // Standard printable ASCII range (32-126)
            else if (code >= 32 && code <= 126) {
                result.push(code);
            }
            // Accented lowercase letters - strip to base ASCII
            else if (code >= 0x00E0 && code <= 0x00FF) {
                // Latin-1 supplement lowercase - convert to base letter
                if ((code >= 0x00E0 && code <= 0x00E6) || code === 0x00E0) result.push(97); // a
                else if (code >= 0x00E8 && code <= 0x00EB) result.push(101); // e
                else if (code >= 0x00EC && code <= 0x00EF) result.push(105); // i
                else if ((code >= 0x00F2 && code <= 0x00F6) || code === 0x00F8) result.push(111); // o
                else if (code >= 0x00F9 && code <= 0x00FC) result.push(117); // u
                else if (code === 0x00F1) result.push(110); // ñ -> n
                else if (code === 0x00E7) result.push(99); // ç -> c
                else if (code === 0x00FD || code === 0x00FF) result.push(121); // y
                else result.push(32); // Space for anything else
            }
            // Accented uppercase letters - strip to base ASCII
            else if (code >= 0x00C0 && code <= 0x00DF) {
                // Latin-1 supplement uppercase - convert to base letter
                if (code >= 0x00C0 && code <= 0x00C6) result.push(65); // A
                else if (code >= 0x00C8 && code <= 0x00CB) result.push(69); // E
                else if (code >= 0x00CC && code <= 0x00CF) result.push(73); // I
                else if ((code >= 0x00D2 && code <= 0x00D6) || code === 0x00D8) result.push(79); // O
                else if (code >= 0x00D9 && code <= 0x00DC) result.push(85); // U
                else if (code === 0x00D1) result.push(78); // Ñ -> N
                else if (code === 0x00C7) result.push(67); // Ç -> C
                else if (code === 0x00DD) result.push(89); // Y
                else result.push(32); // Space for anything else
            }
            // Everything else becomes a space
            else {
                unknownChars.add(char);
                result.push(32); // Space
            }
        }

        // Build final string from bytes
        let sanitized = String.fromCharCode(...result);

        // Report unknown characters
        if (reportUnknown && unknownChars.size > 0) {
            const charList = Array.from(unknownChars).map(c => {
                const code = c.charCodeAt(0);
                if (code >= 32 && code < 127) {
                    return `"${c}"`;
                } else {
                    return `U+${code.toString(16).toUpperCase().padStart(4, '0')}`;
                }
            });

            this.warnings.push({
                type: 'unknown_characters',
                message: `Replaced ${unknownChars.size} incompatible character(s) with spaces`,
                characters: charList
            });
        }

        // Handle length constraints
        if (maxLength && sanitized.length > maxLength) {
            sanitized = sanitized.substring(0, maxLength);
            this.warnings.push({
                type: 'truncated',
                message: `Text truncated to ${maxLength} characters`,
                originalLength: text.length
            });
        }

        // Handle padding
        if (padToLength && sanitized.length < padToLength) {
            if (center) {
                const totalPadding = padToLength - sanitized.length;
                const leftPad = Math.floor(totalPadding / 2);
                const rightPad = totalPadding - leftPad;
                sanitized = ' '.repeat(leftPad) + sanitized + ' '.repeat(rightPad);
            } else {
                sanitized = sanitized.padEnd(padToLength, ' ');
            }
        }

        return {
            text: sanitized,
            warnings: this.warnings,
            hasWarnings: this.warnings.length > 0,
            originalLength: text.length,
            sanitizedLength: sanitized.length
        };
    }

    /**
     * Convert sanitized text to C64 screen codes
     * @param {string} text - Already sanitized ASCII text
     * @param {boolean} useSystemFont - If true, use C64 system font mapping (lowercase at 1-26);
     *                                  if false, use custom font mapping (uppercase at 1-26)
     * @returns {Uint8Array} - Screen code byte array
     */
    toPETSCIIBytes(text, useSystemFont = false) {
        const bytes = [];

        for (let i = 0; i < text.length; i++) {
            const code = text.charCodeAt(i);
            let screenCode;

            if (useSystemFont) {
                // C64 system font in lowercase mode:
                // Screen codes 1-26 = lowercase a-z
                // Screen codes 65-90 = uppercase A-Z (shown as graphics in uppercase mode)
                if (code >= 65 && code <= 90) {
                    // A-Z uppercase -> screen codes 65-90
                    screenCode = code;
                } else if (code >= 97 && code <= 122) {
                    // a-z lowercase -> screen codes 1-26
                    screenCode = code - 96;
                } else if (code >= 32 && code <= 63) {
                    // Space, symbols, digits (ASCII 32-63) -> same screen codes
                    screenCode = code;
                } else if (code === 64) {
                    // @ -> screen code 0
                    screenCode = 0;
                } else {
                    // Default to space
                    screenCode = 32;
                }
            } else {
                // Custom font layout: 1-26 = A-Z (uppercase), 65-90 = a-z (lowercase)
                if (code >= 65 && code <= 90) {
                    // A-Z uppercase -> screen codes 1-26
                    screenCode = code - 64;
                } else if (code >= 97 && code <= 122) {
                    // a-z lowercase -> screen codes 65-90
                    screenCode = code - 32;
                } else if (code >= 32 && code <= 63) {
                    // Space, symbols, digits (ASCII 32-63) -> same screen codes
                    screenCode = code;
                } else if (code === 64) {
                    // @ -> screen code 0
                    screenCode = 0;
                } else {
                    // Default to space
                    screenCode = 32;
                }
            }

            // Ensure screen code is in valid range
            bytes.push(screenCode & 0xFF);
        }

        return new Uint8Array(bytes);
    }

    /**
     * Show warning dialog to user (console only, doesn't modify text)
     * @param {Array} warnings - Array of warning objects
     */
    showWarningDialog(warnings) {
        if (!warnings || warnings.length === 0) return;

        console.warn('PETSCII Sanitization Warnings:');
        warnings.forEach(w => console.warn(`  - ${w.message}`));
    }
}

// Export for use in other modules
window.PETSCIISanitizer = PETSCIISanitizer;