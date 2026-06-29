// =============================================================================
//                          RAISTLIN VERTICAL COLOURS
//          Per-channel SID spectrum painted as a blended colour field
//
//   A full-screen multicolour bitmap. The top 104px (13 char rows) hold a
//   user-supplied logo. The bottom 96px are three contiguous 32px bands
//   (Y104..199), one per SID channel (voice idx % 3).
//
//   40 bars per channel - one bar per 8px char column. Each bar's spectrometer
//   height selects a COLOUR (by instrument/waveform type); the bitmap itself is
//   static and only the screen-RAM nibbles change each frame.
//
//   Each column is BLENDED with the bar to its left: the right 4px of the cell
//   are this bar's solid colour (Cn) and the left 4px dither between Cn and the
//   left neighbour's colour (Cn-1; black for the far-left column). This is done
//   with the screen-RAM nibbles:
//       upper nibble = Cn      (the bitmap's %01 pixels)
//       lower nibble = Cn-1    (the bitmap's %10 pixels)
//   so screen byte = (Cn << 4) | Cn-1, and the static bitmap pattern routes the
//   right half solid to %01 and dithers the left half between %01 and %10.
//
//   Whole scanlines are blanked to black (%00 -> $d021 = black) to texture the
//   field. Colours are self-contained here (four waveform colour sets); the
//   build pipeline only injects the logo bitmap + a border colour.
// =============================================================================

.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()

// =============================================================================
// CONFIGURATION CONSTANTS (needed before the includes)
// =============================================================================

.const NUM_FREQUENCY_BARS               = 40
.const NUM_CHANNELS                     = 3

//; Per-channel "height" range. Heights only ever index the colour ramps, never
//; drawn, so 0..MAX_BAR_HEIGHT just sets colour resolution + dynamics tuning.
.const TOP_SPECTRUM_HEIGHT              = 6
.const MAX_BAR_HEIGHT                   = TOP_SPECTRUM_HEIGHT * 8 - 1     // 47

.const BAR_INCREASE_RATE                = ceil(TOP_SPECTRUM_HEIGHT * 1.3) // 8
.const BAR_DECREASE_RATE                = ceil(TOP_SPECTRUM_HEIGHT * 0.6) // 4

// =============================================================================
// SCREEN LAYOUT (char rows; 25 rows total, 8px each)
//   rows  0..12 : logo (104px, Y0..103)
//   rows 13..16 : band 0  (channel 0)   32px  Y104..135
//   rows 17..20 : band 1  (channel 1)   32px  Y136..167
//   rows 21..24 : band 2  (channel 2)   32px  Y168..199
//   No gaps between bands; the bands fill exactly to Y199.
// =============================================================================

.const LOGO_CHAR_ROWS                   = 13
.const BAND_CHAR_ROWS                   = 4
.const BAND0_ROW                        = LOGO_CHAR_ROWS                       // 13
.const BAND1_ROW                        = BAND0_ROW + BAND_CHAR_ROWS           // 17
.const BAND2_ROW                        = BAND1_ROW + BAND_CHAR_ROWS           // 21

.const LOGO_SCREEN_BYTES                = LOGO_CHAR_ROWS * 40                  // 520
.const LOGO_BITMAP_BYTES                = LOGO_CHAR_ROWS * 40 * 8             // 4160

// =============================================================================
// DATA BLOCK
//   The first $100 bytes of DATA_ADDRESS are the contract with prg-builder.js
//   (SID JMPs, song info, NumSIDChips, BorderColour @ $0d, ...). prg-builder
//   fills them in at export time.
// =============================================================================

* = DATA_ADDRESS "Data Block"
    .fill $100, $00

* = CODE_ADDRESS "Main Code"

    jmp Initialize

.var VIC_BANK                       = floor(LOAD_ADDRESS / $4000)
.var VIC_BANK_ADDRESS               = VIC_BANK * $4000

// =============================================================================
// VIC MEMORY MAP (within the 16KB VIC bank)
//   $0000..$17FF : code + data + tables   (this file)
//   $1800..$1BFF : screen RAM (video matrix)
//   $1C00..$1E07 : logo colour staging    (injected, copied to $d800)
//   $2000..$3FFF : bitmap (8KB)
// =============================================================================

.const SCREEN_BANK                      = 6                                   // $1800
.const BITMAP_BANK                      = 1                                   // $2000

.const SCREEN_ADDRESS                   = VIC_BANK_ADDRESS + (SCREEN_BANK * $400)
.const LOGO_COLOR_STAGING               = VIC_BANK_ADDRESS + $1C00
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
.import source "../INC/freqtable.asm"
.import source "../INC/linkedwitheffect.asm"

// =============================================================================
// PER-CHANNEL CHANGE TRACKING
//   One previous screen-byte per bar/column (40), per channel. Initialised to
//   $ff so the first render writes every column.
// =============================================================================

prevCh0:    .fill NUM_FREQUENCY_BARS, $ff
prevCh1:    .fill NUM_FREQUENCY_BARS, $ff
prevCh2:    .fill NUM_FREQUENCY_BARS, $ff

// =============================================================================
// COLOUR RAMP (shared by all channels and instruments)
//   A single 24-step ramp. Each bar's height is scaled into the ramp, and the
//   bitmap's $66/$99 dither blends two ADJACENT ramp entries together:
//       upper nibble = ramp[s]   (bitmap %01 pixels)
//       lower nibble = ramp[s+1] (bitmap %10 pixels)
//   so the colour climbs smoothly with intensity. heightToByte[height] precombines
//   that into the ready-to-store screen byte; height 0 -> black.
// =============================================================================

.var ramp24 = List().add(0,9,2,5,2,5,10,5,10,14,10,14,13,14,13,7,13,7,15,7,15,1,15,1)

heightToByte:
    .for (var h = 0; h <= MAX_BAR_HEIGHT; h++) {
        .if (h == 0) {
            .byte $00
        } else {
            .var s = floor((h - 1) * 22 / (MAX_BAR_HEIGHT - 1))   // 0..22
            .byte (ramp24.get(s) << 4) | ramp24.get(s + 1)
        }
    }

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
//   - copy the injected logo colour staging into $d800 (colour RAM rows 0..12)
//   - configure VIC for multicolour bitmap mode
//   The spectrum region of screen RAM is left as the assembled $00 (black) and
//   filled by the first render; the logo screen nibbles are already injected.
// =============================================================================

SetupBitmapDisplay:
    //; Colour RAM: clear all, then copy the 520-byte logo colour staging.
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
    lda LOGO_COLOR_STAGING + $000, x
    sta $d800 + $000, x
    lda LOGO_COLOR_STAGING + $100, x
    sta $d800 + $100, x
    inx
    bne !colA-
    ldx #$00
!colB:
    lda LOGO_COLOR_STAGING + $200, x
    sta $d800 + $200, x
    inx
    cpx #(LOGO_SCREEN_BYTES - 512)        //; 8 remaining bytes (520 - 512)
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
    lda #$00                                //; force black so the dither cuts &
    sta $d021                               //; band gaps are always fully black

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
//   One bar per char column (40 cols). screen byte = (Cn << 4) | Cn-1:
//     upper nibble Cn   -> bitmap %01 pixels (right half solid + half the left)
//     lower nibble Cn-1 -> bitmap %10 pixels (the other half of the left dither)
//   Cn-1 starts at black for the far-left column. Per-column change detection;
//   a changed colour also dirties the column to its right (handled because the
//   right column compares its own combined byte too).
// =============================================================================

.macro RenderChannel(smoothedH, prevByte, topRow) {
    ldx #NUM_FREQUENCY_BARS - 1
!loop:
    ldy smoothedH, x
    lda heightToByte, y         //; (ramp[s] << 4) | ramp[s+1]
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
    RenderChannel(smoothedHeightsCh0, prevCh0, BAND0_ROW)
    RenderChannel(smoothedHeightsCh1, prevCh1, BAND1_ROW)
    RenderChannel(smoothedHeightsCh2, prevCh2, BAND2_ROW)
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
// SCREEN RAM + LOGO COLOUR STAGING (reserved; filled at export / runtime)
// =============================================================================

* = SCREEN_ADDRESS "Screen RAM"
    .fill $400, $00

* = LOGO_COLOR_STAGING "Logo Colour Staging"
    .fill $220, $00

// =============================================================================
// BITMAP
//   The whole bitmap is filled with the 8-byte cell pattern
//       $00, $00, $66, $99, $66, $99, $66, $99
//   so every char cell has two black scanlines on top followed by six $66/$99
//   dither lines (which blend the screen-RAM upper & lower nibbles). The logo
//   (top 13 char rows) is overwritten at export with the PNG bitmap.
// =============================================================================

.var barPattern = List().add($00, $00, $66, $99, $66, $99, $66, $99)

* = BITMAP_ADDRESS "Bitmap"
    .fill $2000, barPattern.get(mod(i, 8))

// =============================================================================
// END OF FILE
// =============================================================================
