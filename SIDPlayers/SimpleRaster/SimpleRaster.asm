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

* = PlayerADDR

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
    jsr SIDInit

    //; Ensure we're at a stable position
    jsr VSync

    //; Disable NMI interrupts to prevent interference
    jsr NMIFix

    //; Set up interrupt vectors
    lda #<MusicIRQ
    sta $fffe
    lda #>MusicIRQ
    sta $ffff

    //; Configure first raster position
    ldx #0
    jsr SetNextRaster

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
//; RASTER POSITION SETUP
//; =============================================================================
//; Sets up the next raster interrupt position based on the current call index
//; Input: X = interrupt index (0 to NumCallsPerFrame-1)
//; Registers: Corrupts A

SetNextRaster: {
    lda D012_Values, x                  //; Get raster line low byte
    sta $d012
    lda $d011                           //; Get current VIC control register
    and #$7f                            //; Clear raster high bit
    ora D011_Values, x                  //; Set raster high bit if needed
    sta $d011
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
    cpx #NumCallsPerFrame
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
    jsr SetNextRaster

    //; Acknowledge interrupt
    asl $d019                           //; Clear raster interrupt flag
    rti
}

//; =============================================================================
//; DATA SECTION - Raster Line Timing
//; =============================================================================

.var FrameHeight = 312 // TODO: NTSC!
D011_Values: .fill NumCallsPerFrame, (>(mod(250 + ((FrameHeight * i) / NumCallsPerFrame), 312))) * $80
D012_Values: .fill NumCallsPerFrame, (<(mod(250 + ((FrameHeight * i) / NumCallsPerFrame), 312)))

//; =============================================================================
//; INCLUDES
//; =============================================================================
//; Import common utility routines

.import source "../INC/NMIFix.asm"           //; NMI interrupt protection

//; =============================================================================
//; END OF FILE
//; =============================================================================