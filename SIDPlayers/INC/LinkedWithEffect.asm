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

// When BANK_AWARE_EFFECT is defined the host player has already selected its
// VIC bank and copied a charset into CHARSET_RAM, so the intro draws into that
// player's in-bank screen. Otherwise it falls back to the classic bank-0 $0400
// screen with the lowercase ROM charset (used by all the other players).
#if BANK_AWARE_EFFECT
.var ScreenAddress = SCREEN_RAM
#else
.var ScreenAddress = $0400
#endif
.var VIC_COLOURMEMORY = $d800

// =============================================================================
// DATA
// =============================================================================

EffectLine1:            .byte $20, $20, $20, $20, $4c, $09, $0e, $0b, $05, $04, $20, $57, $09, $14, $08, $20, $20, $20, $20, $20
EffectLine2:            .byte $53, $49, $44, $11, $15, $01, $0b, $05, $2e, $43, $36, $34, $04, $05, $0d, $0f, $2e, $03, $0f, $0d
ColourFadeValues:       .fill 70, $00
                        .byte $0b, $0c, $0f
                        .fill 80, $01
                        .byte $0d, $05, $09
                        .fill 48, $00
                        .byte $ff

// =============================================================================
// EFFECT ENTRY POINT
// =============================================================================

RunLinkedWithEffect:

#if BANK_AWARE_EFFECT
    // Screen addresses are fixed in-bank; no relocation needed.
#else
    // Relocate the intro screen onto the safe bank-0 page chosen by the
    // exporter (avoids a SID that loads low). Patch the clear-loop base and the
    // two text-line store high bytes; the colour writes use fixed $D800.
    ldx IntroScreenHi
    stx ClrSt + 2
    inx
    stx TxtL1 + 2
    inx
    stx TxtL2 + 2
#endif

    jsr VSync

    lda #$00
    sta $d020
    sta $d021

    jsr VSync

    // Clear 4 pages (1000 bytes) of the screen via a single self-modifying
    // store whose high byte walks through the pages.
    ldx #0
    ldy #4
    lda #$20
!clr:
ClrSt:
    sta ScreenAddress,x
    inx
    bne !clr-
    inc ClrSt + 2
    dey
    bne !clr-

    // Draw text and init colors to black
    ldx #EFFECT_WIDTH-1
!txt:
    lda EffectLine1,x
TxtL1:
    sta ScreenAddress + (EFFECT_LINE1_Y * 40) + EFFECT_LINE_X,x
    lda EffectLine2,x
TxtL2:
    sta ScreenAddress + (EFFECT_LINE2_Y * 40) + EFFECT_LINE_X,x

    lda #0              // Start with black (invisible)
    sta VIC_COLOURMEMORY + (EFFECT_LINE1_Y * 40) + EFFECT_LINE_X,x
    sta VIC_COLOURMEMORY + (EFFECT_LINE2_Y * 40) + EFFECT_LINE_X,x
    dex
    bpl !txt-

    jsr VSync

#if BANK_AWARE_EFFECT
    lda #D018_VALUE             // in-bank screen + charset; VIC bank already set
    sta $d018
#else
    // screen = IntroScreenHi page, charset = lowercase ROM ($1800), VIC bank 0
    lda IntroD018
    sta $d018
    lda #$97
    sta $dd00
#endif
    lda #$08
    sta $d016
    lda #$00
    sta $d015
    lda #$1b
    sta $d011

    ldy #$00

OuterLoop:
    ldy #$00

    jsr VSync

    ldx #0
!loop:
    lda ColourFadeValues, y
    sta VIC_COLOURMEMORY + (EFFECT_LINE1_Y * 40) + EFFECT_LINE_X, x
    sta VIC_COLOURMEMORY + (EFFECT_LINE2_Y * 40) + EFFECT_LINE_X, x
    iny
    inx
    cpx #20
    bne !loop-

    inc OuterLoop + 1

    lda ColourFadeValues, y
    bpl OuterLoop

    jsr VSync
    lda #$00
    sta $d011
    jmp VSync

!continue:
    jmp !loop-


