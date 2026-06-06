//; =============================================================================
//;                       3-CHANNEL BAR ANALYSIS MODULE
//;        Per-SID-channel spectrum analysis for stacked visualizers.
//;        Voice idx % 3 determines which channel a voice contributes to:
//;            voices 0,3,6,9  -> channel 0
//;            voices 1,4,7,10 -> channel 1
//;            voices 2,5,8,11 -> channel 2
//; =============================================================================

#importonce

//; Required constants that must be defined before including this file:
//; - NUM_FREQUENCY_BARS
//; - TOP_SPECTRUM_HEIGHT  (per-channel height in chars)
//; - BAR_INCREASE_RATE
//; - BAR_DECREASE_RATE
//; - MAX_BAR_HEIGHT      (per-channel max in pixels)

//; =============================================================================
//; PER-CHANNEL BAR STATE DATA
//; =============================================================================

.align NUM_FREQUENCY_BARS
barHeightsLoCh0:        .fill NUM_FREQUENCY_BARS, 0
.align NUM_FREQUENCY_BARS
barHeightsLoCh1:        .fill NUM_FREQUENCY_BARS, 0
.align NUM_FREQUENCY_BARS
barHeightsLoCh2:        .fill NUM_FREQUENCY_BARS, 0

.align NUM_FREQUENCY_BARS
barVoiceMapCh0:         .fill NUM_FREQUENCY_BARS, $03
.align NUM_FREQUENCY_BARS
barVoiceMapCh1:         .fill NUM_FREQUENCY_BARS, $03
.align NUM_FREQUENCY_BARS
barVoiceMapCh2:         .fill NUM_FREQUENCY_BARS, $03

.align NUM_FREQUENCY_BARS
smoothedHeightsCh0:     .fill NUM_FREQUENCY_BARS, 0
.align NUM_FREQUENCY_BARS
smoothedHeightsCh1:     .fill NUM_FREQUENCY_BARS, 0
.align NUM_FREQUENCY_BARS
smoothedHeightsCh2:     .fill NUM_FREQUENCY_BARS, 0

.align NUM_FREQUENCY_BARS
targetBarHeightsCh0:    .fill NUM_FREQUENCY_BARS, 0
.align NUM_FREQUENCY_BARS
targetBarHeightsCh1:    .fill NUM_FREQUENCY_BARS, 0
.align NUM_FREQUENCY_BARS
targetBarHeightsCh2:    .fill NUM_FREQUENCY_BARS, 0

.align NUM_FREQUENCY_BARS + 4
.byte $00, $00
barHeightsCh0:          .fill NUM_FREQUENCY_BARS, 0
.byte $00, $00

.align NUM_FREQUENCY_BARS + 4
.byte $00, $00
barHeightsCh1:          .fill NUM_FREQUENCY_BARS, 0
.byte $00, $00

.align NUM_FREQUENCY_BARS + 4
.byte $00, $00
barHeightsCh2:          .fill NUM_FREQUENCY_BARS, 0
.byte $00, $00

//; voiceToChannel[voice 0..11] = channel 0..2 (voice mod 3)
voiceToChannel:
    .byte 0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2

//; =============================================================================
//; VOICE STATE DATA (4 SIDs x 3 voices = 12)
//; =============================================================================

.align 16
voiceReleaseHi:         .fill 12, 0
                        .fill 4, BAR_DECREASE_RATE

.align 16
voiceReleaseLo:         .fill 12, 0
                        .fill 4, 0

//; =============================================================================
//; CALCULATION TABLES
//; =============================================================================

.align 128
neighbourSmoothVals:    .fill MAX_BAR_HEIGHT + 1, floor(i * 32.0 / 100.0)
.align 128
neighbourSmoothVals2:   .fill MAX_BAR_HEIGHT + 1, floor(i * 12.0 / 100.0)

//; =============================================================================
//; SID REGISTER ANALYSIS (supports up to 4 SIDs = 12 voices)
//; =============================================================================

.const zpRegPtr    = $FB    // 2-byte pointer to current SID's registers
.const zpVoiceIdx  = $FD    // Voice index for current voice (0..11)
.const zpTempByte  = $FE    // Temporary storage (freq high byte, then sustain height)

AnalyzeSIDRegisters:
    lda zpRegPtr
    pha
    lda zpRegPtr + 1
    pha
    lda zpVoiceIdx
    pha
    lda zpTempByte
    pha

    // SID 1 (always)
    lda #<sidRegisterMirror
    sta zpRegPtr
    lda #>sidRegisterMirror
    sta zpRegPtr + 1
    lda #0
    sta zpVoiceIdx
    jsr AnalyzeSIDChip

    lda NumSIDChips
    cmp #2
    bcs !doSID2+
    jmp !restoreZP+
!doSID2:
    lda #<(sidRegisterMirror + 25)
    sta zpRegPtr
    lda #>(sidRegisterMirror + 25)
    sta zpRegPtr + 1
    lda #3
    sta zpVoiceIdx
    jsr AnalyzeSIDChip

    lda NumSIDChips
    cmp #3
    bcs !doSID3+
    jmp !restoreZP+
!doSID3:
    lda #<(sidRegisterMirror + 50)
    sta zpRegPtr
    lda #>(sidRegisterMirror + 50)
    sta zpRegPtr + 1
    lda #6
    sta zpVoiceIdx
    jsr AnalyzeSIDChip

    lda NumSIDChips
    cmp #4
    bcc !restoreZP+
    lda #<(sidRegisterMirror + 75)
    sta zpRegPtr
    lda #>(sidRegisterMirror + 75)
    sta zpRegPtr + 1
    lda #9
    sta zpVoiceIdx
    jsr AnalyzeSIDChip

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

//; Analyze all 3 voices on one SID chip
AnalyzeSIDChip:
    jsr AnalyzeSingleVoice

    clc
    lda zpRegPtr
    adc #7
    sta zpRegPtr
    bcc !nc1+
    inc zpRegPtr + 1
!nc1:
    inc zpVoiceIdx
    jsr AnalyzeSingleVoice

    clc
    lda zpRegPtr
    adc #7
    sta zpRegPtr
    bcc !nc2+
    inc zpRegPtr + 1
!nc2:
    inc zpVoiceIdx
    jmp AnalyzeSingleVoice

//; Analyze one voice; map to channel via voiceToChannel[voiceIdx]
AnalyzeSingleVoice:
    ldy #4
    lda (zpRegPtr), y
    and #$08
    bne !analyzeFreq+

    lda (zpRegPtr), y
    and #$01
    bne !analyzeFreq+
    rts

!analyzeFreq:
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
    // Mid frequencies (0x1000-0x3FFF)
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
    // High frequencies (>= 0x4000)
    ldy zpTempByte
    lda FreqToBarHi, y
    tax

!gotBar:
    // X = bar index. Update voice release rates indexed by zpVoiceIdx.
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

    // Compute target height from sustain (upper nibble of ADSR)
    ldy #6
    lda (zpRegPtr), y
    lsr
    lsr
    lsr
    lsr
    tay
    lda sustainToHeight, y
    sta zpTempByte                  // save target height (freq hi no longer needed)

    // Dispatch by channel = voiceToChannel[zpVoiceIdx]
    ldy zpVoiceIdx
    lda voiceToChannel, y
    cmp #1
    beq !ch1+
    bcs !ch2+

!ch0:
    lda zpTempByte
    cmp targetBarHeightsCh0, x
    bcc !skipVoice+
    sta targetBarHeightsCh0, x
    lda zpVoiceIdx
    sta barVoiceMapCh0, x
    rts

!ch1:
    lda zpTempByte
    cmp targetBarHeightsCh1, x
    bcc !skipVoice+
    sta targetBarHeightsCh1, x
    lda zpVoiceIdx
    sta barVoiceMapCh1, x
    rts

!ch2:
    lda zpTempByte
    cmp targetBarHeightsCh2, x
    bcc !skipVoice+
    sta targetBarHeightsCh2, x
    lda zpVoiceIdx
    sta barVoiceMapCh2, x

!skipVoice:
    rts

//; =============================================================================
//; BAR ANIMATION UPDATE - applied to one channel
//; =============================================================================

.macro UpdateBarsForChannel(barH, barHLo, targetBarH, barVM) {
    ldx #0
!loop:
    lda targetBarH, x
    beq !decay+

    lda barH, x
    clc
    adc #BAR_INCREASE_RATE
    cmp targetBarH, x
    bcc !skip+
    ldy targetBarH, x
    lda #0
    sta targetBarH, x
    tya
!skip:
    sta barH, x
    jmp !next+

!decay:
    lda barH, x
    beq !next+

    ldy barVM, x
    sec
    lda barHLo, x
    sbc voiceReleaseLo, y
    sta barHLo, x
    lda barH, x
    sbc voiceReleaseHi, y
    bcs !skip2+
    lda #$00
    sta barHLo, x
!skip2:
    sta barH, x

!next:
    inx
    cpx #NUM_FREQUENCY_BARS
    bne !loop-
}

UpdateBars:
    UpdateBarsForChannel(barHeightsCh0, barHeightsLoCh0, targetBarHeightsCh0, barVoiceMapCh0)
    UpdateBarsForChannel(barHeightsCh1, barHeightsLoCh1, targetBarHeightsCh1, barVoiceMapCh1)
    UpdateBarsForChannel(barHeightsCh2, barHeightsLoCh2, targetBarHeightsCh2, barVoiceMapCh2)
    rts

//; =============================================================================
//; SMOOTHING ALGORITHM - applied to one channel
//; Smooths within a channel only (no cross-channel blending).
//; =============================================================================

.macro ApplySmoothingForChannel(barH, smoothedH) {
    ldx #NUM_FREQUENCY_BARS - 1
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
    sta smoothedH, x
    dex
    bpl !loop-
}

ApplySmoothing:
    ApplySmoothingForChannel(barHeightsCh0, smoothedHeightsCh0)
    ApplySmoothingForChannel(barHeightsCh1, smoothedHeightsCh1)
    ApplySmoothingForChannel(barHeightsCh2, smoothedHeightsCh2)
    rts
