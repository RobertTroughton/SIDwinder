//; =============================================================================
//;                      PER-VOICE BAR ANALYSIS MODULE
//;           Maintains separate bar arrays for each SID voice
//;           Each voice maps to its own screen section (3 x 20 bars)
//; =============================================================================

#importonce

//; Required constants that must be defined before including this file:
//; - NUM_BARS_PER_VOICE   (should be 20)
//; - TOP_SPECTRUM_HEIGHT
//; - BAR_INCREASE_RATE
//; - BAR_DECREASE_RATE
//; - MAX_BAR_HEIGHT

//; =============================================================================
//; BAR STATE DATA - Voice 0 (upper section)
//; =============================================================================

.align NUM_BARS_PER_VOICE
barHeightsLoV0:             .fill NUM_BARS_PER_VOICE, 0

.align NUM_BARS_PER_VOICE
barVoiceMapV0:              .fill NUM_BARS_PER_VOICE, $00

.align NUM_BARS_PER_VOICE
smoothedHeightsV0:          .fill NUM_BARS_PER_VOICE, 0

.align NUM_BARS_PER_VOICE
targetBarHeightsV0:         .fill NUM_BARS_PER_VOICE, 0

.align NUM_BARS_PER_VOICE + 4
.byte $00, $00
barHeightsV0:               .fill NUM_BARS_PER_VOICE, 0
.byte $00, $00

//; =============================================================================
//; BAR STATE DATA - Voice 1 (lower section)
//; =============================================================================

.align NUM_BARS_PER_VOICE
barHeightsLoV1:             .fill NUM_BARS_PER_VOICE, 0

.align NUM_BARS_PER_VOICE
barVoiceMapV1:              .fill NUM_BARS_PER_VOICE, $01

.align NUM_BARS_PER_VOICE
smoothedHeightsV1:          .fill NUM_BARS_PER_VOICE, 0

.align NUM_BARS_PER_VOICE
targetBarHeightsV1:         .fill NUM_BARS_PER_VOICE, 0

.align NUM_BARS_PER_VOICE + 4
.byte $00, $00
barHeightsV1:               .fill NUM_BARS_PER_VOICE, 0
.byte $00, $00

//; =============================================================================
//; BAR STATE DATA - Voice 2 (lowest section)
//; =============================================================================

.align NUM_BARS_PER_VOICE
barHeightsLoV2:             .fill NUM_BARS_PER_VOICE, 0

.align NUM_BARS_PER_VOICE
barVoiceMapV2:              .fill NUM_BARS_PER_VOICE, $02

.align NUM_BARS_PER_VOICE
smoothedHeightsV2:          .fill NUM_BARS_PER_VOICE, 0

.align NUM_BARS_PER_VOICE
targetBarHeightsV2:         .fill NUM_BARS_PER_VOICE, 0

.align NUM_BARS_PER_VOICE + 4
.byte $00, $00
barHeightsV2:               .fill NUM_BARS_PER_VOICE, 0
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
//; SID REGISTER ANALYSIS - Per Voice
//; Analyzes each voice separately into its own bar arrays
//; Voice 0 → V0, Voice 1 → V1, Voice 2 → V2
//; Multi-SID: voices are mapped modulo 3 (voice 3→V0, 4→V1, 5→V2, etc.)
//; =============================================================================

.const zpRegPtr    = $FB
.const zpVoiceIdx  = $FD
.const zpTempByte  = $FE

// Alias for compatibility with MusicPlayback.asm (which calls AnalyzeSIDRegisters)
AnalyzeSIDRegisters:
AnalyzeSIDRegistersPerVoice:
    lda zpRegPtr
    pha
    lda zpRegPtr + 1
    pha
    lda zpVoiceIdx
    pha
    lda zpTempByte
    pha

    // SID 1 (always present)
    lda #<sidRegisterMirror
    sta zpRegPtr
    lda #>sidRegisterMirror
    sta zpRegPtr + 1
    lda #0
    sta zpVoiceIdx
    jsr AnalyzeSIDChipPerVoice

    // SID 2 if present
    lda NumSIDChips
    cmp #2
    bcc !restoreZP+
    lda #<(sidRegisterMirror + 25)
    sta zpRegPtr
    lda #>(sidRegisterMirror + 25)
    sta zpRegPtr + 1
    lda #3
    sta zpVoiceIdx
    jsr AnalyzeSIDChipPerVoice

    // SID 3 if present
    lda NumSIDChips
    cmp #3
    bcc !restoreZP+
    lda #<(sidRegisterMirror + 50)
    sta zpRegPtr
    lda #>(sidRegisterMirror + 50)
    sta zpRegPtr + 1
    lda #6
    sta zpVoiceIdx
    jsr AnalyzeSIDChipPerVoice

    // SID 4 if present
    lda NumSIDChips
    cmp #4
    bcc !restoreZP+
    lda #<(sidRegisterMirror + 75)
    sta zpRegPtr
    lda #>(sidRegisterMirror + 75)
    sta zpRegPtr + 1
    lda #9
    sta zpVoiceIdx
    jsr AnalyzeSIDChipPerVoice

!restoreZP:
    pla
    sta zpTempByte
    pla
    sta zpVoiceIdx
    pla
    sta zpRegPtr + 1
    pla
    sta zpRegPtr
    rts

//; =============================================================================
//; Analyze all 3 voices on one SID chip - routing each to its section
//; =============================================================================

AnalyzeSIDChipPerVoice:
    // Voice 0 (of this SID chip) → V0
    jsr SetupTargetV0
    jsr AnalyzeSingleVoicePerVoice

    // Voice 1 → V1
    clc
    lda zpRegPtr
    adc #7
    sta zpRegPtr
    bcc !nc1+
    inc zpRegPtr + 1
!nc1:
    inc zpVoiceIdx
    jsr SetupTargetV1
    jsr AnalyzeSingleVoicePerVoice

    // Voice 2 → V2
    clc
    lda zpRegPtr
    adc #7
    sta zpRegPtr
    bcc !nc2+
    inc zpRegPtr + 1
!nc2:
    inc zpVoiceIdx
    jsr SetupTargetV2
    jmp AnalyzeSingleVoicePerVoice

//; =============================================================================
//; Setup self-modifying code to route analysis to correct voice arrays
//; =============================================================================

SetupTargetV0:
    lda #<targetBarHeightsV0
    sta smcCmpTarget + 1
    sta smcStaTarget + 1
    lda #>targetBarHeightsV0
    sta smcCmpTarget + 2
    sta smcStaTarget + 2
    lda #<barVoiceMapV0
    sta smcStaVoiceMap + 1
    lda #>barVoiceMapV0
    sta smcStaVoiceMap + 2
    rts

SetupTargetV1:
    lda #<targetBarHeightsV1
    sta smcCmpTarget + 1
    sta smcStaTarget + 1
    lda #>targetBarHeightsV1
    sta smcCmpTarget + 2
    sta smcStaTarget + 2
    lda #<barVoiceMapV1
    sta smcStaVoiceMap + 1
    lda #>barVoiceMapV1
    sta smcStaVoiceMap + 2
    rts

SetupTargetV2:
    lda #<targetBarHeightsV2
    sta smcCmpTarget + 1
    sta smcStaTarget + 1
    lda #>targetBarHeightsV2
    sta smcCmpTarget + 2
    sta smcStaTarget + 2
    lda #<barVoiceMapV2
    sta smcStaVoiceMap + 1
    lda #>barVoiceMapV2
    sta smcStaVoiceMap + 2
    rts

//; =============================================================================
//; Single Voice Analysis - writes to self-modified target arrays
//; =============================================================================

AnalyzeSingleVoicePerVoice:
    // Check TEST bit (register offset 4, bit 3)
    ldy #4
    lda (zpRegPtr), y
    and #$08
    bne !analyzeFreq+

    // Check GATE bit (register offset 4, bit 0)
    lda (zpRegPtr), y
    and #$01
    bne !analyzeFreq+
    rts

!analyzeFreq:
    // Get frequency high byte (register offset 1)
    ldy #1
    lda (zpRegPtr), y
    sta zpTempByte
    tay

    cpy #$40
    bcs !useHighTable+

    cpy #$10
    bcs !useMidTable+

    // Low frequencies (0x0000-0x0FFF)
    tya
    asl
    asl
    asl
    asl
    sta !tempOra+ + 1
    ldy #0
    lda (zpRegPtr), y
    lsr
    lsr
    lsr
    lsr
!tempOra:
    ora #$00
    tax
    lda FreqToBarLo, x
    tax
    jmp !gotBar+

!useMidTable:
    lda zpTempByte
    sec
    sbc #$10
    asl
    asl
    sta !tempOra2+ + 1
    ldy #0
    lda (zpRegPtr), y
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
!tempOra2:
    ora #$00
    tax
    lda FreqToBarMid, x
    tax
    jmp !gotBar+

!useHighTable:
    ldy zpTempByte
    lda FreqToBarHi, y
    tax

!gotBar:
    // X = bar index (0 to NUM_BARS_PER_VOICE-1)
    // Store release rate for this voice
    ldy #6
    lda (zpRegPtr), y
    and #$0f
    tay
    lda releaseRateHi, y
    ldy zpVoiceIdx
    sta voiceReleaseHi, y

    ldy #6
    lda (zpRegPtr), y
    and #$0f
    tay
    lda releaseRateLo, y
    ldy zpVoiceIdx
    sta voiceReleaseLo, y

    // Get sustain level and compare with existing target
    ldy #6
    lda (zpRegPtr), y
    lsr
    lsr
    lsr
    lsr
    tay
    lda sustainToHeight, y

    // Self-modified: compare and store to voice-specific target arrays
smcCmpTarget:
    cmp targetBarHeightsV0, x
    bcc !skipVoice+
smcStaTarget:
    sta targetBarHeightsV0, x

    lda zpVoiceIdx
smcStaVoiceMap:
    sta barVoiceMapV0, x

!skipVoice:
    rts

//; =============================================================================
//; UPDATE BARS - Per Voice (macro generates 3 copies)
//; =============================================================================

.macro @UpdateBarsForVoice(targetBars, barH, barHLo, voiceMap) {
    ldx #0
!loop:
    lda targetBars, x
    beq !decay+

    lda barH, x
    clc
    adc #BAR_INCREASE_RATE
    cmp targetBars, x
    bcc !store+
    ldy targetBars, x
    lda #0
    sta targetBars, x
    tya
!store:
    sta barH, x
    jmp !next+

!decay:
    lda barH, x
    beq !next+

    ldy voiceMap, x
    sec
    lda barHLo, x
    sbc voiceReleaseLo, y
    sta barHLo, x
    lda barH, x
    sbc voiceReleaseHi, y
    bcs !store+
    lda #$00
    sta barHLo, x
!store:
    sta barH, x

!next:
    inx
    cpx #NUM_BARS_PER_VOICE
    bne !loop-
    rts
}

UpdateBarsV0: UpdateBarsForVoice(targetBarHeightsV0, barHeightsV0, barHeightsLoV0, barVoiceMapV0)
UpdateBarsV1: UpdateBarsForVoice(targetBarHeightsV1, barHeightsV1, barHeightsLoV1, barVoiceMapV1)
UpdateBarsV2: UpdateBarsForVoice(targetBarHeightsV2, barHeightsV2, barHeightsLoV2, barVoiceMapV2)

UpdateBarsAllVoices:
    jsr UpdateBarsV0
    jsr UpdateBarsV1
    jmp UpdateBarsV2

//; =============================================================================
//; SMOOTHING - Per Voice (macro generates 3 copies)
//; =============================================================================

.macro @ApplySmoothingForVoice(barH, smoothed) {
    ldx #NUM_BARS_PER_VOICE - 1
!loop:
    clc
    lda barH + 0, x
    ldy barH - 1, x
    adc neighbourSmoothVals, y
    ldy barH + 1, x
    adc neighbourSmoothVals, y
    ldy barH - 2, x
    adc neighbourSmoothVals2, y
    ldy barH + 2, x
    adc neighbourSmoothVals2, y
    cmp #MAX_BAR_HEIGHT
    bcc !skip+
    lda #MAX_BAR_HEIGHT
!skip:
    sta smoothed, x
    dex
    bpl !loop-
    rts
}

ApplySmoothingV0: ApplySmoothingForVoice(barHeightsV0, smoothedHeightsV0)
ApplySmoothingV1: ApplySmoothingForVoice(barHeightsV1, smoothedHeightsV1)
ApplySmoothingV2: ApplySmoothingForVoice(barHeightsV2, smoothedHeightsV2)

ApplySmoothingAllVoices:
    jsr ApplySmoothingV0
    jsr ApplySmoothingV1
    jmp ApplySmoothingV2

//; =============================================================================
//; INITIALIZATION
//; =============================================================================

InitializeBarArrays:
    ldy #0
    lda #0
!loop:
    sta barHeightsV0 - 2, y
    sta barHeightsV1 - 2, y
    sta barHeightsV2 - 2, y
    sta smoothedHeightsV0, y
    sta smoothedHeightsV1, y
    sta smoothedHeightsV2, y
    iny
    cpy #NUM_BARS_PER_VOICE + 4
    bne !loop-
    rts

//; =============================================================================
//; END OF PER-VOICE BAR ANALYSIS MODULE
//; =============================================================================
