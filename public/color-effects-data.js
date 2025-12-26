// color-effects-data.js - Color Effect Data for SIDwinder Web
// This module contains the color lookup tables for all color effects,
// allowing the web app to inject the selected color scheme directly.
//
// Color effects are height-based color gradients for the spectrum bars.
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

const NUM_COLOR_EFFECTS = 8;

// Size constants - extra bytes for safety margin
const COLOR_TABLE_SIZE_WATER = 120;   // For RaistlinBars (MAX_BAR_HEIGHT=111 + padding)
const COLOR_TABLE_SIZE_MIRROR = 80;   // For RaistlinMirrorBars (MAX_BAR_HEIGHT=71 + padding)

// Color effect definitions - each defines colors from bottom to top
// Format: array of {color, percentage} where percentage is 0-100 for position in gradient
const COLOR_EFFECT_GRADIENTS = [
    // Effect 0: Cycling Rainbow (Original RaistlinBars style - uses purple/pink palette as base)
    {
        name: "Cycling Rainbow",
        description: "Animated color cycling through palettes",
        gradient: [
            { color: 0x0B, pct: 0 },    // Dark grey (base)
            { color: 0x09, pct: 5 },    // Brown
            { color: 0x04, pct: 15 },   // Purple
            { color: 0x05, pct: 30 },   // Green
            { color: 0x0D, pct: 50 },   // Light green
            { color: 0x0D, pct: 65 },   // Light green
            { color: 0x0F, pct: 85 },   // Light grey
            { color: 0x01, pct: 100 }   // White
        ]
    },

    // Effect 1: Static Rainbow (Original RaistlinMirrorBars style)
    {
        name: "Static Rainbow",
        description: "Classic rainbow gradient from bottom to top",
        gradient: [
            { color: 0x0B, pct: 0 },    // Dark grey
            { color: 0x09, pct: 3 },    // Brown
            { color: 0x06, pct: 20 },   // Blue
            { color: 0x04, pct: 37 },   // Purple
            { color: 0x0E, pct: 52 },   // Light blue
            { color: 0x0D, pct: 67 },   // Light green
            { color: 0x07, pct: 85 },   // Yellow
            { color: 0x01, pct: 100 }   // White (implied at top)
        ]
    },

    // Effect 2: Fire (Red/Orange/Yellow)
    {
        name: "Fire",
        description: "Hot flames from red to yellow to white",
        gradient: [
            { color: 0x00, pct: 0 },    // Black
            { color: 0x09, pct: 8 },    // Brown
            { color: 0x02, pct: 20 },   // Red
            { color: 0x0A, pct: 35 },   // Light red
            { color: 0x08, pct: 50 },   // Orange
            { color: 0x07, pct: 70 },   // Yellow
            { color: 0x0F, pct: 88 },   // Light grey
            { color: 0x01, pct: 100 }   // White
        ]
    },

    // Effect 3: Ice (Blue/Cyan/White)
    {
        name: "Ice",
        description: "Cool ice colors from deep blue to white",
        gradient: [
            { color: 0x00, pct: 0 },    // Black
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

    // Effect 4: Forest (Green shades)
    {
        name: "Forest",
        description: "Natural green forest gradient",
        gradient: [
            { color: 0x00, pct: 0 },    // Black
            { color: 0x0B, pct: 10 },   // Dark grey
            { color: 0x05, pct: 25 },   // Green
            { color: 0x05, pct: 40 },   // Green
            { color: 0x0D, pct: 55 },   // Light green
            { color: 0x0D, pct: 70 },   // Light green
            { color: 0x07, pct: 85 },   // Yellow
            { color: 0x01, pct: 100 }   // White
        ]
    },

    // Effect 5: Purple Haze
    {
        name: "Purple Haze",
        description: "Deep purple to pink gradient",
        gradient: [
            { color: 0x00, pct: 0 },    // Black
            { color: 0x06, pct: 12 },   // Blue
            { color: 0x04, pct: 28 },   // Purple
            { color: 0x04, pct: 42 },   // Purple
            { color: 0x0A, pct: 58 },   // Light red (pink-ish)
            { color: 0x0A, pct: 72 },   // Light red
            { color: 0x0F, pct: 88 },   // Light grey
            { color: 0x01, pct: 100 }   // White
        ]
    },

    // Effect 6: Ocean Depths
    {
        name: "Ocean",
        description: "Deep sea blues and cyans",
        gradient: [
            { color: 0x00, pct: 0 },    // Black
            { color: 0x0B, pct: 10 },   // Dark grey
            { color: 0x06, pct: 25 },   // Blue
            { color: 0x0E, pct: 42 },   // Light blue
            { color: 0x03, pct: 58 },   // Cyan
            { color: 0x0D, pct: 75 },   // Light green (aqua)
            { color: 0x0F, pct: 90 },   // Light grey
            { color: 0x01, pct: 100 }   // White
        ]
    },

    // Effect 7: Monochrome (Grey shades)
    {
        name: "Monochrome",
        description: "Classic grey scale",
        gradient: [
            { color: 0x00, pct: 0 },    // Black
            { color: 0x0B, pct: 18 },   // Dark grey
            { color: 0x0B, pct: 35 },   // Dark grey
            { color: 0x0C, pct: 52 },   // Grey
            { color: 0x0C, pct: 68 },   // Grey
            { color: 0x0F, pct: 85 },   // Light grey
            { color: 0x01, pct: 100 }   // White
        ]
    }
];

// Generate a color lookup table for a given effect and table size
function generateColorTable(effectIndex, tableSize) {
    if (effectIndex < 0 || effectIndex >= NUM_COLOR_EFFECTS) {
        effectIndex = 0;
    }

    const effect = COLOR_EFFECT_GRADIENTS[effectIndex];
    const gradient = effect.gradient;
    const result = new Uint8Array(tableSize);

    // First few entries (height 0-1) are typically the base/background color
    result[0] = 0x0B; // Dark grey for "no bar"

    for (let i = 1; i < tableSize; i++) {
        // Map table position to percentage (1 to tableSize-1 maps to ~0-100%)
        const pct = (i / (tableSize - 1)) * 100;

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
// Also needs a darker color map for the water reflection
function generateWaterColorData(effectIndex) {
    const colorTable = generateColorTable(effectIndex, COLOR_TABLE_SIZE_WATER);
    return colorTable;
}

// Generate color table for mirror-style visualizers (RaistlinMirrorBars)
function generateMirrorColorData(effectIndex) {
    const colorTable = generateColorTable(effectIndex, COLOR_TABLE_SIZE_MIRROR);
    return colorTable;
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
const waterColorCache = new Array(NUM_COLOR_EFFECTS).fill(null);
const mirrorColorCache = new Array(NUM_COLOR_EFFECTS).fill(null);

// Get color effect data for a specific visualizer type
function getColorEffectData(effectType, effectIndex) {
    if (effectIndex < 0 || effectIndex >= NUM_COLOR_EFFECTS) {
        effectIndex = 0;
    }

    if (effectType === 'water') {
        if (!waterColorCache[effectIndex]) {
            waterColorCache[effectIndex] = generateWaterColorData(effectIndex);
        }
        return waterColorCache[effectIndex];
    } else if (effectType === 'mirror') {
        if (!mirrorColorCache[effectIndex]) {
            mirrorColorCache[effectIndex] = generateMirrorColorData(effectIndex);
        }
        return mirrorColorCache[effectIndex];
    }

    return null;
}

// Get effect info for UI display
function getColorEffectInfo() {
    return COLOR_EFFECT_GRADIENTS.map((effect, index) => ({
        value: index,
        name: effect.name,
        description: effect.description
    }));
}

// Export for use in other modules
window.COLOR_EFFECTS_DATA = {
    getColorEffectData: getColorEffectData,
    getColorEffectInfo: getColorEffectInfo,
    getDarkerColorMap: () => DARKER_COLOR_MAP,
    COLOR_TABLE_SIZE_WATER: COLOR_TABLE_SIZE_WATER,
    COLOR_TABLE_SIZE_MIRROR: COLOR_TABLE_SIZE_MIRROR,
    NUM_COLOR_EFFECTS: NUM_COLOR_EFFECTS
};
