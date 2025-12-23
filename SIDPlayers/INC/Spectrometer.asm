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
//; Uses zero page pointers for compact single-routine implementation
//; =============================================================================

//; Zero page locations for voice analysis
.const zpRegPtr    = $FB    // 2-byte pointer to current voice registers
.const zpVoiceIdx  = $FD    // Current voice index (0-11)
.const zpTempByte  = $FE    // Temporary storage

AnalyzeSIDRegisters:
    // Initialize pointer to sidRegisterMirror
    lda #<sidRegisterMirror
    sta zpRegPtr
    lda #>sidRegisterMirror
    sta zpRegPtr + 1

    lda #0
    sta zpVoiceIdx

    // Process all SIDs based on NumSIDChips
    ldx #0                  // SID counter (0-3)

!sidLoop:
    // Process 3 voices for this SID
    ldy #0                  // Voice counter within SID (0-2)

!voiceLoop:
    sty zpTempByte          // Save voice counter
    jsr AnalyzeSingleVoice

    inc zpVoiceIdx

    // Move pointer forward by 7 bytes (one voice worth of registers)
    clc
    lda zpRegPtr
    adc #7
    sta zpRegPtr
    bcc !noCarry1+
    inc zpRegPtr + 1
!noCarry1:

    ldy zpTempByte          // Restore voice counter
    iny
    cpy #3
    bcc !voiceLoop-

    // Move pointer forward by 4 bytes to next SID (25 - 21 = 4)
    clc
    lda zpRegPtr
    adc #4
    sta zpRegPtr
    bcc !noCarry2+
    inc zpRegPtr + 1
!noCarry2:

    inx
    cpx NumSIDChips
    bcc !sidLoop-

    rts

//; =============================================================================
//; Single Voice Analysis Routine
//; Input: zpRegPtr points to current voice's 7 registers
//;        zpVoiceIdx contains voice index (0-11)
//; =============================================================================

AnalyzeSingleVoice:
    // Check TEST bit (register offset 4, bit 3)
    ldy #4
    lda (zpRegPtr), y
    and #$08
    bne !analyzeFreq+

    // Check GATE bit (register offset 4, bit 0)
    lda (zpRegPtr), y
    and #$01
    beq !skipVoice+

!analyzeFreq:
    // Get frequency high byte (register offset 1)
    ldy #1
    lda (zpRegPtr), y
    sta zpTempByte          // Save freq high byte
    tay                     // Y = freq high byte for table lookups

    cpy #$40
    bcs !useHighTable+

    cpy #$10
    bcs !useMidTable+

    // Low frequencies (0x0000-0x0FFF)
    // index = (high_byte << 4) | (low_byte >> 4)
    tya
    asl
    asl
    asl
    asl
    sta !tempOra+ + 1       // Self-modify the ORA operand
    ldy #0
    lda (zpRegPtr), y       // Get freq low byte
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
    // X now contains the bar index
    // Get ADSR register (offset 6) for release rate
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

    // Get sustain level (upper nibble of ADSR)
    ldy #6
    lda (zpRegPtr), y
    lsr
    lsr
    lsr
    lsr
    tay
    lda sustainToHeight, y
    sta targetBarHeights, x

    // Store voice index in bar map
    lda zpVoiceIdx
    sta barVoiceMap, x

!skipVoice:
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