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

* = $4100

.var MainAddress = * - $100
.var SIDInit = MainAddress + 0
.var SIDPlay = MainAddress + 3
.var BackupSIDMemory = MainAddress + 6
.var RestoreSIDMemory = MainAddress + 9
.var SongName = MainAddress + 16
.var ArtistName = MainAddress + 16 + 32
.var NumCallsPerFrame = 1

.const VIC_BANK                         = 1
.const VIC_BANK_ADDRESS                 = VIC_BANK * $4000
.const BITMAP_BANK                      = 1                                             //; $6000-7fff
.const COLOUR_BANK                      = 6 //; temp store - to be copied to $d800      //; $5800-5bff
.const SCREEN_BANK                      = 7                                             //; $5c00-5fff

.const DD00Value                        = 3 - VIC_BANK
.const DD02Value                        = 60 + VIC_BANK
.const D018Value                        = (SCREEN_BANK * 16) + (BITMAP_BANK * 8)

.const BitmapMAPData                    = VIC_BANK_ADDRESS + (BITMAP_BANK * $2000)
.const BitmapCOLData                    = VIC_BANK_ADDRESS + (COLOUR_BANK * $0400)
.const BitmapSCRData                    = VIC_BANK_ADDRESS + (SCREEN_BANK * $0400)
.const BorderColour     			    = $5bfe
.const BitmapScreenColour			    = $5bff

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
    sta $d021                           //; Black background

    //; Initialize the music
	tax
	tay
    jsr SIDInit

    //; Ensure stable timing
    jsr VSync

    //; Disable NMI interrupts
    jsr NMIFix

    //; ==========================================================================
    //; COLOR RAM INITIALIZATION
    //; ==========================================================================
    //; Copy color data to hardware color RAM at $D800

    ldy #$00
!loop:
    //; Unrolled loop for faster color RAM initialization
    lda BitmapCOLData + (0 * 256), y   //; Copy first page
    sta $d800         + (0 * 256), y
    lda BitmapCOLData + (1 * 256), y   //; Copy second page
    sta $d800         + (1 * 256), y
    lda BitmapCOLData + (2 * 256), y   //; Copy third page
    sta $d800         + (2 * 256), y
    lda BitmapCOLData + (3 * 256), y   //; Copy fourth page (partial)
    sta $d800         + (3 * 256), y
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

    //; Wait for stable position before enabling display
    jsr VSync

    lda BorderColour
    sta $d020

    //; Configure first raster position
    ldx #0
    jsr SetNextRaster

    //; ==========================================================================
    //; VIC-II BITMAP MODE CONFIGURATION
    //; ==========================================================================

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

    //; Enable bitmap display
    lda $d011
    and #$80                            //; Preserve raster high bit
    ora #$3b                            //; Bitmap mode, display on, 25 rows
    sta $d011

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
//; Handles music playback for multi-speed tunes
//; No visual effects to maintain clean bitmap display

MusicIRQ: {
    //; Track which call this is within the frame
callCount:
    ldx #0                              //; Self-modifying counter
    inx
    cpx #NumCallsPerFrame
    bne JustPlayMusic
    ldx #0                              //; Reset counter at frame boundary

JustPlayMusic:
    stx callCount + 1                   //; Store updated counter

    //; Play the music
    jsr SIDPlay

    //; Set up next interrupt
    ldx callCount + 1
    jsr SetNextRaster

    //; Acknowledge interrupt
    asl $d019                           //; Clear raster interrupt flag
    rti
}

//; =============================================================================
//; INCLUDES
//; =============================================================================
//; Import common utility routines

.import source "../INC/NMIFix.asm"           //; NMI interrupt protection

//; =============================================================================
//; DATA SECTION - Raster Line Timing
//; =============================================================================

.var FrameHeight = 312 // TODO: NTSC!
D011_Values: .fill NumCallsPerFrame, (>(mod(250 + ((FrameHeight * i) / NumCallsPerFrame), 312))) * $80
D012_Values: .fill NumCallsPerFrame, (<(mod(250 + ((FrameHeight * i) / NumCallsPerFrame), 312)))

//; =============================================================================
//; END OF FILE
//; =============================================================================