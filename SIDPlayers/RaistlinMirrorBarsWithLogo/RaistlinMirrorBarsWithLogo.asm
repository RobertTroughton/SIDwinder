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
//; RaistlinMirrorBarsWithLogo creates a real-time spectrum analyzer that visualizes C64 
//; SID music with a mirrored effect. It captures frequency and envelope data 
//; from the SID chip and transforms it into animated bars that dance to the 
//; music, with bars reflected vertically for a symmetrical display. Plus, in includes a
//; logo at the top of the screen.
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

.const LOGO_HEIGHT						= 10

.const TOP_SPECTRUM_HEIGHT				= 6
.const TOTAL_SPECTRUM_HEIGHT			= TOP_SPECTRUM_HEIGHT * 2

.const BAR_INCREASE_RATE				= (TOP_SPECTRUM_HEIGHT * 1.5)
.const BAR_DECREASE_RATE				= (TOP_SPECTRUM_HEIGHT * 0.3)

.const SONG_TITLE_LINE					= 23
.const SPECTRUM_START_LINE				= 11

.eval setSeed(55378008)

//; Memory configuration
.const VIC_BANK							= 1 //; $4000-$7FFF
.const VIC_BANK_ADDRESS					= VIC_BANK * $4000
.const SCREEN0_BANK						= 4 //; $5000-$53FF
.const SCREEN1_BANK						= 5 //; $5400-$57FF
.const CHARSET_BANK						= 3 //; $5800-$5FFF
.const BITMAP_BANK						= 1 //; $6000-$7F3F

//; Calculated addresses
.const SCREEN0_ADDRESS					= VIC_BANK_ADDRESS + (SCREEN0_BANK * $400)
.const SCREEN1_ADDRESS					= VIC_BANK_ADDRESS + (SCREEN1_BANK * $400)
.const CHARSET_ADDRESS					= VIC_BANK_ADDRESS + (CHARSET_BANK * $800)
.const BITMAP_ADDRESS					= VIC_BANK_ADDRESS + (BITMAP_BANK * $2000)

//; VIC register values
.const D018_VALUE_0						= (SCREEN0_BANK * 16) + (CHARSET_BANK * 2)
.const D018_VALUE_1						= (SCREEN1_BANK * 16) + (CHARSET_BANK * 2)
.const D018_VALUE_BITMAP				= (SCREEN0_BANK * 16) + (BITMAP_BANK * 8)

//; Calculated bar values
.const MAX_BAR_HEIGHT					= TOP_SPECTRUM_HEIGHT * 8 - 1
.const MAIN_BAR_OFFSET					= MAX_BAR_HEIGHT - 8

//; =============================================================================
//; EXTERNAL RESOURCES
//; =============================================================================

.var file_charsetData = LoadBinary("CharSet.map")

//; =============================================================================
//; INITIALIZATION
//; =============================================================================

Initialize: {
	sei

	//; Wait for stable raster before setup
	bit $d011
	bpl *-3
	bit $d011
	bmi *-3

	//; Turn off display during initialization
	lda #$00
	sta $d011
	sta $d020

	//; System setup
	jsr SetupStableRaster
	jsr SetupSystem
	jsr NMIFix

	//; Initialize display
	jsr InitializeVIC
	jsr DrawScreens

	ldy #$00
	lda #$00
!loop:
	sta barHeights - 2, y
	sta smoothedHeights - 2, y
	iny
	cpy #NUM_FREQUENCY_BARS + 4
	bne !loop-

	//; Wait for stable raster before enabling display
	bit $d011
	bpl *-3
	bit $d011
	bmi *-3

	//; Setup interrupts
	jsr SetupInterrupts

	//; Initialize music
	jsr SetupMusic

	bit $d011
	bpl *-3
	bit $d011
	bmi *-3

	lda BorderColour
	sta $d020

	lda BitmapScreenColour
	sta $d021

	cli

	//; Main loop - wait for visualization updates
MainLoop:
	lda visualizationUpdateFlag
	beq MainLoop

	jsr ApplySmoothing
	jsr RenderBars

	lda #$00
	sta visualizationUpdateFlag

	//; Toggle double buffer
	lda currentScreenBuffer
	eor #$01
	sta currentScreenBuffer

	jmp MainLoop
}

//; =============================================================================
//; SYSTEM SETUP
//; =============================================================================

SetupSystem: {
	lda #$35
	sta $01

	//; Set VIC bank
	lda #(63 - VIC_BANK)
	sta $dd00
	lda #VIC_BANK
	sta $dd02

	rts
}

//; =============================================================================
//; VIC INITIALIZATION
//; =============================================================================

.const SKIP_REGISTER = $e1

InitializeVIC: {
	//; Apply VIC register configuration
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
}

//; =============================================================================
//; INTERRUPT SETUP
//; =============================================================================

SetupInterrupts: {
	//; Set IRQ vectors
	lda #<MainIRQ
	sta $fffe
	lda #>MainIRQ
	sta $ffff

	//; Setup raster interrupt
	lda #251
	sta $d012
	lda #$7b
	sta $d011

	//; Enable raster interrupts
	lda #$01
	sta $d01a
	sta $d019

	rts
}

//; =============================================================================
//; MAIN INTERRUPT HANDLER
//; =============================================================================

MainIRQ: {
	pha
	txa
	pha
	tya
	pha

	lda #D018_VALUE_BITMAP
	sta $d018
	lda #$18
	sta $d016
	lda #$3b
	sta $d011
	lda BitmapScreenColour
    sta $d021

	ldy currentScreenBuffer
	lda D018Values, y
	sta SpectrometerD018 + 1

	//; Signal visualization update
	inc visualizationUpdateFlag

	//; Play music and analyze
	jsr PlayMusicWithAnalysis

	//; Update bar animations
	jsr UpdateBarDecay

	//; Frame counter
	inc frameCounter
	bne !skip+
	inc frame256Counter
!skip:

	lda #50 + (LOGO_HEIGHT * 8)
	sta $d012
	lda #$3b
	sta $d011
	
	lda #<SpectrometerDisplayIRQ
	sta $fffe
	lda #>SpectrometerDisplayIRQ
	sta $ffff

	//; Acknowledge interrupt
	lda #$01
	sta $d01a
	sta $d019

	pla
	tay
	pla
	tax
	pla
	rti
}

SpectrometerDisplayIRQ:
	pha
	txa
	pha
	tya
	pha

	ldx #4
!loop:
	dex
	bpl !loop-
	nop

	lda #$1b
	sta $d011
	lda #$00
	sta $d021
SpectrometerD018:
	lda #$00
	sta $d018
	lda #$08
	sta $d016

	lda #251
	sta $d012

	lda #<MainIRQ
	sta $fffe
	lda #>MainIRQ
	sta $ffff

	//; Acknowledge interrupt
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
//; MUSIC PLAYBACK WITH ANALYSIS
//; =============================================================================

PlayMusicWithAnalysis: {

	//; First playback - normal music playing with state preservation
	jsr BackupSIDMemory
	jsr SIDPlay
	jsr RestoreSIDMemory

	//; Second playback - capture SID registers
	lda $01
	pha
	lda #$30
	sta $01
	jsr SIDPlay

	ldy #24
!loop:
	lda $d400, y
	sta sidRegisterMirror, y
	dey
	bpl !loop-

	pla
	sta $01

	//; Analyze captured registers
	jmp AnalyzeSIDRegisters
}

//; =============================================================================
//; SID REGISTER ANALYSIS
//; =============================================================================

AnalyzeSIDRegisters: {
	//; Process each voice
	.for (var voice = 0; voice < 3; voice++) {
		//; Check if voice is active
		lda sidRegisterMirror + (voice * 7) + 4		//; Control register
		bmi !skipVoice+									//; Skip if noise
		and #$01										//; Check gate
		beq !skipVoice+

		//; Get frequency and map to bar position
		ldy sidRegisterMirror + (voice * 7) + 1		//; Frequency high
		cpy #4
		bcc !lowFreq+

		//; High frequency lookup
		ldx frequencyToBarHi, y
		jmp !gotBar+

	!lowFreq:
		//; Low frequency lookup
		lda sidRegisterMirror + (voice * 7) + 0		//; Frequency low
		lsr
		lsr
		ora multiply64Table, y
		tay
		ldx frequencyToBarLo, y

	!gotBar:
		//; Process envelope
		lda sidRegisterMirror + (voice * 7) + 6		//; SR register
		pha

		//; Set release rate for this voice
		and #$0f
		tay
		lda releaseRateHi, y
		sta voiceReleaseHi + voice
		lda releaseRateLo, y
		sta voiceReleaseLo + voice

		//; Check sustain level
		pla
		lsr
		lsr
		lsr
		lsr
		tay
		lda sustainToHeight, y
		sta targetBarHeights, x
		lda #voice
		sta barVoiceMap, x

	!skipVoice:
	}
	rts
}

//; =============================================================================
//; BAR ANIMATION
//; =============================================================================

UpdateBarDecay: {
	//; Apply decay and interpolation to each bar
	ldx #NUM_FREQUENCY_BARS - 1
!loop:
	//; Check if we have a new target
	lda targetBarHeights, x
	beq !justDecay+
	
	//; We have a target - interpolate towards it
	cmp barHeights, x
	beq !clearTarget+			//; Already at target
	bcc !moveDown+				//; Target is lower
	
	//; Target is higher - move up quickly
	lda barHeights, x
	clc
	adc #BAR_INCREASE_RATE
	cmp targetBarHeights, x
	bcc !storeHeight+
	lda targetBarHeights, x		//; Don't overshoot
	jmp !storeHeight+
	
!moveDown:
	//; Target is lower - move down slowly
	lda barHeights, x
	sec
	sbc #BAR_DECREASE_RATE
	cmp targetBarHeights, x
	bcs !storeHeight+
	lda targetBarHeights, x		//; Don't undershoot
	
!storeHeight:
	sta barHeights, x
	lda #$00
	sta barHeightsLo, x
	
!clearTarget:
	//; Clear target once reached
	lda #$00
	sta targetBarHeights, x
	jmp !next+
	
!justDecay:
	//; No target - apply normal decay
	ldy barVoiceMap, x

	//; 16-bit subtraction for smooth decay
	sec
	lda barHeightsLo, x
	sbc voiceReleaseLo, y
	sta barHeightsLo, x
	lda barHeights, x
	sbc voiceReleaseHi, y
	bpl !positive+

	//; Clamp to zero
	lda #$00
	sta barHeightsLo, x
!positive:
	sta barHeights, x

!next:
	dex
	bpl !loop-
	rts
}

//; =============================================================================
//; SMOOTHING ALGORITHM
//; =============================================================================

ApplySmoothing: {
	//; Apply gaussian-like smoothing for natural movement
	ldx #0
!loop:
	lda barHeights, x
	lsr
	ldy barHeights - 2, x
	adc div16, y
	ldy barHeights - 1, x
	adc div16mul3, y
	ldy barHeights + 1, x
	adc div16mul3, y
	ldy barHeights + 2, x
	adc div16, y
	sta smoothedHeights, x

	inx
	cpx #NUM_FREQUENCY_BARS
	bne !loop-
	rts
}

//; =============================================================================
//; RENDERING
//; =============================================================================

RenderBars: {
	//; Update colors based on height only
	ldy #NUM_FREQUENCY_BARS
!colorLoop:
	dey
	bmi !colorsDone+

	//; Get bar height
	ldx smoothedHeights, y
	
	//; Get color from table
	lda heightColorTable, x
	
	cmp previousColors, y
	beq !colorLoop-
	sta previousColors, y

	//; Update main bars - both halves
	.for (var line = 0; line < TOTAL_SPECTRUM_HEIGHT; line++) {
		sta $d800 + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}
	jmp !colorLoop-

!colorsDone:

	//; Render to appropriate screen buffer
	lda currentScreenBuffer
	beq !renderScreen1+

	//; Render to screen 0
	jmp RenderToScreen0

!renderScreen1:
	//; Render to screen 1
	jmp RenderToScreen1
}

//; Screen-specific rendering routines
RenderToScreen0: {
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

	//; Draw both halves of the bar
	.for (var line = 0; line < TOP_SPECTRUM_HEIGHT; line++) {
		lda barCharacterMap - MAIN_BAR_OFFSET + (line * 8), x
		sta SCREEN0_ADDRESS + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
		adc #10
		sta SCREEN0_ADDRESS + ((SPECTRUM_START_LINE + (TOTAL_SPECTRUM_HEIGHT - 1) - line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}
	jmp !loop-
}

RenderToScreen1: {
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

	//; Draw both halves of the bar
	.for (var line = 0; line < TOP_SPECTRUM_HEIGHT; line++) {
		lda barCharacterMap - MAIN_BAR_OFFSET + (line * 8), x
		sta SCREEN1_ADDRESS + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
		adc #10
		sta SCREEN1_ADDRESS + ((SPECTRUM_START_LINE + (TOP_SPECTRUM_HEIGHT * 2 - 1) - line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}
	jmp !loop-
}

//; =============================================================================
//; UTILITY FUNCTIONS
//; =============================================================================

DrawScreens: {

	ldy #00
!loop:
	lda SCREEN1_ADDRESS + (0 * 200), y
	sta $d800 + (0 * 200), y
	lda SCREEN1_ADDRESS + (1 * 200), y
	sta $d800 + (1 * 200), y
	lda #$00
	sta $d800 + (2 * 200), y
	sta $d800 + (3 * 200), y
	sta $d800 + (4 * 200), y
	iny
	cpy #200
	bne !loop-

//; add the song title to screen 0
	ldy #31
!loop:
	//; Song Title
	lda SongName, y
	sta SCREEN0_ADDRESS + (SONG_TITLE_LINE * 40) + 4, y
	sta SCREEN1_ADDRESS + (SONG_TITLE_LINE * 40) + 4, y
	ora #$80
	sta SCREEN0_ADDRESS + ((SONG_TITLE_LINE + 1) * 40) + 4, y
	sta SCREEN1_ADDRESS + ((SONG_TITLE_LINE + 1) * 40) + 4, y
	lda #$01
	sta $d800 + ((SONG_TITLE_LINE + 0) * 40) + 4, y
	sta $d800 + ((SONG_TITLE_LINE + 1) * 40) + 4, y
	dey
	bpl !loop-

	rts
}

SetupMusic: {
	//; Clear SID
	ldy #24
	lda #$00
!loop:
	sta $d400, y
	dey
	bpl !loop-

	//; Initialize player
	lda SongNumber
	tax
	tay
	jmp SIDInit
}

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
	.byte $18							//; D016
	.byte $00							//; Sprite Y expand
	.byte D018_VALUE_BITMAP				//; Memory setup
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
colorUpdateIndex:			.byte $00
currentPalette:				.byte $00

D018Values:					.byte D018_VALUE_0, D018_VALUE_1

//; =============================================================================
//; DATA SECTION - Bar State
//; =============================================================================

barHeightsLo:				.fill NUM_FREQUENCY_BARS, 0
barVoiceMap:				.fill NUM_FREQUENCY_BARS, 0
targetBarHeights:			.fill NUM_FREQUENCY_BARS, 0

previousHeightsScreen0:		.fill NUM_FREQUENCY_BARS, 255
previousHeightsScreen1:		.fill NUM_FREQUENCY_BARS, 255
previousColors:				.fill NUM_FREQUENCY_BARS, 255

.byte $00, $00
barHeights:					.fill NUM_FREQUENCY_BARS, 0
.byte $00, $00

smoothedHeights:			.fill NUM_FREQUENCY_BARS, 0

//; =============================================================================
//; DATA SECTION - Voice State
//; =============================================================================

voiceReleaseHi:				.fill 3, 0
voiceReleaseLo:				.fill 3, 0
sidRegisterMirror:			.fill 32, 0

//; =============================================================================
//; DATA SECTION - Calculations
//; =============================================================================

multiply64Table:			.fill 4, i * 64

//; =============================================================================
//; DATA SECTION - Height-Based Color Table
//; =============================================================================

//; Color table based on bar height with flickering transitions
//; MAX_BAR_HEIGHT = 71 (TOP_SPECTRUM_HEIGHT * 8 - 1 = 9 * 8 - 1)
//; We'll use groups of 4 entries for each height range
heightColorTable:
	.fill 3, $0B
	.fill 3, $09
	.fill 3, $02
	.fill 3, $06
	.fill 3, $08
	.fill 3, $04
	.fill 3, $05
	.fill 3, $0E
	.fill 3, $0A
	.fill 3, $0D
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

.import source "../INC/NMIFix.asm"
.import source "../INC/StableRasterSetup.asm"

.align 256
.import source "../INC/FreqTable.asm"

.align 128
div16:						.fill 128, i / 16.0
div16mul3:					.fill 128, ((3.0 * i) / 16.0)

//; =============================================================================
//; CHARSET AND BITMAP DATA
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
	.fill LOGO_HEIGHT * 40, $00
	.fill $400 - (LOGO_HEIGHT * 40), $20

* = SCREEN1_ADDRESS "Screen 1"
	.fill LOGO_HEIGHT * 40, $00
	.fill $400 - (LOGO_HEIGHT * 40), $20

* = BITMAP_ADDRESS "Bitmap"
	.fill $2000, $00

//; =============================================================================
//; END OF FILE
//; =============================================================================