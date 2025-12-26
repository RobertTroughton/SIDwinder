// =============================================================================
//                           RAISTLIN BARS WITH LOGO
//                   Advanced SID Music Spectrum Visualizer
// =============================================================================

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

.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()

//; =============================================================================
//; CONFIGURATION CONSTANTS (needed before data block)
//; =============================================================================

.const NUM_FREQUENCY_BARS				= 40
.const LOGO_HEIGHT						= 11
.const TOP_SPECTRUM_HEIGHT				= 8
.const BOTTOM_SPECTRUM_HEIGHT			= 3

//; =============================================================================
//; DATA BLOCK
//; =============================================================================

* = DATA_ADDRESS "Data Block"
    .fill $60, $00                      // Reserved bytes 0-95 (includes borderColor at $0D, backgroundColor at $0E)
colorEffectMode:
    .byte $00                           // Byte 96 ($60): Color effect mode (0=Height, 1=LineGradient, 2=Solid)
lineGradientColors:
    .fill TOP_SPECTRUM_HEIGHT + BOTTOM_SPECTRUM_HEIGHT, $0b  // Bytes 97-107 ($61-$6B): Line gradient colors
songNameColor:
    .byte $01                           // Song name text color (default: white)
    .fill $100 - $61 - (TOP_SPECTRUM_HEIGHT + BOTTOM_SPECTRUM_HEIGHT) - 1, $00  // Fill rest of reserved space

* = CODE_ADDRESS "Main Code"

    jmp Initialize

.var VIC_BANK						= floor(LOAD_ADDRESS / $4000)
.var VIC_BANK_ADDRESS               = VIC_BANK * $4000

//; =============================================================================
//; EXTERNAL RESOURCES
//; =============================================================================

.var file_charsetData = LoadBinary("CharSet.map")
.var file_waterSpritesData = LoadBinary("WaterSprites.map")

//; =============================================================================
//; CONFIGURATION CONSTANTS (continued)
//; =============================================================================

.const BAR_INCREASE_RATE				= ceil(TOP_SPECTRUM_HEIGHT * 1.3)
.const BAR_DECREASE_RATE				= ceil(TOP_SPECTRUM_HEIGHT * 0.2)

.const SONG_TITLE_LINE					= 23
.const SPECTRUM_START_LINE				= 12
.const REFLECTION_SPRITES_YVAL			= 50 + (SPECTRUM_START_LINE + TOP_SPECTRUM_HEIGHT) * 8 + 3

.eval setSeed(55378008)

//; Memory configuration
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
.const MAIN_BAR_OFFSET					= MAX_BAR_HEIGHT - 7
.const REFLECTION_OFFSET				= WATER_REFLECTION_HEIGHT - 7

//; Color table configuration
.const COLOR_TABLE_SIZE					= MAX_BAR_HEIGHT + 9
.const COLOR_TABLE_ADDRESS				= BITMAP_ADDRESS - $80    //; 128 bytes before bitmap

//; =============================================================================
//; INCLUDES
//; =============================================================================

#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR
#define INCLUDE_MUSIC_ANALYSIS

.import source "../INC/Common.asm"
.import source "../INC/Keyboard.asm"
.import source "../INC/MusicPlayback.asm"
.import source "../INC/StableRasterSetup.asm"
.import source "../INC/Spectrometer.asm"
.import source "../INC/FreqTable.asm"
.import source "../INC/BarStyles.asm"

//; =============================================================================
//; DATA
//; =============================================================================

.align NUM_FREQUENCY_BARS
previousHeightsScreen0:     .fill NUM_FREQUENCY_BARS, 255

.align NUM_FREQUENCY_BARS
previousHeightsScreen1:     .fill NUM_FREQUENCY_BARS, 255

.align NUM_FREQUENCY_BARS
previousColors:             .fill NUM_FREQUENCY_BARS, 255

//; =============================================================================
//; INITIALIZATION
//; =============================================================================

Initialize:
	sei

	jsr VSync

	lda #$00
	sta $d011
	sta $d020

    jsr InitKeyboard

	jsr SetupStableRaster
	jsr SetupSystem
	jsr NMIFix

	jsr InitializeVIC
	//; Bar style character data is now injected at build time by the web app
	jsr DrawScreens
	jsr InitializeColors

	ldy #$00
	lda #$00
!loop:
	sta barHeights - 2, y
	sta smoothedHeights - 2, y
	iny
	cpy #NUM_FREQUENCY_BARS + 4
	bne !loop-

	jsr SetupMusic

	lda BitmapScreenColour
	sta $d021

	jsr VSync

	lda BorderColour
	sta $d020

	lda #<MainIRQ
	sta $fffe
	lda #>MainIRQ
	sta $ffff

	lda #251
	sta $d012

	lda #$01
	sta $d01a
	sta $d019

	cli

MainLoop:
    jsr CheckKeyboard

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

	jsr UpdateBars
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
	//; Check color effect mode - skip dynamic colors for static modes
	lda colorEffectMode
	bne !colorsDone+

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
//; NOTE: Color table (heightToColor) is now injected at build time by the web app
//; =============================================================================

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
	lda songNameColor
	sta $d800 + ((SONG_TITLE_LINE + 0) * 40) + 4, y
	sta $d800 + ((SONG_TITLE_LINE + 1) * 40) + 4, y
	dey
	bpl !loop-

	rts

//; InitializeColors - Set up color RAM for static color effect modes
InitializeColors:
	lda colorEffectMode
	beq !done+					//; Mode 0 (Height) = dynamic, nothing to init

	//; Static modes (Line Gradient or Solid) - initialize color RAM
	ldx #NUM_FREQUENCY_BARS - 1
!barLoop:
	//; Set colors for each line of the spectrum
	.for (var line = 0; line < TOP_SPECTRUM_HEIGHT; line++) {
		lda lineGradientColors + line
		sta $d800 + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), x
	}
	//; Set colors for reflection lines (reversed order)
	.for (var line = 0; line < BOTTOM_SPECTRUM_HEIGHT; line++) {
		lda lineGradientColors + TOP_SPECTRUM_HEIGHT + line
		sta $d800 + ((SPECTRUM_START_LINE + TOP_SPECTRUM_HEIGHT + BOTTOM_SPECTRUM_HEIGHT - 1 - line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), x
	}
	dex
	bpl !barLoop-

!done:
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

D018Values:					.byte D018_VALUE_0, D018_VALUE_1

darkerColorMap:				.byte $00, $0c, $09, $0e, $06, $09, $0b, $08
							.byte $02, $0b, $02, $0b, $0b, $05, $06, $0c

//; =============================================================================
//; Note: Color table data moved to COLOR_TABLE_ADDRESS section
//; =============================================================================

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
//; COLOR TABLE DATA
//; This area is filled at build time by the web app based on colorEffect selection
//; =============================================================================

* = COLOR_TABLE_ADDRESS "Color Table"
heightToColor:				.fill COLOR_TABLE_SIZE, $0b

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
//; This area is filled at build time by the web app based on BarStyle selection
	.fill BAR_STYLE_SIZE_WATER, $00

* = SCREEN0_ADDRESS "Screen 0"
	.fill LOGO_HEIGHT * 40, $00
	.fill $400 - (LOGO_HEIGHT * 40), $20

* = SCREEN1_ADDRESS "Screen 1"
	.fill LOGO_HEIGHT * 40, $00
	.fill $400 - (LOGO_HEIGHT * 40), $20

* = BITMAP_ADDRESS "Bitmap"
	.fill LOGO_HEIGHT * 40 * 8, $00

//; =============================================================================
//; END OF FILE
//; =============================================================================