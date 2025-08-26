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

//; Memory Map

//; On Load
//; VICBANK + $2000-$2C7F : Logo Bitmap (10 * $140)
//; VICBANK + $3000-$318F : Logo Screen Data
//; VICBANK + $3400-$358F : Logo Colour Data

//; Real-time
//; VICBANK + $2000-$2C7F : Logo Bitmap (10 * $140)
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
.const VIC_BANK							= (BASE_ADDRESS / $4000)
.const VIC_BANK_ADDRESS					= VIC_BANK * $4000
.const DD00Value                        = 3 - VIC_BANK
.const DD02Value                        = 60 + VIC_BANK

.const SCREEN0_BANK						= 12	//; $7000-$73FF
.const SCREEN1_BANK						= 13	//; $7400-$77FF
.const CHARSET_BANK						= 7		//; $7800-$7FFF
.const BITMAP_BANK						= 1		//; $6000-$6C7F
.const SPRITE_BASE_INDEX				= $B8	//; $6E00-$6FFF

//; Calculated addresses
.const BITMAP_ADDRESS					= VIC_BANK_ADDRESS + (BITMAP_BANK * $2000)
.const SCREEN0_ADDRESS					= VIC_BANK_ADDRESS + (SCREEN0_BANK * $400)
.const SCREEN1_ADDRESS					= VIC_BANK_ADDRESS + (SCREEN1_BANK * $400)
.const BITMAP_COL_DATA					= SCREEN1_ADDRESS //; on load, we have the COL data in the SCR1 data
.const CHARSET_ADDRESS					= VIC_BANK_ADDRESS + (CHARSET_BANK * $800)

.const SPRITES_ADDRESS					= VIC_BANK_ADDRESS + (SPRITE_BASE_INDEX * $40)
.const SPRITE_POINTERS_0				= SCREEN0_ADDRESS + $3F8
.const SPRITE_POINTERS_1				= SCREEN1_ADDRESS + $3F8

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
	jsr DrawScreens

	ldy #$00
	lda #$00
!loop:
	sta barHeights - 2, y
	sta smoothedHeights - 2, y
	iny
	cpy #NUM_FREQUENCY_BARS + 4
	bne !loop-

	jsr SetupInterrupts

	jsr SetupMusic

	lda BitmapScreenColour
	sta $d021

	jsr VSync

	lda BorderColour
	sta $d020

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

	jsr InitializeColors

	rts

//; =============================================================================
//; INTERRUPT SETUP
//; =============================================================================

SetupInterrupts:
	lda #<MainIRQ
	sta $fffe
	lda #>MainIRQ
	sta $ffff

	lda #251
	sta $d012
	lda $d011
	and #$7f
	sta $d011

	lda #$01
	sta $d01a
	sta $d019

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

	inc visualizationUpdateFlag

	jsr PlayMusicWithAnalysis

	jsr UpdateBarDecay
	jsr UpdateColors
	jsr UpdateSprites

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

	lda #$01
	sta $d01a
	sta $d019

	pla
	tay
	pla
	tax
	pla
	rti

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

	inc visualizationUpdateFlag

	lda #251
	sta $d012

	lda #<MainIRQ
	sta $fffe
	lda #>MainIRQ
	sta $ffff

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
//; RENDERING
//; =============================================================================

RenderBars:
	ldy #NUM_FREQUENCY_BARS
!colorLoop:
	dey
	bmi !colorsDone+

	ldx smoothedHeights, y
	lda heightToColor, x
	cmp previousColors, y
	beq !colorLoop-
	sta previousColors, y

	.for (var line = 0; line < TOP_SPECTRUM_HEIGHT; line++) {
		sta $d800 + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}

	tax
	lda darkerColorMap, x
	.for (var line = 0; line < BOTTOM_SPECTRUM_HEIGHT; line++) {
		sta $d800 + ((SPECTRUM_START_LINE + TOP_SPECTRUM_HEIGHT + BOTTOM_SPECTRUM_HEIGHT - 1 - line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
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

	.for (var line = 0; line < TOP_SPECTRUM_HEIGHT; line++) {
		lda barCharacterMap - MAIN_BAR_OFFSET + (line * 8), x
		sta SCREEN0_ADDRESS + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}

	txa
	lsr
	tax
	.for (var line = 0; line < BOTTOM_SPECTRUM_HEIGHT; line++) {
		lda barCharacterMap - REFLECTION_OFFSET + (line * 8), x
		clc
		adc #10
		sta SCREEN0_ADDRESS + ((SPECTRUM_START_LINE + TOP_SPECTRUM_HEIGHT + BOTTOM_SPECTRUM_HEIGHT - 1 - line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
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

	.for (var line = 0; line < TOP_SPECTRUM_HEIGHT; line++) {
		lda barCharacterMap - MAIN_BAR_OFFSET + (line * 8), x
		sta SCREEN1_ADDRESS + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}

	txa
	lsr
	tax
	.for (var line = 0; line < BOTTOM_SPECTRUM_HEIGHT; line++) {
		lda barCharacterMap - REFLECTION_OFFSET + (line * 8), x
		clc
		adc #20
		sta SCREEN1_ADDRESS + ((SPECTRUM_START_LINE + TOP_SPECTRUM_HEIGHT + BOTTOM_SPECTRUM_HEIGHT - 1 - line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}
	jmp !loop-

//; =============================================================================
//; COLOR MANAGEMENT
//; =============================================================================

UpdateColors:
	lda frameCounter
	bne !done+

	inc frame256Counter
	lda #$00
	sta colorUpdateIndex

	ldx currentPalette
	inx
	cpx #NUM_COLOR_PALETTES
	bne !setPalette+
	ldx #$00
!setPalette:
	stx currentPalette

	lda colorPalettesLo, x
	sta !readColor+ + 1
	lda colorPalettesHi, x
	sta !readColor+ + 2

!done:
	ldx colorUpdateIndex
	bmi !exit+

	lda #$0b
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

//; =============================================================================
//; SPRITE ANIMATION
//; =============================================================================

UpdateSprites:
	ldx spriteAnimationIndex

	lda spriteSineTable, x
	.for (var i = 0; i < 8; i++) {
		sta $d000 + (i * 2)
		.if (i != 7) {
			clc
			adc #$30
		}
	}
	ldy #$c0
	lda $d000 + (5 * 2)
	bmi !skip+
	ldy #$e0
!skip:
	sty $d010

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

//; =============================================================================
//; UTILITY FUNCTIONS
//; =============================================================================

DrawScreens:

	ldy #00
!loop:
	.for (var i = 0; i < 4; i++)
	{
		lda BITMAP_COL_DATA + (i * 256), y
		sta $d800 + (i * 256), y
	}
	iny
	bne !loop-

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
	dey
	bpl !loop-

	rts

InitializeColors:
	ldx #0
!loop:
	lda #$0b
	ldy heightToColorIndex, x
	bmi !useDefault+
	lda colorPalettes, y
!useDefault:
	sta heightToColor, x
	inx
	cpx #MAX_BAR_HEIGHT + 5
	bne !loop-
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

.import source "../INC/Common.asm"
.import source "../INC/StableRasterSetup.asm"
.import source "../INC/Spectrometer.asm"

.align 256
.import source "../INC/FreqTable.asm"

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

* = SCREEN0_ADDRESS "Screen 0"
	.fill LOGO_HEIGHT * 40, $00
	.fill $400 - (LOGO_HEIGHT * 40), $20

* = SCREEN1_ADDRESS "Screen 1"
	.fill LOGO_HEIGHT * 40, $00
	.fill $400 - (LOGO_HEIGHT * 40), $20

* = BITMAP_ADDRESS "Bitmap"
	.fill $C80, $00

//; =============================================================================
//; END OF FILE
//; =============================================================================