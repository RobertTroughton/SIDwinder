// =============================================================================
//                             SIMPLE BITMAP PLAYER
//                   Bitmap Graphics SID Music Player for C64
// =============================================================================

.var BASE_ADDRESS = cmdLineVars.get("loadAddress").asNumber()

* = BASE_ADDRESS + $100 "Main Code"

    jmp Initialize

.const VIC_BANK                         = (BASE_ADDRESS / $4000)
.const VIC_BANK_ADDRESS                 = VIC_BANK * $4000
.const BITMAP_BANK                      = 1
.const SCREEN_BANK                      = 6
.const COLOUR_BANK                      = 7

.const DD00Value                        = 3 - VIC_BANK
.const DD02Value                        = 60 + VIC_BANK
.const D018Value                        = (SCREEN_BANK * 16) + (BITMAP_BANK * 8)

.const BITMAP_MAP_DATA                  = VIC_BANK_ADDRESS + (BITMAP_BANK * $2000)
.const BITMAP_SCREEN_DATA               = VIC_BANK_ADDRESS + (SCREEN_BANK * $0400)
.const BITMAP_COLOUR_DATA               = VIC_BANK_ADDRESS + (COLOUR_BANK * $0400)

// =============================================================================
// INCLUDES
// =============================================================================

#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR

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

init_D011_D012_values:
    ldx NumCallsPerFrame
    lda D011_Values_Lookup_Lo, x
    sta d011_values_ptr + 1
    lda D011_Values_Lookup_Hi, x
    sta d011_values_ptr + 2
    lda D012_Values_Lookup_Lo, x
    sta d012_values_ptr + 1
    lda D012_Values_Lookup_Hi, x
    sta d012_values_ptr + 2
    rts

set_d011_and_d012:
d012_values_ptr:
    lda $abcd, x
    sta $d012
    lda $d011
    and #$7f
d011_values_ptr:
    ora $abcd, x
    sta $d011
    rts

// =============================================================================
// DATA SECTION - Raster Line Timing
// =============================================================================

.var FrameHeight = 312

D011_Values_1Call: .fill 1, (>(mod(250 + ((FrameHeight * i) / 1), 312))) * $80
D012_Values_1Call: .fill 1, (<(mod(250 + ((FrameHeight * i) / 1), 312)))
D011_Values_2Calls: .fill 2, (>(mod(250 + ((FrameHeight * i) / 2), 312))) * $80
D012_Values_2Calls: .fill 2, (<(mod(250 + ((FrameHeight * i) / 2), 312)))
D011_Values_3Calls: .fill 3, (>(mod(250 + ((FrameHeight * i) / 3), 312))) * $80
D012_Values_3Calls: .fill 3, (<(mod(250 + ((FrameHeight * i) / 3), 312)))
D011_Values_4Calls: .fill 4, (>(mod(250 + ((FrameHeight * i) / 4), 312))) * $80
D012_Values_4Calls: .fill 4, (<(mod(250 + ((FrameHeight * i) / 4), 312)))
D011_Values_5Calls: .fill 5, (>(mod(250 + ((FrameHeight * i) / 5), 312))) * $80
D012_Values_5Calls: .fill 5, (<(mod(250 + ((FrameHeight * i) / 5), 312)))
D011_Values_6Calls: .fill 6, (>(mod(250 + ((FrameHeight * i) / 6), 312))) * $80
D012_Values_6Calls: .fill 6, (<(mod(250 + ((FrameHeight * i) / 6), 312)))
D011_Values_7Calls: .fill 7, (>(mod(250 + ((FrameHeight * i) / 7), 312))) * $80
D012_Values_7Calls: .fill 7, (<(mod(250 + ((FrameHeight * i) / 7), 312)))
D011_Values_8Calls: .fill 8, (>(mod(250 + ((FrameHeight * i) / 8), 312))) * $80
D012_Values_8Calls: .fill 8, (<(mod(250 + ((FrameHeight * i) / 8), 312)))

D011_Values_Lookup_Lo: .byte <D011_Values_1Call, <D011_Values_1Call, <D011_Values_2Calls, <D011_Values_3Calls, <D011_Values_4Calls, <D011_Values_5Calls, <D011_Values_6Calls, <D011_Values_7Calls, <D011_Values_8Calls
D011_Values_Lookup_Hi: .byte >D011_Values_1Call, >D011_Values_1Call, >D011_Values_2Calls, >D011_Values_3Calls, >D011_Values_4Calls, >D011_Values_5Calls, >D011_Values_6Calls, >D011_Values_7Calls, >D011_Values_8Calls
D012_Values_Lookup_Lo: .byte <D012_Values_1Call, <D012_Values_1Call, <D012_Values_2Calls, <D012_Values_3Calls, <D012_Values_4Calls, <D012_Values_5Calls, <D012_Values_6Calls, <D012_Values_7Calls, <D012_Values_8Calls
D012_Values_Lookup_Hi: .byte >D012_Values_1Call, >D012_Values_1Call, >D012_Values_2Calls, >D012_Values_3Calls, >D012_Values_4Calls, >D012_Values_5Calls, >D012_Values_6Calls, >D012_Values_7Calls, >D012_Values_8Calls

// =============================================================================
// DATA SECTION - Placeholder screen and bitmap data
// =============================================================================

* = BITMAP_MAP_DATA "Bitmap MAP Data"
    .fill $2000, $00

* = BITMAP_SCREEN_DATA "Bitmap SCR Data"
    .fill $400, $00

* = BITMAP_COLOUR_DATA "Bitmap COL Data"
    .fill $400, $00