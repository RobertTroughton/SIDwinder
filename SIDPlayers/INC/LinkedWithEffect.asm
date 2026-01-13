#importonce

// =============================================================================
//                          LINKED WITH EFFECT
//                   Right-to-left color sweep text intro
// =============================================================================
// Displays "Linked With" / "SIDquake.C64demo.com" with color fade effect
// Timing: 1s fade-in, 2s hold, 1s fade-out (200 frames @ 50fps)
// =============================================================================

.const EFFECT_TOTAL_FRAMES      = 200
.const EFFECT_FADE_IN_END       = 50
.const EFFECT_HOLD_END          = 150
.const EFFECT_LINE1_Y           = 11
.const EFFECT_LINE2_Y           = 13
.const EFFECT_LINE_X            = 10
.const EFFECT_WIDTH             = 20

// =============================================================================
// EFFECT ENTRY POINT
// =============================================================================

RunLinkedWithEffect:
    // Save and setup VIC state
    lda $d011
    sta effectSaved
    lda $d018
    sta effectSaved+1
    lda $dd00
    sta effectSaved+2
    lda #$1b
    sta $d011
    lda #$17
    sta $d018
    lda #$97
    sta $dd00

    // Clear screen
    ldx #0
    lda #$20
!clr:
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne !clr-

    // Draw text and init colors to black
    ldx #EFFECT_WIDTH-1
!txt:
    lda EffectLine1,x
    sta $0400 + (EFFECT_LINE1_Y * 40) + EFFECT_LINE_X,x
    lda EffectLine2,x
    sta $0400 + (EFFECT_LINE2_Y * 40) + EFFECT_LINE_X,x
    lda #0
    sta $d800 + (EFFECT_LINE1_Y * 40) + EFFECT_LINE_X,x
    sta $d800 + (EFFECT_LINE2_Y * 40) + EFFECT_LINE_X,x
    dex
    bpl !txt-

    // Init frame counter
    lda #0
    sta effectFrame
    sta effectFrame+1

EffectLoop:
    // VSync
    bit $d011
    bpl *-3
    bit $d011
    bmi *-3

    // Calculate wave position and mode based on frame
    lda effectFrame+1
    bne !fadeOut+
    lda effectFrame
    cmp #EFFECT_FADE_IN_END
    bcc !fadeIn+
    cmp #EFFECT_HOLD_END
    bcc !hold+

!fadeOut:
    lda effectFrame
    sec
    sbc #EFFECT_HOLD_END
    lsr
    eor #$ff              // Invert for fade out direction
    clc
    adc #EFFECT_WIDTH
    sta effectWave
    lda #1                // Mode 1 = fade out
    bne !doColor+

!fadeIn:
    lda #EFFECT_FADE_IN_END-1
    sec
    sbc effectFrame
    lsr
    sta effectWave
    lda #0                // Mode 0 = fade in
    beq !doColor+

!hold:
    lda #1                // White
    ldx #EFFECT_WIDTH-1
!hLoop:
    sta $d800 + (EFFECT_LINE1_Y * 40) + EFFECT_LINE_X,x
    sta $d800 + (EFFECT_LINE2_Y * 40) + EFFECT_LINE_X,x
    dex
    bpl !hLoop-
    jmp !next+

!doColor:
    sta effectMode
    ldx #EFFECT_WIDTH-1
!cLoop:
    txa
    sec
    sbc effectWave
    bmi !cBright+
    cmp #3
    bcs !cDark+
    tay
    lda effectMode
    beq !fadeInCol+
    lda EffectColOut,y
    jmp !cStore+
!fadeInCol:
    lda EffectColIn,y
    jmp !cStore+
!cDark:
    lda effectMode
    bne !cWhite+
    lda #0
    beq !cStore+
!cWhite:
    lda #1
    bne !cStore+
!cBright:
    lda effectMode
    beq !cW2+
    lda #0
    beq !cStore+
!cW2:
    lda #1
!cStore:
    sta $d800 + (EFFECT_LINE1_Y * 40) + EFFECT_LINE_X,x
    sta $d800 + (EFFECT_LINE2_Y * 40) + EFFECT_LINE_X,x
    dex
    bpl !cLoop-

!next:
    inc effectFrame
    bne !noHi+
    inc effectFrame+1
!noHi:
    lda effectFrame+1
    bne !done+
    lda effectFrame
    cmp #EFFECT_TOTAL_FRAMES
    bcs !done+
    jmp EffectLoop

!done:
    lda effectSaved
    sta $d011
    lda effectSaved+1
    sta $d018
    lda effectSaved+2
    sta $dd00
    rts

// =============================================================================
// DATA
// =============================================================================

effectFrame:    .word 0
effectWave:     .byte 0
effectMode:     .byte 0
effectSaved:    .byte 0, 0, 0

// Color gradients (3 colors each for smaller code)
EffectColIn:    .byte $0b, $0c, $01      // black->grey->white
EffectColOut:   .byte $0c, $0b, $00      // white->grey->black

// "    Linked With    " (20 chars)
EffectLine1:
    .byte $20, $20, $20, $20, $4c, $09, $0e, $0b, $05, $04
    .byte $20, $57, $09, $14, $08, $20, $20, $20, $20, $20

// "SIDquake.C64demo.com" (20 chars)
EffectLine2:
    .byte $53, $49, $44, $11, $15, $01, $0b, $05, $2e, $43
    .byte $36, $34, $04, $05, $0d, $0f, $2e, $03, $0f, $0d
