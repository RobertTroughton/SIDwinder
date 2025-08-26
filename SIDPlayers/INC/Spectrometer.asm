//; =============================================================================
//;                           BAR ANALYSIS MODULE
//;              Common SID Analysis and Bar Animation Functions
//; =============================================================================

#importonce

//; Required constants that must be defined before including this file:
//; - NUM_FREQUENCY_BARS
//; - TOP_SPECTRUM_HEIGHT  
//; - BAR_INCREASE_RATE
//; - BAR_DECREASE_RATE
//; - MAX_BAR_HEIGHT

//; =============================================================================
//; BAR STATE DATA
//; =============================================================================

.align NUM_FREQUENCY_BARS
barHeightsLo:               .fill NUM_FREQUENCY_BARS, 0

.align NUM_FREQUENCY_BARS
barVoiceMap:                .fill NUM_FREQUENCY_BARS, 0

.align NUM_FREQUENCY_BARS
targetBarHeights:           .fill NUM_FREQUENCY_BARS, 0

.align NUM_FREQUENCY_BARS
previousHeightsScreen0:     .fill NUM_FREQUENCY_BARS, 255

.align NUM_FREQUENCY_BARS
previousHeightsScreen1:     .fill NUM_FREQUENCY_BARS, 255

.align NUM_FREQUENCY_BARS
previousColors:             .fill NUM_FREQUENCY_BARS, 255

.align NUM_FREQUENCY_BARS
smoothedHeights:            .fill NUM_FREQUENCY_BARS, 0

.align NUM_FREQUENCY_BARS + 4
.byte $00, $00
barHeights:                 .fill NUM_FREQUENCY_BARS, 0
.byte $00, $00

//; =============================================================================
//; VOICE STATE DATA
//; =============================================================================

.align 3
voiceReleaseHi:             .fill 3, 0

.align 3
voiceReleaseLo:             .fill 3, 0

//; =============================================================================
//; CALCULATION TABLES
//; =============================================================================

.align 4
multiply64Table:            .fill 4, i * 64

.align 128
div16:                      .fill 128, i / 16.0

.align 128
div16mul3:                  .fill 128, ((3.0 * i) / 16.0)

//; =============================================================================
//; SID REGISTER ANALYSIS
//; =============================================================================

AnalyzeSIDRegisters:
    // This routine expects sidRegisterMirror to be populated by MusicPlayback.asm
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