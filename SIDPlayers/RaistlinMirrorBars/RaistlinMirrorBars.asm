// =============================================================================
//                            RAISTLIN MIRROR BARS
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
    .fill $100, $00                     // Reserved for system (includes BarStyle at $70)

* = CODE_ADDRESS "Main Code"

    jmp Initialize

.var VIC_BANK						= floor(LOAD_ADDRESS / $4000)
.var VIC_BANK_ADDRESS               = VIC_BANK * $4000

//; =============================================================================
//; EXTERNAL RESOURCES
//; =============================================================================

.var file_charsetData = LoadBinary("CharSet.map")

//; =============================================================================
//; CONFIGURATION CONSTANTS
//; =============================================================================

.const NUM_FREQUENCY_BARS				= 40

.const TOP_SPECTRUM_HEIGHT				= 9
.const TOTAL_SPECTRUM_HEIGHT			= TOP_SPECTRUM_HEIGHT * 2

.const BAR_INCREASE_RATE				= (TOP_SPECTRUM_HEIGHT * 0.6)
.const BAR_DECREASE_RATE				= (TOP_SPECTRUM_HEIGHT * 0.2)

.const SONG_TITLE_LINE					= 0
.const ARTIST_NAME_LINE					= 23
.const SPECTRUM_START_LINE				= 3

.eval setSeed(55378008)

.const SCREEN0_BANK						= 12
.const SCREEN1_BANK						= 13
.const CHARSET_BANK						= 7

.const SCREEN0_ADDRESS					= VIC_BANK_ADDRESS + (SCREEN0_BANK * $400)
.const SCREEN1_ADDRESS					= VIC_BANK_ADDRESS + (SCREEN1_BANK * $400)
.const CHARSET_ADDRESS					= VIC_BANK_ADDRESS + (CHARSET_BANK * $800)

.const D018_VALUE_0						= (SCREEN0_BANK * 16) + (CHARSET_BANK * 2)
.const D018_VALUE_1						= (SCREEN1_BANK * 16) + (CHARSET_BANK * 2)

.const MAX_BAR_HEIGHT					= TOP_SPECTRUM_HEIGHT * 8 - 1
.const MAIN_BAR_OFFSET					= MAX_BAR_HEIGHT - 7

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

	lda #$00
	sta visualizationUpdateFlag

	jsr ApplySmoothing

	jsr RenderBars

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
	jsr AnalyseMusic
	jsr UpdateBars

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

	lda FastForwardActive
	bne !done+
	
	jsr JustPlayMusic

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
	ldy #NUM_FREQUENCY_BARS - 1
!colorLoop:
	ldx smoothedHeights, y
	lda heightColorTable, x
	cmp previousColors, y
	beq !skip+

	sta previousColors, y
	.for (var line = 0; line < TOTAL_SPECTRUM_HEIGHT; line++) {
		sta $d800 + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}
!skip:

	dey
	bpl !colorLoop-

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
	.fill 2, $0B
	.fill 12, $09
	.fill 12, $06
	.fill 12, $04
	.fill 11, $0E
	.fill 11, $0D
	.fill 12, $07

//; =============================================================================
//; DATA SECTION - Display Mapping
//; =============================================================================

	.fill MAX_BAR_HEIGHT, 224
barCharacterMap:
	.fill 8, 225 + i
	.fill MAX_BAR_HEIGHT, 233

//; =============================================================================
//; CHARSET DATA
//; =============================================================================

* = CHARSET_ADDRESS "Font"
	.fill min($700, file_charsetData.getSize()), file_charsetData.get(i)

* = CHARSET_ADDRESS + (224 * 8) "Bar Chars"
//; This area is filled at build time by the web app based on BarStyle selection
	.fill BAR_STYLE_SIZE_MIRROR, $00

* = SCREEN0_ADDRESS "Screen 0"
	.fill $400, $00

* = SCREEN1_ADDRESS "Screen 1"
	.fill $400, $00

//; =============================================================================
//; END OF FILE
//; =============================================================================