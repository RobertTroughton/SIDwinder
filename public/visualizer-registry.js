// visualizer-registry.js - Define available visualizers

const VISUALIZERS = [
    {
        id: 'RaistlinBars',
        name: 'Raistlin Bars',
        description: 'Classic raster bars with optional logo',
        preview: 'prg/raistlinbars.png',
        binary: 'prg/raistlinbars.bin',
        config: 'prg/raistlinbars.json'
    },
    {
        id: 'SimpleBitmap',
        name: 'Simple Bitmap',
        description: 'Full-screen bitmap display',
        preview: 'prg/simplebitmap.png',
        binary: 'prg/simplebitmap.bin',
        config: 'prg/simplebitmap.json'
    },
    {
        id: 'SimpleRaster',
        name: 'Simple Raster',
        description: 'Minimal raster effect',
        preview: 'prg/simpleraster.png',
        binary: 'prg/simpleraster.bin',
        config: 'prg/simpleraster.json'
    }
];

window.VISUALIZERS = VISUALIZERS;