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

.var LoadAddress = BASE_ADDRESS + $c0
.var InitAddress = BASE_ADDRESS + $c2
.var PlayAddress = BASE_ADDRESS + $c4
.var EndAddress = BASE_ADDRESS + $c6
.var NumSongs = BASE_ADDRESS + $c8
.var ClockType = BASE_ADDRESS + $c9     // 0=PAL, 1=NTSC
.var SIDModel = BASE_ADDRESS + $ca      // 0=6581, 1=8580
.var ZPUsageData = BASE_ADDRESS + $e0   // Will store formatted ZP usage string

.import source "../INC/keyboard.asm"

CurrentSong:      .byte $00
FastForwardActive:.byte $00
FFCallCounter:    .byte $00

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

    // Initialize keyboard scanning
    jsr InitKeyboard

    // Initialize variables
    lda SongNumber
    sta CurrentSong
    
    // Check if NumSongs is set, default to 1 if not
    lda NumSongs
    bne !skip+
    lda #1
    sta NumSongs
!skip:

    // Initialize the music
    lda CurrentSong
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
    jsr CheckKeyboard
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
    pha
    txa
    pha
    tya
    pha

    // Check if we're in fast-forward mode
    lda FastForwardActive
    beq !normalPlay+
    
    // Fast forward - call multiple times
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

CheckKeyboard:
    jsr CheckSpaceKey

    lda NumSongs
    cmp #2
    bcs !multiSong+
    rts
    
!multiSong:
    // Check +/- keys for song navigation
    jsr CheckPlusKey
    lda PlusKeyPressed
    beq !notPlus+
    lda PlusKeyReleased
    beq !notPlus+
    
    lda #0
    sta PlusKeyReleased
    jsr NextSong
    jmp !done+
    
!notPlus:
    lda PlusKeyPressed
    bne !stillPlus+
    lda #1
    sta PlusKeyReleased
!stillPlus:

    jsr CheckMinusKey
    lda MinusKeyPressed
    beq !notMinus+
    lda MinusKeyReleased
    beq !notMinus+
    
    lda #0
    sta MinusKeyReleased
    jsr PrevSong
    jmp !done+
    
!notMinus:
    lda MinusKeyPressed
    bne !stillMinus+
    lda #1
    sta MinusKeyReleased
!stillMinus:

    // Check number/letter keys
    jsr ScanKeyboard
    cmp #0
    beq !done+
    
    jsr GetKeyWithShift
    
    // Check 1-9
    cmp #'1'
    bcc !done+
    cmp #':'
    bcs !checkLetters+
    
    sec
    sbc #'1'
    cmp NumSongs
    bcs !done+
    jsr SelectSong
    jmp !done+
    
!checkLetters:
    // Check A-Z
    cmp #'A'
    bcc !checkLower+
    cmp #'['
    bcs !checkLower+
    
    sec
    sbc #'A'-9
    cmp NumSongs
    bcs !done+
    jsr SelectSong
    jmp !done+
    
!checkLower:
    cmp #'a'
    bcc !done+
    cmp #'{'
    bcs !done+
    
    sec
    sbc #'a'-9
    cmp NumSongs
    bcs !done+
    jsr SelectSong
    
!done:
    rts

// Direct key checks
CheckSpaceKey:
    lda #%01111111
    sta $DC00
    lda $DC01
    and #%00010000
    eor #%00010000
    sta FastForwardActive
    rts

CheckPlusKey:
    lda #%11011111
    sta $DC00
    lda $DC01
    and #%00000001
    eor #%00000001
    sta PlusKeyPressed
    rts

CheckMinusKey:
    lda #%11011111
    sta $DC00
    lda $DC01
    and #%00001000
    eor #%00001000
    sta MinusKeyPressed
    rts

// Key state variables
PlusKeyPressed:  .byte 0
PlusKeyReleased: .byte 1
MinusKeyPressed: .byte 0
MinusKeyReleased:.byte 1

// Song selection
SelectSong:
    sta CurrentSong
    tax
    tay
    jmp SIDInit

NextSong:
    lda CurrentSong
    clc
    adc #1
    cmp NumSongs
    bcc !ok+
    lda #0
!ok:
    jsr SelectSong
    rts

PrevSong:
    lda CurrentSong
    bne !ok+
    lda NumSongs
!ok:
    sec
    sbc #1
    jsr SelectSong
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