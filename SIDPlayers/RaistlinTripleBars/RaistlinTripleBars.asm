// =============================================================================
//                              RAISTLIN TRIPLE BARS
//             Per-Channel SID Music Spectrum Visualizer (3 stacked)
//
//   Three independent spectrum strips, one per SID channel, stacked vertically.
//   Voice index modulo 3 selects the channel (so multi-SID songs collapse to
//   the same three channel lanes).
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

//; =============================================================================
//; CONFIGURATION CONSTANTS (needed before data block)
//; =============================================================================

.const NUM_FREQUENCY_BARS               = 40
.const NUM_CHANNELS                     = 3
.const TOP_SPECTRUM_HEIGHT              = 6
.const TOTAL_SPECTRUM_HEIGHT            = TOP_SPECTRUM_HEIGHT * NUM_CHANNELS

//; =============================================================================
//; DATA BLOCK
//; =============================================================================

* = DATA_ADDRESS "Data Block"
    .fill $0D, $00                      // Reserved bytes 0-12
borderColor:
    .byte $00                           // Byte 13 ($0D)
backgroundColor:
    .byte $00                           // Byte 14 ($0E)
    .fill $60 - $0F, $00                // Reserved bytes 15-95
colorEffectMode:
    .byte $00                           // Byte 96 ($60): 0=Height, 1=LineGradient, 2=Solid
lineGradientColors:
    .fill TOTAL_SPECTRUM_HEIGHT, $0b    // 18 bytes: $61-$72
songNameColor:
    .byte $01                           // $73
artistNameColor:
    .byte $0f                           // $74
    .fill $100 - $75, $00               // Fill rest of reserved space

* = CODE_ADDRESS "Main Code"

    jmp Initialize

.var VIC_BANK                       = floor(LOAD_ADDRESS / $4000)
.var VIC_BANK_ADDRESS               = VIC_BANK * $4000

//; =============================================================================
//; EXTERNAL RESOURCES
//; =============================================================================

.var file_charsetData = LoadBinary("CharSet.map")

//; =============================================================================
//; CONFIGURATION CONSTANTS (continued)
//; =============================================================================

.const BAR_INCREASE_RATE                = ceil(TOP_SPECTRUM_HEIGHT * 1.3)
.const BAR_DECREASE_RATE                = ceil(TOP_SPECTRUM_HEIGHT * 0.6)

.const SONG_TITLE_LINE                  = 0
.const ARTIST_NAME_LINE                 = 4
.const SPECTRUM_START_LINE              = 7

.const CH0_TOP_LINE                     = SPECTRUM_START_LINE
.const CH1_TOP_LINE                     = SPECTRUM_START_LINE + TOP_SPECTRUM_HEIGHT
.const CH2_TOP_LINE                     = SPECTRUM_START_LINE + (TOP_SPECTRUM_HEIGHT * 2)

.eval setSeed(55378008)

.const SCREEN0_BANK                     = 12 //; $7000-$73FF
.const SCREEN1_BANK                     = 13 //; $7400-$77FF
.const CHARSET_BANK                     = 7 //; $7800-$7FFF

.const SCREEN0_ADDRESS                  = VIC_BANK_ADDRESS + (SCREEN0_BANK * $400)
.const SCREEN1_ADDRESS                  = VIC_BANK_ADDRESS + (SCREEN1_BANK * $400)
.const CHARSET_ADDRESS                  = VIC_BANK_ADDRESS + (CHARSET_BANK * $800)
.const COLOR_TABLE_ADDRESS              = VIC_BANK_ADDRESS + $2D80

.const D018_VALUE_0                     = (SCREEN0_BANK * 16) + (CHARSET_BANK * 2)
.const D018_VALUE_1                     = (SCREEN1_BANK * 16) + (CHARSET_BANK * 2)

.const MAX_BAR_HEIGHT                   = TOP_SPECTRUM_HEIGHT * 8 - 1
.const MAIN_BAR_OFFSET                  = MAX_BAR_HEIGHT - 7

.const COLOR_TABLE_SIZE                 = MAX_BAR_HEIGHT + 9

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
.import source "../INC/Spectrometer3Channel.asm"
.import source "../INC/FreqTable.asm"
.import source "../INC/BarStyles.asm"
.import source "../INC/LinkedWithEffect.asm"

//; =============================================================================
//; PER-SCREEN, PER-CHANNEL TRACKING
//; =============================================================================

.align NUM_FREQUENCY_BARS
previousHeightsScreen0Ch0:  .fill NUM_FREQUENCY_BARS, 255
.align NUM_FREQUENCY_BARS
previousHeightsScreen0Ch1:  .fill NUM_FREQUENCY_BARS, 255
.align NUM_FREQUENCY_BARS
previousHeightsScreen0Ch2:  .fill NUM_FREQUENCY_BARS, 255

.align NUM_FREQUENCY_BARS
previousHeightsScreen1Ch0:  .fill NUM_FREQUENCY_BARS, 255
.align NUM_FREQUENCY_BARS
previousHeightsScreen1Ch1:  .fill NUM_FREQUENCY_BARS, 255
.align NUM_FREQUENCY_BARS
previousHeightsScreen1Ch2:  .fill NUM_FREQUENCY_BARS, 255

.align NUM_FREQUENCY_BARS
previousColorsCh0:          .fill NUM_FREQUENCY_BARS, 255
.align NUM_FREQUENCY_BARS
previousColorsCh1:          .fill NUM_FREQUENCY_BARS, 255
.align NUM_FREQUENCY_BARS
previousColorsCh2:          .fill NUM_FREQUENCY_BARS, 255

//; =============================================================================
//; INITIALIZATION
//; =============================================================================

Initialize:
    sei

    lda #$35
    sta $01

    jsr RunLinkedWithEffect

    jsr InitKeyboard

    jsr SetupStableRaster
    lda #(63 - VIC_BANK)
    sta $dd00
    lda #VIC_BANK
    sta $dd02
    jsr NMIFix

    jsr InitializeVIC
    jsr ClearScreens
    jsr InitializeColors
    jsr DisplaySongInfo
    jsr init_D011_D012_values

    jsr ClearBarState

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

ClearBarState:
    ldy #$00
    lda #$00
!loop:
    sta barHeightsCh0 - 2, y
    sta barHeightsCh1 - 2, y
    sta barHeightsCh2 - 2, y
    sta smoothedHeightsCh0, y
    sta smoothedHeightsCh1, y
    sta smoothedHeightsCh2, y
    iny
    cpy #NUM_FREQUENCY_BARS + 4
    bne !loop-
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

    lda borderColor
    sta $d020
    lda backgroundColor
    sta $d021

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

//; Update color RAM for one channel (Dynamic Pulse mode only).
.macro UpdateColorsForChannel(smoothedH, prevC, channelTopLine) {
    ldy #NUM_FREQUENCY_BARS
!colorLoop:
    dey
    bmi !done+

    ldx smoothedH, y
    lda heightToColor, x
    cmp prevC, y
    beq !colorLoop-
    sta prevC, y

    .for (var line = 0; line < TOP_SPECTRUM_HEIGHT; line++) {
        sta $d800 + ((channelTopLine + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
    }
    jmp !colorLoop-
!done:
}

//; Render bars to a screen for one channel.
.macro RenderChannelToScreen(SCREEN_ADDR, smoothedH, prevH, channelTopLine) {
    ldy #NUM_FREQUENCY_BARS
!loop:
    dey
    bpl !continue+
    rts
!continue:

    lda smoothedH, y
    cmp prevH, y
    beq !loop-
    sta prevH, y
    tax

    .for (var line = 0; line < TOP_SPECTRUM_HEIGHT; line++) {
        lda barCharacterMap - MAIN_BAR_OFFSET + (line * 8), x
        sta SCREEN_ADDR + ((channelTopLine + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
    }
    jmp !loop-
}

RenderBars:
    //; Dynamic-pulse colours: only run when colorEffectMode == 0
    lda colorEffectMode
    bne !colorsDone+
    jsr UpdateColorsCh0
    jsr UpdateColorsCh1
    jsr UpdateColorsCh2
!colorsDone:

    lda currentScreenBuffer
    bne !screen1+

    jsr RenderToScreen0Ch0
    jsr RenderToScreen0Ch1
    jmp RenderToScreen0Ch2

!screen1:
    jsr RenderToScreen1Ch0
    jsr RenderToScreen1Ch1
    jmp RenderToScreen1Ch2

UpdateColorsCh0:
    UpdateColorsForChannel(smoothedHeightsCh0, previousColorsCh0, CH0_TOP_LINE)
    rts
UpdateColorsCh1:
    UpdateColorsForChannel(smoothedHeightsCh1, previousColorsCh1, CH1_TOP_LINE)
    rts
UpdateColorsCh2:
    UpdateColorsForChannel(smoothedHeightsCh2, previousColorsCh2, CH2_TOP_LINE)
    rts

RenderToScreen0Ch0:
    RenderChannelToScreen(SCREEN0_ADDRESS, smoothedHeightsCh0, previousHeightsScreen0Ch0, CH0_TOP_LINE)
RenderToScreen0Ch1:
    RenderChannelToScreen(SCREEN0_ADDRESS, smoothedHeightsCh1, previousHeightsScreen0Ch1, CH1_TOP_LINE)
RenderToScreen0Ch2:
    RenderChannelToScreen(SCREEN0_ADDRESS, smoothedHeightsCh2, previousHeightsScreen0Ch2, CH2_TOP_LINE)

RenderToScreen1Ch0:
    RenderChannelToScreen(SCREEN1_ADDRESS, smoothedHeightsCh0, previousHeightsScreen1Ch0, CH0_TOP_LINE)
RenderToScreen1Ch1:
    RenderChannelToScreen(SCREEN1_ADDRESS, smoothedHeightsCh1, previousHeightsScreen1Ch1, CH1_TOP_LINE)
RenderToScreen1Ch2:
    RenderChannelToScreen(SCREEN1_ADDRESS, smoothedHeightsCh2, previousHeightsScreen1Ch2, CH2_TOP_LINE)

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
    lda songNameColor
    sta $d800 + ((SONG_TITLE_LINE + 0) * 40) + 4, y
    sta $d800 + ((SONG_TITLE_LINE + 1) * 40) + 4, y

    lda ArtistName, y
    sta SCREEN0_ADDRESS + (ARTIST_NAME_LINE * 40) + 4, y
    sta SCREEN1_ADDRESS + (ARTIST_NAME_LINE * 40) + 4, y
    ora #$80
    sta SCREEN0_ADDRESS + ((ARTIST_NAME_LINE + 1) * 40) + 4, y
    sta SCREEN1_ADDRESS + ((ARTIST_NAME_LINE + 1) * 40) + 4, y
    lda artistNameColor
    sta $d800 + ((ARTIST_NAME_LINE + 0) * 40) + 4, y
    sta $d800 + ((ARTIST_NAME_LINE + 1) * 40) + 4, y

    dey
    bpl !loop-

    rts

//; InitializeColors - Set up color RAM for static color effect modes
InitializeColors:
    lda colorEffectMode
    beq !done+                  //; Mode 0 (Height) = dynamic, nothing to init

    //; Static modes: write per-line colours covering all 3 channel stacks.
    ldx #NUM_FREQUENCY_BARS - 1
!barLoop:
    .for (var line = 0; line < TOTAL_SPECTRUM_HEIGHT; line++) {
        lda lineGradientColors + line
        sta $d800 + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), x
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
    .byte $00, $00                      //; Sprite 0 X,Y
    .byte $00, $00                      //; Sprite 1 X,Y
    .byte $00, $00                      //; Sprite 2 X,Y
    .byte $00, $00                      //; Sprite 3 X,Y
    .byte $00, $00                      //; Sprite 4 X,Y
    .byte $00, $00                      //; Sprite 5 X,Y
    .byte $00, $00                      //; Sprite 6 X,Y
    .byte $00, $00                      //; Sprite 7 X,Y
    .byte $00                           //; Sprite X MSB
    .byte SKIP_REGISTER                 //; D011
    .byte SKIP_REGISTER                 //; D012
    .byte SKIP_REGISTER                 //; D013
    .byte SKIP_REGISTER                 //; D014
    .byte $00                           //; Sprite enable
    .byte $08                           //; D016
    .byte $00                           //; Sprite Y expand
    .byte D018_VALUE_0                  //; Memory setup
    .byte SKIP_REGISTER                 //; D019
    .byte SKIP_REGISTER                 //; D01A
    .byte $00                           //; Sprite priority
    .byte $00                           //; Sprite multicolor
    .byte $00                           //; Sprite X expand
    .byte $00                           //; Sprite-sprite collision
    .byte $00                           //; Sprite-background collision
    .byte SKIP_REGISTER                 //; Border color - loaded from data block
    .byte SKIP_REGISTER                 //; Background color - loaded from data block
    .byte $00, $00                      //; Extra colors
    .byte $00, $00, $00                 //; Sprite extra colors
    .byte $00, $00, $00, $00            //; Sprite colors 0-3
    .byte $00, $00, $00, $00            //; Sprite colors 4-7
VICConfigEnd:

//; =============================================================================
//; DATA SECTION - Animation State
//; =============================================================================

visualizationUpdateFlag:    .byte $00
frameCounter:               .byte $00
frame256Counter:            .byte $00
currentScreenBuffer:        .byte $00

D018Values:                 .byte D018_VALUE_0, D018_VALUE_1

//; =============================================================================
//; DATA SECTION - Display Mapping
//; =============================================================================

    .fill MAX_BAR_HEIGHT, 224
barCharacterMap:
    .fill 8, 225 + i
    .fill MAX_BAR_HEIGHT, 233

//; =============================================================================
//; COLOR TABLE DATA
//; Filled at build time by the web app based on colorEffect selection
//; =============================================================================

* = COLOR_TABLE_ADDRESS "Color Table"
heightToColor:              .fill COLOR_TABLE_SIZE, $0b

//; =============================================================================
//; CHARSET DATA
//; =============================================================================

* = CHARSET_ADDRESS "Font"
    .fill min($700, file_charsetData.getSize()), file_charsetData.get(i)

* = CHARSET_ADDRESS + (224 * 8) "Bar Chars"
//; Filled at build time by the web app based on BarStyle selection.
//; Triple bars use the mirror layout (160 bytes); only the first 80 bytes
//; (the main bar chars 224..233) are referenced when rendering, but we
//; allocate the full mirror block so the standard build pipeline can
//; inject any of the existing styles unchanged.
    .fill BAR_STYLE_SIZE_MIRROR, $00

* = SCREEN0_ADDRESS "Screen 0"
    .fill $400, $00

* = SCREEN1_ADDRESS "Screen 1"
    .fill $400, $00

//; =============================================================================
//; END OF FILE
//; =============================================================================
