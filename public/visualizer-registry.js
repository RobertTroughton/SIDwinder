// visualizer-registry.js - Define available visualizers (UI metadata only)

const VISUALIZERS = [
    {
        id: 'default',
        name: 'Default',
        description: 'Minimal player with textual information',
        preview: 'prg/default.png',
        config: 'prg/default.json'
    },
    {
        id: 'DefaultWithPETSCIILogo',
        name: 'Default With PETSCII Logo',
        description: 'Text information with a 9-row PETSCII art logo',
        preview: 'prg/defaultwithpetsciilogo.png',
        config: 'prg/defaultwithpetsciilogo.json'
    },
    {
        id: 'RaistlinBars',
        name: 'Raistlin Bars',
        description: 'Spectrometer bars',
        preview: 'prg/raistlinbars.png',
        config: 'prg/raistlinbars.json'
    },
    {
        id: 'RaistlinBarsWithLogo',
        name: 'Raistlin Bars With Logo',
        description: 'Spectrometer bars below an 80px tall logo',
        preview: 'prg/raistlinbarswithlogo.png',
        config: 'prg/raistlinbarswithlogo.json'
    },
    {
        id: 'RaistlinMirrorBars',
        name: 'Raistlin Mirror Bars',
        description: 'Spectrometer mirrored bars',
        preview: 'prg/raistlinmirrorbars.png',
        config: 'prg/raistlinmirrorbars.json'
    },
    {
        id: 'RaistlinMirrorBarsWithLogo',
        name: 'Raistlin Mirror Bars With Logo',
        description: 'Spectrometer mirrored bars below an 80px tall logo',
        preview: 'prg/raistlinmirrorbarswithlogo.png',
        config: 'prg/raistlinmirrorbarswithlogo.json'
    },
    {
        id: 'SimpleBitmap',
        name: 'Simple Bitmap',
        description: 'Full-screen bitmap',
        preview: 'prg/simplebitmap.png',
        config: 'prg/simplebitmap.json'
    },
    {
        id: 'SimpleBitmapWithScroller',
        name: 'Simple Bitmap With Scroller',
        description: 'Full-screen bitmap - with a scroller on top',
        preview: 'prg/simplebitmapwithscroller.png',
        config: 'prg/simplebitmapwithscroller.json'
    },
    {
        id: 'SimpleRaster',
        name: 'Simple Raster',
        description: 'Minimal rasterbar effect',
        preview: 'prg/simpleraster.png',
        config: 'prg/simpleraster.json'
    }
];

window.VISUALIZERS = VISUALIZERS;