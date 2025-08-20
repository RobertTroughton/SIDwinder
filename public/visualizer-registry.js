// visualizer-registry.js - Define available visualizers

const VISUALIZERS = [
    {
        id: 'RaistlinBars',
        name: 'Raistlin Bars',
        description: 'Spectrometer bars',
        preview: 'prg/raistlinbars.png',
        binary: 'prg/raistlinbars.bin',
        config: 'prg/raistlinbars.json'
    },
    {
        id: 'RaistlinBarsWithLogo',
        name: 'Raistlin Bars With Logo',
        description: 'Spectrumeter bars below an 80px tall logo',
        preview: 'prg/raistlinbarswithlogo.png',
        binary: 'prg/raistlinbarswithlogo.bin',
        config: 'prg/raistlinbarswithlogo.json'
    },
    {
        id: 'RaistlinMirrorBars',
        name: 'Raistlin Mirror Bars',
        description: 'Spectrometer mirrored bars',
        preview: 'prg/raistlinmirrorbars.png',
        binary: 'prg/raistlinmirrorbars.bin',
        config: 'prg/raistlinmirrorbars.json'
    },
    {
        id: 'RaistlinMirrorBarsWithLogo',
        name: 'Raistlin Mirror Bars With Logo',
        description: 'Spectrometer mirrored bars below an 80px tall logo',
        preview: 'prg/raistlinmirrorbarswithlogo.png',
        binary: 'prg/raistlinmirrorbarswithlogo.bin',
        config: 'prg/raistlinmirrorbarswithlogo.json'
    },
    {
        id: 'SimpleBitmap',
        name: 'Simple Bitmap',
        description: 'Full-screen bitmap',
        preview: 'prg/simplebitmap.png',
        binary: 'prg/simplebitmap.bin',
        config: 'prg/simplebitmap.json'
    },
    {
        id: 'SimpleRaster',
        name: 'Simple Raster',
        description: 'Minimal rasterbar effect',
        preview: 'prg/simpleraster.png',
        binary: 'prg/simpleraster.bin',
        config: 'prg/simpleraster.json'
    }
];

window.VISUALIZERS = VISUALIZERS;