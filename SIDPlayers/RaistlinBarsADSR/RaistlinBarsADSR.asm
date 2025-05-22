//; =============================================================================
//; RaistlinBars - SID Music Visualizer with Spectrum Analyzer Effect
//; (c) 2018, Raistlin of Genesis*Project
//; Revised and optimized version with improved smoothing algorithm
//; ADSR Extension added to implement complete envelope visualization
//; =============================================================================

* = PlayerADDR

    jmp MUSICPLAYER_Initialize   //; Entry point for the player

//; =============================================================================
//; RESOURCE FILES
//; =============================================================================
.var spritesine_bin = LoadBinary("SpriteSine.bin")       //; Sine wave data for sprite movement
.var freqtable_bin = LoadBinary("FreqTable.bin")         //; Lookup tables for frequency mapping
.var charset_map = LoadBinary("CharSet.map")             //; Character set for visualization
.var watersprites_map = LoadBinary("WaterSprites.map")   //; Sprites for water reflection effect

//; =============================================================================
//; DISPLAY CONFIGURATION
//; =============================================================================
.var NUM_FREQS_ON_SCREEN = 40                //; Number of frequency bars shown
.var FREQ_BARS_PADDING = 1                   //; Extra padding bytes on each side for smoothing

//; Song information display settings
.var SONG_TITLE_COLOR = $01                  //; Color for song title
.var SONG_TITLE_SCREEN_LINE = 0              //; Screen line for song title
.var SONG_TITLE_LENGTH = min(SIDName.size(), 40) //; Truncate to screen width
.var SONG_TITLE_PADDING = (40 - SONG_TITLE_LENGTH) / 2 //; Centering padding

//; Artist information display settings
.var ARTIST_NAME_COLOR = $0f                 //; Color for artist name
.var ARTIST_NAME_SCREEN_LINE = 3             //; Screen line for artist name
.var ARTIST_NAME_LENGTH = min(SIDAuthor.size(), 40) //; Truncate to screen width
.var ARTIST_NAME_PADDING = (40 - ARTIST_NAME_LENGTH) / 2 //; Centering padding

//; Visualization layout
.var TOP_SPECTROMETER_HEIGHT = 15            //; Height of main spectrometer in chars
.var TOP_SPECTROMETER_PIXELHEIGHT = (TOP_SPECTROMETER_HEIGHT * 8)
.var BOTTOM_SPECTROMETER_HEIGHT = 3          //; Height of reflection effect in chars
.var SPECTROMETER_START_LINE = 25 - (TOP_SPECTROMETER_HEIGHT + BOTTOM_SPECTROMETER_HEIGHT)

//; =============================================================================
//; MEMORY CONFIGURATION
//; =============================================================================
.var BASE_BANK = 3                           //; Memory bank (3=c000-ffff)
.var BASE_BANK_ADDRESS = (BASE_BANK * $4000) //; Start address of the bank
.var SCREEN_BANK = 14                        //; Screen memory location (Bank+[3800,3bff])
.var CHAR_BANK_FONT = 6                      //; Character set location (Bank+[3000,37ff])
.var SCREEN_ADDRESS = (BASE_BANK_ADDRESS + (SCREEN_BANK * $400)) //; Screen memory address
.var SPRITE_POINTERS = (SCREEN_ADDRESS + $3F8) //; Sprite pointer table in screen memory
.var CHARSET_ADDRESS = (BASE_BANK_ADDRESS + (CHAR_BANK_FONT * $800)) //; Character set address
.var SPRITE_INDEX_START = $80                //; First sprite index
.var WATERSPRITES_ADDRESS = (BASE_BANK_ADDRESS + (SPRITE_INDEX_START * $40)) //; Water sprites

//; =============================================================================
//; LOCAL DATA SECTION
//; =============================================================================
StartLocalData:

    //; Constant for VIC register initialization skipping
    .var SKIP_VALUE = $e1

    //; VIC-II register initialization values
    .var NUM_VIC_INIT_VALUES = EndVICInitValues - StartVICInitValues

    StartVICInitValues:
        .byte $10                                        //; D000: Sprite0X
        .byte $e5                                        //; D001: Sprite0Y
        .byte $40                                        //; D002: Sprite1X
        .byte $e5                                        //; D003: Sprite1Y
        .byte $70                                        //; D004: Sprite2X
        .byte $e5                                        //; D005: Sprite2Y
        .byte $a0                                        //; D006: Sprite3X
        .byte $e5                                        //; D007: Sprite3Y
        .byte $d0                                        //; D008: Sprite4X
        .byte $e5                                        //; D009: Sprite4Y
        .byte $00                                        //; D00A: Sprite5X
        .byte $e5                                        //; D00B: Sprite5Y
        .byte $30                                        //; D00C: Sprite6X
        .byte $e5                                        //; D00D: Sprite6Y
        .byte $00                                        //; D00E: Sprite7X
        .byte $00                                        //; D00F: Sprite7Y
        .byte $60                                        //; D010: SpriteXMSB
        .byte SKIP_VALUE                                 //; D011: Screen control register 1
        .byte SKIP_VALUE                                 //; D012: Raster line
        .byte SKIP_VALUE                                 //; D013: LightPenX
        .byte SKIP_VALUE                                 //; D014: LightPenY
        .byte $7f                                        //; D015: SpriteEnable (all enabled)
        .byte $08                                        //; D016: Screen control register 2
        .byte $00                                        //; D017: SpriteDoubleHeight
        .byte ((SCREEN_BANK * 16) + (CHAR_BANK_FONT * 2)) //; D018: Memory setup
        .byte SKIP_VALUE                                 //; D019: Interrupt status
        .byte SKIP_VALUE                                 //; D01A: Interrupt control
        .byte $00                                        //; D01B: SpriteDrawPriority
        .byte $00                                        //; D01C: SpriteMulticolourMode
        .byte $7f                                        //; D01D: SpriteDoubleWidth (all enabled)
        .byte $00                                        //; D01E: SpriteSpriteCollision
        .byte $00                                        //; D01F: SpriteBackgroundCollision
        .byte $00                                        //; D020: BorderColour
        .byte $00                                        //; D021: ScreenColour
        .byte $00                                        //; D022: MultiColour0
        .byte $00                                        //; D023: MultiColour1
        .byte $00                                        //; D024: ExtraBackgroundColour2
        .byte $00                                        //; D025: SpriteExtraColour0
        .byte $00                                        //; D026: SpriteExtraColour1
        .byte $00                                        //; D027: Sprite0Colour
        .byte $00                                        //; D028: Sprite1Colour
        .byte $00                                        //; D029: Sprite2Colour
        .byte $00                                        //; D02A: Sprite3Colour
        .byte $00                                        //; D02B: Sprite4Colour
        .byte $00                                        //; D02C: Sprite5Colour
        .byte $00                                        //; D02D: Sprite6Colour
        .byte $00                                        //; D02E: Sprite7Colour
    EndVICInitValues:

    //; Song metadata
    SongData_Title:           .text SIDName.substring(0, min(SIDName.size(), 40))
    SongData_Artist:          .text SIDAuthor.substring(0, min(SIDAuthor.size(), 40))

    //; Visualization variables
    UpdateVisualizerSignal:   .byte $00      //; Flag to trigger visualization update
    FrameCounter:             .byte $00      //; Counter for current frame (0-255)
    Frame_256Counter:         .byte $00      //; Counter for 256-frame cycles

    //; Cache for previous frame data to optimize rendering
    PrevFrame_BarHeights:     .fill NUM_FREQS_ON_SCREEN, 255  //; Previous bar heights
    PrevFrame_BarColors:      .fill NUM_FREQS_ON_SCREEN, 255  //; Previous bar colors

    .align 128
  
    SoundBarSine:             .fill 128, (TOP_SPECTROMETER_PIXELHEIGHT - 1.0) * sin(toRadians(i*90/128)) //; Sine wave data for sound bar animation

    .align 256

    Div3Table:                .fill 256, i / 3

//; =============================================================================
//; ADSR State and Timing Constants
//; =============================================================================
//; ADSR State constants
.var ADSR_ATTACK = 0
.var ADSR_DECAY = 1
.var ADSR_SUSTAIN = 2
.var ADSR_RELEASE = 3

//; 16-bit frame count tables for ADSR timing based on SID chip specifications
AttackFramesLo:
    .byte <1    //; Attack 0: 2ms ≈ 1 frame
    .byte <1    //; Attack 1: 8ms ≈ 1 frame
    .byte <1    //; Attack 2: 16ms ≈ 1 frame
    .byte <2    //; Attack 3: 24ms ≈ 2 frames
    .byte <2    //; Attack 4: 38ms ≈ 2 frames
    .byte <3    //; Attack 5: 56ms ≈ 3 frames
    .byte <4    //; Attack 6: 68ms ≈ 4 frames
    .byte <4    //; Attack 7: 80ms ≈ 4 frames
    .byte <5    //; Attack 8: 100ms ≈ 5 frames
    .byte <13   //; Attack 9: 250ms ≈ 13 frames
    .byte <25   //; Attack 10: 500ms ≈ 25 frames
    .byte <40   //; Attack 11: 800ms ≈ 40 frames
    .byte <50   //; Attack 12: 1s ≈ 50 frames
    .byte <150  //; Attack 13: 3s ≈ 150 frames
    .byte <250  //; Attack 14: 5s ≈ 250 frames
    .byte <400  //; Attack 15: 8s ≈ 400 frames

AttackFramesHi:
    .byte >1    //; Attack 0
    .byte >1    //; Attack 1
    .byte >1    //; Attack 2
    .byte >2    //; Attack 3
    .byte >2    //; Attack 4
    .byte >3    //; Attack 5
    .byte >4    //; Attack 6
    .byte >4    //; Attack 7
    .byte >5    //; Attack 8
    .byte >13   //; Attack 9
    .byte >25   //; Attack 10
    .byte >40   //; Attack 11
    .byte >50   //; Attack 12
    .byte >150  //; Attack 13
    .byte >250  //; Attack 14
    .byte >400  //; Attack 15

DecayFramesLo:
    .byte <1    //; Decay 0: 6ms ≈ 1 frame
    .byte <2    //; Decay 1: 24ms ≈ 2 frames
    .byte <3    //; Decay 2: 48ms ≈ 3 frames
    .byte <4    //; Decay 3: 72ms ≈ 4 frames
    .byte <6    //; Decay 4: 114ms ≈ 6 frames
    .byte <9    //; Decay 5: 168ms ≈ 9 frames
    .byte <11   //; Decay 6: 204ms ≈ 11 frames
    .byte <12   //; Decay 7: 240ms ≈ 12 frames
    .byte <15   //; Decay 8: 300ms ≈ 15 frames
    .byte <38   //; Decay 9: 750ms ≈ 38 frames
    .byte <75   //; Decay 10: 1.5s ≈ 75 frames
    .byte <120  //; Decay 11: 2.4s ≈ 120 frames
    .byte <150  //; Decay 12: 3s ≈ 150 frames
    .byte <450  //; Decay 13: 9s ≈ 450 frames
    .byte <750  //; Decay 14: 15s ≈ 750 frames
    .byte <1200  //; Decay 15: 24s ≈ 1200 frames

DecayFramesHi:
    .byte >1    //; Decay 0
    .byte >2    //; Decay 1
    .byte >3    //; Decay 2
    .byte >4    //; Decay 3
    .byte >6    //; Decay 4
    .byte >9    //; Decay 5
    .byte >11   //; Decay 6
    .byte >12   //; Decay 7
    .byte >15   //; Decay 8
    .byte >38   //; Decay 9
    .byte >75   //; Decay 10
    .byte >120  //; Decay 11
    .byte >150  //; Decay 12
    .byte >450  //; Decay 13
    .byte >750  //; Decay 14
    .byte >1200  //; Decay 15

ReleaseFramesLo:
    .byte <1    //; Release 0: 6ms ≈ 1 frame
    .byte <2    //; Release 1: 24ms ≈ 2 frames
    .byte <3    //; Release 2: 48ms ≈ 3 frames
    .byte <4    //; Release 3: 72ms ≈ 4 frames
    .byte <6    //; Release 4: 114ms ≈ 6 frames
    .byte <9    //; Release 5: 168ms ≈ 9 frames
    .byte <11   //; Release 6: 204ms ≈ 11 frames
    .byte <12   //; Release 7: 240ms ≈ 12 frames
    .byte <15   //; Release 8: 300ms ≈ 15 frames
    .byte <38   //; Release 9: 750ms ≈ 38 frames
    .byte <75   //; Release 10: 1.5s ≈ 75 frames
    .byte <120  //; Release 11: 2.4s ≈ 120 frames
    .byte <150  //; Release 12: 3s ≈ 150 frames
    .byte <450  //; Release 13: 9s ≈ 450
    .byte <750  //; Release 14: 15s ≈ 750
    .byte <1200  //; Release 15: 24s ≈ 1200

ReleaseFramesHi:
    .byte >1    //; Release 0
    .byte >2    //; Release 1
    .byte >3    //; Release 2
    .byte >4    //; Release 3
    .byte >6    //; Release 4
    .byte >9    //; Release 5
    .byte >11   //; Release 6
    .byte >12   //; Release 7
    .byte >15   //; Release 8
    .byte >38   //; Release 9
    .byte >75   //; Release 10
    .byte >120  //; Release 11
    .byte >150  //; Release 12
    .byte >450  //; Release 13
    .byte >750  //; Release 14
    .byte >1200  //; Release 15

//; Pre-computed step rates for attack phase (how much to add per frame)
//; Updated to use 24-bit precision with two tables
AttackStepHi:
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 1  )  //; Attack 0: Full height in 1 frame
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 1  )  //; Attack 1: Full height in 1 frame
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 1  )  //; Attack 2: Full height in 1 frame
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 2  )  //; Attack 3: Full height in 2 frames
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 2  )  //; Attack 4: Full height in 2 frames
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 3  )  //; Attack 5: Full height in 3 frames
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 4  )  //; Attack 6: Full height in 4 frames
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 4  )  //; Attack 7: Full height in 4 frames
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 5  )  //; Attack 8: Full height in 5 frames
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 13 )  //; Attack 9: Full height in 13 frames
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 25 )  //; Attack 10: Full height in 25 frames
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 40 )  //; Attack 11: Full height in 40 frames
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 50 )  //; Attack 12: Full height in 50 frames
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 150)  //; Attack 13: Full height in 150 frames
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 250)  //; Attack 14: Full height in 250 frames
    .byte <(TOP_SPECTROMETER_PIXELHEIGHT / 400)  //; Attack 15: Full height in 400 frames

//; Extension byte for higher precision with 24-bit attack increment
AttackStepLo:
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 1  )  //; Attack 0
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 1  )  //; Attack 1
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 1  )  //; Attack 2
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 2  )  //; Attack 3
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 2  )  //; Attack 4
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 3  )  //; Attack 5
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 4  )  //; Attack 6
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 4  )  //; Attack 7
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 5  )  //; Attack 8
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 13 )  //; Attack 9
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 25 )  //; Attack 10
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 40 )  //; Attack 11
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 50 )  //; Attack 12
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 150)  //; Attack 13
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 250)  //; Attack 14
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 256) / 400)  //; Attack 15

//; For slower attack rates, we might need to calculate fractional steps
//; This is the lowest byte of our 24-bit precision
AttackStepExt:
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 1  )  //; Attack 0
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 1  )  //; Attack 1
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 1  )  //; Attack 2
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 2  )  //; Attack 3
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 2  )  //; Attack 4
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 3  )  //; Attack 5
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 4  )  //; Attack 6
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 4  )  //; Attack 7
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 5  )  //; Attack 8
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 13 )  //; Attack 9
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 25 )  //; Attack 10
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 40 )  //; Attack 11
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 50 )  //; Attack 12
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 150)  //; Attack 13
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 250)  //; Attack 14
    .byte <((TOP_SPECTROMETER_PIXELHEIGHT * 65536) / 400)  //; Attack 15

//; Pre-computed decay divider (how many frames to wait before decrementing)
DecayDividers:
    .byte 1     //; Decay 0: Decrement every frame
    .byte 1     //; Decay 1: Decrement every frame
    .byte 1     //; Decay 2: Decrement every frame
    .byte 1     //; Decay 3: Decrement every frame
    .byte 2     //; Decay 4: Decrement every 2 frames
    .byte 2     //; Decay 5: Decrement every 2 frames
    .byte 3     //; Decay 6: Decrement every 3 frames
    .byte 3     //; Decay 7: Decrement every 3 frames
    .byte 4     //; Decay 8: Decrement every 4 frames
    .byte 6     //; Decay 9: Decrement every 6 frames
    .byte 10    //; Decay 10: Decrement every 10 frames
    .byte 15    //; Decay 11: Decrement every 15 frames
    .byte 20    //; Decay 12: Decrement every 20 frames
    .byte 30    //; Decay 13: Decrement every 30 frames
    .byte 40    //; Decay 14: Decrement every 40 frames
    .byte 60    //; Decay 15: Decrement every 60 frames

//; Similar dividers for release phase
ReleaseMultipliers:
    .byte 1     //; Release 0: Standard release rate
    .byte 1     //; Release 1: Standard release rate
    .byte 1     //; Release 2: Standard release rate
    .byte 1     //; Release 3: Standard release rate
    .byte 1     //; Release 4: Standard release rate
    .byte 1     //; Release 5: Standard release rate
    .byte 1     //; Release 6: Standard release rate
    .byte 1     //; Release 7: Standard release rate
    .byte 1     //; Release 8: Standard release rate
    .byte 1     //; Release 9: Standard release rate
    .byte 1     //; Release 10: Standard release rate
    .byte 1     //; Release 11: Standard release rate
    .byte 1     //; Release 12: Standard release rate
    .byte 1     //; Release 13: Standard release rate
    .byte 1     //; Release 14: Standard release rate
    .byte 1     //; Release 15: Standard release rate

//; Sustain level conversion
SustainConversion:
    .fill 16, (i * (TOP_SPECTROMETER_PIXELHEIGHT) / 15)

//; =============================================================================
//; ADSR State Tracking Variables
//; =============================================================================
//; ADSR state for each channel
ChannelADSRState:         .fill 3, ADSR_RELEASE

//; 16-bit frame counters for ADSR timing
ChannelFrameCountLo:      .fill 3, 0
ChannelFrameCountHi:      .fill 3, 0
ChannelTotalFramesLo:     .fill 3, 0
ChannelTotalFramesHi:     .fill 3, 0

//; Target heights for sustain phase
ChannelTargetHeights:     .fill 3, 0

//; Divisor counters for attack/decay/release
ChannelDivisorCounter:    .fill 3, 0

//; Colors for each ADSR phase
ADSRPhaseColors:
    .byte $0e   //; Light blue for Attack phase
    .byte $08   //; Orange for Decay phase
    .byte $07   //; Yellow for Sustain phase
    .byte $05   //; Green for Release phase

//; SID register ghost copy for analysis
SIDRegisterCopy:            .fill 32, 0    //; Copy of SID registers 
PrevSIDRegisterCopy:        .fill 32, 0    //; Previous SID register values for gate detection

//; Frequency conversion tables
LoFreqToLookupTable:      .fill 256, i / 4
HiFreqToLookupTable:      .fill 4, i * 64

//; Sine wave data for sprite movement
SpriteSine:               .fill spritesine_bin.getSize(), spritesine_bin.get(i)

//; Frequency lookup tables
FreqTable:                .fill freqtable_bin.getSize(), freqtable_bin.get(i)

//; Analyzer data buffers with padding bytes for smoothing
ChannelToFreqMap:               .fill NUM_FREQS_ON_SCREEN, 0                        //; Maps screen positions to SID channels
RawBarHeightsHi:                .fill NUM_FREQS_ON_SCREEN, 0                        //; High bytes of raw bar heights
RawBarHeightsLo:                .fill NUM_FREQS_ON_SCREEN, 0                        //; Low bytes of raw bar heights
RawBarHeightsExt:               .fill NUM_FREQS_ON_SCREEN, 0                        //; Extension bytes for 24-bit precision

//; Channel-specific release rates
ChannelReleaseHi:               .fill 3, 0                                          //; High bytes of release rates per channel
ChannelReleaseLo:               .fill 3, 0                                          //; Low bytes of release rates per channel

CurrentChannel:                 .byte $00

//; New buffer for smoothed bar heights
SmoothedBarHeights:             .fill NUM_FREQS_ON_SCREEN, 0                        //; Smoothed bar heights

//; Current bar heights for drawing
.byte $00
FrequencyBarHeights:          .fill NUM_FREQS_ON_SCREEN, 0  //; Final heights for display
.byte $00

//; Color lookup tables
DarkColorLookup:            .byte $00, $0c, $00, $0e, $06, $09, $00, $08
                           .byte $02, $0b, $02, $00, $0b, $05, $06, $0c

//; Color palettes for the visualization
.var NUM_COLOR_PALETTES = 4
ColorPaletteA:              .byte $09, $04, $0d, $01
ColorPaletteB:              .byte $06, $0e, $07, $01
ColorPaletteC:              .byte $02, $0a, $0d, $01
ColorPaletteD:              .byte $0b, $0c, $0f, $01

//; Pointers to color palettes
ColorPalettePtr_Lo:         .byte <ColorPaletteA, <ColorPaletteB, <ColorPaletteC, <ColorPaletteD
ColorPalettePtr_Hi:         .byte >ColorPaletteA, >ColorPaletteB, >ColorPaletteC, >ColorPaletteD

//; Color mapping table based on bar height
BarHeightToColorIndex:    .byte $ff                                      //;  baseline
                          .fill TOP_SPECTROMETER_PIXELHEIGHT, (i * 4) / TOP_SPECTROMETER_PIXELHEIGHT
                          .byte $03

//; Color tables for the visualization
BarColorsDark:              .fill TOP_SPECTROMETER_PIXELHEIGHT, $00  //; Darker colors for reflections
BarColors:                  .fill TOP_SPECTROMETER_PIXELHEIGHT, $0b  //; Main colors for bars

//; Calculate which IRQ should update the analyzer
.var VISUALIZER_UPDATE_IRQ = 0
.if (NumCallsPerFrame == 2) {
    .eval VISUALIZER_UPDATE_IRQ = 1
} else {
    .if (NumCallsPerFrame == 3) {
        .eval VISUALIZER_UPDATE_IRQ = 2
    } else {
        .if (NumCallsPerFrame == 4) {
            .eval VISUALIZER_UPDATE_IRQ = 2
        } else {
            .if (NumCallsPerFrame == 5) {
                .eval VISUALIZER_UPDATE_IRQ = 3
            } else {
                .if (NumCallsPerFrame == 6) {
                    .eval VISUALIZER_UPDATE_IRQ = 3
                }
            }
        }
    }
}

//; Character mapping for meter visualization
.var METER_TO_CHAR_PADDING = TOP_SPECTROMETER_PIXELHEIGHT - 8

.align 256  
    .fill METER_TO_CHAR_PADDING, 224      //; Initial padding
MeterToCharValues:
    .fill 8, i + 224 + 1              //; First 8 values increment
    .fill METER_TO_CHAR_PADDING, 224 + 9

//; Lookup table for 7*channel calculation
Mul7: .fill 3, i * 7

EndLocalData:

//; Pre-calculate addresses for frequency tables
.var FreqHiTable = FreqTable + (0 * 256)
.var FreqLoTable = FreqTable + (1 * 256)

//; =============================================================================
//; CODE SEGMENT
//; =============================================================================
StartCodeSegment:

//; =============================================================================
//; MUSICPLAYER_Initialize() - Entry point for the music visualizer
//; =============================================================================
MUSICPLAYER_Initialize:
        sei                           //; Disable interrupts

        //; Wait for stable raster line
        bit $d011
        bpl *-3
        bit $d011
        bmi *-3

        //; Turn off screen temporarily during setup
        lda #$00
        sta $d011
        sta $d020

        //; Wait for another stable raster to ensure VIC is ready
        bit $d011
        bpl *-3
        bit $d011
        bmi *-3

        //; Set up the system
        jsr PreDemoSetup             //; Initialize system
        jsr NMIFix                   //; Fix NMI to prevent crashes

        //; Initialize VIC-II registers
        ldx #(NUM_VIC_INIT_VALUES - 1)
    InitVICRegisters:
        lda StartVICInitValues, x
        cmp #SKIP_VALUE
        beq SkipThisRegister
        sta $d000, x                 //; Set VIC register 
    SkipThisRegister:
        dex
        bpl InitVICRegisters

        //; Set up VIC memory banks
        lda #(63-BASE_BANK)          //; Calculate CIA value for bank
        sta $dd00
        lda #BASE_BANK
        sta $dd02

        //; Initialize the bar color values
        ldx #0
    InitBarColorsLoop:
        lda #$0b                     //; Default color
        ldy BarHeightToColorIndex, x
        bmi UseDefaultColor
        lda ColorPaletteA, y         //; Get color from palette
    UseDefaultColor:
        sta BarColors, x             //; Set main color
        tay
        lda DarkColorLookup, y       //; Look up darker version
        sta BarColorsDark, x         //; Set dark color for reflection
        inx
        cpx #TOP_SPECTROMETER_PIXELHEIGHT
        bne InitBarColorsLoop

        //; Clear screen and color memory
        ldx #$00
        lda #$20                     //; Space character
    ClearScreenLoop:
        sta $d800 + (0 * 256), x     //; Clear color RAM
        sta $d800 + (1 * 256), x
        sta $d800 + (2 * 256), x
        sta $d800 + (3 * 256), x
        sta SCREEN_ADDRESS + (0 * 256), x  //; Clear screen RAM
        sta SCREEN_ADDRESS + (1 * 256), x
        sta SCREEN_ADDRESS + (2 * 256), x
        sta SCREEN_ADDRESS + (3 * 256), x
        inx
        bne ClearScreenLoop

        //; Set up song and artist name colors
        ldx #79
    SetupTitleColorsLoop:
        lda #SONG_TITLE_COLOR
        sta $d800 + ((SONG_TITLE_SCREEN_LINE + 0) * 40), x
        lda #ARTIST_NAME_COLOR
        sta $d800 + ((ARTIST_NAME_SCREEN_LINE + 0) * 40), x
        dex
        bpl SetupTitleColorsLoop

        //; Wait for stable raster before turning screen back on
        bit $d011
        bpl *-3
        bit $d011
        bmi *-3

        //; Turn on the screen
        lda #$1b
        sta $d011

        //; Set up IRQ system
        lda #<MUSICPLAYER_IRQ0       //; Set IRQ vector
        sta $fffe
        lda #>MUSICPLAYER_IRQ0
        sta $ffff
        lda D012_Values              //; Set raster line
        sta $d012
        lda $d011
        and #$3f
        ora D011_Values
        sta $d011

        //; Enable raster IRQs
        lda #$01
        sta $d01a
        sta $d019

        //; Set final memory configuration
        lda #$35
        sta $01

        //; Initialize ADSR states for all channels
        ldx #3
        dex
    InitADSRLoop:
        lda #ADSR_RELEASE
        sta ChannelADSRState, x
        lda #0
        sta ChannelTargetHeights, x
        sta ChannelFrameCountLo, x
        sta ChannelFrameCountHi, x
        sta ChannelTotalFramesLo, x
        sta ChannelTotalFramesHi, x
        sta ChannelDivisorCounter, x
        dex
        bpl InitADSRLoop

        cli                           //; Enable interrupts
    
        //; Initialize music and visualizer
        jsr MUSICPLAYER_SetupSong

        //; Main program loop - waits for visualization updates
    MainLoop:
        lda UpdateVisualizerSignal    //; Check if update is needed
        beq JustUpdateADSR            //; If no visual update, still update ADSR

        //; Update the visualization
        jsr MUSICPLAYER_SmoothBars    //; Apply smoothing to the bars
        jsr MUSICPLAYER_DrawBars      //; Draw the visualization

        lda #$00
        sta UpdateVisualizerSignal    //; Clear update flag

    JustUpdateADSR:
        jsr MUSICPLAYER_UpdateBarHeights  //; Apply ADSR envelope updates

        jmp MainLoop                  //; Continue looping

//; =============================================================================
//; MUSICPLAYER_NextIRQ() - Set up the next IRQ in the chain
//; =============================================================================
MUSICPLAYER_NextIRQ:
        ldx #$00                      //; IRQ counter (self-modified)

        //; Check if this is the IRQ that should update the visualizer
        ldy #$00
        cpx #VISUALIZER_UPDATE_IRQ
        bne SkipVisualizerUpdate
        iny                           //; Set update flag if this is the right IRQ
    SkipVisualizerUpdate:
        sty UpdateVisualizerSignal

        //; Move to next IRQ in the chain
        inx
        cpx #NumCallsPerFrame
        bne NotLastIRQ

        ldx #$00                      //; Reset to first IRQ if at end
    NotLastIRQ:
        stx MUSICPLAYER_NextIRQ + 1  //; Store for next time

        //; Set up for next IRQ
        lda D012_Values, x            //; Get raster line
        sta $d012
        lda $d011
        and #$3f
        ora D011_Values, x            //; Set high bit of raster line
        sta $d011

        //; Set appropriate vector based on which IRQ
        cpx #$00
        bne SetMusicOnlyIRQ

        //; Set vector for main IRQ
        lda #<MUSICPLAYER_IRQ0
        sta $fffe
        lda #>MUSICPLAYER_IRQ0
        sta $ffff
        rts

    SetMusicOnlyIRQ:
        //; Set vector for music-only IRQ
        lda #<MUSICPLAYER_IRQ_MusicOnly
        sta $fffe
        lda #>MUSICPLAYER_IRQ_MusicOnly
        sta $ffff
        rts

//; =============================================================================
//; MUSICPLAYER_IRQ0() - Main IRQ handler for music and visualization
//; =============================================================================
MUSICPLAYER_IRQ0:
        pha                           //; Save registers
        txa
        pha
        tya
        pha

        jsr MUSICPLAYER_PlayMusic     //; Play music

        //; Frame counter logic
        inc FrameCounter
        bne NotNewColorCycle

        //; Every 256 frames, update the color cycle counter
        inc Frame_256Counter

        //; Reset color update pointer
        lda #$00
        sta UpdateNextColorEntry + 1

    UpdateColorPalette:
        //; Update color palette every 256 frames
        ldx #$00
        inx
        cpx #NUM_COLOR_PALETTES
        bne NotLastPalette
        ldx #$00                      //; Loop back to first palette
    NotLastPalette:
        stx UpdateColorPalette + 1

        //; Update the active color palette pointers
        lda ColorPalettePtr_Lo, x
        sta ReadColorPaletteValue + 1
        lda ColorPalettePtr_Hi, x
        sta ReadColorPaletteValue + 2
    NotNewColorCycle:

    UpdateNextColorEntry:
        //; Gradually update colors over time
        lda #$00
        bmi DontUpdateColors
        tax

        //; Set up the color based on the palette and height
        lda #$0b                      //; Default color
        ldy BarHeightToColorIndex, x
        bmi UseBaseColor
    ReadColorPaletteValue:
        lda ColorPaletteA, y          //; Get color from current palette
    UseBaseColor:
        sta BarColors, x

        //; Look up darker version for reflection
        tay
        lda DarkColorLookup, y
        sta BarColorsDark, x

        //; Move to next color entry
        lda UpdateNextColorEntry + 1
        clc
        adc #$01
        cmp #$50
        bne NotFinishedColorUpdate
        lda #$ff                      //; Mark as done when all colors updated
    NotFinishedColorUpdate:
        sta UpdateNextColorEntry + 1
    DontUpdateColors:

    //; Update sprite positions based on sine wave
    UpdateSpritePositions:
        ldx #$00                      //; Self-modified index

        //; Read position from sine table
        lda SpriteSine, x
        
        //; Set X positions for all sprites, incrementing by 48 pixels each time
        .for (var i = 0; i < 7; i++) {
            sta $d000 + (i * 2)
            .if (i != 6) {
                clc
                adc #$30              //; 48 pixels between each sprite
            }
        }

        //; Set high bit of X position (for positions > 255)
        lda SpriteSine + 128, x
        sta $d010

    //; Animate sprites
    AnimateSprites:
        ldy #$00                      //; Self-modified animation frame

        //; Calculate sprite frame based on frame counter
        lda FrameCounter
        lsr                           //; Divide by 4 to slow animation
        lsr
        and #$07                      //; 8 animation frames
        ora #SPRITE_INDEX_START       //; Add base sprite index
        
        //; Set sprite pointers for all sprites
        .for (var i = 0; i < 7; i++) {
            sta SPRITE_POINTERS + i
        }

        //; Update sine wave position for next frame
        stx UpdateSpritePositions + 1

        //; Set up next IRQ
        jsr MUSICPLAYER_NextIRQ

        //; Acknowledge the interrupt
        lda #$01
        sta $d01a
        sta $d019

        //; Restore registers and return
        pla
        tay
        pla
        tax
        pla
        rti

//; =============================================================================
//; MUSICPLAYER_IRQ_MusicOnly() - Secondary IRQ handler (music only)
//; =============================================================================
MUSICPLAYER_IRQ_MusicOnly:
        pha                           //; Save registers
        txa
        pha
        tya
        pha

        jsr MUSICPLAYER_PlayMusic     //; Play music

        jsr MUSICPLAYER_NextIRQ       //; Set up next IRQ

        //; Acknowledge the interrupt
        lda #$01
        sta $d01a
        sta $d019

        //; Restore registers and return
        pla
        tay
        pla
        tax
        pla
        rti

//; =============================================================================
//; MUSICPLAYER_UpdateADSREnvelopes() - Update envelope state for all channels
//; =============================================================================
MUSICPLAYER_UpdateADSREnvelopes:
        //; Process each SID channel
        ldx #2                              //; Start with channel 2 (0-based indexing)
    ProcessChannelLoop:
        stx CurrentChannel

        //; Check if channel is active by examining gate bit
        ldy Mul7, x
        lda SIDRegisterCopy + 4, y         //; Control register (D404/D40B/D412)
        and #1                             //; Isolate gate bit
        beq ChannelInRelease               //; If gate is off, force release phase

        //; Channel is active (gate on), determine which ADSR phase it's in
        lda ChannelADSRState, x
        cmp #ADSR_ATTACK
        bne !notAttack+
        jmp ProcessAttackPhase
    !notAttack:
        cmp #ADSR_DECAY
        bne !notDecay+
        jmp ProcessDecayPhase
    !notDecay:
        cmp #ADSR_SUSTAIN
        bne !notSustain+
        jmp ProcessSustainPhase
    !notSustain:
        
        //; If we get here, something is wrong - reset to attack phase
        lda #ADSR_ATTACK
        sta ChannelADSRState, x
        jmp ProcessAttackPhase

    ChannelInRelease:
        //; Force channel to release phase if gate bit is off
        lda #ADSR_RELEASE
        sta ChannelADSRState, x
        jmp ProcessReleasePhase

    //; -------------------------------------------------------------------------
    //; Attack Phase Processing
    //; -------------------------------------------------------------------------
    ProcessAttackPhase:
        //; Increment 16-bit frame counter
        inc ChannelFrameCountLo, x
        bne !nocarry+
        inc ChannelFrameCountHi, x
    !nocarry:

        //; Find all bars controlled by this channel and increase height
        ldy #NUM_FREQS_ON_SCREEN - 1
    !attackLoop:
        lda ChannelToFreqMap, y
        cmp CurrentChannel
        bne !nextBarAttack+

        //; Get attack step size based on attack value
        ldx CurrentChannel
        ldy Mul7, x
        lda SIDRegisterCopy + 5, y     //; Attack/Decay register
        lsr
        lsr
        lsr
        lsr                            //; Get attack value (0-15)
        tay
        
        //; Increase height using 24-bit precision (extension, lo, hi)
        //; Extension byte (lowest precision)
        clc
        lda RawBarHeightsExt, y
        adc AttackStepExt, y
        sta RawBarHeightsExt, y
        
        //; Low byte (middle precision)
        lda RawBarHeightsLo, y
        adc AttackStepLo, y
        sta RawBarHeightsLo, y
        
        //; High byte (highest precision)
        lda RawBarHeightsHi, y
        adc AttackStepHi, y
        sta RawBarHeightsHi, y

        //; Cap at maximum height if necessary
        cmp #<(TOP_SPECTROMETER_PIXELHEIGHT)
        bcc !nextBarAttack+
/*        bne !capHeight+
        lda RawBarHeightsLo, y
        cmp #<(TOP_SPECTROMETER_PIXELHEIGHT)
        bcc !nextBarAttack+*/

    !capHeight:
        //; Set to exact maximum height
        lda #<(TOP_SPECTROMETER_PIXELHEIGHT)
        sta RawBarHeightsHi, y
        lda #0
        sta RawBarHeightsLo, y
        sta RawBarHeightsExt, y

    !nextBarAttack:
        dey
        bpl !attackLoop-

        //; Compare 16-bit frame counters to check if attack phase is complete
        lda ChannelFrameCountLo, x
        cmp ChannelTotalFramesLo, x
        lda ChannelFrameCountHi, x
        sbc ChannelTotalFramesHi, x
        bcc !continueAttack+           //; If counter < total, continue
        
        //; Time is up - transition to decay phase
        lda #ADSR_DECAY
        sta ChannelADSRState, x
        
        //; Set up decay parameters
        ldy Mul7, x
        lda SIDRegisterCopy + 5, y     //; Attack/Decay register
        and #$0F                       //; Mask to get decay value (0-15)
        tay
        lda DecayFramesLo, y           //; Get frame count (low byte)
        sta ChannelTotalFramesLo, x
        lda DecayFramesHi, y           //; Get frame count (high byte)
        sta ChannelTotalFramesHi, x
        lda #0
        sta ChannelFrameCountLo, x
        sta ChannelFrameCountHi, x
        sta ChannelDivisorCounter, x
        
        //; Calculate and store sustain target height
        ldy Mul7, x
        lda SIDRegisterCopy + 6, y     //; Sustain/Release register
        lsr                           //; Get sustain value (0-15)
        lsr
        lsr
        lsr
        tay
        lda SustainConversion, y      //; Convert to height
        sta ChannelTargetHeights, x
        
        //; Ensure all bars reach max height at the end of attack phase
        ldy #NUM_FREQS_ON_SCREEN - 1
    !setMaxHeightLoop:
        lda ChannelToFreqMap, y
        cmp CurrentChannel
        bne !nextBarSetMax+
        
        //; Set this bar to maximum height
        lda #<(TOP_SPECTROMETER_PIXELHEIGHT)
        sta RawBarHeightsHi, y
        lda #0
        sta RawBarHeightsLo, y
        sta RawBarHeightsExt, y
        
    !nextBarSetMax:
        dey
        bpl !setMaxHeightLoop-
    
    !continueAttack:
        jmp NextChannel

    //; -------------------------------------------------------------------------
    //; Decay Phase Processing
    //; -------------------------------------------------------------------------
    ProcessDecayPhase:
        //; Increment frame counter
        inc ChannelFrameCountLo, x
        bne !nocarry+
        inc ChannelFrameCountHi, x
    !nocarry:

        //; For slow decay rates, we use a divider counter
        ldy Mul7, x
        lda SIDRegisterCopy + 5, y      //; Attack/Decay register
        and #$0F                        //; Get decay value (0-15)
        tay
        lda DecayDividers, y            //; Get divider for this decay rate
        cmp #1
        beq !noSkip+                    //; If divider is 1, no need to skip frames
        
        //; Handle slow decay by only updating every N frames
        inc ChannelDivisorCounter, x
        cmp ChannelDivisorCounter, x
        bne !skipDecayUpdate+
        
        //; Reset divisor counter when it matches the divider
        lda #0
        sta ChannelDivisorCounter, x
        jmp !noSkip+
        
    !skipDecayUpdate:
        //; Skip updating this frame for slow decay rates
        jmp SkipDecayUpdate
        
    !noSkip:
        //; Compare 16-bit counters
        lda ChannelFrameCountLo, x
        cmp ChannelTotalFramesLo, x
        lda ChannelFrameCountHi, x
        sbc ChannelTotalFramesHi, x
        bcc !continueDecay+            //; If counter < total, continue

        //; Time is up - transition to sustain phase
        lda #ADSR_SUSTAIN
        sta ChannelADSRState, x

        //; Set all bars to exact sustain height
        ldy #NUM_FREQS_ON_SCREEN - 1
    !findBarsLoop:
        lda ChannelToFreqMap, y
        cmp CurrentChannel
        bne !nextBar+

        //; Set this bar to sustain height
        lda ChannelTargetHeights, x
        sta RawBarHeightsHi, y
        lda #0
        sta RawBarHeightsLo, y
        sta RawBarHeightsExt, y

    !nextBar:
        dey
        bpl !findBarsLoop-
        jmp NextChannel

    !continueDecay:
        //; Find all bars controlled by this channel and decrease height
        ldy #NUM_FREQS_ON_SCREEN - 1
    !decayLoop:
        lda ChannelToFreqMap, y
        cmp CurrentChannel
        bne !nextBarDecay+

        //; Simple linear decay approach - decrement by 1 each time
        sec
        lda RawBarHeightsHi, y
        sbc #1                        //; Fixed decrement (adjust as needed)
        sta RawBarHeightsHi, y

        //; Check if reached sustain level
        cmp ChannelTargetHeights, x
        bcs !nextBarDecay+

        //; Set to exact sustain level
        lda ChannelTargetHeights, x
        sta RawBarHeightsHi, y
        lda #0
        sta RawBarHeightsLo, y
        sta RawBarHeightsExt, y

        //; Transition to sustain phase
        lda #ADSR_SUSTAIN
        sta ChannelADSRState, x

    !nextBarDecay:
        dey
        bpl !decayLoop-

    SkipDecayUpdate:
        jmp NextChannel

    //; -------------------------------------------------------------------------
    //; Sustain Phase Processing
    //; -------------------------------------------------------------------------
    ProcessSustainPhase:
        //; During Sustain phase, heights remain constant until gate bit is cleared
        //; Check if sustain level changed (e.g., modulated effect)
        ldy Mul7, x
        lda SIDRegisterCopy + 6, y     //; Sustain/Release register
        lsr                           //; Get sustain value (0-15)
        lsr
        lsr
        lsr
        tay
        lda SustainConversion, y      //; Convert to height
        
        //; Has sustain level changed? If so, update target and return to decay phase
        cmp ChannelTargetHeights, x
        beq SustainLevelUnchanged
        
        //; Sustain level changed - update target
        sta ChannelTargetHeights, x
        
        //; Find bars controlled by this channel and adjust height if needed
        ldy #NUM_FREQS_ON_SCREEN - 1
    !checkBarsLoop:
        lda ChannelToFreqMap, y
        cmp CurrentChannel
        bne !nextBarCheck+

        //; Set new sustain height immediately
        lda ChannelTargetHeights, x
        sta RawBarHeightsHi, y
        lda #0
        sta RawBarHeightsLo, y
        sta RawBarHeightsExt, y

    !nextBarCheck:
        dey
        bpl !checkBarsLoop-
        
    SustainLevelUnchanged:
        jmp NextChannel

    //; -------------------------------------------------------------------------
    //; Release Phase Processing
    //; -------------------------------------------------------------------------
    ProcessReleasePhase:
        //; Find all bars controlled by this channel and decrease height to zero
        ldy #NUM_FREQS_ON_SCREEN - 1
    !releaseLoop:
        lda ChannelToFreqMap, y
        cmp CurrentChannel
        bne !nextBarRelease+
        
        //; Check if bar already at zero height
        lda RawBarHeightsHi, y
        ora RawBarHeightsLo, y
        ora RawBarHeightsExt, y
        beq !nextBarRelease+             //; Skip if already zero
        
        //; Decrease height using release rate
        sec
        lda RawBarHeightsExt, y
        sbc #0                          //; No extension byte for release
        sta RawBarHeightsExt, y
        lda RawBarHeightsLo, y
        sbc ChannelReleaseLo, x
        sta RawBarHeightsLo, y
        lda RawBarHeightsHi, y
        sbc ChannelReleaseHi, x
        
        //; Check if reached zero or went negative
        bmi !setZeroHeight+
        sta RawBarHeightsHi, y
        
        //; Double check if reached zero
        ora RawBarHeightsLo, y
        ora RawBarHeightsExt, y
        bne !nextBarRelease+
        
    !setZeroHeight:
        //; Set height to exactly zero
        lda #0
        sta RawBarHeightsHi, y
        sta RawBarHeightsLo, y
        sta RawBarHeightsExt, y
        
    !nextBarRelease:
        dey
        bpl !releaseLoop-

    NextChannel:
        //; Move to next channel
        ldx CurrentChannel
        dex
        bmi !done+
        jmp ProcessChannelLoop
    !done:
        rts

//; =============================================================================
//; MUSICPLAYER_UpdateBarHeights() - Apply decay to all bar heights (per frame)
//; =============================================================================
MUSICPLAYER_UpdateBarHeights:
        //; First update ADSR envelopes for all channels
        jsr MUSICPLAYER_UpdateADSREnvelopes

        //; Convert raw heights to display heights using sine wave (for smoother visual)
        ldx #NUM_FREQS_ON_SCREEN - 1
    ConvertHeightsLoop:
        lda RawBarHeightsHi, x
        tay
        lda SoundBarSine, y
        sta FrequencyBarHeights, x
        dex
        bpl ConvertHeightsLoop

        rts

//; =============================================================================
//; MUSICPLAYER_SmoothBars() - Apply smoothing to create more natural visualization
//; =============================================================================
MUSICPLAYER_SmoothBars:

        ldx #0
    SmoothingLoop:

        lda FrequencyBarHeights - 1, x  //; Left neighbor
        clc
        adc FrequencyBarHeights + 1, x  //; Right neighbor
        lsr
        clc
        adc FrequencyBarHeights, x      //; Current bar
        lsr
        sta SmoothedBarHeights, x

        inx
        cpx #NUM_FREQS_ON_SCREEN
        bne SmoothingLoop
        
        rts

//; =============================================================================
//; MUSICPLAYER_DrawBars() - Draw the spectrometer bars on screen
//; =============================================================================
MUSICPLAYER_DrawBars:
        //; Draw each frequency bar with its reflection
        .for (var i = 0; i < NUM_FREQS_ON_SCREEN; i++) {
            //; Check if this bar changed since last frame
            ldx SmoothedBarHeights + i
            cpx PrevFrame_BarHeights + i
            beq !skipBarUpdate+

        !updateBar:
            //; Store new height for next comparison
            stx PrevFrame_BarHeights + i

            //; Draw the main spectrometer bars
            .for (var line = 0; line < TOP_SPECTROMETER_HEIGHT; line++) {
                lda MeterToCharValues - METER_TO_CHAR_PADDING + (line * 8), x
                sta SCREEN_ADDRESS + ((SPECTROMETER_START_LINE + line) * 40) + ((40 - NUM_FREQS_ON_SCREEN) / 2) + i
            }

            //; Draw the reflection effect (use division by 3 to make it smaller)
            lda Div3Table, x
            tay
            .for (var line = 0; line < BOTTOM_SPECTROMETER_HEIGHT; line++) {
                lda MeterToCharValues - 17 + (line * 8), y
                clc
                adc ReflectionOffset + 1     //; Add animation offset
                sta SCREEN_ADDRESS + ((SPECTROMETER_START_LINE + TOP_SPECTROMETER_HEIGHT + BOTTOM_SPECTROMETER_HEIGHT - 1 - line) * 40) + ((40 - NUM_FREQS_ON_SCREEN) / 2) + i
            }

        !skipBarUpdate:

            //; Always update the bar colors based on ADSR state
            //; Get the channel that controls this bar
            ldy ChannelToFreqMap + i
            cpy #3                           //; Check if valid channel (0-2)
            bcs !useStandardColor+

            //; Use color based on ADSR phase
            lda ChannelADSRState, y          //; Get ADSR state
            tax
            lda ADSRPhaseColors, x           //; Get color for this phase
            jmp !setColors+

        !useStandardColor:
            //; Use standard color based on height
            ldx SmoothedBarHeights + i
            lda BarColors, x
            
        !setColors:
            //; Remember the color for reflection calculation
            //; Set colors for main bars
            .for (var line = 0; line < TOP_SPECTROMETER_HEIGHT; line++) {
                sta $d800 + ((SPECTROMETER_START_LINE + line) * 40) + ((40 - NUM_FREQS_ON_SCREEN) / 2) + i
            }

            //; Set darker colors for reflection (using saved color)
            tax
            lda DarkColorLookup, x
            .for (var line = 0; line < BOTTOM_SPECTROMETER_HEIGHT; line++) {
                sta $d800 + ((SPECTROMETER_START_LINE + TOP_SPECTROMETER_HEIGHT + BOTTOM_SPECTROMETER_HEIGHT - 1 - line) * 40) + ((40 - NUM_FREQS_ON_SCREEN) / 2) + i
            }
        }

    //; Animate the reflection effect
    ReflectionOffset:
        lda #10
        sec
        sbc #10
        bne ReflectionOffsetOK
        lda #20                      //; Loop back to initial value
    ReflectionOffsetOK:
        sta ReflectionOffset + 1

        rts

//; =============================================================================
//; MUSICPLAYER_PlayMusic() - Handle SID music playback and register capture
//; =============================================================================
MUSICPLAYER_PlayMusic:
        //; Save current memory configuration
        lda $01
        pha
        
        //; Switch to bank with BASIC/KERNAL ROM visible
        lda #$30
        sta $01

        //; Call the music player routine
        jsr SIDPlay

        //; Save current SID registers to previous buffer, then update current
        .for (var i=24; i >= 0; i--) {
            lda SIDRegisterCopy + i
            sta PrevSIDRegisterCopy + i      //; Save current as previous
            lda $d400 + i
            sta SIDRegisterCopy + i          //; Update current
        }
        
        //; Restore memory configuration
        pla
        sta $01

        //; Write registers back to SID
        #if SID_REGISTER_REORDER_AVAILABLE
            //; Use custom register write order if available
            .for (var i = 0; i < SIDRegisterCount; i++) {
                lda SIDRegisterCopy + SIDRegisterOrder.get(i)
                sta $d400 + SIDRegisterOrder.get(i)
            }
        #else
            //; Standard register write order
            .for (var i = 0; i <= 24; i++) {
                lda SIDRegisterCopy + i
                sta $d400 + i
            }
        #endif

        //; Analyze SID registers and update visualizer
        jmp MUSICPLAYER_AnalyzeSIDRegisters

//; =============================================================================
//; MUSICPLAYER_AnalyzeSIDRegisters() - Analyze SID registers for visualization
//; =============================================================================
MUSICPLAYER_AnalyzeSIDRegisters:
        //; Process each of the three SID channels
        .for (var channel = 0; channel < 3; channel++) {
            //; Check if voice is active (gate bit set and not in noise mode)
            lda SIDRegisterCopy + (channel * 7) + 4  //; Control register
            bmi !skipChannelJMP+                     //; Skip if in noise mode
            and #1                                   //; Check gate bit
            bne !processChannel+                     //; Process if gate is on
        !skipChannelJMP:
            jmp !skipChannel+                        //; Skip if gate is off

        !processChannel:
            //; Get the frequency and map it to a bar position
            ldy SIDRegisterCopy + (channel * 7) + 1  //; hi-freq

            cpy #4
            bcc !useLoFreqTable+            //; Use lo-freq table if hi-freq < 4

        !useHiFreqTable:
            //; For higher frequencies, use the hi-freq table
            ldx FreqHiTable, y
            jmp !gotBarPosition+

!useLoFreqTable:
            //; For lower frequencies, combine lo and hi values
            ldx SIDRegisterCopy + (channel * 7) + 0  //; lo-freq
            lda LoFreqToLookupTable, x
            ora HiFreqToLookupTable, y
            tay
            ldx FreqLoTable, y
            
        !gotBarPosition:
            //; Check for note-on transition (gate bit turning from 0 to 1)
            lda PrevSIDRegisterCopy + (channel * 7) + 4  //; Previous control register
            and #1                                       //; Check previous gate bit
            bne !skipNoteOn+                             //; If gate was already on, skip
            
            //; This is a new note - start in Attack phase
            lda #ADSR_ATTACK
            sta ChannelADSRState + channel
            
            //; Set up attack parameters
            lda SIDRegisterCopy + (channel * 7) + 5  //; Get attack/decay register
            lsr
            lsr
            lsr
            lsr                                      //; Shift to get attack value (0-15)
            tay
            lda AttackFramesLo, y                    //; Get frame count (low byte)
            sta ChannelTotalFramesLo + channel
            lda AttackFramesHi, y                    //; Get frame count (high byte)
            sta ChannelTotalFramesHi + channel

            //; Reset frame counters and divisor counter
            lda #0
            sta ChannelFrameCountLo + channel
            sta ChannelFrameCountHi + channel
            sta ChannelDivisorCounter + channel
            
            //; Clear all previous mappings for this channel
            ldy #NUM_FREQS_ON_SCREEN - 1
        !clearMappingsLoop:
            lda ChannelToFreqMap, y
            cmp #channel
            bne !nextBar+
            
            //; Clear this mapping
            lda #ADSR_RELEASE    //; Mark as available
            sta ChannelToFreqMap, y
            
            //; Also reset the height for this bar
            lda #0
            sta RawBarHeightsHi, y
            sta RawBarHeightsLo, y
            sta RawBarHeightsExt, y
            
        !nextBar:
            dey
            bpl !clearMappingsLoop-

            //; Now assign the precise frequency bar for this channel
            lda #channel
            sta ChannelToFreqMap, x  //; X register contains the frequency bar position
            
            //; Initialize bar height to zero for this new note
            lda #0
            sta RawBarHeightsHi, x
            sta RawBarHeightsLo, x
            sta RawBarHeightsExt, x
            
            jmp !skipChannel+        //; Skip the rest of the processing since we've handled everything

        !skipNoteOn:
            //; Get attack/decay values
            lda SIDRegisterCopy + (channel * 7) + 5  //; attack(hi)/decay(lo)

            //; Get the sustain/release values
            ldy SIDRegisterCopy + (channel * 7) + 6  //; sustain(hi)/release(lo)
            
            //; Set up release rate for this channel
            sty !yStore+ + 1
            and #$0F                               //; Mask to get release value (0-15)
            tay
            lda ReleaseFramesLo, y                 //; Get frame count (low byte)
            sta ChannelTotalFramesLo + channel
            lda ReleaseFramesHi, y                 //; Get frame count (high byte)
            sta ChannelTotalFramesHi + channel
        !yStore:
            ldy #$00

            //; Also set up a simple release rate of 1 per frame
            //; (We'll handle the actual timing with frame counting)
            lda #1
            sta ChannelReleaseHi + channel
            lda #0
            sta ChannelReleaseLo + channel

            //; Record which channel controls this frequency bar
            lda #channel
            sta ChannelToFreqMap, x

        !skipChannel:
        }
        rts

//; =============================================================================
//; MUSICPLAYER_SetupSong() - Initialize music and display information
//; =============================================================================
MUSICPLAYER_SetupSong:

        //; Clear SID registers
        ldy #24
        lda #$00
    ClearSIDRegisters:
        sta $d400, y
        dey
        bpl ClearSIDRegisters

        //; Display song title
        ldy #SONG_TITLE_LENGTH - 1
    DisplaySongTitle:
        lda SongData_Title, y
        sta SCREEN_ADDRESS + ((SONG_TITLE_SCREEN_LINE + 0) * 40) + SONG_TITLE_PADDING, y
        ora #$80                      //; Reverse character for bottom row
        sta SCREEN_ADDRESS + ((SONG_TITLE_SCREEN_LINE + 1) * 40) + SONG_TITLE_PADDING, y
        dey
        bpl DisplaySongTitle

        //; Display artist name
        ldy #ARTIST_NAME_LENGTH - 1
    DisplayArtistName:
        lda SongData_Artist, y
        sta SCREEN_ADDRESS + ((ARTIST_NAME_SCREEN_LINE + 0) * 40) + ARTIST_NAME_PADDING, y
        ora #$80                      //; Reverse character for bottom row
        sta SCREEN_ADDRESS + ((ARTIST_NAME_SCREEN_LINE + 1) * 40) + ARTIST_NAME_PADDING, y
        dey
        bpl DisplayArtistName

        //; Initialize the SID player
        lda #$00                      //; Start with song #0
        jmp SIDInit

//; =============================================================================
//; PreDemoSetup() - Initialize system for stable raster IRQs
//; =============================================================================
.align 256
PreDemoSetup:
        //; From Spindle by lft, www.linusakesson.net/software/spindle/
        //; Prepare CIA #1 timer B to compensate for interrupt jitter.
        //; Also initialize d01a and dc02.

        //; Wait for stable raster
        bit $d011
        bmi *-3

        bit $d011
        bpl *-3

        ldx $d012
        inx
    ResyncRaster:
        cpx $d012
        bne *-3

        ldy #0
        sty $dc07
        lda #62
        sta $dc06
        iny
        sty $d01a
        dey
        dey
        sty $dc02
        cmp (0,x)
        cmp (0,x)
        cmp (0,x)
        lda #$11
        sta $dc0f
        txa
        inx
        inx
        cmp $d012
        bne ResyncRaster

        //; Set up IRQ system
        lda #$7f
        sta $dc0d
        sta $dd0d
        lda $dc0d
        lda $dd0d

        //; Wait for stable raster
        bit $d011
        bpl *-3
        bit $d011
        bmi *-3

        //; Enable raster IRQs
        lda #$01
        sta $d01a

        rts

//; =============================================================================
//; Include necessary system files
//; =============================================================================
.import source "../INC/NMIFix.asm"
.import source "../INC/RasterLineTiming.asm"

EndCodeSegment:

//; =============================================================================
//; DATA SEGMENTS - Character and sprite data
//; =============================================================================

//; Water reflection sprites
* = WATERSPRITES_ADDRESS
StartWaterSprites:
    .fill watersprites_map.getSize(), watersprites_map.get(i)
EndWaterSprites:

//; Character set for bars
* = CHARSET_ADDRESS
StartCharSet:
    .fill charset_map.getSize(), charset_map.get(i)
EndCharSet:

//; =============================================================================
//; Memory usage summary
//; =============================================================================
    .print "* $" + toHexString(StartCodeSegment) + "-$" + toHexString(EndCodeSegment - 1) + " Code Segment"
    .print "* $" + toHexString(StartLocalData) + "-$" + toHexString(EndLocalData - 1) + " Local Data"
    .print "* $" + toHexString(StartCharSet) + "-$" + toHexString(EndCharSet - 1) + " Character Set"
    .print "* $" + toHexString(StartWaterSprites) + "-$" + toHexString(EndWaterSprites - 1) + " Water Sprites"