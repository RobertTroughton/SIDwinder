//; =============================================================================
//;                             SIMPLE BITMAP PLAYER
//;                   Bitmap Graphics SID Music Player for C64
//; =============================================================================
//; Part of the SIDwinder player collection
//; A music player that displays a multicolor bitmap while playing SID tunes
//; =============================================================================
//;
//; DESCRIPTION:
//; ------------
//; SimpleBitmap combines SID music playback with visual presentation using
//; the C64's multicolor bitmap mode. It displays a static image while playing
//; music through raster interrupt driven playback.
//;
//; KEY FEATURES:
//; - Multicolor bitmap display (160x200 resolution, 4 colors per cell)
//; - Raster interrupt driven music playback
//; - Support for multi-speed tunes
//; - Automatic bitmap data loading and display setup
//; - NMI interrupt protection
//;
//; TECHNICAL DETAILS:
//; - Uses VIC-II bitmap mode with color RAM configuration
//; - Bitmap data loaded from external files (map, screen, color)
//; - Memory layout: Bitmap at $A000, Color at $8800, Screen at $8C00
//; - Stable raster interrupts ensure smooth playback
//;
//; REQUIRED FILES:
//; - bitmap.map: Bitmap pixel data (8000 bytes)
//; - bitmap.scr: Screen color data (1000 bytes)
//; - bitmap.col: Color RAM data (1000 bytes)
//;
//; =============================================================================

//; Memory Map

//; On Load
//; VICBANK + $2000-$3f3f : Bitmap
//; VICBANK + $1800-$1BFF : Screen Data
//; VICBANK + $1C00-$1FFF : Colour Data

//; Real-time
//; VICBANK + $2000-$3f3f : Bitmap
//; VICBANK + $1800-$1BFF : Screen Data
//; VICBANK + $1C00-$1FFF : Colour Data

.var BASE_ADDRESS = cmdLineVars.get("loadAddress").asNumber()

* = BASE_ADDRESS + $100 "Main Code"

	jmp Initialize

.var SIDInit = BASE_ADDRESS + 0
.var SIDPlay = BASE_ADDRESS + 3
.var BackupSIDMemory = BASE_ADDRESS + 6
.var RestoreSIDMemory = BASE_ADDRESS + 9
.var NumCallsPerFrame = BASE_ADDRESS + 12
.var BorderColour = BASE_ADDRESS + 13
.var BitmapScreenColour = BASE_ADDRESS + 14
.var SongNumber = BASE_ADDRESS + 15
.var SongName = BASE_ADDRESS + 16
.var ArtistName = BASE_ADDRESS + 16 + 32

.const VIC_BANK                         = 1
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

//; =============================================================================
//; INITIALIZATION ENTRY POINT
//; =============================================================================

Initialize: {
    sei                                 //; Disable interrupts during setup

    //; Configure memory mapping
    lda #$35                            //; Enable KERNAL, BASIC, and I/O
    sta $01

    //; Wait for stable raster position
    jsr VSync

    //; Blank screen during initialization
    lda #$00
    sta $d011                           //; Turn off display
    sta $d020                           //; Black border
    sta $d021                           //; Black background

    //; Initialize the music
    lda SongNumber
	tax
	tay
    jsr SIDInit

    //; Disable NMI interrupts
    jsr NMIFix

    //; Ensure stable timing
    jsr VSync

    jsr init_D011_D012_values

    //; ==========================================================================
    //; COLOR RAM INITIALIZATION
    //; ==========================================================================

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

    //; ==========================================================================
    //; INTERRUPT SYSTEM SETUP
    //; ==========================================================================

    //; Set up interrupt vectors
    lda #<MusicIRQ
    sta $fffe
    lda #>MusicIRQ
    sta $ffff

    //; Configure interrupt sources
    lda #$7f
    sta $dc0d                           //; Disable CIA interrupts
    lda $dc0d                           //; Acknowledge any pending
    lda #$01
    sta $d01a                           //; Enable raster interrupts
    lda #$01
    sta $d019                           //; Clear any pending raster interrupt

    //; Set VIC bank (bank 0: $0000-$3FFF)
    lda #DD00Value
    sta $dd00
    lda #DD02Value
    sta $dd02

    //; Configure VIC memory pointers
    lda #D018Value
    sta $d018

    //; Set display mode
    lda #$18                            //; Multicolor mode on
    sta $d016

    lda #$00                            //; Sprites off
    sta $d015

    //; Wait for stable position before enabling display
    jsr VSync

    lda BorderColour
    sta $d020

    lda #$3b
    sta $d011

    //; Configure first raster position
    ldx #0
    jsr set_d011_and_d012

    cli                                 //; Enable interrupts

    //; Main loop - music plays via interrupts
Forever:
    jmp Forever
}

//; =============================================================================
//; VERTICAL SYNC ROUTINE
//; =============================================================================
//; Waits for the vertical blank period to ensure stable timing
//; Registers: Preserves all

VSync: {
    bit $d011                           //; Wait for raster to leave
    bpl *-3                             //; the vertical blank area
    bit $d011                           //; Wait for raster to enter
    bmi *-3                             //; the vertical blank area
    rts
}

//; =============================================================================
//; MAIN MUSIC INTERRUPT HANDLER
//; =============================================================================
//; Handles music playback for multi-speed tunes
//; No visual effects to maintain clean bitmap display

MusicIRQ: {
    //; Track which call this is within the frame
callCount:
    ldx #0                              //; Self-modifying counter
    inx
    cpx NumCallsPerFrame
    bne JustPlayMusic
    ldx #0                              //; Reset counter at frame boundary

JustPlayMusic:
    stx callCount + 1                   //; Store updated counter

    //; Play the music
    jsr SIDPlay

    //; Set up next interrupt
    ldx callCount + 1
    jsr set_d011_and_d012

    //; Acknowledge interrupt
    asl $d019                           //; Clear raster interrupt flag
    rti
}

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
ora_D011_value:
d011_values_ptr:
	ora $abcd, x
	sta $d011
	rts

//; =============================================================================
//; DATA SECTION - Raster Line Timing
//; =============================================================================

.var FrameHeight = 312 // TODO: NTSC!

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

//; =============================================================================
//; INCLUDES
//; =============================================================================
//; Import common utility routines

.import source "../INC/NMIFix.asm"           //; NMI interrupt protection

//; =============================================================================
//; DATA SECTION - Placeholder screen and bitmap data
//; =============================================================================

* = BITMAP_MAP_DATA "Bitmap MAP Data"
	.fill $2000, $00

* = BITMAP_SCREEN_DATA "Bitmap SCR Data"
	.fill $400, $00

* = BITMAP_COLOUR_DATA "Bitmap COL Data"
	.fill $400, $00


//; =============================================================================
//; END OF FILE
//; =============================================================================