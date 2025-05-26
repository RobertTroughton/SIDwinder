//; =============================================================================
//; RaistlinBars - SID Music Visualizer with Spectrum Analyzer Effect
//; (c) 2018, Raistlin of Genesis*Project
//; Revised and optimized version with improved smoothing algorithm
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
.var TOP_SPECTROMETER_PIXELHEIGHT = 127
.var TOP_SPECTROMETER_HEIGHT = ceil(TOP_SPECTROMETER_PIXELHEIGHT / 8)
.var BOTTOM_SPECTROMETER_PIXELHEIGHT = 24
.var BOTTOM_SPECTROMETER_HEIGHT = ceil(BOTTOM_SPECTROMETER_PIXELHEIGHT / 8)
.var SPECTROMETER_START_LINE = 25 - (TOP_SPECTROMETER_HEIGHT + BOTTOM_SPECTROMETER_HEIGHT)

//; =============================================================================
//; MEMORY CONFIGURATION
//; =============================================================================
.var BASE_BANK = 3                                                              //; VIC bank (3=c000-ffff)
.var BASE_BANK_ADDRESS = (BASE_BANK * $4000)                                    //; Start address of the bank
.var SCREEN_BANK0 = 12                                                          //; Screen memory location (Bank+[3800,3bff])
.var SCREEN_BANK1 = 13                                                          //; Screen memory location (Bank+[3800,3bff])
.var CHAR_BANK_FONT = 7                                                         //; Character set location (Bank+[3800,3fff])
.var SCREEN_ADDRESS0 = (BASE_BANK_ADDRESS + (SCREEN_BANK0 * $400))
.var SCREEN_ADDRESS1 = (BASE_BANK_ADDRESS + (SCREEN_BANK1 * $400))
.var SPRITE_POINTERS0 = (SCREEN_ADDRESS0 + $3F8)
.var SPRITE_POINTERS1 = (SCREEN_ADDRESS1 + $3F8)
.var D018Value0 = ((SCREEN_BANK0 * 16) + (CHAR_BANK_FONT * 2))
.var D018Value1 = ((SCREEN_BANK1 * 16) + (CHAR_BANK_FONT * 2))
.var CHARSET_ADDRESS = (BASE_BANK_ADDRESS + (CHAR_BANK_FONT * $800))
.var SPRITE_INDEX_START = $80
.var WATERSPRITES_ADDRESS = (BASE_BANK_ADDRESS + (SPRITE_INDEX_START * $40))

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
        .byte D018Value0                                 //; D018: Memory setup
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
    PrevFrame_BarHeights_Frame0:     .fill NUM_FREQS_ON_SCREEN, 255  //; Previous bar heights
    PrevFrame_BarHeights_Frame1:     .fill NUM_FREQS_ON_SCREEN, 255  //; Previous bar heights
    PrevFrame_BarColors:      .fill NUM_FREQS_ON_SCREEN, 255  //; Previous bar colors

//;  -------------------------------------------------------------------------
//; ADSR Conversion Tables
//; These tables convert the SID's ADSR values to visual representations
//; 
//; Sustain: Converts sustain value (0-15) to visible bar height (35-125)
//;  - Formula: (sustain / 16) * 6 + 35
//;  - Higher sustain values in SID = taller bars in visualization
//;
//; Release: Converts release value (0-15) to bar decay rate
//;  - Formula: mod(release, 16) * 96 + 768
//;  - Stored as 16-bit value (hi/lo bytes)
//;  - Higher release values = faster visual decay of bars

    SustainConversion:        .fill 16, (i * (TOP_SPECTROMETER_PIXELHEIGHT - 1)) / 15

    ReleaseConversionLo:      .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 1   ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 2   ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 3   ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 4   ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 6   ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 9   ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 11  ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 12  ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 15  ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 38  ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 75  ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 120 ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 150 ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 450 ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 750 ) + 32)
                              .byte <(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 1200) + 32)

    ReleaseConversionHi:      .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 1   ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 2   ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 3   ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 4   ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 6   ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 9   ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 11  ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 12  ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 15  ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 38  ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 75  ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 120 ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 150 ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 450 ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 750 ) + 32)
                              .byte >(((TOP_SPECTROMETER_PIXELHEIGHT * 256.0) / 1200) + 32)

//;  -------------------------------------------------------------------------

    Mul64:                    .fill 4, i * 64

    //; Sine wave data for sprite movement
    SpriteSine:               .fill spritesine_bin.getSize(), spritesine_bin.get(i)
    
    //; Frequency lookup tables
    FreqTable:                .fill freqtable_bin.getSize(), freqtable_bin.get(i)

    //; Analyzer data buffers with padding bytes for smoothing
    ChannelToFreqMap:               .fill NUM_FREQS_ON_SCREEN, 0                        //; Maps screen positions to SID channels

    .byte $00
    FrequencyBarHeights:                .fill NUM_FREQS_ON_SCREEN, 0                        //; High bytes of raw bar heights - includes pad-byte before and after for simpler smoothing code
    .byte $00

    FrequencyBarHeightsLo:                .fill NUM_FREQS_ON_SCREEN, 0                        //; Low bytes of raw bar heights

    //; Channel-specific release rates
    ChannelReleaseHi:               .fill 3, 0                                          //; High bytes of release rates per channel
    ChannelReleaseLo:               .fill 3, 0                                          //; Low bytes of release rates per channel

    //; New buffer for smoothed bar heights
    SmoothedBarHeights:             .fill NUM_FREQS_ON_SCREEN, 0                        //; Smoothed bar heights
    
    //; SID register ghost copy for analysis
    SIDRegisterCopy:            .fill 32, 0    //; Copy of SID registers 

    //; Color lookup tables
    DarkColorLookup:            .byte $00, $0c, $09, $0e, $06, $09, $0b, $08
                                .byte $02, $0b, $02, $0b, $0b, $05, $06, $0c

    TuneBackupData:              .fill AddressesThatChange.size(), $00

    //; Color palettes for the visualization
    .var NUM_COLOR_PALETTES = 3
    .var NUM_COLORS_PER_PALETTE = 8
    ColorPalettes:
                                  .byte $09, $04, $05, $05, $0d, $0d, $0f, $01
                                  .byte $09, $06, $0e, $0e, $03, $03, $0f, $01
                                  .byte $09, $02, $0a, $0a, $07, $07, $0f, $01

    //; Pointers to color palettes
    ColorPalettePtr_Lo:         .fill NUM_COLOR_PALETTES, <(ColorPalettes + i * NUM_COLORS_PER_PALETTE)
    ColorPalettePtr_Hi:         .fill NUM_COLOR_PALETTES, >(ColorPalettes + i * NUM_COLORS_PER_PALETTE)

    .byte $12, $01, $09, $13, $14, $0c, $09, $0e
    //; Color mapping table based on bar height
    BarHeightToColorIndex:      .byte $ff
                                .fill TOP_SPECTROMETER_PIXELHEIGHT + 4, max(0, min(floor(((i * NUM_COLORS_PER_PALETTE) + (random() * (TOP_SPECTROMETER_PIXELHEIGHT * 0.8) - (TOP_SPECTROMETER_PIXELHEIGHT * 0.4))) / TOP_SPECTROMETER_PIXELHEIGHT), NUM_COLORS_PER_PALETTE - 1))

    //; Color tables for the visualization
    BarColors:                  .fill TOP_SPECTROMETER_PIXELHEIGHT, $0b  //; Main colors for bars

    //; Calculate which IRQ should update the analyzer
    .var VISUALIZER_UPDATE_IRQ = 0

    //; Character mapping for meter visualization
    .align 256
        .fill TOP_SPECTROMETER_PIXELHEIGHT, 224
    MeterToCharValues:
        .fill 8, 225 + i
        .fill TOP_SPECTROMETER_PIXELHEIGHT, 233

    D018Values:                     .byte D018Value0, D018Value1
    CurrentDB:                      .byte 0

    //; Offsets into this table. Normally we should offset both by -7 .. but we use -8 for the mainbars so that we get that nice divider-line for free
    .var MAINBARS_OFFSET = TOP_SPECTROMETER_PIXELHEIGHT - 8
    .var REFLECTION_OFFSET = BOTTOM_SPECTROMETER_PIXELHEIGHT - 7

EndLocalData:

//; Pre-calculate addresses for frequency tables
.var FreqHiTable = FreqTable + (0 * 256)
.var FreqLoTable = FreqTable + (1 * 256)

//; =============================================================================
//; Macros
//; =============================================================================
.macro CallSubroutinesButAvoidCallingThemOnTopOfThemselves(list_of_subroutines_to_call) {
are_the_subroutines_still_running_lda: lda #0
    bne !+
    // Protect against us being invoked again on top of our own invocation
    lda #1
    sta are_the_subroutines_still_running_lda + 1

    .for (var i = 0; i < list_of_subroutines_to_call.size(); i++) {
        jsr list_of_subroutines_to_call.get(i)
    }

    lda #0
    sta are_the_subroutines_still_running_lda + 1
!:
}

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
        lda ColorPalettes, y         //; Get color from palette
    UseDefaultColor:
        sta BarColors, x             //; Set main color
        inx
        cpx #TOP_SPECTROMETER_PIXELHEIGHT + 2
        bne InitBarColorsLoop

        //; Clear screen and color memory
        ldx #$00
        lda #$20                     //; Space character
    ClearScreenLoop:
        sta $d800 + (0 * 256), x
        sta $d800 + (1 * 256), x
        sta $d800 + (2 * 256), x
        sta $d800 + (3 * 256), x
        sta SCREEN_ADDRESS0 + (0 * 256), x
        sta SCREEN_ADDRESS0 + (1 * 256), x
        sta SCREEN_ADDRESS0 + (2 * 256), x
        sta SCREEN_ADDRESS0 + (3 * 256), x
        sta SCREEN_ADDRESS1 + (0 * 256), x
        sta SCREEN_ADDRESS1 + (1 * 256), x
        sta SCREEN_ADDRESS1 + (2 * 256), x
        sta SCREEN_ADDRESS1 + (3 * 256), x
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

        cli                           //; Enable interrupts
    
        //; Initialize music and visualizer
        jsr MUSICPLAYER_SetupSong

        //; Main program loop - waits for visualization updates
    MainLoop:
        lda UpdateVisualizerSignal    //; Check if update is needed
        beq MainLoop                  //; If not, keep waiting

        jsr MUSICPLAYER_SmoothBars    //; Apply smoothing to the bars
        jsr MUSICPLAYER_DrawBars      //; Draw the visualization
        
        lda #$00
        sta UpdateVisualizerSignal    //; Clear update flag

        lda CurrentDB
        eor #$01
        sta CurrentDB

        jmp MainLoop                  //; Continue looping

//; =============================================================================
//; MUSICPLAYER_NextIRQ() - Set up the next IRQ in the chain
//; =============================================================================
MUSICPLAYER_NextIRQ:
        ldx #$00                      //; IRQ counter (self-modified)
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
        lda $01
        pha
        lda #$35
        sta $01

        ldy CurrentDB
        lda D018Values, y
        cmp $d018
        beq !skip+
        sta $d018

    !skip:

        jsr MUSICPLAYER_PlayMusic     //; Play music

        jsr DoAllTheVisualizerThings  //; Do all the visualizer things

        //; Set up next IRQ
        jsr MUSICPLAYER_NextIRQ

        //; Acknowledge the interrupt
        lda #$01
        sta $d01a
        sta $d019

        //; Restore registers and return
        pla
        sta $01
        pla
        tay
        pla
        tax
        pla
        rti

//; =============================================================================
//; DoAllTheVisualizerThings() - Subroutine that does all the visualizer things
//; =============================================================================
DoAllTheVisualizerThings:


        inc UpdateVisualizerSignal
        jsr MUSICPLAYER_UpdateBarHeights  //; Apply decay to bar heights


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
        lda ColorPalettes, y          //; Get color from current palette
    UseBaseColor:
        sta BarColors, x

        //; Move to next color entry
        lda UpdateNextColorEntry + 1
        clc
        adc #$01
        cmp #TOP_SPECTROMETER_PIXELHEIGHT + 4 + 1
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
            sta SPRITE_POINTERS0 + i
            sta SPRITE_POINTERS1 + i
        }

        //; Update sine wave position for next frame
        stx UpdateSpritePositions + 1
        rts

//; =============================================================================
//; MUSICPLAYER_IRQ_MusicOnly() - Secondary IRQ handler (music only)
//; =============================================================================
MUSICPLAYER_IRQ_MusicOnly:
        pha                           //; Save registers
        txa
        pha
        tya
        pha
        lda $01
        pha
        lda #$35
        sta $01

        jsr MUSICPLAYER_PlayMusic     //; Play music

        jsr MUSICPLAYER_NextIRQ       //; Set up next IRQ

        //; Acknowledge the interrupt
        lda #$01
        sta $d01a
        sta $d019

        //; Restore registers and return
        pla
        sta $01
        pla
        tay
        pla
        tax
        pla
        rti

//; =============================================================================
//; MUSICPLAYER_UpdateBarHeights() - Apply decay to all bar heights (per frame)
//; =============================================================================
MUSICPLAYER_UpdateBarHeights:

        //; Apply decay to each frequency bar based on its release rate
        ldx #NUM_FREQS_ON_SCREEN - 1
    DecayBarsLoop:
        //; Get the channel associated with this bar
        ldy ChannelToFreqMap, x

        //; Subtract release value from the bar height (16-bit)
        sec
        lda FrequencyBarHeightsLo, x
        sbc ChannelReleaseLo, y
        sta FrequencyBarHeightsLo, x
        lda FrequencyBarHeights, x
        sbc ChannelReleaseHi, y
        bpl BarHeightNotNegative

        //; If height went negative, clamp to zero
        lda #$00
        sta FrequencyBarHeightsLo, x
    BarHeightNotNegative:
        sta FrequencyBarHeights, x

        dex
        bpl DecayBarsLoop

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

    //; Update $d800 colour screen first!
        ldy #NUM_FREQS_ON_SCREEN
    !loop:
        dey
        bpl !continue+
        jmp !FinishedColourUpdates+

    !continue:
        ldx SmoothedBarHeights, y
        lda BarColors, x
        cmp PrevFrame_BarColors, y
        beq !loop-
        sta PrevFrame_BarColors, y
        .for (var line = 0; line < TOP_SPECTROMETER_HEIGHT; line++) {
            sta $d800 + ((SPECTROMETER_START_LINE + line) * 40) + ((40 - NUM_FREQS_ON_SCREEN) / 2), y
        }
        tax
        lda DarkColorLookup, x
        .for (var line = 0; line < BOTTOM_SPECTROMETER_HEIGHT; line++) {
            sta $d800 + ((SPECTROMETER_START_LINE + TOP_SPECTROMETER_HEIGHT + BOTTOM_SPECTROMETER_HEIGHT - 1 - line) * 40) + ((40 - NUM_FREQS_ON_SCREEN) / 2), y
        }
        jmp !loop-

    !FinishedColourUpdates:

        lda CurrentDB
        bne UpdateFrame0
        jmp UpdateFrame1

    UpdateFrame0:

    //; Update screen with bars...
        ldy #NUM_FREQS_ON_SCREEN

    !loop:
        dey
        bpl !continue+

        rts

    !continue:
        lda SmoothedBarHeights, y
        cmp PrevFrame_BarHeights_Frame0, y
        beq !loop-

    !updateBar:
        //; Store new height for next comparison
        sta PrevFrame_BarHeights_Frame0, y
        tax

        .for (var line = 0; line < TOP_SPECTROMETER_HEIGHT; line++) {
            lda MeterToCharValues - MAINBARS_OFFSET + (line * 8), x
            sta SCREEN_ADDRESS0 + ((SPECTROMETER_START_LINE + line) * 40) + ((40 - NUM_FREQS_ON_SCREEN) / 2), y
        }
        txa
        lsr
        lsr
        tax
        .for (var line = 0; line < BOTTOM_SPECTROMETER_HEIGHT; line++) {
            lda MeterToCharValues - REFLECTION_OFFSET + (line * 8), x
            clc
            adc #10
            sta SCREEN_ADDRESS0 + ((SPECTROMETER_START_LINE + TOP_SPECTROMETER_HEIGHT + BOTTOM_SPECTROMETER_HEIGHT - 1 - line) * 40) + ((40 - NUM_FREQS_ON_SCREEN) / 2), y
        }
        jmp !loop-

    UpdateFrame1:

    //; Update screen with bars...
        ldy #NUM_FREQS_ON_SCREEN

    !loop:
        dey
        bpl !continue+

        rts

    !continue:
        lda SmoothedBarHeights, y
        cmp PrevFrame_BarHeights_Frame1, y
        beq !loop-

    !updateBar:
        //; Store new height for next comparison
        sta PrevFrame_BarHeights_Frame1, y
        tax

        .for (var line = 0; line < TOP_SPECTROMETER_HEIGHT; line++) {
            lda MeterToCharValues - MAINBARS_OFFSET + (line * 8), x
            sta SCREEN_ADDRESS1 + ((SPECTROMETER_START_LINE + line) * 40) + ((40 - NUM_FREQS_ON_SCREEN) / 2), y
        }
        txa
        lsr
        lsr
        tax
        .for (var line = 0; line < BOTTOM_SPECTROMETER_HEIGHT; line++) {
            lda MeterToCharValues - REFLECTION_OFFSET + (line * 8), x
            clc
            adc #20
            sta SCREEN_ADDRESS1 + ((SPECTROMETER_START_LINE + TOP_SPECTROMETER_HEIGHT + BOTTOM_SPECTROMETER_HEIGHT - 1 - line) * 40) + ((40 - NUM_FREQS_ON_SCREEN) / 2), y
        }
        jmp !loop-

BackupAddresses:
        .for (var i = 0; i < AddressesThatChange.size(); i++)
        {
            lda AddressesThatChange.get(i)
            sta TuneBackupData + i
        }
        rts
        
RestoreAddresses:
        .for (var i = 0; i < AddressesThatChange.size(); i++)
        {
            lda TuneBackupData + i
            sta AddressesThatChange.get(i)
        }
        rts
       


//; =============================================================================
//; MUSICPLAYER_PlayMusic() - Handle SID music playback and register capture
//; =============================================================================
MUSICPLAYER_PlayMusic:

        //; Save current memory configuration
        lda $01
        pha
        
        //; first call is our "clean" call which will actually play the music
        //; we backup and restore everything so that the 2nd call can be made safely
        jsr BackupAddresses
        jsr SIDPlay
        jsr RestoreAddresses

        lda #$30
        sta $01
        jsr SIDPlay
        .for (var i=24; i >= 0; i--) {
            lda $d400 + i
            sta SIDRegisterCopy + i
        }
        pla
        sta $01

        //; Write registers back to SID
/*        #if SID_REGISTER_REORDER_AVAILABLE
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
        #endif*/

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
            bmi !skipChannel+                //; Skip if in noise mode
            and #1                                  //; Check gate bit
            bne !processChannel+            //; Process if gate is on
            jmp !skipChannel+               //; Skip if gate is off

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
            txa
            lsr
            lsr
            ora Mul64, y
            tay
            ldx FreqLoTable, y
            
        !gotBarPosition:
            //; Get the sustain/release values
            lda SIDRegisterCopy + (channel * 7) + 6  //; sustain(hi)/release(lo)
            pha
            and #$0f
            tay
            //; Set up release rate for this channel
            lda ReleaseConversionHi, y
            sta ChannelReleaseHi + channel
            lda ReleaseConversionLo, y
            sta ChannelReleaseLo + channel

            pla
            lsr
            lsr
            lsr
            lsr
            tay

            //; Check if we should update the bar height
            lda SustainConversion, y                //; Get sustain height 
            cmp FrequencyBarHeights + 0, x              //; Compare to current height
            bcc !skipChannel+              //; Skip if current is higher

        !updateBarHeight:
            //; Set new bar height
            sta FrequencyBarHeights + 0, x
            lda #0
            sta FrequencyBarHeightsLo + 0, x
            
            //; Record which channel controls this frequency bar
            lda #channel
            sta ChannelToFreqMap + 0, x

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
        sta SCREEN_ADDRESS0 + ((SONG_TITLE_SCREEN_LINE + 0) * 40) + SONG_TITLE_PADDING, y
        sta SCREEN_ADDRESS1 + ((SONG_TITLE_SCREEN_LINE + 0) * 40) + SONG_TITLE_PADDING, y
        ora #$80                      //; Reverse character for bottom row
        sta SCREEN_ADDRESS0 + ((SONG_TITLE_SCREEN_LINE + 1) * 40) + SONG_TITLE_PADDING, y
        sta SCREEN_ADDRESS1 + ((SONG_TITLE_SCREEN_LINE + 1) * 40) + SONG_TITLE_PADDING, y
        dey
        bpl DisplaySongTitle

        //; Display artist name
        ldy #ARTIST_NAME_LENGTH - 1
    DisplayArtistName:
        lda SongData_Artist, y
        sta SCREEN_ADDRESS0 + ((ARTIST_NAME_SCREEN_LINE + 0) * 40) + ARTIST_NAME_PADDING, y
        sta SCREEN_ADDRESS1 + ((ARTIST_NAME_SCREEN_LINE + 0) * 40) + ARTIST_NAME_PADDING, y
        ora #$80                      //; Reverse character for bottom row
        sta SCREEN_ADDRESS0 + ((ARTIST_NAME_SCREEN_LINE + 1) * 40) + ARTIST_NAME_PADDING, y
        sta SCREEN_ADDRESS1 + ((ARTIST_NAME_SCREEN_LINE + 1) * 40) + ARTIST_NAME_PADDING, y
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
