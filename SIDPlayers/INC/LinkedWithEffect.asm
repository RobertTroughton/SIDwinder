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
    // Save VIC state
    lda $d011
    sta effectSaved
    lda $d018
    sta effectSaved+1
    lda $dd00
    sta effectSaved+2
    lda $d021
    sta effectSaved+3

    // Setup for effect: text mode, ROM charset lowercase, bank 0
    lda #$1b
    sta $d011
    lda #$17
    sta $d018
    lda #$97
    sta $dd00
    lda #$00            // Black background
    sta $d021

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
    lda #0              // Start with black (invisible)
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

    // Determine phase based on frame counter
    lda effectFrame+1
    bne !fadeOut+
    lda effectFrame
    cmp #EFFECT_FADE_IN_END
    bcc !fadeIn+
    cmp #EFFECT_HOLD_END
    bcc !hold+

!fadeOut:
    // Fade out phase: wave moves from left (0) to right (19)
    // Columns LEFT of wave = black (already hidden)
    // Columns at wave = gradient (cyan->lightblue->blue->black)
    // Columns RIGHT of wave = white (still visible)
    lda effectFrame
    sec
    sbc #EFFECT_HOLD_END
    lsr                     // Divide by 2 to map 50 frames to ~25 steps
    sta effectWave          // Wave position (0 to ~25, clamped to 19)
    cmp #EFFECT_WIDTH
    bcc !doFadeOut+
    lda #EFFECT_WIDTH-1
    sta effectWave
!doFadeOut:
    ldx #EFFECT_WIDTH-1
!foLoop:
    // Calculate distance from wave: X - wavePos
    lda effectXPos,x
    sec
    sbc effectWave
    bmi !foHidden+          // X < wave, already hidden (black)
    cmp #4
    bcs !foVisible+         // X far right of wave, still visible (white)
    // In gradient zone
    tay
    lda EffectColOut,y
    jmp !foStore+
!foVisible:
    lda #1                  // White
    jmp !foStore+
!foHidden:
    lda #0                  // Black
!foStore:
    sta $d800 + (EFFECT_LINE1_Y * 40) + EFFECT_LINE_X,x
    sta $d800 + (EFFECT_LINE2_Y * 40) + EFFECT_LINE_X,x
    dex
    bpl !foLoop-
    jmp !next+

!fadeIn:
    // Fade in phase: wave moves from right (19) to left (0)
    // Columns LEFT of wave = black (not yet revealed)
    // Columns at wave = gradient (brown->green->lightgreen->white)
    // Columns RIGHT of wave = white (already revealed)
    lda #EFFECT_FADE_IN_END-1
    sec
    sbc effectFrame
    lsr                     // Divide by 2
    sta effectWave          // Wave starts at ~24, goes to 0
    cmp #EFFECT_WIDTH
    bcc !doFadeIn+
    lda #EFFECT_WIDTH-1
    sta effectWave
!doFadeIn:
    ldx #EFFECT_WIDTH-1
!fiLoop:
    // Calculate distance from wave: wavePos - X
    lda effectWave
    sec
    sbc effectXPos,x
    bmi !fiRevealed+        // X > wave, already revealed (white)
    cmp #4
    bcs !fiHidden+          // X far left of wave, still hidden (black)
    // In gradient zone
    tay
    lda EffectColIn,y
    jmp !fiStore+
!fiRevealed:
    lda #1                  // White
    jmp !fiStore+
!fiHidden:
    lda #0                  // Black
!fiStore:
    sta $d800 + (EFFECT_LINE1_Y * 40) + EFFECT_LINE_X,x
    sta $d800 + (EFFECT_LINE2_Y * 40) + EFFECT_LINE_X,x
    dex
    bpl !fiLoop-
    jmp !next+

!hold:
    // Hold phase: all white
    lda #1
    ldx #EFFECT_WIDTH-1
!hLoop:
    sta $d800 + (EFFECT_LINE1_Y * 40) + EFFECT_LINE_X,x
    sta $d800 + (EFFECT_LINE2_Y * 40) + EFFECT_LINE_X,x
    dex
    bpl !hLoop-

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
    // Restore VIC state
    lda effectSaved
    sta $d011
    lda effectSaved+1
    sta $d018
    lda effectSaved+2
    sta $dd00
    lda effectSaved+3
    sta $d021
    rts

// =============================================================================
// DATA
// =============================================================================

effectFrame:    .word 0
effectWave:     .byte 0
effectSaved:    .byte 0, 0, 0, 0

// X position lookup (just 0-19)
effectXPos:     .fill EFFECT_WIDTH, i

// Fade-in colors (reversed): white(1) -> light green(13) -> green(5) -> brown(9)
// Index 0 = at wave (brightest), index 3 = edge near black (darkest transition)
EffectColIn:    .byte 1, 13, 5, 9

// Fade-out colors (reversed): blue(6) -> light blue(14) -> cyan(3) -> white(1)
// Index 0 = at wave (darkest transition), index 3 = edge near white (brightest)
EffectColOut:   .byte 6, 14, 3, 1

// "    Linked With    " (20 chars)
EffectLine1:
    .byte $20, $20, $20, $20, $4c, $09, $0e, $0b, $05, $04
    .byte $20, $57, $09, $14, $08, $20, $20, $20, $20, $20

// "SIDquake.C64demo.com" (20 chars)
EffectLine2:
    .byte $53, $49, $44, $11, $15, $01, $0b, $05, $2e, $43
    .byte $36, $34, $04, $05, $0d, $0f, $2e, $03, $0f, $0d
