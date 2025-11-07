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
//; VOICE STATE DATA
//; =============================================================================

.align 4
voiceReleaseHi:             .fill 3, 0
                            .byte BAR_DECREASE_RATE

.align 4
voiceReleaseLo:             .fill 3, 0
                            .byte 0

//; =============================================================================
//; CALCULATION TABLES
//; =============================================================================

neighbourScaleVals:         .fill MAX_BAR_HEIGHT + 1, floor(i * 30.0 / 100.0)

//; =============================================================================
//; SID REGISTER ANALYSIS
//; =============================================================================

AnalyzeSIDRegisters:
    .for (var voice = 0; voice < 3; voice++) {

    lda sidRegisterMirror + (voice * 7) + 4
    and #$08
    bne AnalyzeFrequency

    lda sidRegisterMirror + (voice * 7) + 4
    and #$01               // Check GATE bit and skip if off
    beq !skipVoice+

AnalyzeFrequency:

    ldy sidRegisterMirror + (voice * 7) + 1  // High byte of frequency
    
    cpy #$40
    bcs !useHighTable+      // >= 0x4000: use high table
    
    cpy #$10
    bcs !useMidTable+       // >= 0x1000: use mid table
    
    // FIXED: Low frequencies (0x0000-0x0FFF)
    // We need to create an index from both bytes properly
    // The table expects: (freq >> 4) as index (0-255)
    
    // Method 1: If we can use both registers
    tya                     // High byte in A
    asl
    asl
    asl
    asl
    sta tempIndex + 1       // Store high nibble
    lda sidRegisterMirror + (voice * 7) + 0  // Low byte
    lsr
    lsr
    lsr
    lsr                     // Low byte >> 4 (top nibble)
tempIndex:
    ora #$00                // OR with (high byte << 4)
    tax
    lda FreqToBarLo, x
    tax
    jmp !gotBar+
    
    // Alternative Method 2: If we want to be more compact
    // This properly combines high and low bytes:
    // index = (high_byte << 4) | (low_byte >> 4)
    //
    // tya                  // High byte in A  
    // asl
    // asl
    // asl
    // asl                  // High byte << 4 (now in top nibble)
    // sta tempByte         // Save it
    // lda sidRegisterMirror + (voice * 7) + 0  // Low byte
    // lsr
    // lsr  
    // lsr
    // lsr                  // Low byte >> 4 (top nibble to bottom)
    // ora tempByte         // Combine them
    // tax
    // lda FreqToBarLo, x
    // tax
    // jmp !gotBar+
    
!useMidTable:
    // Mid frequencies (0x1000-0x3FFF): use high byte + top bits of low
    tya
    sec
    sbc #$10                // Subtract 16 to get 0-47 range
    asl
    asl                     // * 4
    sta tempIndex2 + 1
    lda sidRegisterMirror + (voice * 7) + 0
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr                     // Top 2 bits of low byte
tempIndex2:
    ora #$00
    tax
    lda FreqToBarMid, x
    tax
    jmp !gotBar+
    
!useHighTable:
    // High frequencies (>= 0x4000): just use high byte
    lda FreqToBarHi, y
    tax

!gotBar:
        lda sidRegisterMirror + (voice * 7) + 6
        and #$0f
        tay
        lda releaseRateHi, y
        sta voiceReleaseHi + voice
        lda releaseRateLo, y
        sta voiceReleaseLo + voice

        lda sidRegisterMirror + (voice * 7) + 6
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
    bpl !skip+
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

neighbourSmoothVals: .fill MAX_BAR_HEIGHT + 1, floor(i * 30.0 / 100.0)

ApplySmoothing:

    //; out = min(MAX_BAR_HEIGHT, current + left * 0.3 + right * 0.3)
    ldx #NUM_FREQUENCY_BARS - 1
!loop:
    clc
    lda barHeights + 0, x
    ldy barHeights - 1, x
    adc neighbourSmoothVals, y
    ldy barHeights + 1, x
    adc neighbourSmoothVals, y
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