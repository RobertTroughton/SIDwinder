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
//; RaistlinBars creates a real-time spectrum analyzer that visualizes C64 SID
//; music. It captures the frequency and envelope data from the SID chip and
//; transforms it into animated bars that dance to the music, complete with
//; water reflection effects and dynamic color cycling.
//;
//; KEY FEATURES:
//; - 40 frequency bars with 80-pixel resolution
//; - Real-time SID register analysis without affecting playback
//; - Water reflection effects using hardware sprites
//; - Dynamic color cycling with multiple palettes
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

//; Display layout
.const NUM_FREQUENCY_BARS				= 40

.const LOGO_HEIGHT						= 10
.const TOP_SPECTRUM_HEIGHT				= 9
.const BOTTOM_SPECTRUM_HEIGHT			= 3

.const BAR_INCREASE_RATE				= ceil(TOP_SPECTRUM_HEIGHT * 1.3)
.const BAR_DECREASE_RATE				= ceil(TOP_SPECTRUM_HEIGHT * 0.2)

.const SONG_TITLE_LINE					= 23
.const SPECTRUM_START_LINE				= 11
.const REFLECTION_SPRITES_YVAL			= 50 + (SPECTRUM_START_LINE + TOP_SPECTRUM_HEIGHT) * 8 + 3

.eval setSeed(55378008)

//; Memory configuration
.const VIC_BANK							= 1 //; $C000-$FFFF
.const VIC_BANK_ADDRESS					= VIC_BANK * $4000
.const DD00Value                        = 3 - VIC_BANK
.const DD02Value                        = 60 + VIC_BANK

.const SCREEN0_BANK						= 4	//; $5000-53E7
.const SCREEN1_BANK						= 5	//; $5400-57E7
.const CHARSET_BANK						= 3 //; $5800-5FFF
.const BITMAP_BANK						= 1 //; $6000-7F3F
.const SPRITE_BASE_INDEX				= $38 //; $4E00-4FFF

//; Calculated addresses
.const BITMAP_SCR0_DATA					= VIC_BANK_ADDRESS + (SCREEN0_BANK * $400)
.const BITMAP_SCR1_DATA					= VIC_BANK_ADDRESS + (SCREEN1_BANK * $400)
.const BITMAP_COL_DATA					= BITMAP_SCR1_DATA //; on load, we have the COL data in the SCR1 data
.const CHARSET_ADDRESS					= VIC_BANK_ADDRESS + (CHARSET_BANK * $800)
.const BITMAP_MAP_DATA					= VIC_BANK_ADDRESS + (BITMAP_BANK * $2000)
.const SPRITES_ADDRESS					= VIC_BANK_ADDRESS + (SPRITE_BASE_INDEX * $40)
.const SPRITE_POINTERS_0				= BITMAP_SCR0_DATA + $3F8
.const SPRITE_POINTERS_1				= BITMAP_SCR1_DATA + $3F8

//; VIC register values
.const D018_VALUE_0						= (SCREEN0_BANK * 16) + (CHARSET_BANK * 2)
.const D018_VALUE_1						= (SCREEN1_BANK * 16) + (CHARSET_BANK * 2)
.const D018_VALUE_BITMAP				= (SCREEN0_BANK * 16) + (BITMAP_BANK * 8)

//; Calculated bar values
.const MAX_BAR_HEIGHT					= TOP_SPECTRUM_HEIGHT * 8 - 1
.const WATER_REFLECTION_HEIGHT			= BOTTOM_SPECTRUM_HEIGHT * 8
.const MAIN_BAR_OFFSET					= MAX_BAR_HEIGHT - 8
.const REFLECTION_OFFSET				= WATER_REFLECTION_HEIGHT - 7

//; Color palette configuration
.const NUM_COLOR_PALETTES				= 3
.const COLORS_PER_PALETTE				= 8

//; =============================================================================
//; EXTERNAL RESOURCES
//; =============================================================================

.var file_charsetData = LoadBinary("CharSet.map")
.var file_waterSpritesData = LoadBinary("WaterSprites.map")

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

	//; Initialize color palette
	jsr InitializeColors

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
	lda $d011
	and #$7f
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
	jsr UpdateColors
	jsr UpdateSprites

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

	//; Signal visualization update
	inc visualizationUpdateFlag

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
		ldx sidRegisterMirror + (voice * 7) + 0		//; Frequency low
		txa
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
	//; Update colors first
	ldy #NUM_FREQUENCY_BARS
!colorLoop:
	dey
	bmi !colorsDone+

	ldx smoothedHeights, y
	lda heightToColor, x
	cmp previousColors, y
	beq !colorLoop-
	sta previousColors, y

	//; Update main bars
	.for (var line = 0; line < TOP_SPECTRUM_HEIGHT; line++) {
		sta $d800 + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}

	//; Update reflection with darker color
	tax
	lda darkerColorMap, x
	.for (var line = 0; line < BOTTOM_SPECTRUM_HEIGHT; line++) {
		sta $d800 + ((SPECTRUM_START_LINE + TOP_SPECTRUM_HEIGHT + BOTTOM_SPECTRUM_HEIGHT - 1 - line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
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

	//; Draw main bar
	.for (var line = 0; line < TOP_SPECTRUM_HEIGHT; line++) {
		lda barCharacterMap - MAIN_BAR_OFFSET + (line * 8), x
		sta BITMAP_SCR0_DATA + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}

	//; Draw reflection
	txa
	lsr
	tax
	.for (var line = 0; line < BOTTOM_SPECTRUM_HEIGHT; line++) {
		lda barCharacterMap - REFLECTION_OFFSET + (line * 8), x
		clc
		adc #10
		sta BITMAP_SCR0_DATA + ((SPECTRUM_START_LINE + TOP_SPECTRUM_HEIGHT + BOTTOM_SPECTRUM_HEIGHT - 1 - line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
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

	//; Draw main bar
	.for (var line = 0; line < TOP_SPECTRUM_HEIGHT; line++) {
		lda barCharacterMap - MAIN_BAR_OFFSET + (line * 8), x
		sta BITMAP_SCR1_DATA + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}

	//; Draw reflection
	txa
	lsr
	tax
	.for (var line = 0; line < BOTTOM_SPECTRUM_HEIGHT; line++) {
		lda barCharacterMap - REFLECTION_OFFSET + (line * 8), x
		clc
		adc #20
		sta BITMAP_SCR1_DATA + ((SPECTRUM_START_LINE + TOP_SPECTRUM_HEIGHT + BOTTOM_SPECTRUM_HEIGHT - 1 - line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}
	jmp !loop-
}

//; =============================================================================
//; COLOR MANAGEMENT
//; =============================================================================

UpdateColors: {
	//; Update color cycling on 256-frame boundaries
	lda frameCounter
	bne !done+

	inc frame256Counter
	lda #$00
	sta colorUpdateIndex

	//; Cycle to next palette
	ldx currentPalette
	inx
	cpx #NUM_COLOR_PALETTES
	bne !setPalette+
	ldx #$00
!setPalette:
	stx currentPalette

	//; Update palette pointers
	lda colorPalettesLo, x
	sta !readColor+ + 1
	lda colorPalettesHi, x
	sta !readColor+ + 2

!done:
	//; Gradual color update
	ldx colorUpdateIndex
	bmi !exit+

	lda #$0b							//; Default color
	ldy heightToColorIndex, x
	bmi !useDefault+
!readColor:
	lda colorPalettes, y
!useDefault:
	sta heightToColor, x

	inc colorUpdateIndex
	lda colorUpdateIndex
	cmp #MAX_BAR_HEIGHT + 5
	bne !exit+
	lda #$ff
	sta colorUpdateIndex
!exit:
	rts
}

//; =============================================================================
//; SPRITE ANIMATION
//; =============================================================================

UpdateSprites: {
	ldx spriteAnimationIndex

	//; Update X positions from sine table
	lda spriteSineTable, x
	.for (var i = 0; i < 8; i++) {
		sta $d000 + (i * 2)
		.if (i != 7) {
			clc
			adc #$30					//; 48 pixels between sprites
		}
	}
	ldy #$c0
	lda $d000 + (5 * 2)
	bmi !skip+
	ldy #$e0
!skip:
	sty $d010

	//; Update sprite pointers
	lda frameCounter
	lsr
	lsr
	and #$07
	ora #SPRITE_BASE_INDEX
	.for (var i = 0; i < 8; i++) {
		sta SPRITE_POINTERS_0 + i
		sta SPRITE_POINTERS_1 + i
	}

	clc
	lda spriteAnimationIndex
	adc #$01
	and #$7f
	sta spriteAnimationIndex

	rts
}

//; =============================================================================
//; UTILITY FUNCTIONS
//; =============================================================================

DrawScreens: {

	ldy #00
!loop:
	lda BITMAP_COL_DATA + (0 * 200), y
	sta $d800 + (0 * 200), y
	lda BITMAP_COL_DATA + (1 * 200), y
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
	sta BITMAP_SCR0_DATA + (SONG_TITLE_LINE * 40) + 4, y
	sta BITMAP_SCR1_DATA + (SONG_TITLE_LINE * 40) + 4, y
	ora #$80
	sta BITMAP_SCR0_DATA + ((SONG_TITLE_LINE + 1) * 40) + 4, y
	sta BITMAP_SCR1_DATA + ((SONG_TITLE_LINE + 1) * 40) + 4, y
	lda #$01
	sta $d800 + ((SONG_TITLE_LINE + 0) * 40) + 4, y
	sta $d800 + ((SONG_TITLE_LINE + 1) * 40) + 4, y
	dey
	bpl !loop-

	rts
}

InitializeColors: {
	//; Initialize bar colors
	ldx #0
!loop:
	lda #$0b							//; Default cyan
	ldy heightToColorIndex, x
	bmi !useDefault+
	lda colorPalettes, y
!useDefault:
	sta heightToColor, x
	inx
	cpx #MAX_BAR_HEIGHT + 5
	bne !loop-
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
	.byte $00, REFLECTION_SPRITES_YVAL	//; Sprite 0 X,Y
	.byte $00, REFLECTION_SPRITES_YVAL	//; Sprite 1 X,Y
	.byte $00, REFLECTION_SPRITES_YVAL	//; Sprite 2 X,Y
	.byte $00, REFLECTION_SPRITES_YVAL	//; Sprite 3 X,Y
	.byte $00, REFLECTION_SPRITES_YVAL	//; Sprite 4 X,Y
	.byte $00, REFLECTION_SPRITES_YVAL	//; Sprite 5 X,Y
	.byte $00, REFLECTION_SPRITES_YVAL	//; Sprite 6 X,Y
	.byte $00, REFLECTION_SPRITES_YVAL	//; Sprite 7 X,Y
	.byte $00							//; Sprite X MSB
	.byte SKIP_REGISTER					//; D011
	.byte SKIP_REGISTER					//; D012
	.byte SKIP_REGISTER					//; D013
	.byte SKIP_REGISTER					//; D014
	.byte $ff							//; Sprite enable
	.byte $18							//; D016
	.byte $00							//; Sprite Y expand
	.byte D018_VALUE_BITMAP				//; Memory setup
	.byte SKIP_REGISTER					//; D019
	.byte SKIP_REGISTER					//; D01A
	.byte $00							//; Sprite priority
	.byte $00							//; Sprite multicolor
	.byte $ff							//; Sprite X expand
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
spriteAnimationIndex:		.byte $00
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

//; Color tables
darkerColorMap:				.byte $00, $0c, $09, $0e, $06, $09, $0b, $08
							.byte $02, $0b, $02, $0b, $0b, $05, $06, $0c

//; =============================================================================
//; DATA SECTION - Color Palettes
//; =============================================================================

colorPalettes:
	.byte $09, $04, $05, $05, $0d, $0d, $0f, $01		//; Purple/pink
	.byte $09, $06, $0e, $0e, $03, $03, $0f, $01		//; Blue/cyan
	.byte $09, $02, $0a, $0a, $07, $07, $0f, $01		//; Red/orange

colorPalettesLo:			.fill NUM_COLOR_PALETTES, <(colorPalettes + i * COLORS_PER_PALETTE)
colorPalettesHi:			.fill NUM_COLOR_PALETTES, >(colorPalettes + i * COLORS_PER_PALETTE)

heightToColorIndex:			.byte $ff
							.fill MAX_BAR_HEIGHT + 4, max(0, min(floor(((i * COLORS_PER_PALETTE) + (random() * (MAX_BAR_HEIGHT * 0.8) - (MAX_BAR_HEIGHT * 0.4))) / MAX_BAR_HEIGHT), COLORS_PER_PALETTE - 1))

heightToColor:				.fill MAX_BAR_HEIGHT + 5, $0b

//; =============================================================================
//; DATA SECTION - Display Mapping
//; =============================================================================

	.fill MAX_BAR_HEIGHT, 224
barCharacterMap:
	.fill 8, 225 + i
	.fill MAX_BAR_HEIGHT, 233

//; =============================================================================
//; DATA SECTION - Animation Data
//; =============================================================================

spriteSineTable:			.fill 128, 11.5 + 11.5*sin(toRadians(i*360/128))

//; =============================================================================
//; INCLUDES
//; =============================================================================

.import source "../INC/NMIFix.asm"
.import source "../INC/StableRasterSetup.asm"

.import source "../INC/FreqTable.asm"

.align 128
div16:						.fill 128, i / 16.0
div16mul3:					.fill 128, ((3.0 * i) / 16.0)

//; =============================================================================
//; SPRITE DATA
//; =============================================================================

* = SPRITES_ADDRESS "Water Sprites"
	.fill file_waterSpritesData.getSize(), file_waterSpritesData.get(i)

//; =============================================================================
//; CHARSET DATA
//; =============================================================================

* = CHARSET_ADDRESS "Font"
	.fill min($700, file_charsetData.getSize()), file_charsetData.get(i)

* = CHARSET_ADDRESS + (224 * 8) "Bar Chars"
//; First, the chars for the main bar
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $00, $00, $00, $00, $00, $00, $00, $7C
	.byte $00, $00, $00, $00, $00, $00, $7C, $BE
	.byte $00, $00, $00, $00, $00, $7C, $BE, $BE
	.byte $00, $00, $00, $00, $7C, $14, $BE, $BE
	.byte $00, $00, $00, $7C, $BE, $14, $BE, $BE
	.byte $00, $00, $7C, $BE, $BE, $14, $BE, $BE
	.byte $00, $7C, $BE, $BE, $BE, $14, $BE, $BE
	.byte $7C, $14, $BE, $BE, $BE, $14, $BE, $BE
	.byte $BE, $14, $BE, $BE, $BE, $14, $BE, $BE

//; reflection chars - frame 1 is &55 (for flicker)
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $54, $00, $00, $00, $00, $00, $00, $00
	.byte $aa, $54, $00, $00, $00, $00, $00, $00
	.byte $54, $aa, $54, $00, $00, $00, $00, $00
	.byte $aa, $54, $aa, $54, $00, $00, $00, $00
	.byte $54, $aa, $54, $aa, $54, $00, $00, $00
	.byte $aa, $54, $aa, $54, $aa, $54, $00, $00
	.byte $54, $aa, $54, $aa, $54, $aa, $54, $00
	.byte $aa, $54, $aa, $54, $aa, $54, $aa, $54
	.byte $54, $aa, $54, $aa, $54, $aa, $54, $aa

//; reflection chars - frame 2 is &AA (for flicker)
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $aa, $00, $00, $00, $00, $00, $00, $00
	.byte $54, $aa, $00, $00, $00, $00, $00, $00
	.byte $aa, $54, $aa, $00, $00, $00, $00, $00
	.byte $54, $aa, $54, $aa, $00, $00, $00, $00
	.byte $aa, $54, $aa, $54, $aa, $00, $00, $00
	.byte $54, $aa, $54, $aa, $54, $aa, $00, $00
	.byte $aa, $54, $aa, $54, $aa, $54, $54, $00
	.byte $54, $aa, $54, $aa, $54, $aa, $54, $aa
	.byte $aa, $54, $aa, $54, $aa, $54, $aa, $54

* = BITMAP_SCR0_DATA "Screen 0"
	.fill LOGO_HEIGHT * 40, $00
	.fill $400 - (LOGO_HEIGHT * 40), $20

* = BITMAP_SCR1_DATA "Screen 1"
	.fill LOGO_HEIGHT * 40, $00
	.fill $400 - (LOGO_HEIGHT * 40), $20

* = BITMAP_MAP_DATA "Bitmap"
	.fill $2000, $00

//; =============================================================================
//; END OF FILE
//; =============================================================================