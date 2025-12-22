# Bar Style Preview Images

This folder contains 64x64 pixel preview thumbnails for the bar styles.

## Naming Convention

Images should be named `style-{N}.png` where N is the style number (0-7):

- `style-0.png` - Classic (rounded with highlights)
- `style-1.png` - Solid (full solid bars)
- `style-2.png` - Thin (narrow 4-pixel bars)
- `style-3.png` - Outline (hollow bars)
- `style-4.png` - Chunky (blocky pixel bars)
- `style-5.png` - Smooth (rounded without highlights)
- `style-6.png` - Pointed (pointed top)
- `style-7.png` - Lined (solid with scanlines)

## Image Requirements

- Size: 64x64 pixels
- Format: PNG
- Background: Should match the C64 theme (dark background recommended)

## Adding New Styles

To add a new bar style:
1. Add the style data to `bar-styles-data.js`
2. Add a new entry in the JSON config files (raistlinbars.json, etc.)
3. Create a corresponding `style-{N}.png` preview image
