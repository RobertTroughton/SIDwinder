// visualizer-registry.js - Define available visualizers

const VISUALIZERS = [
    {
        id: 'RaistlinBars',
        name: 'Raistlin Bars',
        description: 'Spectrometer bars',
        preview: 'prg/raistlinbars.png',
        binary: 'prg/raistlinbars.bin',
        maxCallsPerFrame: 1,
        config: 'prg/raistlinbars.json'
    },
    {
        id: 'RaistlinBarsWithLogo',
        name: 'Raistlin Bars With Logo',
        description: 'Spectrumeter bars below an 80px tall logo',
        preview: 'prg/raistlinbarswithlogo.png',
        binary: 'prg/raistlinbarswithlogo.bin',
        maxCallsPerFrame: 1,
        config: 'prg/raistlinbarswithlogo.json'
    },
    {
        id: 'RaistlinMirrorBars',
        name: 'Raistlin Mirror Bars',
        description: 'Spectrometer mirrored bars',
        preview: 'prg/raistlinmirrorbars.png',
        binary: 'prg/raistlinmirrorbars.bin',
        maxCallsPerFrame: 1,
        config: 'prg/raistlinmirrorbars.json'
    },
    {
        id: 'RaistlinMirrorBarsWithLogo',
        name: 'Raistlin Mirror Bars With Logo',
        description: 'Spectrometer mirrored bars below an 80px tall logo',
        preview: 'prg/raistlinmirrorbarswithlogo.png',
        binary: 'prg/raistlinmirrorbarswithlogo.bin',
        maxCallsPerFrame: 1,
        config: 'prg/raistlinmirrorbarswithlogo.json'
    },
    {
        id: 'SimpleBitmap',
        name: 'Simple Bitmap',
        description: 'Full-screen bitmap',
        preview: 'prg/simplebitmap.png',
        binary: 'prg/simplebitmap.bin',
        maxCallsPerFrame: 8,
        config: 'prg/simplebitmap.json'
    },
    {
        id: 'SimpleRaster',
        name: 'Simple Raster',
        description: 'Minimal rasterbar effect',
        preview: 'prg/simpleraster.png',
        binary: 'prg/simpleraster.bin',
        maxCallsPerFrame: 8,
        config: 'prg/simpleraster.json'
    },
    {
        id: 'TextInfo',
        name: 'Text Info',
        description: 'Minimal player with textual information - similar to PSID64',
        preview: 'prg/textinfo.png',
        binary: 'prg/textinfo.bin',
        maxCallsPerFrame: 8,
        config: 'prg/textinfo.json'
    }
];

window.VISUALIZERS = VISUALIZERS;