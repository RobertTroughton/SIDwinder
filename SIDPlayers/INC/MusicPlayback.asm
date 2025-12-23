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
// Supports up to 4 SID chips at $D400, $D420, $D440, $D460
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

    // Mirror SID 1 registers ($D400-$D418) - always active
    ldy #24
!loopSID1:
    lda $d400, y
    sta sidRegisterMirror, y
    dey
    bpl !loopSID1-

    // Mirror SID 2 registers ($D420-$D438) if NumSIDChips >= 2
    lda NumSIDChips
    cmp #2
    bcc !skipSID2+
    ldy #24
!loopSID2:
    lda $d420, y
    sta sidRegisterMirror + 25, y
    dey
    bpl !loopSID2-
!skipSID2:

    // Mirror SID 3 registers ($D440-$D458) if NumSIDChips >= 3
    lda NumSIDChips
    cmp #3
    bcc !skipSID3+
    ldy #24
!loopSID3:
    lda $d440, y
    sta sidRegisterMirror + 50, y
    dey
    bpl !loopSID3-
!skipSID3:

    // Mirror SID 4 registers ($D460-$D478) if NumSIDChips >= 4
    lda NumSIDChips
    cmp #4
    bcc !skipSID4+
    ldy #24
!loopSID4:
    lda $d460, y
    sta sidRegisterMirror + 75, y
    dey
    bpl !loopSID4-
!skipSID4:

    pla
    sta $01

    jmp AnalyzeSIDRegisters

// 4 x 25 bytes = 100 bytes for up to 4 SID chip register mirrors
sidRegisterMirror: .fill 100, 0
#endif // INCLUDE_MUSIC_ANALYSIS

// =============================================================================
// Combined playback routine for visualizers
// =============================================================================
#if INCLUDE_MUSIC_ANALYSIS
PlayMusicWithAnalysis:
    jsr JustPlayMusic
    jmp AnalyseMusic
#endif // INCLUDE_MUSIC_ANALYSIS