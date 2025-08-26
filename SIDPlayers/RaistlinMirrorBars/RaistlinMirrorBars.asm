//; =============================================================================
//;                              RAISTLINBARS v2.0
//;                   Advanced SID Music Spectrum Visualizer
//; =============================================================================
//; Original code by Raistlin of Genesis*Project
//; Enhanced with SIDwinder integration and advanced analysis features
//; =============================================================================
//;
//; DESCRIPTION:
//; ------------
//; RaistlinMirrorBars creates a real-time spectrum analyzer that visualizes C64 
//; SID music with a mirrored effect. It captures frequency and envelope data 
//; from the SID chip and transforms it into animated bars that dance to the 
//; music, with bars reflected vertically for a symmetrical display.
//;
//; KEY FEATURES:
//; - 40 frequency bars with 96-pixel resolution (48 pixels per half)
//; - Real-time SID register analysis without affecting playback
//; - Mirrored bar display for symmetrical visualization
//; - Static color gradient with height-based brightness
//; - Double-buffered display for flicker-free animation
//;
//; TECHNICAL APPROACH:
//; The visualizer uses a dual-playback technique to safely read SID registers:
//; 1. First playback with memory preservation (normal music playback)
//; 2. Second playback with $01=$30 to capture SID states
//; This allows real-time analysis without corrupting the music player's state.
//;
//; =============================================================================

//; Memory Map

//; On Load
//; VICBANK + $3800-$3FFF : CharSet

//; Real-time
//; VICBANK + $3000-$33FF : Screen 0
//; VICBANK + $3400-$37FF : Screen 1
//; VICBANK + $3800-$3FFF : CharSet

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

//; =============================================================================
//; CONFIGURATION CONSTANTS
//; =============================================================================

.const NUM_FREQUENCY_BARS				= 40

.const TOP_SPECTRUM_HEIGHT				= 9
.const TOTAL_SPECTRUM_HEIGHT			= TOP_SPECTRUM_HEIGHT * 2

.const BAR_INCREASE_RATE				= (TOP_SPECTRUM_HEIGHT * 1.5)
.const BAR_DECREASE_RATE				= (TOP_SPECTRUM_HEIGHT * 0.3)

.const SONG_TITLE_LINE					= 0
.const ARTIST_NAME_LINE					= 23
.const SPECTRUM_START_LINE				= 3

.eval setSeed(55378008)

.const VIC_BANK							= (BASE_ADDRESS / $4000)
.const VIC_BANK_ADDRESS					= VIC_BANK * $4000
.const SCREEN0_BANK						= 12
.const SCREEN1_BANK						= 13
.const CHARSET_BANK						= 7

.const SCREEN0_ADDRESS					= VIC_BANK_ADDRESS + (SCREEN0_BANK * $400)
.const SCREEN1_ADDRESS					= VIC_BANK_ADDRESS + (SCREEN1_BANK * $400)
.const CHARSET_ADDRESS					= VIC_BANK_ADDRESS + (CHARSET_BANK * $800)

.const D018_VALUE_0						= (SCREEN0_BANK * 16) + (CHARSET_BANK * 2)
.const D018_VALUE_1						= (SCREEN1_BANK * 16) + (CHARSET_BANK * 2)

.const MAX_BAR_HEIGHT					= TOP_SPECTRUM_HEIGHT * 8 - 1
.const MAIN_BAR_OFFSET					= MAX_BAR_HEIGHT - 8

//; =============================================================================
//; EXTERNAL RESOURCES
//; =============================================================================

.var file_charsetData = LoadBinary("CharSet.map")

//; =============================================================================
//; INITIALIZATION
//; =============================================================================

Initialize:
	sei

	jsr VSync

	lda #$00
	sta $d011
	sta $d020

	jsr SetupStableRaster
	jsr SetupSystem
	jsr NMIFix

	jsr InitializeVIC
	jsr ClearScreens
	jsr DisplaySongInfo
	jsr init_D011_D012_values

	ldy #$00
	lda #$00
!loop:
	sta barHeights - 2, y
	sta smoothedHeights - 2, y
	iny
	cpy #NUM_FREQUENCY_BARS + 4
	bne !loop-

	jsr SetupMusic

	jsr VSync

	lda #$1b
	sta $d011

	jsr SetupInterrupts

	cli

MainLoop:
	lda visualizationUpdateFlag
	beq MainLoop

	jsr ApplySmoothing
	jsr RenderBars

	lda #$00
	sta visualizationUpdateFlag

	lda currentScreenBuffer
	eor #$01
	sta currentScreenBuffer

	jmp MainLoop

//; =============================================================================
//; SYSTEM SETUP
//; =============================================================================

SetupSystem:
	lda #$35
	sta $01

	lda #(63 - VIC_BANK)
	sta $dd00
	lda #VIC_BANK
	sta $dd02

	rts

//; =============================================================================
//; VIC INITIALIZATION
//; =============================================================================

.const SKIP_REGISTER = $e1

InitializeVIC:
	ldx #VICConfigEnd - VICConfigStart - 1
!loop:
	lda VICConfigStart, x
	cmp #SKIP_REGISTER
	beq !skip+
	sta $d000, x
!skip:
	dex
	bpl !loop-

	rts

//; =============================================================================
//; INTERRUPT SETUP
//; =============================================================================

SetupInterrupts:

	lda #<MainIRQ
	sta $fffe
	lda #>MainIRQ
	sta $ffff

	ldx #$00
	jsr set_d011_and_d012

	lda #$01
	sta $d01a
	sta $d019

	lda #$00
	sta NextIRQ + 1

	rts

//; =============================================================================
//; MAIN INTERRUPT HANDLER
//; =============================================================================

MainIRQ:
	pha
	txa
	pha
	tya
	pha

	ldy currentScreenBuffer
	lda D018Values, y
	cmp $d018
	beq !skip+
	sta $d018
!skip:

	inc visualizationUpdateFlag

	jsr UpdateBarDecay

	jsr PlayMusicWithAnalysis

	inc frameCounter
	bne !skip+
	inc frame256Counter
!skip:

	jsr NextIRQ

	lda #$01
	sta $d01a
	sta $d019

	pla
	tay
	pla
	tax
	pla
	rti

//; =============================================================================
//; MUSIC-ONLY INTERRUPT HANDLER
//; =============================================================================

MusicOnlyIRQ:
	pha
	txa
	pha
	tya
	pha

	jsr PlayMusicWithAnalysis
	jsr NextIRQ

	lda #$01
	sta $d01a
	sta $d019

	pla
	tay
	pla
	tax
	pla
	rti

//; =============================================================================
//; INTERRUPT CHAINING
//; =============================================================================

NextIRQ:
	ldx #$00
	inx
	cpx NumCallsPerFrame
	bne !notLast+
	ldx #$00
!notLast:
	stx NextIRQ + 1

	jsr set_d011_and_d012

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

//; =============================================================================
//; RENDERING
//; =============================================================================

RenderBars:
	ldy #NUM_FREQUENCY_BARS
!colorLoop:
	dey
	bmi !colorsDone+

	ldx smoothedHeights, y
	
	lda heightColorTable, x
	
	cmp previousColors, y
	beq !colorLoop-
	sta previousColors, y

	.for (var line = 0; line < TOTAL_SPECTRUM_HEIGHT; line++) {
		sta $d800 + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}
	jmp !colorLoop-

!colorsDone:

	lda currentScreenBuffer
	beq !renderScreen1+

	jmp RenderToScreen0

!renderScreen1:
	jmp RenderToScreen1

RenderToScreen0:
	ldy #NUM_FREQUENCY_BARS
!loop:
	dey
	bpl !continue+
	rts
!continue:

	lda smoothedHeights, y
	cmp previousHeightsScreen0, y
	beq !loop-
	sta previousHeightsScreen0, y
	tax

	clc

	.for (var line = 0; line < TOP_SPECTRUM_HEIGHT; line++) {
		lda barCharacterMap - MAIN_BAR_OFFSET + (line * 8), x
		sta SCREEN0_ADDRESS + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
		adc #10
		sta SCREEN0_ADDRESS + ((SPECTRUM_START_LINE + (TOTAL_SPECTRUM_HEIGHT - 1) - line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}
	jmp !loop-

RenderToScreen1:
	ldy #NUM_FREQUENCY_BARS
!loop:
	dey
	bpl !continue+
	rts
!continue:

	lda smoothedHeights, y
	cmp previousHeightsScreen1, y
	beq !loop-
	sta previousHeightsScreen1, y
	tax

	clc

	.for (var line = 0; line < TOP_SPECTRUM_HEIGHT; line++) {
		lda barCharacterMap - MAIN_BAR_OFFSET + (line * 8), x
		sta SCREEN1_ADDRESS + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
		adc #10
		sta SCREEN1_ADDRESS + ((SPECTRUM_START_LINE + (TOTAL_SPECTRUM_HEIGHT - 1) - line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}
	jmp !loop-

//; =============================================================================
//; UTILITY FUNCTIONS
//; =============================================================================

ClearScreens:
	ldy #$00
	lda #$20
!loop:
	.for (var i = 0; i < 4; i++)
	{
		sta SCREEN0_ADDRESS + (i * 256), y
		sta SCREEN1_ADDRESS + (i * 256), y
		sta $d800 + (i * 256), y
	}
	iny
	bne !loop-
	rts

DisplaySongInfo:
	ldy #31

!loop:

	lda SongName, y
	sta SCREEN0_ADDRESS + (SONG_TITLE_LINE * 40) + 4, y
	sta SCREEN1_ADDRESS + (SONG_TITLE_LINE * 40) + 4, y
	ora #$80
	sta SCREEN0_ADDRESS + ((SONG_TITLE_LINE + 1) * 40) + 4, y
	sta SCREEN1_ADDRESS + ((SONG_TITLE_LINE + 1) * 40) + 4, y
	lda #$01
	sta $d800 + ((SONG_TITLE_LINE + 0) * 40) + 4, y
	sta $d800 + ((SONG_TITLE_LINE + 1) * 40) + 4, y

	lda ArtistName, y
	sta SCREEN0_ADDRESS + (ARTIST_NAME_LINE * 40) + 4, y
	sta SCREEN1_ADDRESS + (ARTIST_NAME_LINE * 40) + 4, y
	ora #$80
	sta SCREEN0_ADDRESS + ((ARTIST_NAME_LINE + 1) * 40) + 4, y
	sta SCREEN1_ADDRESS + ((ARTIST_NAME_LINE + 1) * 40) + 4, y
	lda #$0f
	sta $d800 + ((ARTIST_NAME_LINE + 0) * 40) + 4, y
	sta $d800 + ((ARTIST_NAME_LINE + 1) * 40) + 4, y

	dey
	bpl !loop-

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
//; DATA SECTION - VIC Configuration
//; =============================================================================

VICConfigStart:
	.byte $00, $00						//; Sprite 0 X,Y
	.byte $00, $00						//; Sprite 1 X,Y
	.byte $00, $00						//; Sprite 2 X,Y
	.byte $00, $00						//; Sprite 3 X,Y
	.byte $00, $00						//; Sprite 4 X,Y
	.byte $00, $00						//; Sprite 5 X,Y
	.byte $00, $00						//; Sprite 6 X,Y
	.byte $00, $00						//; Sprite 7 X,Y
	.byte $00							//; Sprite X MSB
	.byte SKIP_REGISTER					//; D011
	.byte SKIP_REGISTER					//; D012
	.byte SKIP_REGISTER					//; D013
	.byte SKIP_REGISTER					//; D014
	.byte $00							//; Sprite enable
	.byte $08							//; D016
	.byte $00							//; Sprite Y expand
	.byte D018_VALUE_0					//; Memory setup
	.byte SKIP_REGISTER					//; D019
	.byte SKIP_REGISTER					//; D01A
	.byte $00							//; Sprite priority
	.byte $00							//; Sprite multicolor
	.byte $00							//; Sprite X expand
	.byte $00							//; Sprite-sprite collision
	.byte $00							//; Sprite-background collision
	.byte $00							//; Border color
	.byte $00							//; Background color
	.byte $00, $00						//; Extra colors
	.byte $00, $00, $00					//; Sprite extra colors
	.byte $00, $00, $00, $00			//; Sprite colors 0-3
	.byte $00, $00, $00, $00			//; Sprite colors 4-7
VICConfigEnd:

//; =============================================================================
//; DATA SECTION - Animation State
//; =============================================================================

visualizationUpdateFlag:	.byte $00
frameCounter:				.byte $00
frame256Counter:			.byte $00
currentScreenBuffer:		.byte $00

D018Values:					.byte D018_VALUE_0, D018_VALUE_1

//; =============================================================================
//; DATA SECTION - Height-Based Color Table
//; =============================================================================

heightColorTable:
	.fill 5, $0B
	.fill 5, $09
	.fill 5, $02
	.fill 5, $06
	.fill 5, $08
	.fill 5, $04
	.fill 5, $05
	.fill 5, $0E
	.fill 5, $0A
	.fill 5, $0D
	.fill 32, $01

//; =============================================================================
//; DATA SECTION - Display Mapping
//; =============================================================================

	.fill MAX_BAR_HEIGHT, 224
barCharacterMap:
	.fill 8, 225 + i
	.fill MAX_BAR_HEIGHT, 233

//; =============================================================================
//; INCLUDES
//; =============================================================================

.import source "../INC/Common.asm"
.import source "../INC/StableRasterSetup.asm"
.import source "../INC/Spectrometer.asm"

.align 256
.import source "../INC/FreqTable.asm"

//; =============================================================================
//; CHARSET DATA
//; =============================================================================

* = CHARSET_ADDRESS "Font"
	.fill min($700, file_charsetData.getSize()), file_charsetData.get(i)

* = CHARSET_ADDRESS + (224 * 8) "Bar Chars"
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $00, $00, $00, $00, $00, $00, $00, $7C
	.byte $00, $00, $00, $00, $00, $00, $7C, $BE
	.byte $00, $00, $00, $00, $00, $7C, $BE, $BE
	.byte $00, $00, $00, $00, $7C, $BE, $BE, $BE
	.byte $00, $00, $00, $7C, $BE, $BE, $BE, $BE
	.byte $00, $00, $7C, $BE, $BE, $BE, $BE, $BE
	.byte $00, $7C, $BE, $BE, $BE, $BE, $BE, $BE
	.byte $7C, $BE, $BE, $BE, $BE, $BE, $BE, $BE
	.byte $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE

	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $7C, $00, $00, $00, $00, $00, $00, $00
	.byte $BE, $7C, $00, $00, $00, $00, $00, $00
	.byte $BE, $BE, $7C, $00, $00, $00, $00, $00
	.byte $BE, $BE, $BE, $7C, $00, $00, $00, $00
	.byte $BE, $BE, $BE, $BE, $7C, $00, $00, $00
	.byte $BE, $BE, $BE, $BE, $BE, $7C, $00, $00
	.byte $BE, $BE, $BE, $BE, $BE, $BE, $7C, $00
	.byte $BE, $BE, $BE, $BE, $BE, $BE, $BE, $7C
	.byte $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE

* = SCREEN0_ADDRESS "Screen 0"
	.fill $400, $00

* = SCREEN1_ADDRESS "Screen 1"
	.fill $400, $00

//; =============================================================================
//; END OF FILE
//; =============================================================================