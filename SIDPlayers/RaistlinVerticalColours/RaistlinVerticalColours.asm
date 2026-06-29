// =============================================================================
//                          RAISTLIN VERTICAL COLOURS
//          Per-channel SID spectrum painted as colour into a bitmap
//
//   A full-screen multicolour bitmap. The top 96px (12 char rows) hold a
//   user-supplied logo. The bottom of the screen is split into three 32px
//   bands - one per SID channel (voice idx % 3) - each filled with the fixed
//   bit pattern $5a (%01 01 10 10). In multicolour bitmap mode that pattern
//   makes the left 4px of every 8px cell take the screen-RAM upper nibble and
//   the right 4px take the lower nibble, so each char column shows TWO
//   independent 4px-wide vertical strips of colour: 40 columns x 2 = 80 strips.
//
//   We never grow bars. Instead, each strip's spectrometer height selects a
//   COLOUR (per-channel gradient, dark->bright) that is written into screen
//   RAM. The bitmap itself is static; only the screen-RAM nibbles change each
//   frame. A fixed "dither" (whole blanked bitmap rows = $00 instead of $5a)
//   carves a 4px gap at the top/bottom of every band, separating the three
//   bands and giving the colour field a textured, rounded look.
//
//   Colours are completely self-contained in this file (three baked
//   height->colour tables); the build pipeline only injects the logo bitmap +
//   a border colour.
// =============================================================================

.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()

// =============================================================================
// CONFIGURATION CONSTANTS (needed before the includes)
// =============================================================================

.const NUM_FREQUENCY_BARS               = 80
.const NUM_CHANNELS                     = 3

//; Per-channel "height" range. Heights are only ever used to index the colour
//; ramps, never drawn, so 0..MAX_BAR_HEIGHT just sets the colour resolution and
//; the dynamics tuning (shared with the freq/release tables).
.const TOP_SPECTRUM_HEIGHT              = 6
.const MAX_BAR_HEIGHT                   = TOP_SPECTRUM_HEIGHT * 8 - 1     // 47

.const BAR_INCREASE_RATE                = ceil(TOP_SPECTRUM_HEIGHT * 1.3) // 8
.const BAR_DECREASE_RATE                = ceil(TOP_SPECTRUM_HEIGHT * 0.6) // 4

// =============================================================================
// SCREEN LAYOUT (char rows; 25 rows total, 8px each)
//   rows  0..11 : logo (96px)
//   rows 12..15 : band 0  (channel 0)   32px
//   rows 16..19 : band 1  (channel 1)   32px
//   rows 20..23 : band 2  (channel 2)   32px
//   row     24  : blank
// =============================================================================

.const LOGO_CHAR_ROWS                   = 12
.const BAND_CHAR_ROWS                   = 4
.const BAND0_ROW                        = LOGO_CHAR_ROWS                       // 12
.const BAND1_ROW                        = BAND0_ROW + BAND_CHAR_ROWS           // 16
.const BAND2_ROW                        = BAND1_ROW + BAND_CHAR_ROWS           // 20

.const LOGO_SCREEN_BYTES                = LOGO_CHAR_ROWS * 40                  // 480
.const LOGO_BITMAP_BYTES                = LOGO_CHAR_ROWS * 40 * 8             // 3840

// =============================================================================
// DATA BLOCK
//   The first $100 bytes of DATA_ADDRESS are the contract with prg-builder.js
//   (SID JMPs, song info, NumSIDChips, BorderColour @ $0d, screen/background
//   colour @ $0e, ...). prg-builder fills them in at export time.
// =============================================================================

* = DATA_ADDRESS "Data Block"
    .fill $100, $00

* = CODE_ADDRESS "Main Code"

    jmp Initialize

.var VIC_BANK                       = floor(LOAD_ADDRESS / $4000)
.var VIC_BANK_ADDRESS               = VIC_BANK * $4000

// =============================================================================
// VIC MEMORY MAP (within the 16KB VIC bank)
//   $0000..$19FF : code + data + tables   (this file)
//   $1A00..$1BFF : logo colour staging    (injected, copied to $d800)
//   $1C00..$1FFF : screen RAM (video matrix)
//   $2000..$3FFF : bitmap (8KB)
// =============================================================================

.const SCREEN_BANK                      = 7                                   // $1C00
.const BITMAP_BANK                      = 1                                   // $2000

.const LOGO_COLOR_STAGING               = VIC_BANK_ADDRESS + $1A00
.const SCREEN_ADDRESS                   = VIC_BANK_ADDRESS + (SCREEN_BANK * $400)
.const BITMAP_ADDRESS                   = VIC_BANK_ADDRESS + (BITMAP_BANK * $2000)

.const D018_VALUE                       = (SCREEN_BANK * 16) + (BITMAP_BANK * 8)

// =============================================================================
// INCLUDES
// =============================================================================

#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR
#define INCLUDE_MUSIC_ANALYSIS

#define INCLUDE_RASTER_TIMING_CODE
.var DEFAULT_RASTERTIMING_Y = 250

.import source "../INC/common.asm"
.import source "../INC/keyboard.asm"
.import source "../INC/musicplayback.asm"
.import source "../INC/stablerastersetup.asm"
.import source "../INC/spectrometer3channel.asm"
.import source "../INC/freqtable80.asm"
.import source "../INC/linkedwitheffect.asm"

// =============================================================================
// PER-CHANNEL CHANGE TRACKING
//   One previous combined colour-byte per column (40), per channel. Initialised
//   to $ff so the first render writes every column.
// =============================================================================

.const NUM_COLS = NUM_FREQUENCY_BARS / 2     // 40

prevCh0:    .fill NUM_COLS, $ff
prevCh1:    .fill NUM_COLS, $ff
prevCh2:    .fill NUM_COLS, $ff

colorTemp:  .byte $00

// =============================================================================
// HEIGHT -> COLOUR RAMPS (one per channel, dark->bright)
//   Stepped gradients across the height range. Channels: cool blue / green /
//   fire, so the three bands read as distinct voices.
// =============================================================================

.var ch0ramp = List().add($06,$06,$0e,$0e,$03,$03,$01,$01)   // blue  -> white
.var ch1ramp = List().add($05,$05,$0d,$0d,$0d,$07,$01,$01)   // green -> yellow/white
.var ch2ramp = List().add($02,$02,$08,$08,$0a,$0a,$07,$01)   // red   -> yellow/white

heightToColorCh0: .fill MAX_BAR_HEIGHT + 1, ch0ramp.get(floor(i * ch0ramp.size() / (MAX_BAR_HEIGHT + 1)))
heightToColorCh1: .fill MAX_BAR_HEIGHT + 1, ch1ramp.get(floor(i * ch1ramp.size() / (MAX_BAR_HEIGHT + 1)))
heightToColorCh2: .fill MAX_BAR_HEIGHT + 1, ch2ramp.get(floor(i * ch2ramp.size() / (MAX_BAR_HEIGHT + 1)))

// =============================================================================
// INITIALIZATION
// =============================================================================

Initialize:
    sei

    lda #$35
    sta $01

    jsr RunLinkedWithEffect

    jsr InitKeyboard

    jsr SetupStableRaster
    lda #(63 - VIC_BANK)
    sta $dd00
    lda #VIC_BANK
    sta $dd02
    jsr NMIFix

    jsr SetupBitmapDisplay
    jsr init_D011_D012_values

    jsr ClearBarState

    jsr SetupMusic

    lda #$00
    sta NextIRQLdx + 1
    tax
    jsr set_d011_and_d012

    lda #<MainIRQ
    sta $fffe
    lda #>MainIRQ
    sta $ffff

    lda #$01
    sta $d01a
    sta $d019

    jsr VSync

    lda #$3b                    //; bitmap mode on, screen on, yscroll 3
    sta $d011

    cli

MainLoop:
    jsr CheckKeyboard

    lda visualizationUpdateFlag
    beq MainLoop

    jsr ApplySmoothing
    jsr RenderBars

    lda #$00
    sta visualizationUpdateFlag

    jmp MainLoop

ClearBarState:
    ldy #$00
    lda #$00
!loop:
    sta barHeightsCh0 - 2, y
    sta barHeightsCh1 - 2, y
    sta barHeightsCh2 - 2, y
    sta smoothedHeightsCh0, y
    sta smoothedHeightsCh1, y
    sta smoothedHeightsCh2, y
    iny
    cpy #NUM_FREQUENCY_BARS + 4
    bne !loop-
    rts

// =============================================================================
// BITMAP DISPLAY SETUP
//   - clear the spectrum region of the screen (logo nibbles already injected)
//   - copy the injected logo colour staging into $d800 (colour RAM)
//   - configure VIC for multicolour bitmap mode
// =============================================================================

SetupBitmapDisplay:
    //; Clear the spectrum region (offset 480..1023) of the screen.
    //; Tail of page 1 (480..511 = 32 bytes):
    ldx #$00
!clrTail:
    lda #$00
    sta SCREEN_ADDRESS + LOGO_SCREEN_BYTES, x
    inx
    cpx #(512 - LOGO_SCREEN_BYTES)        //; 32
    bne !clrTail-
    //; Pages 2 and 3 (512..1023 = 512 bytes):
    ldx #$00
!clrPages:
    lda #$00
    sta SCREEN_ADDRESS + 512, x
    sta SCREEN_ADDRESS + 768, x
    inx
    bne !clrPages-

    //; Colour RAM: clear everything, then copy the logo colour staging (480
    //; bytes) into $d800. The spectrum bands never use the %11 colour, so the
    //; bar region of $d800 is irrelevant.
    ldx #$00
!clrColor:
    lda #$00
    sta $d800 + $000, x
    sta $d800 + $100, x
    sta $d800 + $200, x
    sta $d800 + $300, x
    inx
    bne !clrColor-

    ldx #$00
!colA:
    lda LOGO_COLOR_STAGING, x
    sta $d800, x
    inx
    bne !colA-
    ldx #$00
!colB:
    lda LOGO_COLOR_STAGING + 256, x
    sta $d800 + 256, x
    inx
    cpx #(LOGO_SCREEN_BYTES - 256)        //; 224
    bne !colB-

    //; VIC registers for multicolour bitmap mode.
    lda #$00
    sta $d015                              //; sprites off

    lda #$18                               //; multicolour + 40 columns
    sta $d016

    lda #D018_VALUE
    sta $d018

    lda BorderColour
    sta $d020
    lda BitmapScreenColour
    sta $d021

    rts

// =============================================================================
// MAIN INTERRUPT HANDLER
// =============================================================================

MainIRQ:
    pha
    txa
    pha
    tya
    pha
    lda $01
    pha
    lda #$35
    sta $01

    lda FastForwardActive
    beq !normalPlay+

!ffFrameLoop:
    lda NumCallsPerFrame
    sta FFCallCounter

!ffCallLoop:
    jsr SIDPlay
    inc $d020
    dec FFCallCounter
    bne !ffCallLoop-

    jsr CheckSpaceKey
    lda FastForwardActive
    bne !ffFrameLoop-

    lda #$00
    sta NextIRQLdx + 1
    lda BorderColour
    sta $d020
    ldx #$00
    jsr set_d011_and_d012
    jmp !done+

!normalPlay:
    inc visualizationUpdateFlag

    inc frameCounter
    bne !skip+
    inc frame256Counter
!skip:

    jsr JustPlayMusic
    jsr AnalyseMusic
    jsr UpdateBars

!done:
    jsr NextIRQ

    pla
    sta $01
    pla
    tay
    pla
    tax
    pla
    rti

// =============================================================================
// MUSIC-ONLY INTERRUPT HANDLER
// =============================================================================

MusicOnlyIRQ:
    pha
    txa
    pha
    tya
    pha
    lda $01
    pha
    lda #$35
    sta $01

    jsr JustPlayMusic

    jsr NextIRQ

    pla
    sta $01
    pla
    tay
    pla
    tax
    pla
    rti

// =============================================================================
// INTERRUPT CHAINING
// =============================================================================

NextIRQ:
NextIRQLdx:
    ldx #$00
    inx
    cpx NumCallsPerFrame
    bne !notLast+
    ldx #$00
!notLast:
    stx NextIRQLdx + 1

    jsr set_d011_and_d012

    lda #$01
    sta $d019

    cpx #$00
    bne !musicOnly+

    lda #<MainIRQ
    sta $fffe
    lda #>MainIRQ
    sta $ffff
    rts

!musicOnly:
    lda #<MusicOnlyIRQ
    sta $fffe
    lda #>MusicOnlyIRQ
    sta $ffff
    rts

// =============================================================================
// RENDERING
//   Paint each channel's 80 colours into screen RAM. Each column holds two
//   strips: left strip = screen-RAM upper nibble, right strip = lower nibble.
//   We write the combined byte to all four char rows of the band.
// =============================================================================

.macro RenderBand(smoothedH, h2c, prevByte, topRow) {
    ldx #NUM_COLS - 1
!loop:
    txa
    asl                         //; A = col*2  (left bar / upper nibble)
    tay
    lda smoothedH, y
    tay
    lda h2c, y
    asl
    asl
    asl
    asl
    sta colorTemp
    txa
    asl
    tay
    iny                         //; Y = col*2+1 (right bar / lower nibble)
    lda smoothedH, y
    tay
    lda h2c, y
    ora colorTemp               //; combined colour byte
    cmp prevByte, x
    beq !skip+
    sta prevByte, x
    sta SCREEN_ADDRESS + ((topRow + 0) * 40), x
    sta SCREEN_ADDRESS + ((topRow + 1) * 40), x
    sta SCREEN_ADDRESS + ((topRow + 2) * 40), x
    sta SCREEN_ADDRESS + ((topRow + 3) * 40), x
!skip:
    dex
    bpl !loop-
}

RenderBars:
    RenderBand(smoothedHeightsCh0, heightToColorCh0, prevCh0, BAND0_ROW)
    RenderBand(smoothedHeightsCh1, heightToColorCh1, prevCh1, BAND1_ROW)
    RenderBand(smoothedHeightsCh2, heightToColorCh2, prevCh2, BAND2_ROW)
    rts

// =============================================================================
// MUSIC SETUP
// =============================================================================

SetupMusic:
    ldy #24
    lda #$00
!loop:
    sta $d400, y
    dey
    bpl !loop-

    lda SongNumber
    tax
    tay
    jmp SIDInit

// =============================================================================
// ANIMATION STATE
// =============================================================================

visualizationUpdateFlag:    .byte $00
frameCounter:               .byte $00
frame256Counter:            .byte $00

// =============================================================================
// DITHER PATTERN (32 lines per band)
//   $5a = solid colour pair, $00 = blank line (shows background). The blanked
//   lines top & bottom carve a 4px gap that separates the bands and rounds the
//   colour field. Tweak freely.
// =============================================================================

.var ditherLine = List().add($00,$00,$00,$00,$5a,$5a,$00,$5a, $5a,$00,$5a,$5a,$5a,$5a,$5a,$5a, $5a,$5a,$5a,$5a,$5a,$5a,$00,$5a, $5a,$00,$5a,$5a,$00,$00,$00,$00)

// =============================================================================
// LOGO COLOUR STAGING + SCREEN RAM (reserved; filled at export / runtime)
// =============================================================================

* = LOGO_COLOR_STAGING "Logo Colour Staging"
    .fill $200, $00

* = SCREEN_ADDRESS "Screen RAM"
    .fill $400, $00

// =============================================================================
// BITMAP
//   rows 0..11  : logo placeholder (injected by prg-builder from the PNG)
//   rows 12..23 : three 32px bands of the $5a/$00 dither pattern
//   row    24   : blank
// =============================================================================

* = BITMAP_ADDRESS "Bitmap"
    //; Logo region (top 12 char rows) - overwritten at export with PNG data.
    .fill LOGO_BITMAP_BYTES, $00

    //; Three bands (char rows 12..23). Same dither pattern in each band.
    .for (var br = 0; br < (NUM_CHANNELS * BAND_CHAR_ROWS); br++) {
        .for (var c = 0; c < 40; c++) {
            .for (var p = 0; p < 8; p++) {
                .byte ditherLine.get(mod(br, BAND_CHAR_ROWS) * 8 + p)
            }
        }
    }

    //; Row 24 (blank) + pad to the end of the 8KB bitmap.
    .fill (BITMAP_ADDRESS + $2000) - *, $00

// =============================================================================
// END OF FILE
// =============================================================================
