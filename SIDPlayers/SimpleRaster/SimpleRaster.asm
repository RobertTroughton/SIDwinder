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

.var BASE_ADDRESS = cmdLineVars.get("loadAddress").asNumber()

* = BASE_ADDRESS + $100 "Main Code"

	jmp Initialize

//; =============================================================================
//; INCLUDES
//; =============================================================================

#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE

.import source "../INC/Common.asm"
.import source "../INC/keyboard.asm"
.import source "../INC/musicplayback.asm"

//; =============================================================================
//; INITIALIZATION ENTRY POINT
//; =============================================================================

Initialize:
    sei

    lda #$35
    sta $01

    jsr VSync

    lda #$00
    sta $d011
    sta $d020

    jsr InitKeyboard

    lda SongNumber
    sta CurrentSong
    
    lda NumSongs
    bne !skip+
    lda #1
    sta NumSongs
!skip:

    lda CurrentSong
    tax
    tay
    jsr SIDInit

    jsr VSync

    jsr NMIFix

    jsr init_D011_D012_values

    lda #<MusicIRQ
    sta $fffe
    lda #>MusicIRQ
    sta $ffff

    ldx #0
	jsr set_d011_and_d012

    lda #$7f
    sta $dc0d
    lda $dc0d
    lda #$01
    sta $d01a
    lda #$01
    sta $d019

    cli

Forever:
    jsr CheckKeyboard
    jmp Forever

//; =============================================================================
//; MAIN MUSIC INTERRUPT HANDLER
//; =============================================================================

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
    inc $d020  // Visual feedback
    dec FFCallCounter
    lda FFCallCounter
    bne !ffCallLoop-
    
    // Check if space is still held
    jsr CheckSpaceKey
    lda FastForwardActive
    bne !ffFrameLoop-
    
    lda #$00
    sta $d020
    lda #0
    sta callCount + 1
    jmp !done+

!normalPlay:
    // Normal playback
callCount:
    ldx #0
    inx
    cpx NumCallsPerFrame
    bne !justPlay+
    
    // Frame boundary - update visual
ColChangeFrame:
    ldy #$c0
    iny
    bne !skip2+
    inc $d020
    ldy #$c0
!skip2:
    sty ColChangeFrame + 1
    ldx #0

!justPlay:
    stx callCount + 1
    
    inc $d020
    jsr SIDPlay
    dec $d020

!done:
    // Setup next interrupt
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
//; END OF FILE
//; =============================================================================