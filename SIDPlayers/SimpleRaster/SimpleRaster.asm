//; =============================================================================
//;                              SIMPLE RASTER PLAYER
//;                        Basic SID Music Player for C64
//; =============================================================================
//; Part of the SIDwinder player collection
//; A straightforward raster-interrupt based music player with visual feedback
//; =============================================================================
//;
//; DESCRIPTION:
//; ------------
//; SimpleRaster provides a minimal but functional SID music player that uses
//; raster interrupts to ensure accurate playback timing. It includes a simple
//; visual indicator that changes the background color on each frame.
//;
//; KEY FEATURES:
//; - Raster interrupt driven playback
//; - Support for multi-speed tunes (configurable calls per frame)
//; - Visual frame counter via background color changes
//; - NMI interrupt protection
//; - Minimal memory footprint
//;
//; TECHNICAL DETAILS:
//; - Uses stable raster interrupts for jitter-free playback
//; - Automatically distributes multiple play calls across the frame
//; - Shows CPU usage by flashing border during SID play routine
//;
//; =============================================================================

* = $4100 "Main Code"

.var MainAddress = * - $100
.var SIDInit = MainAddress + 0
.var SIDPlay = MainAddress + 3
//;.var BackupSIDMemory = MainAddress + 6
//;.var RestoreSIDMemory = MainAddress + 9
.var NumCallsPerFrame = MainAddress + 12
//;.var BorderColour = MainAddress + 13
//;.var BitmapScreenColour = MainAddress + 14

//; =============================================================================
//; INITIALIZATION ENTRY POINT
//; =============================================================================

InitIRQ: {
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

    //; Initialize the music
	tax
	tay
    jsr SIDInit

    //; Ensure we're at a stable position
    jsr VSync

    //; Disable NMI interrupts to prevent interference
    jsr NMIFix

    jsr init_D011_D012_values

    //; Set up interrupt vectors
    lda #<MusicIRQ
    sta $fffe
    lda #>MusicIRQ
    sta $ffff

    //; Configure first raster position
    ldx #0
	jsr set_d011_and_d012

    //; Configure interrupt sources
    lda #$7f
    sta $dc0d                           //; Disable CIA interrupts
    lda $dc0d                           //; Acknowledge any pending
    lda #$01
    sta $d01a                           //; Enable raster interrupts
    lda #$01
    sta $d019                           //; Clear any pending raster interrupt

    cli                                 //; Enable interrupts

    //; Main loop - the music plays via interrupts
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
//; Handles music playback and visual feedback
//; Automatically manages multiple calls per frame for multi-speed tunes

MusicIRQ: {
    //; Increment call counter
callCount:
    ldx #0                              //; Self-modifying counter
    inx
    cpx NumCallsPerFrame
    bne JustPlayMusic

    //; Frame boundary reached - update visual feedback
ColChangeFrame:
    ldy #$c0                            //; Self-modifying color index
    iny
    bne !skip+
    inc $d020                           //; Change background color
    ldy #$c0                            //; Reset color cycle
!skip:
    sty ColChangeFrame + 1              //; Store new color index
    ldx #0                              //; Reset call counter

JustPlayMusic:
    stx callCount + 1                   //; Store updated counter

    //; Visual CPU usage indicator
    inc $d020                           //; Flash border during playback
    jsr SIDPlay                         //; Call the music player
    dec $d020                           //; Restore border color

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
d011_values_ptr:
	lda $abcd, x
	sta $d012
	lda $d011
	and #$7f
ora_D011_value:
d012_values_ptr:
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
//; END OF FILE
//; =============================================================================