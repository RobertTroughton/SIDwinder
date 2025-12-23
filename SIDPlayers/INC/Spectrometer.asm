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
barVoiceMap:                .fill NUM_FREQUENCY_BARS, $03

.align NUM_FREQUENCY_BARS
smoothedHeights:            .fill NUM_FREQUENCY_BARS, 0

.align NUM_FREQUENCY_BARS
targetBarHeights:           .fill NUM_FREQUENCY_BARS, 0

.align NUM_FREQUENCY_BARS + 4
.byte $00, $00
barHeights:                 .fill NUM_FREQUENCY_BARS, 0
.byte $00, $00


//; =============================================================================
//; VOICE STATE DATA (expanded for up to 4 SIDs = 12 voices)
//; =============================================================================

.align 16
voiceReleaseHi:             .fill 12, 0
                            .fill 4, BAR_DECREASE_RATE

.align 16
voiceReleaseLo:             .fill 12, 0
                            .fill 4, 0

//; =============================================================================
//; CALCULATION TABLES
//; =============================================================================

.align 128
neighbourSmoothVals: .fill MAX_BAR_HEIGHT + 1, floor(i * 32.0 / 100.0)
.align 128
neighbourSmoothVals2: .fill MAX_BAR_HEIGHT + 1, floor(i * 12.0 / 100.0)

//; =============================================================================
//; SID REGISTER ANALYSIS (supports up to 4 SIDs = 12 voices)
//; =============================================================================

AnalyzeSIDRegisters:
    // Always analyze SID 1 (voices 0-2)
    .for (var voice = 0; voice < 3; voice++) {
        .eval var sidOffset = 0
        .eval var voiceIndex = voice
        jsr AnalyzeVoice_S0V0 + (voice * (AnalyzeVoice_S0V1 - AnalyzeVoice_S0V0))
    }

    // Analyze SID 2 (voices 3-5) if NumSIDChips >= 2
    lda NumSIDChips
    cmp #2
    bcc !skipSID2+
    .for (var voice = 0; voice < 3; voice++) {
        jsr AnalyzeVoice_S1V0 + (voice * (AnalyzeVoice_S1V1 - AnalyzeVoice_S1V0))
    }
!skipSID2:

    // Analyze SID 3 (voices 6-8) if NumSIDChips >= 3
    lda NumSIDChips
    cmp #3
    bcc !skipSID3+
    .for (var voice = 0; voice < 3; voice++) {
        jsr AnalyzeVoice_S2V0 + (voice * (AnalyzeVoice_S2V1 - AnalyzeVoice_S2V0))
    }
!skipSID3:

    // Analyze SID 4 (voices 9-11) if NumSIDChips >= 4
    lda NumSIDChips
    cmp #4
    bcc !skipSID4+
    .for (var voice = 0; voice < 3; voice++) {
        jsr AnalyzeVoice_S3V0 + (voice * (AnalyzeVoice_S3V1 - AnalyzeVoice_S3V0))
    }
!skipSID4:

    rts

//; =============================================================================
//; Voice Analysis Subroutines (generated for each SID/voice combination)
//; =============================================================================

// Macro to generate voice analysis code
.macro AnalyzeVoiceCode(sidNum, voiceNum) {
    .eval var sidOffset = sidNum * 25
    .eval var voiceOffset = voiceNum * 7
    .eval var totalOffset = sidOffset + voiceOffset
    .eval var voiceIndex = sidNum * 3 + voiceNum

    lda sidRegisterMirror + totalOffset + 4
    and #$08
    bne !analyzeFreq+

    lda sidRegisterMirror + totalOffset + 4
    and #$01               // Check GATE bit and skip if off
    beq !skipVoice+

!analyzeFreq:
    ldy sidRegisterMirror + totalOffset + 1  // High byte of frequency

    cpy #$40
    bcs !useHighTable+      // >= 0x4000: use high table

    cpy #$10
    bcs !useMidTable+       // >= 0x1000: use mid table

    // Low frequencies (0x0000-0x0FFF)
    tya                     // High byte in A
    asl
    asl
    asl
    asl
    sta !tempIndex+ + 1     // Store high nibble (self-modifying)
    lda sidRegisterMirror + totalOffset + 0  // Low byte
    lsr
    lsr
    lsr
    lsr                     // Low byte >> 4 (top nibble)
!tempIndex:
    ora #$00                // OR with (high byte << 4)
    tax
    lda FreqToBarLo, x
    tax
    jmp !gotBar+

!useMidTable:
    // Mid frequencies (0x1000-0x3FFF)
    tya
    sec
    sbc #$10                // Subtract 16 to get 0-47 range
    asl
    asl                     // * 4
    sta !tempIndex2+ + 1
    lda sidRegisterMirror + totalOffset + 0
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr                     // Top 2 bits of low byte
!tempIndex2:
    ora #$00
    tax
    lda FreqToBarMid, x
    tax
    jmp !gotBar+

!useHighTable:
    // High frequencies (>= 0x4000)
    lda FreqToBarHi, y
    tax

!gotBar:
    lda sidRegisterMirror + totalOffset + 6
    and #$0f
    tay
    lda releaseRateHi, y
    sta voiceReleaseHi + voiceIndex
    lda releaseRateLo, y
    sta voiceReleaseLo + voiceIndex

    lda sidRegisterMirror + totalOffset + 6
    lsr
    lsr
    lsr
    lsr
    tay
    lda sustainToHeight, y
    sta targetBarHeights, x
    lda #voiceIndex
    sta barVoiceMap, x

!skipVoice:
    rts
}

// Generate code for SID 0 (voices 0-2)
AnalyzeVoice_S0V0: AnalyzeVoiceCode(0, 0)
AnalyzeVoice_S0V1: AnalyzeVoiceCode(0, 1)
AnalyzeVoice_S0V2: AnalyzeVoiceCode(0, 2)

// Generate code for SID 1 (voices 3-5)
AnalyzeVoice_S1V0: AnalyzeVoiceCode(1, 0)
AnalyzeVoice_S1V1: AnalyzeVoiceCode(1, 1)
AnalyzeVoice_S1V2: AnalyzeVoiceCode(1, 2)

// Generate code for SID 2 (voices 6-8)
AnalyzeVoice_S2V0: AnalyzeVoiceCode(2, 0)
AnalyzeVoice_S2V1: AnalyzeVoiceCode(2, 1)
AnalyzeVoice_S2V2: AnalyzeVoiceCode(2, 2)

// Generate code for SID 3 (voices 9-11)
AnalyzeVoice_S3V0: AnalyzeVoiceCode(3, 0)
AnalyzeVoice_S3V1: AnalyzeVoiceCode(3, 1)
AnalyzeVoice_S3V2: AnalyzeVoiceCode(3, 2)

//; =============================================================================
//; BAR ANIMATION UPDATE
//; =============================================================================

UpdateBars:
    ldx #0
!loop:
    lda targetBarHeights, x
    beq !decay+

    lda barHeights, x
    clc
    adc #BAR_INCREASE_RATE
    cmp targetBarHeights, x
    bcc !skip+
    ldy targetBarHeights, x
    lda #0
    sta targetBarHeights, x
    tya
!skip:
    sta barHeights, x
    jmp !next+
    
!decay:
    lda barHeights, x
    beq !next+

    ldy barVoiceMap, x
    sec
    lda barHeightsLo, x
    sbc voiceReleaseLo, y
    sta barHeightsLo, x
    lda barHeights, x
    sbc voiceReleaseHi, y
    bcs !skip+
    lda #$00
    sta barHeightsLo, x
!skip:
    sta barHeights, x

!next:
    inx
    cpx #NUM_FREQUENCY_BARS
    bne !loop-

    rts

//; =============================================================================
//; SMOOTHING ALGORITHM
//; =============================================================================

ApplySmoothing:

    ldx #NUM_FREQUENCY_BARS - 1
!loop:
    clc
    lda barHeights + 0, x
    ldy barHeights - 1, x
    adc neighbourSmoothVals, y
    ldy barHeights + 1, x
    adc neighbourSmoothVals, y
    ldy barHeights - 2, x
    adc neighbourSmoothVals2, y
    ldy barHeights + 2, x
    adc neighbourSmoothVals2, y
    cmp #MAX_BAR_HEIGHT
    bcc !skip+
    lda #MAX_BAR_HEIGHT
!skip:
    sta smoothedHeights, x
    dex
    bpl !loop-
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