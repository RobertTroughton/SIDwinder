// musicplayback.asm - Music playback routines
// =============================================================================
//                          MUSIC PLAYBACK MODULE
//                     Unified music playback for all visualizers
// =============================================================================

#importonce

// =============================================================================
// Standard music playback (with optional raster bars)
// =============================================================================
JustPlayMusic:
    #if INCLUDE_F1_SHOWRASTERTIMINGBAR
    lda ShowRasterBars
    beq !skip+
    lda #$02
    sta $d020
!skip:
    #endif

    jsr SIDPlay

    #if INCLUDE_F1_SHOWRASTERTIMINGBAR
    lda ShowRasterBars
    beq !skip+
    lda #$00
    sta $d020
!skip:
    #endif // INCLUDE_F1_SHOWRASTERTIMINGBAR

    rts

// =============================================================================
// Music playback with SID analysis (for visualizers)
// =============================================================================
#if INCLUDE_MUSIC_ANALYSIS
AnalyseMusic:
    lda $01
    pha
    lda #$30
    sta $01

    jsr BackupSIDMemory
    jsr SIDPlay
    jsr RestoreSIDMemory

    ldy #24
!loop:
    lda $d400, y
    sta sidRegisterMirror, y
    dey
    bpl !loop-

    pla
    sta $01

    jmp AnalyzeSIDRegisters

sidRegisterMirror: .fill 25, 0
#endif // INCLUDE_MUSIC_ANALYSIS

// =============================================================================
// Combined playback routine for visualizers
// =============================================================================
#if INCLUDE_MUSIC_ANALYSIS
PlayMusicWithAnalysis:
    jsr JustPlayMusic
    jmp AnalyseMusic
#endif // INCLUDE_MUSIC_ANALYSIS