// =============================================================================
//                          RAISTLIN TRIPLE MIRROR BARS
//             Per-Channel SID Music Spectrum Visualizer (3 mirrored stacks)
//
//   Three independent mirrored spectrum strips, one per SID channel, stacked
//   vertically. Each strip is 3 chars tall reflected to 6 chars total.
//   Voice index modulo 3 selects the channel.
//
//   Colours are completely fixed: a per-row gradient is written to colour RAM
//   once at startup and never touched again, so the IRQ only updates screen
//   chars. The visualizer is intended for 1x-call, single-SID tunes only - the
//   web export pipeline gates on that via the JSON config.
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
.const TOP_SPECTRUM_HEIGHT              = 3                                     //; per-channel half height (chars)
.const CHANNEL_HEIGHT                   = TOP_SPECTRUM_HEIGHT * 2               //; per-channel full mirrored height
.const TOTAL_SPECTRUM_HEIGHT            = CHANNEL_HEIGHT * NUM_CHANNELS

//; Fixed text colours - not user-customisable.
.const SONG_NAME_COLOR                  = $01           // White
.const ARTIST_NAME_COLOR                = $0f           // Light grey
.const BORDER_COLOR                     = $00           // Black
.const BACKGROUND_COLOR                 = $00           // Black

//; =============================================================================
//; DATA BLOCK
//; The first $100 bytes of DATA_ADDRESS are the contract with prg-builder.js.
//; This visualizer no longer exposes any colour-related option bytes; the
//; build pipeline will leave the option range zeroed.
//; =============================================================================

* = DATA_ADDRESS "Data Block"
    .fill $100, $00

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

.const CH0_BASE_LINE                    = SPECTRUM_START_LINE
.const CH1_BASE_LINE                    = SPECTRUM_START_LINE + CHANNEL_HEIGHT
.const CH2_BASE_LINE                    = SPECTRUM_START_LINE + (CHANNEL_HEIGHT * 2)

.eval setSeed(55378008)

.const SCREEN0_BANK                     = 12
.const SCREEN1_BANK                     = 13
.const CHARSET_BANK                     = 7

.const SCREEN0_ADDRESS                  = VIC_BANK_ADDRESS + (SCREEN0_BANK * $400)
.const SCREEN1_ADDRESS                  = VIC_BANK_ADDRESS + (SCREEN1_BANK * $400)
.const CHARSET_ADDRESS                  = VIC_BANK_ADDRESS + (CHARSET_BANK * $800)

.const D018_VALUE_0                     = (SCREEN0_BANK * 16) + (CHARSET_BANK * 2)
.const D018_VALUE_1                     = (SCREEN1_BANK * 16) + (CHARSET_BANK * 2)

.const MAX_BAR_HEIGHT                   = TOP_SPECTRUM_HEIGHT * 8 - 1
.const MAIN_BAR_OFFSET                  = MAX_BAR_HEIGHT - 7

//; =============================================================================
//; INCLUDES
//; =============================================================================

#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR
#define INCLUDE_MUSIC_ANALYSIS

#define INCLUDE_RASTER_TIMING_CODE
.var DEFAULT_RASTERTIMING_Y = 250

.import source "../INC/common.asm"
.import source "../INC/keyboard.asm"
.import source "../INC/musicplayback.asm"
.import source "../INC/stablerastersetup.asm"
.import source "../INC/spectrometer3channel.asm"
.import source "../INC/freqtable.asm"
.import source "../INC/barstyles.asm"
.import source "../INC/linkedwitheffect.asm"

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

//; =============================================================================
//; FIXED PER-ROW COLOUR GRADIENT
//; 18 entries (3 channels x (3 + 3 mirror) rows). Bright at the centre seam,
//; dimmer at the channel edges. Channels: V1 cyan/blue, V2 green/yellow, V3 red.
//; =============================================================================

channelRowColors:
    //; Channel 0 (V1) - cool cyan/blue, peak at centre seam.
    .byte $06, $0e, $03, $03, $0e, $06     //; blue, lt-blue, cyan, cyan, lt-blue, blue
    //; Channel 1 (V2) - green family (no yellow, so it doesn't read like V3),
    //; peak at centre seam.
    .byte $09, $05, $0d, $0d, $05, $09     //; brown, green, lt-green, lt-green, green, brown
    //; Channel 2 (V3) - red/orange, peak at centre seam.
    .byte $02, $0a, $07, $07, $0a, $02     //; red, lt-red, yellow, yellow, lt-red, red

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

    lda #BORDER_COLOR
    sta $d020
    lda #BACKGROUND_COLOR
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
//; Render to the *off-screen* buffer (the one not currently being displayed)
//; so the user only ever sees a complete frame.
//; =============================================================================

.macro RenderChannelToScreen(SCREEN_ADDR, smoothedH, prevH, channelBaseLine) {
    ldy #NUM_FREQUENCY_BARS - 1
!loop:
    lda smoothedH, y
    cmp prevH, y
    beq !next+
    sta prevH, y
    tax
    clc
    .for (var line = 0; line < TOP_SPECTRUM_HEIGHT; line++) {
        lda barCharacterMap - MAIN_BAR_OFFSET + (line * 8), x
        sta SCREEN_ADDR + ((channelBaseLine + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
        adc #10
        sta SCREEN_ADDR + ((channelBaseLine + (CHANNEL_HEIGHT - 1) - line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
    }
!next:
    dey
    bpl !loop-
}

RenderBars:
    lda currentScreenBuffer
    bne !renderToScreen0+
    jmp RenderToScreen1     //; cSB == 0 -> display 0, render to 1
!renderToScreen0:
    jmp RenderToScreen0     //; cSB == 1 -> display 1, render to 0

RenderToScreen0:
    RenderChannelToScreen(SCREEN0_ADDRESS, smoothedHeightsCh0, previousHeightsScreen0Ch0, CH0_BASE_LINE)
    RenderChannelToScreen(SCREEN0_ADDRESS, smoothedHeightsCh1, previousHeightsScreen0Ch1, CH1_BASE_LINE)
    RenderChannelToScreen(SCREEN0_ADDRESS, smoothedHeightsCh2, previousHeightsScreen0Ch2, CH2_BASE_LINE)
    rts

RenderToScreen1:
    RenderChannelToScreen(SCREEN1_ADDRESS, smoothedHeightsCh0, previousHeightsScreen1Ch0, CH0_BASE_LINE)
    RenderChannelToScreen(SCREEN1_ADDRESS, smoothedHeightsCh1, previousHeightsScreen1Ch1, CH1_BASE_LINE)
    RenderChannelToScreen(SCREEN1_ADDRESS, smoothedHeightsCh2, previousHeightsScreen1Ch2, CH2_BASE_LINE)
    rts

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
    lda #SONG_NAME_COLOR
    sta $d800 + ((SONG_TITLE_LINE + 0) * 40) + 4, y
    sta $d800 + ((SONG_TITLE_LINE + 1) * 40) + 4, y

    lda ArtistName, y
    sta SCREEN0_ADDRESS + (ARTIST_NAME_LINE * 40) + 4, y
    sta SCREEN1_ADDRESS + (ARTIST_NAME_LINE * 40) + 4, y
    ora #$80
    sta SCREEN0_ADDRESS + ((ARTIST_NAME_LINE + 1) * 40) + 4, y
    sta SCREEN1_ADDRESS + ((ARTIST_NAME_LINE + 1) * 40) + 4, y
    lda #ARTIST_NAME_COLOR
    sta $d800 + ((ARTIST_NAME_LINE + 0) * 40) + 4, y
    sta $d800 + ((ARTIST_NAME_LINE + 1) * 40) + 4, y

    dey
    bpl !loop-

    rts

//; Write the fixed per-row gradient into colour RAM, once. Each of the 18
//; spectrum rows gets its own fixed colour across all 40 columns.
InitializeColors:
    ldx #NUM_FREQUENCY_BARS - 1
!barLoop:
    .for (var line = 0; line < TOTAL_SPECTRUM_HEIGHT; line++) {
        lda channelRowColors + line
        sta $d800 + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), x
    }
    dex
    bpl !barLoop-
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
    .byte SKIP_REGISTER                 //; Border color - set by InitializeVIC
    .byte SKIP_REGISTER                 //; Background color - set by InitializeVIC
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
//; CHARSET DATA
//; =============================================================================

* = CHARSET_ADDRESS "Font"
    .fill min($700, file_charsetData.getSize()), file_charsetData.get(i)

* = CHARSET_ADDRESS + (224 * 8) "Bar Chars"
//; Filled at build time by the web app based on BarStyle selection.
//; Mirror layout: 10 main chars + 10 mirror chars (160 bytes).
    .fill BAR_STYLE_SIZE_MIRROR, $00

* = SCREEN0_ADDRESS "Screen 0"
    .fill $400, $00

* = SCREEN1_ADDRESS "Screen 1"
    .fill $400, $00

//; =============================================================================
//; END OF FILE
//; =============================================================================
