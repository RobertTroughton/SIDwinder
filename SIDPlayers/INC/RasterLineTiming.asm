.var FrameHeight = 312 // TODO: NTSC!

D012_Values:
.for (var i=0; i<NumCallsPerFrame; i++) {
    .var line = (FrameHeight * i) / NumCallsPerFrame
    .eval line = mod(line + 250, FrameHeight);
    .byte line & $ff
}

D011_Values:
.for (var i=0; i<NumCallsPerFrame; i++) {
    .var line = (FrameHeight * i) / NumCallsPerFrame
    .eval line = mod(line + 250, FrameHeight);
    .byte (line >= 256) ? $80 : $00
}
