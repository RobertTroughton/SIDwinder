#!/usr/bin/env node
/**
 * Generate 64x64 PNG previews for each color palette defined below.
 * Output goes to public/PNG/Palettes/ and is consumed by the picker UI.
 * Palette gradient definitions must stay in sync with color-palettes-data.js.
 */

const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

// C64 hardware colors as RGB triples, indexed by C64 colour code $0..$F.
const C64_COLORS = {
    0x00: { r: 0,   g: 0,   b: 0   },   // Black
    0x01: { r: 255, g: 255, b: 255 },   // White
    0x02: { r: 136, g: 57,  b: 50  },   // Red
    0x03: { r: 103, g: 182, b: 189 },   // Cyan
    0x04: { r: 139, g: 63,  b: 150 },   // Purple
    0x05: { r: 85,  g: 160, b: 73  },   // Green
    0x06: { r: 64,  g: 49,  b: 141 },   // Blue
    0x07: { r: 191, g: 206, b: 114 },   // Yellow
    0x08: { r: 139, g: 84,  b: 41  },   // Orange
    0x09: { r: 87,  g: 66,  b: 0   },   // Brown
    0x0A: { r: 184, g: 105, b: 98  },   // Light Red
    0x0B: { r: 80,  g: 80,  b: 80  },   // Dark Grey
    0x0C: { r: 120, g: 120, b: 120 },   // Grey
    0x0D: { r: 148, g: 224, b: 137 },   // Light Green
    0x0E: { r: 120, g: 105, b: 196 },   // Light Blue
    0x0F: { r: 159, g: 159, b: 159 }    // Light Grey
};

// Mirror of COLOR_PALETTE_GRADIENTS in public/color-palettes-data.js.
// Keep entries here in lockstep with that file.
const PALETTES = [
    {
        name: "palette-rainbow",
        borderColor: 0x00,
        backgroundColor: 0x00,
        gradient: [
            { color: 0x0B, pct: 0 },
            { color: 0x09, pct: 3 },
            { color: 0x06, pct: 20 },
            { color: 0x04, pct: 37 },
            { color: 0x0E, pct: 52 },
            { color: 0x0D, pct: 67 },
            { color: 0x07, pct: 85 },
            { color: 0x01, pct: 100 }
        ]
    },
    {
        name: "palette-fire",
        borderColor: 0x00,
        backgroundColor: 0x00,
        gradient: [
            { color: 0x0B, pct: 0 },
            { color: 0x09, pct: 8 },
            { color: 0x02, pct: 20 },
            { color: 0x0A, pct: 35 },
            { color: 0x08, pct: 50 },
            { color: 0x07, pct: 70 },
            { color: 0x0F, pct: 88 },
            { color: 0x01, pct: 100 }
        ]
    },
    {
        name: "palette-ice",
        borderColor: 0x06,
        backgroundColor: 0x06,
        gradient: [
            { color: 0x06, pct: 0 },
            { color: 0x06, pct: 15 },
            { color: 0x06, pct: 30 },
            { color: 0x0E, pct: 45 },
            { color: 0x0E, pct: 55 },
            { color: 0x03, pct: 70 },
            { color: 0x03, pct: 82 },
            { color: 0x0F, pct: 92 },
            { color: 0x01, pct: 100 }
        ]
    },
    {
        name: "palette-forest",
        borderColor: 0x00,
        backgroundColor: 0x00,
        gradient: [
            { color: 0x0B, pct: 0 },
            { color: 0x0B, pct: 10 },
            { color: 0x05, pct: 25 },
            { color: 0x05, pct: 40 },
            { color: 0x0D, pct: 55 },
            { color: 0x0D, pct: 70 },
            { color: 0x07, pct: 85 },
            { color: 0x01, pct: 100 }
        ]
    },
    {
        name: "palette-purplehaze",
        borderColor: 0x00,
        backgroundColor: 0x00,
        gradient: [
            { color: 0x0B, pct: 0 },
            { color: 0x06, pct: 12 },
            { color: 0x04, pct: 28 },
            { color: 0x04, pct: 42 },
            { color: 0x0A, pct: 58 },
            { color: 0x0A, pct: 72 },
            { color: 0x0F, pct: 88 },
            { color: 0x01, pct: 100 }
        ]
    },
    {
        name: "palette-ocean",
        borderColor: 0x06,
        backgroundColor: 0x06,
        gradient: [
            { color: 0x06, pct: 0 },
            { color: 0x06, pct: 10 },
            { color: 0x06, pct: 25 },
            { color: 0x0E, pct: 42 },
            { color: 0x03, pct: 58 },
            { color: 0x0D, pct: 75 },
            { color: 0x0F, pct: 90 },
            { color: 0x01, pct: 100 }
        ]
    },
    {
        name: "palette-mono",
        borderColor: 0x00,
        backgroundColor: 0x00,
        gradient: [
            { color: 0x0B, pct: 0 },
            { color: 0x0B, pct: 18 },
            { color: 0x0B, pct: 35 },
            { color: 0x0C, pct: 52 },
            { color: 0x0C, pct: 68 },
            { color: 0x0F, pct: 85 },
            { color: 0x01, pct: 100 }
        ]
    }
];

/**
 * Pick the C64 colour at a given percentage along a gradient.
 * Stops are nearest-neighbour (stepped), not interpolated, to match the
 * runtime palette generator in color-palettes-data.js.
 */
function getColorAtPosition(gradient, pct) {
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

    return color;
}

function generatePalettePNG(palette, outputPath) {
    const width = 64;
    const height = 64;

    const png = new PNG({ width, height });

    const bgColor = C64_COLORS[palette.backgroundColor];

    for (let y = 0; y < height; y++) {
        // Gradient runs from bottom (0%) to top (100%), so invert Y.
        const pct = ((height - 1 - y) / (height - 1)) * 100;
        const c64Color = getColorAtPosition(palette.gradient, pct);
        const color = C64_COLORS[c64Color];

        for (let x = 0; x < width; x++) {
            const idx = (width * y + x) << 2;

            // 2-pixel border filled with the palette's background colour.
            if (x < 2 || x >= width - 2 || y < 2 || y >= height - 2) {
                png.data[idx] = bgColor.r;
                png.data[idx + 1] = bgColor.g;
                png.data[idx + 2] = bgColor.b;
                png.data[idx + 3] = 255;
            } else {
                png.data[idx] = color.r;
                png.data[idx + 1] = color.g;
                png.data[idx + 2] = color.b;
                png.data[idx + 3] = 255;
            }
        }
    }

    const buffer = PNG.sync.write(png);
    fs.writeFileSync(outputPath, buffer);
    console.log(`Generated: ${outputPath}`);
}

const outputDir = path.join(__dirname, '../public/PNG/Palettes');

if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

for (const palette of PALETTES) {
    const outputPath = path.join(outputDir, `${palette.name}.png`);
    generatePalettePNG(palette, outputPath);
}

console.log('Done!');
