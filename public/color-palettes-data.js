// color-palettes-data.js - Color Palette Data for SIDwinder Web
// This module contains the color lookup tables for all color palettes,
// allowing the web app to inject the selected color scheme directly.
//
// Color palettes are height-based color gradients for the spectrum bars.
// Different visualizers have different max heights:
// - Water (RaistlinBars): MAX_BAR_HEIGHT = 111 (14 rows * 8 - 1), needs ~116 entries
// - Mirror (RaistlinMirrorBars): MAX_BAR_HEIGHT = 71 (9 rows * 8 - 1), needs ~76 entries

// C64 Color Palette Reference:
// $00 = Black       $08 = Orange
// $01 = White       $09 = Brown
// $02 = Red         $0A = Light Red
// $03 = Cyan        $0B = Dark Grey
// $04 = Purple      $0C = Grey
// $05 = Green       $0D = Light Green
// $06 = Blue        $0E = Light Blue
// $07 = Yellow      $0F = Light Grey

const NUM_COLOR_PALETTES = 7;

// Size constants - extra bytes for safety margin
const COLOR_TABLE_SIZE_WATER = 120;   // For RaistlinBars (MAX_BAR_HEIGHT=111 + padding)
const COLOR_TABLE_SIZE_MIRROR = 80;   // For RaistlinMirrorBars (MAX_BAR_HEIGHT=71 + padding)

// Color palette definitions - each defines colors from bottom to top
// Format: array of {color, percentage} where percentage is 0-100 for position in gradient
// Note: Avoid using black ($00) as a bar color since it's the screen background
const COLOR_PALETTE_GRADIENTS = [
    // Palette 0: Rainbow
    {
        name: "Rainbow",
        description: "Classic rainbow gradient from bottom to top",
        borderColor: 0x00,      // Black
        backgroundColor: 0x00,  // Black
        previewImage: "PNG/Palettes/palette-rainbow.png",
        gradient: [
            { color: 0x0B, pct: 0 },    // Dark grey (base - avoids black)
            { color: 0x09, pct: 3 },    // Brown
            { color: 0x06, pct: 20 },   // Blue
            { color: 0x04, pct: 37 },   // Purple
            { color: 0x0E, pct: 52 },   // Light blue
            { color: 0x0D, pct: 67 },   // Light green
            { color: 0x07, pct: 85 },   // Yellow
            { color: 0x01, pct: 100 }   // White
        ]
    },

    // Palette 1: Fire (Red/Orange/Yellow)
    {
        name: "Fire",
        description: "Hot flames from red to yellow to white",
        borderColor: 0x00,      // Black
        backgroundColor: 0x00,  // Black
        previewImage: "PNG/Palettes/palette-fire.png",
        gradient: [
            { color: 0x0B, pct: 0 },    // Dark grey (base - avoids black)
            { color: 0x09, pct: 8 },    // Brown
            { color: 0x02, pct: 20 },   // Red
            { color: 0x0A, pct: 35 },   // Light red
            { color: 0x08, pct: 50 },   // Orange
            { color: 0x07, pct: 70 },   // Yellow
            { color: 0x0F, pct: 88 },   // Light grey
            { color: 0x01, pct: 100 }   // White
        ]
    },

    // Palette 2: Ice (Blue/Cyan/White)
    {
        name: "Ice",
        description: "Cool ice colors from deep blue to white",
        borderColor: 0x06,      // Blue
        backgroundColor: 0x06,  // Blue
        previewImage: "PNG/Palettes/palette-ice.png",
        gradient: [
            { color: 0x06, pct: 0 },    // Blue (base - matches background)
            { color: 0x06, pct: 15 },   // Blue
            { color: 0x06, pct: 30 },   // Blue
            { color: 0x0E, pct: 45 },   // Light blue
            { color: 0x0E, pct: 55 },   // Light blue
            { color: 0x03, pct: 70 },   // Cyan
            { color: 0x03, pct: 82 },   // Cyan
            { color: 0x0F, pct: 92 },   // Light grey
            { color: 0x01, pct: 100 }   // White
        ]
    },

    // Palette 3: Forest (Green shades)
    {
        name: "Forest",
        description: "Natural green forest gradient",
        borderColor: 0x00,      // Black
        backgroundColor: 0x00,  // Black
        previewImage: "PNG/Palettes/palette-forest.png",
        gradient: [
            { color: 0x0B, pct: 0 },    // Dark grey (base - avoids black)
            { color: 0x0B, pct: 10 },   // Dark grey
            { color: 0x05, pct: 25 },   // Green
            { color: 0x05, pct: 40 },   // Green
            { color: 0x0D, pct: 55 },   // Light green
            { color: 0x0D, pct: 70 },   // Light green
            { color: 0x07, pct: 85 },   // Yellow
            { color: 0x01, pct: 100 }   // White
        ]
    },

    // Palette 4: Purple Haze
    {
        name: "Purple Haze",
        description: "Deep purple to pink gradient",
        borderColor: 0x00,      // Black
        backgroundColor: 0x00,  // Black
        previewImage: "PNG/Palettes/palette-purplehaze.png",
        gradient: [
            { color: 0x0B, pct: 0 },    // Dark grey (base - avoids black)
            { color: 0x06, pct: 12 },   // Blue
            { color: 0x04, pct: 28 },   // Purple
            { color: 0x04, pct: 42 },   // Purple
            { color: 0x0A, pct: 58 },   // Light red (pink-ish)
            { color: 0x0A, pct: 72 },   // Light red
            { color: 0x0F, pct: 88 },   // Light grey
            { color: 0x01, pct: 100 }   // White
        ]
    },

    // Palette 5: Ocean Depths
    {
        name: "Ocean",
        description: "Deep sea blues and cyans",
        borderColor: 0x06,      // Blue
        backgroundColor: 0x06,  // Blue
        previewImage: "PNG/Palettes/palette-ocean.png",
        gradient: [
            { color: 0x06, pct: 0 },    // Blue (base - matches background)
            { color: 0x06, pct: 10 },   // Blue
            { color: 0x06, pct: 25 },   // Blue
            { color: 0x0E, pct: 42 },   // Light blue
            { color: 0x03, pct: 58 },   // Cyan
            { color: 0x0D, pct: 75 },   // Light green (aqua)
            { color: 0x0F, pct: 90 },   // Light grey
            { color: 0x01, pct: 100 }   // White
        ]
    },

    // Palette 6: Monochrome (Grey shades)
    {
        name: "Monochrome",
        description: "Classic grey scale",
        borderColor: 0x00,      // Black
        backgroundColor: 0x00,  // Black
        previewImage: "PNG/Palettes/palette-mono.png",
        gradient: [
            { color: 0x0B, pct: 0 },    // Dark grey (base - avoids black)
            { color: 0x0B, pct: 18 },   // Dark grey
            { color: 0x0B, pct: 35 },   // Dark grey
            { color: 0x0C, pct: 52 },   // Grey
            { color: 0x0C, pct: 68 },   // Grey
            { color: 0x0F, pct: 85 },   // Light grey
            { color: 0x01, pct: 100 }   // White
        ]
    }
];

// Generate a color lookup table for a given palette and table size
function generateColorTable(paletteIndex, tableSize) {
    if (paletteIndex < 0 || paletteIndex >= NUM_COLOR_PALETTES) {
        paletteIndex = 0;
    }

    const palette = COLOR_PALETTE_GRADIENTS[paletteIndex];
    const gradient = palette.gradient;
    const result = new Uint8Array(tableSize);

    // COLOR_TABLE_SIZE = MAX_BAR_HEIGHT + 9, so actual max height is tableSize - 9
    // Use this as the reference for 100% so bars reach full brightness at max height
    const maxHeight = tableSize - 9;

    // First entry (height 0) uses the base color from gradient
    result[0] = gradient[0].color;

    for (let i = 1; i < tableSize; i++) {
        // Map table position to percentage based on actual max bar height
        // At i = maxHeight, we want pct = 100%
        const pct = Math.min((i / maxHeight) * 100, 100);

        // Find the two gradient stops this percentage falls between
        let color = gradient[0].color;

        for (let g = 0; g < gradient.length - 1; g++) {
            if (pct >= gradient[g].pct && pct <= gradient[g + 1].pct) {
                // Use the lower gradient stop's color (stepped, not interpolated)
                // For a more gradual effect, we pick the nearer one
                const midPoint = (gradient[g].pct + gradient[g + 1].pct) / 2;
                color = pct < midPoint ? gradient[g].color : gradient[g + 1].color;
                break;
            }
            if (pct > gradient[g + 1].pct) {
                color = gradient[g + 1].color;
            }
        }

        result[i] = color;
    }

    return result;
}

// Generate color table for water-style visualizers (RaistlinBars)
function generateWaterColorData(paletteIndex) {
    const colorTable = generateColorTable(paletteIndex, COLOR_TABLE_SIZE_WATER);
    return colorTable;
}

// Generate color table for mirror-style visualizers (RaistlinMirrorBars)
function generateMirrorColorData(paletteIndex) {
    const colorTable = generateColorTable(paletteIndex, COLOR_TABLE_SIZE_MIRROR);
    return colorTable;
}

// Color effect types
const COLOR_EFFECT_HEIGHT = 0;      // Dynamic - color based on bar height
const COLOR_EFFECT_LINE_GRADIENT = 1; // Static - fixed colors per screen line
const COLOR_EFFECT_SOLID = 2;       // Static - single color throughout

// Line counts for different visualizer types
const LINE_COUNT_WATER = 17;        // TOP_SPECTRUM_HEIGHT (14) + BOTTOM_SPECTRUM_HEIGHT (3)
const LINE_COUNT_WATER_LOGO = 11;   // TOP_SPECTRUM_HEIGHT (8) + BOTTOM_SPECTRUM_HEIGHT (3)
const LINE_COUNT_MIRROR = 18;       // TOTAL_SPECTRUM_HEIGHT (9 * 2)
const LINE_COUNT_MIRROR_LOGO = 10;  // TOTAL_SPECTRUM_HEIGHT (5 * 2)

// Generate line gradient colors for water-style visualizers
// Returns colors from top to bottom (brightest at top, darker at bottom)
function generateLineGradientWater(paletteIndex, topHeight, bottomHeight) {
    if (paletteIndex < 0 || paletteIndex >= NUM_COLOR_PALETTES) {
        paletteIndex = 0;
    }

    const palette = COLOR_PALETTE_GRADIENTS[paletteIndex];
    const gradient = palette.gradient;
    const totalLines = topHeight + bottomHeight;
    const result = new Uint8Array(totalLines);

    // Generate colors for top section (top to bottom = brightest to darker)
    // Only the last line of top section gets the darkest color (0%)
    // Lines 0 to topHeight-2 map to 100% down to 20%
    for (let line = 0; line < topHeight; line++) {
        let pct;
        if (line === topHeight - 1) {
            pct = 0;  // Bottom line of top section gets darkest color
        } else {
            // Map lines 0 to topHeight-2 to 100%-20% range (skip the dark range)
            pct = 100 - (line / (topHeight - 2)) * 80;
        }

        let color = gradient[0].color;
        for (let g = 0; g < gradient.length - 1; g++) {
            if (pct >= gradient[g].pct && pct <= gradient[g + 1].pct) {
                const midPoint = (gradient[g].pct + gradient[g + 1].pct) / 2;
                color = pct < midPoint ? gradient[g].color : gradient[g + 1].color;
                break;
            }
            if (pct > gradient[g + 1].pct) {
                color = gradient[g + 1].color;
            }
        }
        result[line] = color;
    }

    // Generate darker colors for bottom reflection section
    // Only the last line gets the darkest color
    const topDarkColor = result[topHeight - 1];
    const bottomDarkColor = DARKER_COLOR_MAP[topDarkColor];
    for (let line = 0; line < bottomHeight; line++) {
        if (line === bottomHeight - 1) {
            result[topHeight + line] = bottomDarkColor;  // Only last line is darkest
        } else {
            // Use the color from the line above the darkest in top section
            result[topHeight + line] = DARKER_COLOR_MAP[result[topHeight - 2]];
        }
    }

    return result;
}

// Generate line gradient colors for mirror-style visualizers
// Returns colors from top to bottom (brightest at center, darker at edges)
function generateLineGradientMirror(paletteIndex, halfHeight) {
    if (paletteIndex < 0 || paletteIndex >= NUM_COLOR_PALETTES) {
        paletteIndex = 0;
    }

    const palette = COLOR_PALETTE_GRADIENTS[paletteIndex];
    const gradient = palette.gradient;
    const totalLines = halfHeight * 2;
    const result = new Uint8Array(totalLines);

    // Generate colors for top half (top to center = darker to brighter)
    // Only line 0 gets the darkest color (0%), remaining lines map to 20%-100%
    for (let line = 0; line < halfHeight; line++) {
        let pct;
        if (line === 0) {
            pct = 0;  // Edge line gets darkest color
        } else {
            // Map lines 1 to halfHeight-1 to 20%-100% range (skip the dark range)
            pct = 20 + ((line - 1) / (halfHeight - 2)) * 80;
        }

        let color = gradient[0].color;
        for (let g = 0; g < gradient.length - 1; g++) {
            if (pct >= gradient[g].pct && pct <= gradient[g + 1].pct) {
                const midPoint = (gradient[g].pct + gradient[g + 1].pct) / 2;
                color = pct < midPoint ? gradient[g].color : gradient[g + 1].color;
                break;
            }
            if (pct > gradient[g + 1].pct) {
                color = gradient[g + 1].color;
            }
        }
        result[line] = color;
    }

    // Mirror colors for bottom half (center to bottom = brighter to darker)
    for (let line = 0; line < halfHeight; line++) {
        result[halfHeight + line] = result[halfHeight - 1 - line];
    }

    return result;
}

// Generate solid color (single color for all lines)
function generateSolidColors(paletteIndex, lineCount) {
    if (paletteIndex < 0 || paletteIndex >= NUM_COLOR_PALETTES) {
        paletteIndex = 0;
    }

    const palette = COLOR_PALETTE_GRADIENTS[paletteIndex];
    // Use the brightest color from the palette (last gradient stop)
    const brightestColor = palette.gradient[palette.gradient.length - 1].color;
    const result = new Uint8Array(lineCount);
    result.fill(brightestColor);
    return result;
}

// Darker color lookup for water reflections
// Maps each C64 color to a darker equivalent
const DARKER_COLOR_MAP = new Uint8Array([
    0x00,  // $00 Black -> Black
    0x0C,  // $01 White -> Grey
    0x09,  // $02 Red -> Brown
    0x0E,  // $03 Cyan -> Light Blue
    0x06,  // $04 Purple -> Blue
    0x09,  // $05 Green -> Brown
    0x0B,  // $06 Blue -> Dark Grey
    0x08,  // $07 Yellow -> Orange
    0x02,  // $08 Orange -> Red
    0x0B,  // $09 Brown -> Dark Grey
    0x02,  // $0A Light Red -> Red
    0x0B,  // $0B Dark Grey -> Dark Grey
    0x0B,  // $0C Grey -> Dark Grey
    0x05,  // $0D Light Green -> Green
    0x06,  // $0E Light Blue -> Blue
    0x0C   // $0F Light Grey -> Grey
]);

// Cache for generated data
const waterColorCache = new Array(NUM_COLOR_PALETTES).fill(null);
const mirrorColorCache = new Array(NUM_COLOR_PALETTES).fill(null);

// Get color palette data for a specific visualizer type
function getColorPaletteData(paletteType, paletteIndex) {
    if (paletteIndex < 0 || paletteIndex >= NUM_COLOR_PALETTES) {
        paletteIndex = 0;
    }

    if (paletteType === 'water') {
        if (!waterColorCache[paletteIndex]) {
            waterColorCache[paletteIndex] = generateWaterColorData(paletteIndex);
        }
        return waterColorCache[paletteIndex];
    } else if (paletteType === 'mirror') {
        if (!mirrorColorCache[paletteIndex]) {
            mirrorColorCache[paletteIndex] = generateMirrorColorData(paletteIndex);
        }
        return mirrorColorCache[paletteIndex];
    }

    return null;
}

// Get palette info for UI display
function getColorPaletteInfo() {
    return COLOR_PALETTE_GRADIENTS.map((palette, index) => ({
        value: index,
        name: palette.name,
        description: palette.description,
        previewImage: palette.previewImage,
        borderColor: palette.borderColor,
        backgroundColor: palette.backgroundColor
    }));
}

// Get specific palette details
function getColorPaletteDetails(paletteIndex) {
    if (paletteIndex < 0 || paletteIndex >= NUM_COLOR_PALETTES) {
        paletteIndex = 0;
    }
    const palette = COLOR_PALETTE_GRADIENTS[paletteIndex];
    return {
        name: palette.name,
        borderColor: palette.borderColor,
        backgroundColor: palette.backgroundColor,
        previewImage: palette.previewImage
    };
}

// Export for use in other modules
window.COLOR_PALETTES_DATA = {
    getColorPaletteData: getColorPaletteData,
    getColorPaletteInfo: getColorPaletteInfo,
    getColorPaletteDetails: getColorPaletteDetails,
    getDarkerColorMap: () => DARKER_COLOR_MAP,
    COLOR_TABLE_SIZE_WATER: COLOR_TABLE_SIZE_WATER,
    COLOR_TABLE_SIZE_MIRROR: COLOR_TABLE_SIZE_MIRROR,
    NUM_COLOR_PALETTES: NUM_COLOR_PALETTES,
    // Color effect functions and constants
    COLOR_EFFECT_HEIGHT: COLOR_EFFECT_HEIGHT,
    COLOR_EFFECT_LINE_GRADIENT: COLOR_EFFECT_LINE_GRADIENT,
    COLOR_EFFECT_SOLID: COLOR_EFFECT_SOLID,
    generateLineGradientWater: generateLineGradientWater,
    generateLineGradientMirror: generateLineGradientMirror,
    generateSolidColors: generateSolidColors,
    LINE_COUNT_WATER: LINE_COUNT_WATER,
    LINE_COUNT_WATER_LOGO: LINE_COUNT_WATER_LOGO,
    LINE_COUNT_MIRROR: LINE_COUNT_MIRROR,
    LINE_COUNT_MIRROR_LOGO: LINE_COUNT_MIRROR_LOGO
};
