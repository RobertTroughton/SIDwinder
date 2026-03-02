// =============================================================================
//                              SCRAP COLUMNS
//                   3D Column Spectrum Visualizer by Scrap
//                     Adapted for SIDwinder by Claude
// =============================================================================
//
// 20 multicolor 3D columns across the full screen width.
// Each column is 2 characters wide, 24 rows tall (3 sections of 8 rows).
// Each section shows one SID voice independently (V0=upper, V1=lower, V2=lowest).
//
// Memory Map (VIC Bank relative):
//   +$3800-$3FFF : CharSet (MC mode)
//   +$3000-$33FF : Screen
//   +$2B00-$2B77 : Upper char lookup table
//   +$2B80-$2BF7 : Lower char lookup table
//   +$2C00-$2C77 : Lowest char lookup table
//   +$2C80-$2CBF : Conversion table
//   +$2CC0-$2CFF : Column height buffers (3 x 20 bytes)

.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()

// =============================================================================
// CONFIGURATION CONSTANTS
// =============================================================================

.const NUM_BARS_PER_VOICE            = 20
.const NUM_COLUMNS                  = 20

.const TOP_SPECTRUM_HEIGHT          = 8
.const BOTTOM_SPECTRUM_HEIGHT       = 0

.const BAR_INCREASE_RATE            = ceil(TOP_SPECTRUM_HEIGHT * 1.3)
.const BAR_DECREASE_RATE            = ceil(TOP_SPECTRUM_HEIGHT * 0.2)

// Scrap's char tables require buffer values in range $10-$3F (48 values per section)
// Each voice section has 48 height levels (0-47), mapped to $10-$3F
.const MAX_BAR_HEIGHT               = 47

// =============================================================================
// DATA BLOCK
// =============================================================================

* = DATA_ADDRESS "Data Block"
    .fill $0D, $00                      // Reserved bytes 0-12
borderColor:
    .byte $00                           // Byte 13 ($0D): Border color
backgroundColor:
    .byte $00                           // Byte 14 ($0E): Background color
    .fill $60 - $0F, $00                // Reserved bytes 15-95
colorEffectMode:
    .byte $00                           // Byte 96 ($60): Color effect mode (unused but kept for compatibility)
lineGradientColors:
    .fill TOP_SPECTRUM_HEIGHT + BOTTOM_SPECTRUM_HEIGHT, $0b  // Bytes 97+: Line gradient colors
songNameColor:
    .byte $01                           // Song name text color (default: white)
artistNameColor:
    .byte $0f                           // Artist name text color (default: light grey)
    .fill $100 - $61 - (TOP_SPECTRUM_HEIGHT + BOTTOM_SPECTRUM_HEIGHT) - 2, $00

* = CODE_ADDRESS "Main Code"

    jmp Initialize

.var VIC_BANK                       = floor(LOAD_ADDRESS / $4000)
.var VIC_BANK_ADDRESS               = VIC_BANK * $4000

// =============================================================================
// CONFIGURATION CONSTANTS (continued)
// =============================================================================

.const SCREEN_BANK                  = 12    //; +$3000
.const CHARSET_BANK                 = 7     //; +$3800

.const SCREEN_ADDRESS               = VIC_BANK_ADDRESS + (SCREEN_BANK * $400)
.const CHARSET_ADDRESS              = VIC_BANK_ADDRESS + (CHARSET_BANK * $800)

.const D018_VALUE                   = (SCREEN_BANK * 16) + (CHARSET_BANK * 2)

// Char lookup tables placed after code (page-aligned for indexed addressing)
.const UPPER_TABLE_ADDRESS          = VIC_BANK_ADDRESS + $2B00
.const LOWER_TABLE_ADDRESS          = VIC_BANK_ADDRESS + $2B80
.const LOWEST_TABLE_ADDRESS         = VIC_BANK_ADDRESS + $2C00
.const CONV_TABLE_ADDRESS           = VIC_BANK_ADDRESS + $2C80
.const COLUMN_BUFFERS_ADDRESS       = VIC_BANK_ADDRESS + $2CC0

// Sprite data - 64-byte aligned within VIC bank (placed before screen)
.const SPRITE_DATA_ADDRESS          = VIC_BANK_ADDRESS + $2FC0
.const SPRITE_POINTER               = ($2FC0 / $40)

// Color table (for compatibility with prg-builder, though not actively used for dynamic colors)
.const COLOR_TABLE_ADDRESS          = VIC_BANK_ADDRESS + $2D00
.const COLOR_TABLE_SIZE             = MAX_BAR_HEIGHT + 9

// =============================================================================
// INCLUDES
// =============================================================================

#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR
#define INCLUDE_MUSIC_ANALYSIS

#define INCLUDE_RASTER_TIMING_CODE
.var DEFAULT_RASTERTIMING_Y = 232

.import source "../INC/Common.asm"
.import source "../INC/Keyboard.asm"
.import source "../INC/MusicPlayback.asm"
.import source "../INC/StableRasterSetup.asm"
.import source "../INC/SpectrometerPerVoice.asm"
.import source "../INC/FreqTable20.asm"
.import source "../INC/LinkedWithEffect.asm"

// =============================================================================
// DATA
// =============================================================================

visualizationUpdateFlag:    .byte $00
frameCounter:               .byte $00
frame256Counter:            .byte $00

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

    jsr InitializeVIC
    jsr ClearScreen
    jsr InitializeColors
    jsr DisplaySongInfo
    jsr DisplayRow25
    jsr init_D011_D012_values

    jsr InitializeBarArrays

    // Clear column buffers to $10 (minimum visible, valid range $10-$3F)
    lda #$10
    ldx #59
!clrBuf:
    sta columnBuffer, x
    dex
    bpl !clrBuf-

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

    lda #$1b
    sta $d011

    cli

MainLoop:
    jsr CheckKeyboard

    lda visualizationUpdateFlag
    beq MainLoop

    jsr ApplySmoothingAllVoices
    jsr ConvertToColumns
    jsr columnseffect

    lda #$00
    sta visualizationUpdateFlag

    jmp MainLoop

// =============================================================================
// VIC INITIALIZATION
// =============================================================================

InitializeVIC:
    // Set multicolor text mode
    lda #$1b
    sta $d011
    lda #$d8                            // MC on ($d0 | $08)
    sta $d016
    lda #D018_VALUE
    sta $d018

    // Load colors from data block
    lda borderColor
    sta $d020
    lda backgroundColor
    sta $d021

    // Multicolor shared colors
    lda #$0c
    sta $d022                           // MC color 1 (light grey)
    lda #$0b
    sta $d023                           // MC color 2 (dark grey)

    // Setup sprites (7 sprites for bottom border effect)
    lda #%01111111
    sta $d015                           // Enable sprites 0-6
    sta $d01d                           // X-expand sprites 0-6
    sta $d017                           // Y-expand sprites 0-6
    sta $d01c                           // Multicolor sprites 0-6

    lda #$00
    sta $d01b                           // Sprites in front of background
    sta $d026                           // Sprite extra color 2 = black

    // Sprite colors = border color
    lda borderColor
    sta $d027
    sta $d028
    sta $d029
    sta $d02a
    sta $d02b
    sta $d02c
    sta $d02d

    // Sprite positions - spread across screen width
    lda #$fa
    sta $d001
    sta $d003
    sta $d005
    sta $d007
    sta $d009
    sta $d00b
    sta $d00d

    lda #$18
    clc
    sta $d000
    adc #$30
    sta $d002
    adc #$30
    sta $d004
    adc #$30
    sta $d006
    adc #$30
    sta $d008
    adc #$30
    sta $d00a
    clc
    adc #$30
    sta $d00c

    lda #%01100000
    sta $d010                           // X MSB for sprites 5,6

    // Sprite pointers
    lda #SPRITE_POINTER
    ldx #6
!sprPtr:
    sta SCREEN_ADDRESS + $3F8, x
    dex
    bpl !sprPtr-

    // VIC bank setup byte at top of bank
    lda #%00000011
    sta VIC_BANK_ADDRESS + $3FFF

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
    sta $d020
    tax
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
    jsr UpdateBarsAllVoices

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
// CONVERT SMOOTHED HEIGHTS TO COLUMN BUFFERS
// Each voice's smoothed heights (0-47) are mapped to $10-$3F
// Voice 0 → upper section, Voice 1 → lower section, Voice 2 → lowest section
// =============================================================================

ConvertToColumns:
    ldx #NUM_COLUMNS - 1
!loop:
    // Voice 0 → upper section (rows 0-7)
    lda smoothedHeightsV0, x
    clc
    adc #$10
    sta columnBuffer, x

    // Voice 1 → lower section (rows 8-15)
    lda smoothedHeightsV1, x
    clc
    adc #$10
    sta columnBuffer + NUM_COLUMNS, x

    // Voice 2 → lowest section (rows 16-23)
    lda smoothedHeightsV2, x
    clc
    adc #$10
    sta columnBuffer + (NUM_COLUMNS * 2), x

    dex
    bpl !loop-
    rts

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

ClearScreen:
    ldx #$00
    lda #$20
!loop:
    sta SCREEN_ADDRESS + $000, x
    sta SCREEN_ADDRESS + $100, x
    sta SCREEN_ADDRESS + $200, x
    sta SCREEN_ADDRESS + $300, x
    inx
    bne !loop-
    rts

DisplaySongInfo:
    // Song name on row 0 (above the columns, rows 0-1)
    // Artist name on row 24 (below the columns, at very bottom of visible screen)
    // Columns occupy rows 1-24, so put song name on row 0 only
    // Actually, we have 25 visible rows. Columns use rows 0-23 in the original.
    // For SIDwinder, let's not display song/artist text - the columns fill the screen.
    // The text info is shown in the LinkedWith intro anyway.
    rts

InitializeColors:
    // Set color RAM for 3 sections:
    // Rows 0-7 (upper): dark grey ($0b) - cyan highlight on columns
    // Rows 8-15 (lower): light grey ($0f) - yellow highlight on columns
    // Rows 16-23 (lowest): brown ($09) - white highlight on columns
    ldy #0
!colLoop:
    lda #$0B
    sta $d800, y
    sta $d800 + 64, y
    lda #$0f
    sta $d800 + 320, y
    sta $d800 + 384, y
    lda #$09
    sta $d800 + 640, y
    sta $d800 + 704, y
    iny
    cpy #64
    bne !colLoop-

    // Fill remaining rows with dark grey
    ldy #0
    lda #$0b
!colLoop2:
    sta $d800 + 128, y
    sta $d800 + 192, y
    sta $d800 + 256, y
    sta $d800 + 448, y
    sta $d800 + 512, y
    sta $d800 + 576, y
    sta $d800 + 768, y
    sta $d800 + 832, y
    sta $d800 + 896, y
    iny
    cpy #64
    bne !colLoop2-

    rts

DisplayRow25:
    // Row 25 (screen + 960): alternating $0e/$0f chars (like original)
    ldy #0
!row25:
    lda #$0e
    sta SCREEN_ADDRESS + 960, y
    iny
    lda #$0f
    sta SCREEN_ADDRESS + 960, y
    iny
    cpy #40
    bne !row25-
    rts

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
// COLUMNS EFFECT - Unrolled rendering by Scrap
// Reads from columnBuffer (3 x 20 bytes) via convtable
// Writes character codes to screen RAM
// =============================================================================

columnseffect:

.label screen = SCREEN_ADDRESS

//; --- UPPER SECTION (rows 0-7, columnBuffer+0 to +19) ---
.for (var col = 0; col < NUM_COLUMNS; col++) {
    ldy columnBuffer + col
    ldx convtable, y
    clc
    .for (var row = 0; row < 8; row++) {
        lda upper + row, x
        sta screen + (col * 2) + (row * 40)
        adc #1
        sta screen + (col * 2) + 1 + (row * 40)
        .if (row < 7) { clc }
    }
}

//; --- LOWER SECTION (rows 8-15, columnBuffer+20 to +39) ---
.for (var col = 0; col < NUM_COLUMNS; col++) {
    ldy columnBuffer + NUM_COLUMNS + col
    ldx convtable, y
    clc
    .for (var row = 0; row < 8; row++) {
        lda lower + row, x
        sta screen + (col * 2) + ((row + 8) * 40)
        adc #1
        sta screen + (col * 2) + 1 + ((row + 8) * 40)
        .if (row < 7) { clc }
    }
}

//; --- LOWEST SECTION (rows 16-23, columnBuffer+40 to +59) ---
.for (var col = 0; col < NUM_COLUMNS; col++) {
    ldy columnBuffer + (NUM_COLUMNS * 2) + col
    ldx convtable, y
    clc
    .for (var row = 0; row < 8; row++) {
        lda lowest + row, x
        sta screen + (col * 2) + ((row + 16) * 40)
        adc #1
        sta screen + (col * 2) + 1 + ((row + 16) * 40)
        .if (row < 7) { clc }
    }
}

    rts


// =============================================================================
// CHARACTER LOOKUP TABLES (from Scrap's original)
// =============================================================================

// Upper section: $fe = empty row, character codes for filled rows
// Each "height level" is 15 bytes: 8 interleaved height entries + 7 body chars
// Indexed by convtable[height] to get starting offset within table

* = UPPER_TABLE_ADDRESS "Upper Char Table"
upper:
// Height 7 (barely visible - only last row)
c07: .byte $fe
c0f: .byte $fe
c17: .byte $fe
c1f: .byte $fe
c27: .byte $fe
c2f: .byte $fe
c37: .byte $fe
c3f: .byte $00
     .byte $02, $04, $06, $06, $06, $06, $06
// Height 6
c06: .byte $fe
c0e: .byte $fe
c16: .byte $fe
c1e: .byte $fe
c26: .byte $fe
c2e: .byte $fe
c36: .byte $fe
c3e: .byte $10
     .byte $12, $14, $16, $16, $16, $16, $16
// Height 5
c05: .byte $fe
c0d: .byte $fe
c15: .byte $fe
c1d: .byte $fe
c25: .byte $fe
c2d: .byte $fe
c35: .byte $fe
c3d: .byte $20
     .byte $22, $24, $26, $26, $26, $26, $26
// Height 4
c04: .byte $fe
c0c: .byte $fe
c14: .byte $fe
c1c: .byte $fe
c24: .byte $fe
c2c: .byte $fe
c34: .byte $fe
c3c: .byte $30
     .byte $32, $34, $36, $36, $36, $36, $36
// Height 3
c03: .byte $fe
c0b: .byte $fe
c13: .byte $fe
c1b: .byte $fe
c23: .byte $fe
c2b: .byte $fe
c33: .byte $fe
c3b: .byte $40
     .byte $42, $44, $46, $46, $46, $46, $46
// Height 2
c02: .byte $fe
c0a: .byte $fe
c12: .byte $fe
c1a: .byte $fe
c22: .byte $fe
c2a: .byte $fe
c32: .byte $fe
c3a: .byte $50
     .byte $52, $54, $56, $56, $56, $56, $56
// Height 1
c01: .byte $fe
c09: .byte $fe
c11: .byte $fe
c19: .byte $fe
c21: .byte $fe
c29: .byte $fe
c31: .byte $fe
c39: .byte $60
     .byte $62, $64, $66, $66, $66, $66, $66
// Height 0 (tallest - all 8 rows visible)
c00: .byte $fe
c08: .byte $fe
c10: .byte $fe
c18: .byte $fe
c20: .byte $fe
c28: .byte $fe
c30: .byte $fe
c38: .byte $70
     .byte $72, $74, $76, $76, $76, $76, $76

// Lower section char table
* = LOWER_TABLE_ADDRESS "Lower Char Table"
lower:
d07: .byte $06
d0f: .byte $06
d17: .byte $06
d1f: .byte $06
d27: .byte $06
d2f: .byte $06
d37: .byte $06
d3f: .byte $80
     .byte $82, $84, $86, $86, $86, $86, $86
d06: .byte $06
d0e: .byte $06
d16: .byte $06
d1e: .byte $06
d26: .byte $06
d2e: .byte $06
d36: .byte $06
d3e: .byte $90
     .byte $92, $94, $96, $96, $96, $96, $96
d05: .byte $06
d0d: .byte $06
d15: .byte $06
d1d: .byte $06
d25: .byte $06
d2d: .byte $06
d35: .byte $06
d3d: .byte $a0
     .byte $a2, $a4, $a6, $a6, $a6, $a6, $a6
d04: .byte $06
d0c: .byte $06
d14: .byte $06
d1c: .byte $06
d24: .byte $06
d2c: .byte $06
d34: .byte $06
d3c: .byte $b0
     .byte $b2, $b4, $b6, $b6, $b6, $b6, $b6
d03: .byte $06
d0b: .byte $06
d13: .byte $06
d1b: .byte $06
d23: .byte $06
d2b: .byte $06
d33: .byte $06
d3b: .byte $c0
     .byte $c2, $c4, $c6, $c6, $c6, $c6, $c6
d02: .byte $06
d0a: .byte $06
d12: .byte $06
d1a: .byte $06
d22: .byte $06
d2a: .byte $06
d32: .byte $06
d3a: .byte $d0
     .byte $d2, $d4, $d6, $d6, $d6, $d6, $d6
d01: .byte $06
d09: .byte $06
d11: .byte $06
d19: .byte $06
d21: .byte $06
d29: .byte $06
d31: .byte $06
d39: .byte $e0
     .byte $e2, $e4, $e6, $e6, $e6, $e6, $e6
d00: .byte $06
d08: .byte $06
d10: .byte $06
d18: .byte $06
d20: .byte $06
d28: .byte $06
d30: .byte $06
d38: .byte $f0
     .byte $f2, $f4, $f6, $f6, $f6, $f6, $f6

// Lowest section char table
* = LOWEST_TABLE_ADDRESS "Lowest Char Table"
lowest:
e07: .byte $86
e0f: .byte $86
e17: .byte $86
e1f: .byte $86
e27: .byte $86
e2f: .byte $86
e37: .byte $86
e3f: .byte $08
     .byte $0a, $0c, $0e, $0e, $0e, $0e, $0e
e06: .byte $86
e0e: .byte $86
e16: .byte $86
e1e: .byte $86
e26: .byte $86
e2e: .byte $86
e36: .byte $86
e3e: .byte $18
     .byte $1a, $1c, $1e, $1e, $1e, $1e, $1e
e05: .byte $86
e0d: .byte $86
e15: .byte $86
e1d: .byte $86
e25: .byte $86
e2d: .byte $86
e35: .byte $86
e3d: .byte $28
     .byte $2a, $2c, $2e, $2e, $2e, $2e, $2e
e04: .byte $86
e0c: .byte $86
e14: .byte $86
e1c: .byte $86
e24: .byte $86
e2c: .byte $86
e34: .byte $86
e3c: .byte $38
     .byte $3a, $3c, $3e, $3e, $3e, $3e, $3e
e03: .byte $86
e0b: .byte $86
e13: .byte $86
e1b: .byte $86
e23: .byte $86
e2b: .byte $86
e33: .byte $86
e3b: .byte $48
     .byte $4a, $4c, $4e, $4e, $4e, $4e, $4e
e02: .byte $86
e0a: .byte $86
e12: .byte $86
e1a: .byte $86
e22: .byte $86
e2a: .byte $86
e32: .byte $86
e3a: .byte $58
     .byte $5a, $5c, $5e, $5e, $5e, $5e, $5e
e01: .byte $86
e09: .byte $86
e11: .byte $86
e19: .byte $86
e21: .byte $86
e29: .byte $86
e31: .byte $86
e39: .byte $68
     .byte $6a, $6c, $6e, $6e, $6e, $6e, $6e
e00: .byte $86
e08: .byte $86
e10: .byte $86
e18: .byte $86
e20: .byte $86
e28: .byte $86
e30: .byte $86
e38: .byte $78
     .byte $7a, $7c, $7e, $7e, $7e, $7e, $7e


// =============================================================================
// CONVERSION TABLE
// Maps height value (0-63) to offset within char lookup tables
// =============================================================================

* = CONV_TABLE_ADDRESS "Conversion Table"
convtable:
.byte <c00,<c01,<c02,<c03,<c04,<c05,<c06,<c07,<c08,<c09,<c0a,<c0b,<c0c,<c0d,<c0e,<c0f
.byte <c10,<c11,<c12,<c13,<c14,<c15,<c16,<c17,<c18,<c19,<c1a,<c1b,<c1c,<c1d,<c1e,<c1f
.byte <c20,<c21,<c22,<c23,<c24,<c25,<c26,<c27,<c28,<c29,<c2a,<c2b,<c2c,<c2d,<c2e,<c2f
.byte <c30,<c31,<c32,<c33,<c34,<c35,<c36,<c37,<c38,<c39,<c3a,<c3b,<c3c,<c3d,<c3e,<c3f


// =============================================================================
// COLUMN HEIGHT BUFFERS (3 x 20 bytes)
// =============================================================================

* = COLUMN_BUFFERS_ADDRESS "Column Buffers"
columnBuffer:
    .fill NUM_COLUMNS, 0                // Upper section heights (0-63)
    .fill NUM_COLUMNS, 0                // Lower section heights (0-63)
    .fill NUM_COLUMNS, 0                // Lowest section heights (0-63)


// =============================================================================
// COLOR TABLE (for prg-builder compatibility)
// =============================================================================

* = COLOR_TABLE_ADDRESS "Color Table"
heightToColor:              .fill COLOR_TABLE_SIZE, $0b


// =============================================================================
// CHARSET DATA (multicolor pre-shifted column characters by Scrap)
// =============================================================================

* = CHARSET_ADDRESS "Font"
.byte $01,$07,$1F,$7F,$FF,$FF,$7F,$5F
.byte $00,$40,$D0,$F4,$FC,$F4,$D8,$64
.byte $77,$5D,$57,$5D,$57,$55,$57,$55
.byte $98,$68,$98,$68,$A8,$68,$A8,$A8
.byte $57,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $16,$1B,$2F,$BF,$FF,$FF,$7F,$5F
.byte $6A,$AA,$CA,$F2,$FC,$F4,$D8,$64
.byte $77,$5D,$57,$5D,$57,$55,$57,$55
.byte $98,$68,$98,$68,$A8,$68,$A8,$A8
.byte $57,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $00,$01,$07,$1F,$7F,$FF,$FF,$7F
.byte $00,$00,$40,$D0,$F4,$FC,$F4,$D8
.byte $5F,$77,$5D,$57,$5D,$57,$55,$57
.byte $64,$98,$68,$98,$68,$A8,$68,$A8
.byte $55,$57,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $15,$16,$1B,$2F,$BF,$FF,$FF,$7F
.byte $6A,$6A,$AA,$CA,$F2,$FC,$F4,$D8
.byte $5F,$77,$5D,$57,$5D,$57,$55,$57
.byte $64,$98,$68,$98,$68,$A8,$68,$A8
.byte $55,$57,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $00,$00,$01,$07,$1F,$7F,$FF,$FF
.byte $00,$00,$00,$40,$D0,$F4,$FC,$F4
.byte $7F,$5F,$77,$5D,$57,$5D,$57,$55
.byte $D8,$64,$98,$68,$98,$68,$A8,$68
.byte $57,$55,$57,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $15,$15,$16,$1B,$2F,$BF,$FF,$FF
.byte $6A,$6A,$6A,$AA,$CA,$F2,$FC,$F4
.byte $7F,$5F,$77,$5D,$57,$5D,$57,$55
.byte $D8,$64,$98,$68,$98,$68,$A8,$68
.byte $57,$55,$57,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $00,$00,$00,$01,$07,$1F,$7F,$FF
.byte $00,$00,$00,$00,$40,$D0,$F4,$FC
.byte $FF,$7F,$5F,$77,$5D,$57,$5D,$57
.byte $F4,$D8,$64,$98,$68,$98,$68,$A8
.byte $55,$57,$55,$57,$55,$55,$55,$55
.byte $68,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $15,$15,$15,$16,$1B,$2F,$BF,$FF
.byte $6A,$6A,$6A,$6A,$AA,$CA,$F2,$FC
.byte $FF,$7F,$5F,$77,$5D,$57,$5D,$57
.byte $F4,$D8,$64,$98,$68,$98,$68,$A8
.byte $55,$57,$55,$57,$55,$55,$55,$55
.byte $68,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $00,$00,$00,$00,$01,$07,$1F,$7F
.byte $00,$00,$00,$00,$00,$40,$D0,$F4
.byte $FF,$FF,$7F,$5F,$77,$5D,$57,$5D
.byte $FC,$F4,$D8,$64,$98,$68,$98,$68
.byte $57,$55,$57,$55,$57,$55,$55,$55
.byte $A8,$68,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $15,$15,$15,$15,$16,$1B,$2F,$BF
.byte $6A,$6A,$6A,$6A,$6A,$AA,$CA,$F2
.byte $FF,$FF,$7F,$5F,$77,$5D,$57,$5D
.byte $FC,$F4,$D8,$64,$98,$68,$98,$68
.byte $57,$55,$57,$55,$57,$55,$55,$55
.byte $A8,$68,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $00,$00,$00,$00,$00,$01,$07,$1F
.byte $00,$00,$00,$00,$00,$00,$40,$D0
.byte $7F,$FF,$FF,$7F,$5F,$77,$5D,$57
.byte $F4,$FC,$F4,$D8,$64,$98,$68,$98
.byte $5D,$57,$55,$57,$55,$57,$55,$55
.byte $68,$A8,$68,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $15,$15,$15,$15,$15,$16,$1B,$2F
.byte $6A,$6A,$6A,$6A,$6A,$6A,$AA,$CA
.byte $BF,$FF,$FF,$7F,$5F,$77,$5D,$57
.byte $F2,$FC,$F4,$D8,$64,$98,$68,$98
.byte $5D,$57,$55,$57,$55,$57,$55,$55
.byte $68,$A8,$68,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $00,$00,$00,$00,$00,$00,$01,$07
.byte $00,$00,$00,$00,$00,$00,$00,$40
.byte $1F,$7F,$FF,$FF,$7F,$5F,$77,$5D
.byte $D0,$F4,$FC,$F4,$D8,$64,$98,$68
.byte $57,$5D,$57,$55,$57,$55,$57,$55
.byte $98,$68,$A8,$68,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $15,$15,$15,$15,$15,$15,$16,$1B
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$2A
.byte $2F,$BF,$FF,$FF,$7F,$5F,$77,$5D
.byte $CA,$F2,$FC,$F4,$D8,$64,$98,$68
.byte $57,$5D,$57,$55,$57,$55,$57,$55
.byte $98,$68,$A8,$68,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $00,$00,$00,$00,$00,$00,$00,$01
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $07,$1F,$7F,$FF,$FF,$7F,$5F,$77
.byte $40,$D0,$F4,$FC,$F4,$D8,$64,$98
.byte $5D,$57,$5D,$57,$55,$57,$55,$57
.byte $68,$98,$68,$A8,$68,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $15,$15,$15,$15,$15,$15,$15,$16
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $1B,$2F,$3F,$FF,$FF,$7F,$5F,$77
.byte $AA,$CA,$F2,$FC,$F4,$D8,$64,$98
.byte $5D,$57,$5D,$57,$55,$57,$55,$57
.byte $68,$98,$68,$A8,$68,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
// Bottom cap / base characters
.byte $55,$56,$5B,$6F,$BF,$3F,$1F,$17
.byte $28,$C8,$F0,$FC,$FF,$FD,$F6,$D9
.byte $1D,$17,$15,$17,$15,$15,$15,$15
.byte $E6,$5A,$E6,$5A,$EA,$5A,$EA,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $EA,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
// Empty / space character
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
// More shifted variants
.byte $55,$55,$56,$5B,$6F,$BF,$3F,$1F
.byte $A8,$28,$C8,$F0,$FC,$FF,$FD,$F6
.byte $17,$1D,$17,$15,$17,$15,$15,$15
.byte $D9,$E6,$5A,$E6,$5A,$EA,$5A,$EA
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$EA,$6A,$6A,$6A,$6A,$6A,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $55,$55,$55,$56,$5B,$6F,$BF,$3F
.byte $A8,$A8,$28,$C8,$F0,$FC,$FF,$FD
.byte $1F,$17,$1D,$17,$15,$17,$15,$15
.byte $F6,$D9,$E6,$5A,$E6,$5A,$EA,$5A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $EA,$6A,$EA,$6A,$6A,$6A,$6A,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $55,$55,$55,$55,$56,$5B,$6F,$BF
.byte $A8,$A8,$A8,$28,$C8,$F0,$FC,$FF
.byte $3F,$1F,$17,$1D,$17,$15,$17,$15
.byte $FD,$F6,$D9,$E6,$5A,$E6,$5A,$EA
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $5A,$EA,$6A,$EA,$6A,$6A,$6A,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $55,$55,$55,$55,$55,$56,$5B,$6F
.byte $A8,$A8,$A8,$A8,$28,$C8,$F0,$FC
.byte $BF,$3F,$1F,$17,$1D,$17,$15,$17
.byte $FF,$FD,$F6,$D9,$E6,$5A,$E6,$5A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $EA,$5A,$EA,$6A,$EA,$6A,$6A,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $55,$55,$55,$55,$55,$55,$56,$5B
.byte $A8,$A8,$A8,$A8,$A8,$28,$C8,$F0
.byte $6F,$BF,$3F,$1F,$17,$1D,$17,$15
.byte $FC,$FF,$FD,$F6,$D9,$E6,$5A,$E6
.byte $17,$15,$15,$15,$15,$15,$15,$15
.byte $5A,$EA,$5A,$EA,$6A,$EA,$6A,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $55,$55,$55,$55,$55,$55,$55,$56
.byte $A8,$A8,$A8,$A8,$A8,$A8,$28,$C8
.byte $5B,$6F,$BF,$3F,$1F,$17,$1D,$17
.byte $F0,$FC,$FF,$FD,$F6,$D9,$E6,$5A
.byte $15,$17,$15,$15,$15,$15,$15,$15
.byte $E6,$5A,$EA,$5A,$EA,$6A,$EA,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$28
.byte $56,$5B,$6F,$BF,$3F,$1F,$17,$1D
.byte $C8,$F0,$FC,$FF,$FD,$F6,$D9,$E6
.byte $17,$15,$17,$15,$15,$15,$15,$15
.byte $5A,$E6,$5A,$EA,$5A,$EA,$6A,$EA
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00


// =============================================================================
// SPRITE DATA (bottom border visual)
// =============================================================================

* = SPRITE_DATA_ADDRESS "Sprite"
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80

// =============================================================================
// SCREEN
// =============================================================================

* = SCREEN_ADDRESS "Screen"
    .fill $400, $00

// =============================================================================
// END OF FILE
// =============================================================================
