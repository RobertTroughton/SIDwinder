// =============================================================================
//                             SIMPLE BITMAP PLAYER
//                   Bitmap Graphics SID Music Player for C64
// =============================================================================

.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()

.var BASE_ADDRESS                   = LOAD_ADDRESS
.var CODE_ADDRESS                   = BASE_ADDRESS + $100
.var VIC_BANK_ADDRESS               = LOAD_ADDRESS
.var VIC_BANK						= VIC_BANK_ADDRESS / $4000
.var BITMAP_BANK                    = 1
.var SCREEN_BANK                    = 6
.var COLOUR_BANK                    = 7

.if (LOAD_ADDRESS == $c000) {

    .eval BASE_ADDRESS              = $e000
    .eval CODE_ADDRESS              = $e100
    .eval BITMAP_BANK               = 0
    .eval SCREEN_BANK               = 12
    .eval COLOUR_BANK               = 13
}

* = CODE_ADDRESS "Main Code"

.const DD00Value                        = 3 - VIC_BANK
.const DD02Value                        = 60 + VIC_BANK
.const D018Value                        = (SCREEN_BANK * 16) + (BITMAP_BANK * 8)

.const BITMAP_MAP_DATA                  = VIC_BANK_ADDRESS + (BITMAP_BANK * $2000)
.const BITMAP_SCREEN_DATA               = VIC_BANK_ADDRESS + (SCREEN_BANK * $0400)
.const BITMAP_COLOUR_DATA               = VIC_BANK_ADDRESS + (COLOUR_BANK * $0400)

    jmp Initialize

// =============================================================================
// INCLUDES
// =============================================================================

#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR

#define INCLUDE_RASTER_TIMING_CODE
.var DEFAULT_RASTERTIMING_Y = 250

.import source "../INC/Common.asm"
.import source "../INC/keyboard.asm"
.import source "../INC/musicplayback.asm"

// =============================================================================
// INITIALIZATION ENTRY POINT
// =============================================================================

Initialize:
    sei

    lda #$35
    sta $01

    jsr VSync

    lda #$00
    sta $d011
    sta $d020
    sta $d021

    jsr InitKeyboard

    lda SongNumber
    sta CurrentSong
    
    lda NumSongs
    bne !skip+
    lda #1
    sta NumSongs
!skip:

    lda #0
    sta ShowRasterBars

    lda CurrentSong
    tax
    tay
    jsr SIDInit

    jsr NMIFix

    ldy #$00
!loop:
    .for (var i = 0; i < 4; i++)
    {
        lda BITMAP_COLOUR_DATA + (i * 256), y
        sta $d800 + (i * 256), y
    }
    iny
    bne !loop-

    lda BitmapScreenColour
    sta $d021

    jsr init_D011_D012_values

    lda #<MusicIRQ
    sta $fffe
    lda #>MusicIRQ
    sta $ffff

    lda #$7f
    sta $dc0d
    lda $dc0d
    lda #$01
    sta $d01a
    lda #$01
    sta $d019

    lda #DD00Value
    sta $dd00
    lda #DD02Value
    sta $dd02

    lda #D018Value
    sta $d018

    lda #$18
    sta $d016

    lda #$00
    sta $d015

    jsr VSync

    lda BorderColour
    sta $d020

    lda #$3b
    sta $d011

    ldx #0
    jsr set_d011_and_d012

    cli

MainLoop:
    jsr CheckKeyboard
    jmp MainLoop

// =============================================================================
// MAIN MUSIC INTERRUPT HANDLER
// =============================================================================

MusicIRQ:
    pha
    txa
    pha
    tya
    pha

    lda FastForwardActive
    beq !normalPlay+
    
!ffFrameLoop:
    lda NumCallsPerFrame
    sta FFCallCounter
    
!ffCallLoop:
    jsr SIDPlay
    inc $d020
    dec FFCallCounter
    lda FFCallCounter
    bne !ffCallLoop-
    
    jsr CheckSpaceKey
    lda FastForwardActive
    bne !ffFrameLoop-
    
    lda #$00
    sta $d020
    sta callCount + 1
    jmp !done+

!normalPlay:
callCount:
    ldx #0
    inx
    cpx NumCallsPerFrame
    bne !justPlay+
    ldx #0

!justPlay:
    stx callCount + 1

    jsr JustPlayMusic

!done:
    ldx callCount + 1
    jsr set_d011_and_d012

    asl $d019
    pla
    tay
    pla
    tax
    pla
    rti

// =============================================================================
// DATA SECTION - Placeholder screen and bitmap data
// =============================================================================

* = BITMAP_MAP_DATA "Bitmap MAP Data"
    .fill $2000, $00

* = BITMAP_SCREEN_DATA "Bitmap SCR Data"
    .fill $400, $00

* = BITMAP_COLOUR_DATA "Bitmap COL Data"
    .fill $400, $00