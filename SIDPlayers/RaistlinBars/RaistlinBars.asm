// =============================================================================
//                               RAISTLIN BARS
//                   Advanced SID Music Spectrum Visualizer
// =============================================================================

//; Memory Map

//; On Load
//; VICBANK + $3800-$3FFF : CharSet

//; Real-time
//; VICBANK + $3000-$33FF : Screen 0
//; VICBANK + $3400-$37FF : Screen 1
//; VICBANK + $3800-$3FFF : CharSet

.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()

* = DATA_ADDRESS "Data Block"
BarStyle:       .byte $00       // Bar style index (0-4) - set by PRG builder
    .fill $FF, $00

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
//; CONFIGURATION CONSTANTS
//; =============================================================================

.const NUM_FREQUENCY_BARS				= 40

.const TOP_SPECTRUM_HEIGHT				= 14
.const BOTTOM_SPECTRUM_HEIGHT			= 3

.const BAR_INCREASE_RATE				= ceil(TOP_SPECTRUM_HEIGHT * 1.3)
.const BAR_DECREASE_RATE				= ceil(TOP_SPECTRUM_HEIGHT * 0.2)

.const SONG_TITLE_LINE					= 0
.const ARTIST_NAME_LINE					= 23
.const SPECTRUM_START_LINE				= 5
.const REFLECTION_SPRITES_YVAL			= 50 + (SPECTRUM_START_LINE + TOP_SPECTRUM_HEIGHT) * 8 + 3

.eval setSeed(55378008)

.const SCREEN0_BANK						= 12 //; $7000-$73FF
.const SCREEN1_BANK						= 13 //; $7400-$77FF
.const CHARSET_BANK						= 7 //; $7800-$7FFF
.const SPRITE_BASE_INDEX				= $b8 //; $6E00-6FFF for water sprites

.const SCREEN0_ADDRESS					= VIC_BANK_ADDRESS + (SCREEN0_BANK * $400)
.const SCREEN1_ADDRESS					= VIC_BANK_ADDRESS + (SCREEN1_BANK * $400)
.const CHARSET_ADDRESS					= VIC_BANK_ADDRESS + (CHARSET_BANK * $800)
.const SPRITES_ADDRESS					= VIC_BANK_ADDRESS + (SPRITE_BASE_INDEX * $40)
.const SPRITE_POINTERS_0				= SCREEN0_ADDRESS + $3F8
.const SPRITE_POINTERS_1				= SCREEN1_ADDRESS + $3F8

.const D018_VALUE_0						= (SCREEN0_BANK * 16) + (CHARSET_BANK * 2)
.const D018_VALUE_1						= (SCREEN1_BANK * 16) + (CHARSET_BANK * 2)

.const MAX_BAR_HEIGHT					= TOP_SPECTRUM_HEIGHT * 8 - 1
.const WATER_REFLECTION_HEIGHT			= BOTTOM_SPECTRUM_HEIGHT * 8
.const MAIN_BAR_OFFSET					= MAX_BAR_HEIGHT - 7
.const REFLECTION_OFFSET				= WATER_REFLECTION_HEIGHT - 7

.const NUM_COLOR_PALETTES				= 3
.const COLORS_PER_PALETTE				= 8

//; =============================================================================
//; INCLUDES
//; =============================================================================

#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR
#define INCLUDE_MUSIC_ANALYSIS

#define INCLUDE_RASTER_TIMING_CODE
.var DEFAULT_RASTERTIMING_Y = 232

.import source "../INC/Common.asm"
.import source "../INC/Keyboard.asm"
.import source "../INC/MusicPlayback.asm"
.import source "../INC/StableRasterSetup.asm"
.import source "../INC/Spectrometer.asm"
.import source "../INC/FreqTable.asm"

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
	jsr CopyBarStyle
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

	lda #$00
	sta NextIRQLdx + 1
	tax
	jsr set_d011_and_d012

	lda #<MainIRQ
	sta $fffe
	lda #>MainIRQ
	sta $ffff

	lda #$01
	sta $d01a
	sta $d019

	jsr VSync

	lda #$1b
	sta $d011

	cli

MainLoop:
    jsr CheckKeyboard

	lda visualizationUpdateFlag
	beq MainLoop

	jsr ApplySmoothing
	jsr RenderBars

	lda currentScreenBuffer
	eor #$01
	sta currentScreenBuffer

	lda #$00
	sta visualizationUpdateFlag

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
//; CODE SEGMENT
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
//; MAIN INTERRUPT HANDLER
//; =============================================================================

MainIRQ:
	pha
	txa
	pha
	tya
	pha
	lda $01
	pha
	lda #$35
	sta $01

	ldy currentScreenBuffer
	lda D018Values, y
	sta $d018

	lda FastForwardActive
	beq !normalPlay+
	
!ffFrameLoop:
	lda NumCallsPerFrame
	sta FFCallCounter
	
!ffCallLoop:
	jsr SIDPlay
	inc $d020
	dec FFCallCounter
	bne !ffCallLoop-
	
	jsr CheckSpaceKey
	lda FastForwardActive
	bne !ffFrameLoop-
	
	lda #$00
	sta NextIRQLdx + 1
	sta $d020
    tax
    jsr set_d011_and_d012
	jmp !done+

!normalPlay:
	inc visualizationUpdateFlag

	inc frameCounter
	bne !skip+
	inc frame256Counter
!skip:

	jsr JustPlayMusic
	jsr UpdateColors
	jsr AnalyseMusic
	jsr UpdateBars
	jsr UpdateSprites

!done:
	jsr NextIRQ

	pla
	sta $01
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
	lda $01
	pha
	lda #$35
	sta $01

	jsr JustPlayMusic

	jsr NextIRQ

    pla
    sta $01
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

NextIRQLdx:
	ldx #$00
	inx
	cpx NumCallsPerFrame
	bne !notLast+
	ldx #$00
!notLast:
	stx NextIRQLdx + 1

	jsr set_d011_and_d012

	lda #$01
	sta $d019

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
		sta $d800 + ((SPECTRUM_START_LINE + TOP_SPECTRUM_HEIGHT + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
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
	lsr
	tax
	clc
	.for (var line = 0; line < BOTTOM_SPECTRUM_HEIGHT; line++) {
		lda barCharacterMap - REFLECTION_OFFSET + (line * 8), x
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
	lsr
	tax
	clc
	.for (var line = 0; line < BOTTOM_SPECTRUM_HEIGHT; line++) {
		lda barCharacterMap - REFLECTION_OFFSET + (line * 8), x
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

ClearScreens:
	ldx #$00
	lda #$20
!loop:
	sta SCREEN0_ADDRESS + $000, x
	sta SCREEN0_ADDRESS + $100, x
	sta SCREEN0_ADDRESS + $200, x
	sta SCREEN0_ADDRESS + $300, x
	sta SCREEN1_ADDRESS + $000, x
	sta SCREEN1_ADDRESS + $100, x
	sta SCREEN1_ADDRESS + $200, x
	sta SCREEN1_ADDRESS + $300, x
	sta $d800 + $000, x
	sta $d800 + $100, x
	sta $d800 + $200, x
	sta $d800 + $300, x
	inx
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
//; BAR STYLE COPY ROUTINE
//; =============================================================================

.const NUM_BAR_STYLES = 5
.const BAR_STYLE_SIZE = 240		// 30 chars * 8 bytes each

CopyBarStyle:
	// Calculate source address based on BarStyle index
	lda BarStyle
	cmp #NUM_BAR_STYLES
	bcc !validStyle+
	lda #$00					// Default to style 0 if invalid
!validStyle:

	// Multiply by BAR_STYLE_SIZE (240 = $F0)
	// A * 240 = A * 256 - A * 16 = A << 8 - A << 4
	tax
	lda BarStylesLo, x
	sta !copyLoop+ + 1
	lda BarStylesHi, x
	sta !copyLoop+ + 2

	// Copy 240 bytes to charset
	ldx #$00
!copyLoop:
	lda BarStyleData, x			// Source (modified above)
	sta CHARSET_ADDRESS + (224 * 8), x
	inx
	cpx #BAR_STYLE_SIZE
	bne !copyLoop-

	rts

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
	.byte $08							//; D016
	.byte $00							//; Sprite Y expand
	.byte D018_VALUE_0					//; Memory setup
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
							.fill MAX_BAR_HEIGHT + 4, max(0, min(COLORS_PER_PALETTE - 1, floor((i * COLORS_PER_PALETTE) / MAX_BAR_HEIGHT)))

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
//; This area is filled at runtime by CopyBarStyle based on BarStyle selection
	.fill BAR_STYLE_SIZE, $00

//; =============================================================================
//; BAR STYLE DATA - 5 styles, each 240 bytes (30 chars)
//; Each style: 10 main bar chars + 10 reflection frame1 + 10 reflection frame2
//; =============================================================================

BarStylesLo:	.fill NUM_BAR_STYLES, <(BarStyleData + (i * BAR_STYLE_SIZE))
BarStylesHi:	.fill NUM_BAR_STYLES, >(BarStyleData + (i * BAR_STYLE_SIZE))

BarStyleData:

//; =========== STYLE 0: CLASSIC (rounded with highlights) ===========
BarStyle0:
//; Main bar chars (10 chars)
	.byte $00, $00, $00, $00, $00, $00, $00, $00		//; Empty
	.byte $00, $00, $00, $00, $00, $00, $00, $7C		//; 1/8
	.byte $00, $00, $00, $00, $00, $00, $7C, $BE		//; 2/8
	.byte $00, $00, $00, $00, $00, $7C, $BE, $BE		//; 3/8
	.byte $00, $00, $00, $00, $7C, $14, $BE, $BE		//; 4/8
	.byte $00, $00, $00, $7C, $BE, $14, $BE, $BE		//; 5/8
	.byte $00, $00, $7C, $BE, $BE, $14, $BE, $BE		//; 6/8
	.byte $00, $7C, $BE, $BE, $BE, $14, $BE, $BE		//; 7/8
	.byte $7C, $14, $BE, $BE, $BE, $14, $BE, $BE		//; 8/8
	.byte $BE, $14, $BE, $BE, $BE, $14, $BE, $BE		//; Full
//; Reflection frame 1 (&55 flicker)
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
//; Reflection frame 2 (&AA flicker)
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $aa, $00, $00, $00, $00, $00, $00, $00
	.byte $54, $aa, $00, $00, $00, $00, $00, $00
	.byte $aa, $54, $aa, $00, $00, $00, $00, $00
	.byte $54, $aa, $54, $aa, $00, $00, $00, $00
	.byte $aa, $54, $aa, $54, $aa, $00, $00, $00
	.byte $54, $aa, $54, $aa, $54, $aa, $00, $00
	.byte $aa, $54, $aa, $54, $aa, $54, $aa, $00
	.byte $54, $aa, $54, $aa, $54, $aa, $54, $aa
	.byte $aa, $54, $aa, $54, $aa, $54, $aa, $54

//; =========== STYLE 1: SOLID (full solid bars) ===========
BarStyle1:
//; Main bar chars (10 chars) - solid $7E fill
	.byte $00, $00, $00, $00, $00, $00, $00, $00		//; Empty
	.byte $00, $00, $00, $00, $00, $00, $00, $7E		//; 1/8
	.byte $00, $00, $00, $00, $00, $00, $7E, $7E		//; 2/8
	.byte $00, $00, $00, $00, $00, $7E, $7E, $7E		//; 3/8
	.byte $00, $00, $00, $00, $7E, $7E, $7E, $7E		//; 4/8
	.byte $00, $00, $00, $7E, $7E, $7E, $7E, $7E		//; 5/8
	.byte $00, $00, $7E, $7E, $7E, $7E, $7E, $7E		//; 6/8
	.byte $00, $7E, $7E, $7E, $7E, $7E, $7E, $7E		//; 7/8
	.byte $7E, $7E, $7E, $7E, $7E, $7E, $7E, $7E		//; 8/8
	.byte $7E, $7E, $7E, $7E, $7E, $7E, $7E, $7E		//; Full
//; Reflection frame 1 (&55 mask on $7E = $54)
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $54, $00, $00, $00, $00, $00, $00, $00
	.byte $2A, $54, $00, $00, $00, $00, $00, $00
	.byte $54, $2A, $54, $00, $00, $00, $00, $00
	.byte $2A, $54, $2A, $54, $00, $00, $00, $00
	.byte $54, $2A, $54, $2A, $54, $00, $00, $00
	.byte $2A, $54, $2A, $54, $2A, $54, $00, $00
	.byte $54, $2A, $54, $2A, $54, $2A, $54, $00
	.byte $2A, $54, $2A, $54, $2A, $54, $2A, $54
	.byte $54, $2A, $54, $2A, $54, $2A, $54, $2A
//; Reflection frame 2 (&AA mask on $7E = $2A)
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $2A, $00, $00, $00, $00, $00, $00, $00
	.byte $54, $2A, $00, $00, $00, $00, $00, $00
	.byte $2A, $54, $2A, $00, $00, $00, $00, $00
	.byte $54, $2A, $54, $2A, $00, $00, $00, $00
	.byte $2A, $54, $2A, $54, $2A, $00, $00, $00
	.byte $54, $2A, $54, $2A, $54, $2A, $00, $00
	.byte $2A, $54, $2A, $54, $2A, $54, $2A, $00
	.byte $54, $2A, $54, $2A, $54, $2A, $54, $2A
	.byte $2A, $54, $2A, $54, $2A, $54, $2A, $54

//; =========== STYLE 2: THIN (narrow 4-pixel bars) ===========
BarStyle2:
//; Main bar chars (10 chars) - thin $3C fill
	.byte $00, $00, $00, $00, $00, $00, $00, $00		//; Empty
	.byte $00, $00, $00, $00, $00, $00, $00, $3C		//; 1/8
	.byte $00, $00, $00, $00, $00, $00, $3C, $3C		//; 2/8
	.byte $00, $00, $00, $00, $00, $3C, $3C, $3C		//; 3/8
	.byte $00, $00, $00, $00, $3C, $3C, $3C, $3C		//; 4/8
	.byte $00, $00, $00, $3C, $3C, $3C, $3C, $3C		//; 5/8
	.byte $00, $00, $3C, $3C, $3C, $3C, $3C, $3C		//; 6/8
	.byte $00, $3C, $3C, $3C, $3C, $3C, $3C, $3C		//; 7/8
	.byte $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C		//; 8/8
	.byte $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C		//; Full
//; Reflection frame 1 (&55 mask on $3C = $14)
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $14, $00, $00, $00, $00, $00, $00, $00
	.byte $28, $14, $00, $00, $00, $00, $00, $00
	.byte $14, $28, $14, $00, $00, $00, $00, $00
	.byte $28, $14, $28, $14, $00, $00, $00, $00
	.byte $14, $28, $14, $28, $14, $00, $00, $00
	.byte $28, $14, $28, $14, $28, $14, $00, $00
	.byte $14, $28, $14, $28, $14, $28, $14, $00
	.byte $28, $14, $28, $14, $28, $14, $28, $14
	.byte $14, $28, $14, $28, $14, $28, $14, $28
//; Reflection frame 2 (&AA mask on $3C = $28)
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $28, $00, $00, $00, $00, $00, $00, $00
	.byte $14, $28, $00, $00, $00, $00, $00, $00
	.byte $28, $14, $28, $00, $00, $00, $00, $00
	.byte $14, $28, $14, $28, $00, $00, $00, $00
	.byte $28, $14, $28, $14, $28, $00, $00, $00
	.byte $14, $28, $14, $28, $14, $28, $00, $00
	.byte $28, $14, $28, $14, $28, $14, $28, $00
	.byte $14, $28, $14, $28, $14, $28, $14, $28
	.byte $28, $14, $28, $14, $28, $14, $28, $14

//; =========== STYLE 3: OUTLINE (hollow bars) ===========
BarStyle3:
//; Main bar chars (10 chars) - outline only
	.byte $00, $00, $00, $00, $00, $00, $00, $00		//; Empty
	.byte $00, $00, $00, $00, $00, $00, $00, $7E		//; 1/8
	.byte $00, $00, $00, $00, $00, $00, $7E, $42		//; 2/8
	.byte $00, $00, $00, $00, $00, $7E, $42, $42		//; 3/8
	.byte $00, $00, $00, $00, $7E, $42, $42, $42		//; 4/8
	.byte $00, $00, $00, $7E, $42, $42, $42, $42		//; 5/8
	.byte $00, $00, $7E, $42, $42, $42, $42, $42		//; 6/8
	.byte $00, $7E, $42, $42, $42, $42, $42, $42		//; 7/8
	.byte $7E, $42, $42, $42, $42, $42, $42, $42		//; 8/8
	.byte $42, $42, $42, $42, $42, $42, $42, $42		//; Full (just sides)
//; Reflection frame 1 (&55 mask)
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $54, $00, $00, $00, $00, $00, $00, $00
	.byte $2A, $40, $00, $00, $00, $00, $00, $00
	.byte $54, $02, $40, $00, $00, $00, $00, $00
	.byte $2A, $40, $02, $40, $00, $00, $00, $00
	.byte $54, $02, $40, $02, $40, $00, $00, $00
	.byte $2A, $40, $02, $40, $02, $40, $00, $00
	.byte $54, $02, $40, $02, $40, $02, $40, $00
	.byte $2A, $40, $02, $40, $02, $40, $02, $40
	.byte $40, $02, $40, $02, $40, $02, $40, $02
//; Reflection frame 2 (&AA mask)
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $2A, $00, $00, $00, $00, $00, $00, $00
	.byte $54, $02, $00, $00, $00, $00, $00, $00
	.byte $2A, $40, $02, $00, $00, $00, $00, $00
	.byte $54, $02, $40, $02, $00, $00, $00, $00
	.byte $2A, $40, $02, $40, $02, $00, $00, $00
	.byte $54, $02, $40, $02, $40, $02, $00, $00
	.byte $2A, $40, $02, $40, $02, $40, $02, $00
	.byte $54, $02, $40, $02, $40, $02, $40, $02
	.byte $02, $40, $02, $40, $02, $40, $02, $40

//; =========== STYLE 4: CHUNKY (blocky pixel bars) ===========
BarStyle4:
//; Main bar chars (10 chars) - chunky 2x2 pixel blocks
	.byte $00, $00, $00, $00, $00, $00, $00, $00		//; Empty
	.byte $00, $00, $00, $00, $00, $00, $66, $66		//; 1/8
	.byte $00, $00, $00, $00, $00, $00, $66, $66		//; 2/8
	.byte $00, $00, $00, $00, $66, $66, $66, $66		//; 3/8
	.byte $00, $00, $00, $00, $66, $66, $66, $66		//; 4/8
	.byte $00, $00, $66, $66, $66, $66, $66, $66		//; 5/8
	.byte $00, $00, $66, $66, $66, $66, $66, $66		//; 6/8
	.byte $66, $66, $66, $66, $66, $66, $66, $66		//; 7/8
	.byte $66, $66, $66, $66, $66, $66, $66, $66		//; 8/8
	.byte $66, $66, $66, $66, $66, $66, $66, $66		//; Full
//; Reflection frame 1 (&55 mask on $66 = $44)
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $44, $44, $00, $00, $00, $00, $00, $00
	.byte $22, $22, $44, $44, $00, $00, $00, $00
	.byte $44, $44, $22, $22, $00, $00, $00, $00
	.byte $22, $22, $44, $44, $22, $22, $00, $00
	.byte $44, $44, $22, $22, $44, $44, $00, $00
	.byte $22, $22, $44, $44, $22, $22, $44, $44
	.byte $44, $44, $22, $22, $44, $44, $22, $22
	.byte $22, $22, $44, $44, $22, $22, $44, $44
	.byte $44, $44, $22, $22, $44, $44, $22, $22
//; Reflection frame 2 (&AA mask on $66 = $22)
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $22, $22, $00, $00, $00, $00, $00, $00
	.byte $44, $44, $22, $22, $00, $00, $00, $00
	.byte $22, $22, $44, $44, $00, $00, $00, $00
	.byte $44, $44, $22, $22, $44, $44, $00, $00
	.byte $22, $22, $44, $44, $22, $22, $00, $00
	.byte $44, $44, $22, $22, $44, $44, $22, $22
	.byte $22, $22, $44, $44, $22, $22, $44, $44
	.byte $44, $44, $22, $22, $44, $44, $22, $22
	.byte $22, $22, $44, $44, $22, $22, $44, $44

* = SCREEN0_ADDRESS "Screen 0"
	.fill $400, $00

* = SCREEN1_ADDRESS "Screen 1"
	.fill $400, $00

//; =============================================================================
//; END OF FILE
//; =============================================================================