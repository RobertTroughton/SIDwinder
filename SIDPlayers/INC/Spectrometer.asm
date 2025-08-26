//; =============================================================================
//;                           BAR ANALYSIS MODULE
//;              Common SID Analysis and Bar Animation Functions
//; =============================================================================
//; Extracted from RaistlinBars visualizers for code reuse
//; Requires configuration constants to be defined before inclusion
//; =============================================================================

#importonce

//; Required constants that must be defined before including this file:
//; - NUM_FREQUENCY_BARS
//; - TOP_SPECTRUM_HEIGHT  
//; - BAR_INCREASE_RATE
//; - BAR_DECREASE_RATE
//; - MAX_BAR_HEIGHT

//; Required memory locations:
//; - SIDPlay (routine address)
//; - BackupSIDMemory (routine address)
//; - RestoreSIDMemory (routine address)

//; =============================================================================
//; BAR STATE DATA
//; =============================================================================

barHeightsLo:               .fill NUM_FREQUENCY_BARS, 0
barVoiceMap:                .fill NUM_FREQUENCY_BARS, 0
targetBarHeights:           .fill NUM_FREQUENCY_BARS, 0

previousHeightsScreen0:     .fill NUM_FREQUENCY_BARS, 255
previousHeightsScreen1:     .fill NUM_FREQUENCY_BARS, 255
previousColors:             .fill NUM_FREQUENCY_BARS, 255

.byte $00, $00
barHeights:                 .fill NUM_FREQUENCY_BARS, 0
.byte $00, $00

smoothedHeights:            .fill NUM_FREQUENCY_BARS, 0

//; =============================================================================
//; VOICE STATE DATA
//; =============================================================================

voiceReleaseHi:             .fill 3, 0
voiceReleaseLo:             .fill 3, 0
sidRegisterMirror:          .fill 32, 0

//; =============================================================================
//; CALCULATION TABLES
//; =============================================================================

multiply64Table:            .fill 4, i * 64

//; Aligned for optimal access
.align 128
div16:                      .fill 128, i / 16.0
div16mul3:                  .fill 128, ((3.0 * i) / 16.0)

//; =============================================================================
//; MUSIC PLAYBACK WITH ANALYSIS
//; =============================================================================

PlayMusicWithAnalysis:
    jsr BackupSIDMemory
    jsr SIDPlay
    jsr RestoreSIDMemory

    lda $01
    pha
    lda #$30
    sta $01
    jsr SIDPlay

    ldy #24
!loop:
    lda $d400, y
    sta sidRegisterMirror, y
    dey
    bpl !loop-

    pla
    sta $01

    jmp AnalyzeSIDRegisters

//; =============================================================================
//; SID REGISTER ANALYSIS
//; =============================================================================

AnalyzeSIDRegisters:
    .for (var voice = 0; voice < 3; voice++) {
        lda sidRegisterMirror + (voice * 7) + 4
        bmi !skipVoice+
        and #$01
        beq !skipVoice+

        ldy sidRegisterMirror + (voice * 7) + 1
        cpy #4
        bcc !lowFreq+

        ldx frequencyToBarHi, y
        jmp !gotBar+

    !lowFreq:
        ldx sidRegisterMirror + (voice * 7) + 0
        txa
        lsr
        lsr
        ora multiply64Table, y
        tay
        ldx frequencyToBarLo, y

    !gotBar:
        lda sidRegisterMirror + (voice * 7) + 6
        pha

        and #$0f
        tay
        lda releaseRateHi, y
        sta voiceReleaseHi + voice
        lda releaseRateLo, y
        sta voiceReleaseLo + voice

        pla
        lsr
        lsr
        lsr
        lsr
        tay
        lda sustainToHeight, y
        sta targetBarHeights, x
        lda #voice
        sta barVoiceMap, x

    !skipVoice:
    }
    rts

//; =============================================================================
//; BAR ANIMATION UPDATE
//; =============================================================================

UpdateBarDecay:
    ldx #NUM_FREQUENCY_BARS - 1
!loop:
    lda targetBarHeights, x
    beq !justDecay+
    
    cmp barHeights, x
    beq !clearTarget+
    bcc !moveDown+
    
    lda barHeights, x
    clc
    adc #BAR_INCREASE_RATE
    cmp targetBarHeights, x
    bcc !storeHeight+
    lda targetBarHeights, x
    jmp !storeHeight+
    
!moveDown:
    lda barHeights, x
    sec
    sbc #BAR_DECREASE_RATE
    cmp targetBarHeights, x
    bcs !storeHeight+
    lda targetBarHeights, x
    
!storeHeight:
    sta barHeights, x
    lda #$00
    sta barHeightsLo, x
    
!clearTarget:
    lda #$00
    sta targetBarHeights, x
    jmp !next+
    
!justDecay:
    ldy barVoiceMap, x

    sec
    lda barHeightsLo, x
    sbc voiceReleaseLo, y
    sta barHeightsLo, x
    lda barHeights, x
    sbc voiceReleaseHi, y
    bpl !positive+

    lda #$00
    sta barHeightsLo, x
!positive:
    sta barHeights, x

!next:
    dex
    bpl !loop-
    rts

//; =============================================================================
//; SMOOTHING ALGORITHM
//; =============================================================================

ApplySmoothing:
    ldx #0
!loop:
    lda barHeights, x
    lsr
    ldy barHeights - 2, x
    adc div16, y
    ldy barHeights - 1, x
    adc div16mul3, y
    ldy barHeights + 1, x
    adc div16mul3, y
    ldy barHeights + 2, x
    adc div16, y
    sta smoothedHeights, x

    inx
    cpx #NUM_FREQUENCY_BARS
    bne !loop-
    rts

//; =============================================================================
//; INITIALIZATION HELPER
//; =============================================================================

InitializeBarArrays:
    ldy #$00
    lda #$00
!loop:
    sta barHeights - 2, y
    sta smoothedHeights - 2, y
    iny
    cpy #NUM_FREQUENCY_BARS + 4
    bne !loop-
    rts

//; =============================================================================
//; END OF BAR ANALYSIS MODULE
//; =============================================================================