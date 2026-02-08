// =============================================================================
//                       DEFAULT WITH PETSCII LOGO
//           Text Details Player with 12-row PETSCII Logo at Top
// =============================================================================
//
// Memory Map:
//   DATA_ADDRESS + $000-$0FF  : Data Block (metadata, config)
//   CODE_ADDRESS              : Main Code
//   LOGO_SCREEN_ADDRESS       : PETSCII logo screen codes (480 bytes)
//   LOGO_COLOR_ADDRESS        : PETSCII logo color data (480 bytes)
//
// The logo occupies screen rows 0-11. Info text is in rows 12-24.
// An IRQ split at the row 12 boundary switches $d018 to change charset:
//   - Logo area uses the matched PETSCII charset (uppercase or lowercase ROM)
//   - Info area uses the lowercase/uppercase mixed ROM charset ($1800)
// =============================================================================

.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()

// =============================================================================
// CONFIGURATION
// =============================================================================

.const LOGO_ROWS                    = 12
.const LOGO_COLS                    = 40
.const LOGO_CELLS                   = LOGO_ROWS * LOGO_COLS // 480
.const INFO_START_ROW               = 12
.const TOTAL_ROWS                   = 25

// D018 values: screen at $0400 = bank 1
// Uppercase ROM charset at $1000 = charset bank 2: (1 << 4) | (2 << 1) = $14
// Lowercase ROM charset at $1800 = charset bank 3: (1 << 4) | (3 << 1) = $16
.const D018_LOGO_UPPERCASE          = $14
.const D018_LOGO_LOWERCASE          = $16
.const D018_INFO                    = $16   // Info always uses lowercase/mixed ROM

// Raster line where the split occurs (first visible line + 12 rows * 8 pixels)
// PAL: first visible line ~51, so row 12 starts at 51 + 96 = 147
.const SPLIT_RASTERLINE             = 50 + (LOGO_ROWS * 8) - 1

// =============================================================================
// DATA BLOCK
// =============================================================================

* = DATA_ADDRESS "Data Block"
    .fill $0D, $00                      // Reserved bytes 0-12
borderColor:
    .byte $00                           // Byte $0D: Border color
backgroundColor:
    .byte $00                           // Byte $0E: Background color
    .fill $70 - $0F, $00               // Reserved bytes $0F-$6F
logoCharsetType:
    .byte $01                           // Byte $70: Logo charset (0=uppercase, 1=lowercase)
    .fill $100 - $71, $00              // Fill rest

* = CODE_ADDRESS "Main Code"

    jmp Initialize

// =============================================================================
// DISPLAY LAYOUT - Squeezed info in rows 12-24
// =============================================================================
//
// Two-column layout with aligned colons:
//   Left column:  colons at col 12, values at col 14
//   Right column: colons at col 28, values at col 30
//
//   Row 12:      Song Name (centered, 32 chars)
//   Row 13:      Artist (centered, 32 chars)
//   Row 14:      Copyright (centered, 32 chars)
//   Row 15: ----------------------------------------
//   Row 16:       Memory: $xxxx-$xxxx
//   Row 17:         Init: $xxxx       Play: $xxxx
//   Row 18:        Songs: xx         Clock: PAL
//   Row 19:          SID: 6581          ZP: xxxxxxxx
//   Row 20: ----------------------------------------
//   Row 21:         Time: 00:00       Song: 01/xx
//   Row 22: ----------------------------------------
//   Row 23:   F1=Timing Bar   SPACE=Fast Forward
//   Row 24:   +/-=Next/Prev  1-9,A-Z=Select Song

.var Display_Title_Colour           = $01  // White
.var Display_Artist_Colour          = $0c  // Grey
.var Display_Copyright_Colour       = $0c  // Grey
.var Display_Separators_Colour      = $0b  // Dark Grey
.var Display_InfoTitles_Colour      = $0e  // Light Blue
.var Display_InfoValues_Colour      = $01  // White
.var Display_ControlsTitle_Colour   = $02  // Red
.var Display_ControlsInfo_Colour    = $04  // Purple

// Row positions - left column (colon at col 12, value at col 14)
.var Display_Title_X                = 4
.var Display_Title_Y                = 12

.var Display_Artist_X               = 4
.var Display_Artist_Y               = 13

.var Display_Copyright_X            = 4
.var Display_Copyright_Y            = 14

.var Display_Separator1_Y           = 15

.var Display_Memory_X               = 6     // "Memory:" colon at col 12
.var Display_Memory_Y               = 16

.var Display_Init_X                 = 8     // "Init:" colon at col 12
.var Display_Init_Y                 = 17

.var Display_Play_X                 = 24    // "Play:" colon at col 28
.var Display_Play_Y                 = 17

.var Display_Songs_X                = 7     // "Songs:" colon at col 12
.var Display_Songs_Y                = 18

.var Display_Clock_X                = 23    // "Clock:" colon at col 28
.var Display_Clock_Y                = 18

.var Display_SID_X                  = 9     // "SID:" colon at col 12
.var Display_SID_Y                  = 19

.var Display_ZP_X                   = 26    // "ZP:" colon at col 28
.var Display_ZP_Y                   = 19

.var Display_Separator2_Y           = 20

.var Display_Time_X                 = 8     // "Time:" colon at col 12
.var Display_Time_Y                 = 21

.var Display_Song_X                 = 24    // "Song:" colon at col 28
.var Display_Song_Y                 = 21

.var Display_Separator3_Y           = 22

.var Display_Controls_Line1_X       = 3
.var Display_Controls_Line1_Y       = 23

.var Display_Controls_Line2_X       = 3
.var Display_Controls_Line2_Y       = 24

.const SCREEN_RAM = $0400
.const COLOR_RAM = $d800
.const ROW_WIDTH = 40

// =============================================================================
// INCLUDES
// =============================================================================

#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR

#define INCLUDE_RASTER_TIMING_CODE
.var DEFAULT_RASTERTIMING_Y = 250

.import source "../INC/Common.asm"
.import source "../INC/keyboard.asm"
.import source "../INC/musicplayback.asm"
.import source "../INC/LinkedWithEffect.asm"

// =============================================================================
// INITIALIZATION
// =============================================================================

Initialize:

    sei

    lda #$35
    sta $01

    jsr RunLinkedWithEffect

    jsr InitKeyboard

    lda SongNumber
    sta CurrentSong

    lda #0
    sta TimerSeconds
    sta TimerMinutes
    sta FrameCounter
    sta ShowRasterBars

    lda ClockType
    beq !pal+
    lda #60
    jmp !store+
!pal:
    lda #50
!store:
    sta FramesPerSecond

    jsr ClearScreen

    // Set border and background colors
    lda borderColor
    sta $d020
    lda backgroundColor
    sta $d021

    // Determine logo D018 value from charset type byte
    lda logoCharsetType
    beq !uppercase+
    lda #D018_LOGO_LOWERCASE
    jmp !storeD018+
!uppercase:
    lda #D018_LOGO_UPPERCASE
!storeD018:
    sta LogoD018Value + 1

    // Copy logo screen codes to screen RAM (rows 0-11)
    jsr CopyLogoToScreen

    // Copy logo color data to color RAM (rows 0-11)
    jsr CopyLogoColors

    // Set initial D018 for logo area
    lda #D018_LOGO_LOWERCASE
    sta $d018

    jsr PopulateMetadata
    jsr DrawStaticInfo

    lda CurrentSong
    tax
    tay
    jsr SIDInit

    jsr NMIFix

    // Set up the main IRQ (top of screen, for logo D018)
    lda #<TopIRQ
    sta $fffe
    lda #>TopIRQ
    sta $ffff

    lda #$7f
    sta $dc0d
    lda $dc0d
    lda #$01
    sta $d01a
    lda #$01
    sta $d019

    // Raster at line 250 (in vblank, before screen starts)
    lda #250
    sta $d012
    lda #$1b
    sta $d011

    cli

MainLoop:
    jsr CheckKeyboard
    jmp MainLoop

// =============================================================================
// COPY LOGO DATA TO SCREEN AND COLOR RAM
// =============================================================================

CopyLogoToScreen:
    // Copy 480 bytes of screen codes from staging to $0400
    // We do this in two chunks: 256 + 224
    ldx #0
!loop1:
    lda LogoScreenData, x
    sta SCREEN_RAM, x
    inx
    bne !loop1-

    ldx #0
!loop2:
    lda LogoScreenData + 256, x
    sta SCREEN_RAM + 256, x
    inx
    cpx #(LOGO_CELLS - 256)
    bne !loop2-

    rts

CopyLogoColors:
    // Copy 480 bytes of color data from staging to $D800
    ldx #0
!loop1:
    lda LogoColorData, x
    sta COLOR_RAM, x
    inx
    bne !loop1-

    ldx #0
!loop2:
    lda LogoColorData + 256, x
    sta COLOR_RAM + 256, x
    inx
    cpx #(LOGO_CELLS - 256)
    bne !loop2-

    rts

// =============================================================================
// RUNTIME VARIABLES
// =============================================================================

TimerSeconds:     .byte $00
TimerMinutes:     .byte $00
FrameCounter:     .byte $00
FramesPerSecond:  .byte $32

TempStorage:      .byte $00
CursorX:          .byte $00
CursorY:          .byte $00

// =============================================================================
// POPULATE METADATA
// =============================================================================

PopulateMetadata:

    lda SIDInit+1
    sta InitAddress
    lda SIDInit+2
    sta InitAddress+1

    lda SIDPlay+1
    sta PlayAddress
    lda SIDPlay+2
    sta PlayAddress+1

    lda NumSongs
    bne !skip+
    lda #1
    sta NumSongs
!skip:

    rts

// =============================================================================
// DRAW STATIC INFO (squeezed layout, rows 12-24)
// =============================================================================

DrawStaticInfo:
    // Clear only the info area (rows 12-24) with spaces and set color to 0
    ldx #0
!loop:
    lda #$20
    sta SCREEN_RAM + (INFO_START_ROW * ROW_WIDTH), x
    sta SCREEN_RAM + (INFO_START_ROW * ROW_WIDTH) + 256, x
    lda #0
    sta COLOR_RAM + (INFO_START_ROW * ROW_WIDTH), x
    sta COLOR_RAM + (INFO_START_ROW * ROW_WIDTH) + 256, x
    inx
    bne !loop-
    // Clear remaining bytes (13 rows * 40 = 520 - 256 = 264 bytes)
    ldx #0
!loop2:
    lda #$20
    sta SCREEN_RAM + (INFO_START_ROW * ROW_WIDTH) + 512, x
    lda #0
    sta COLOR_RAM + (INFO_START_ROW * ROW_WIDTH) + 512, x
    inx
    cpx #(TOTAL_ROWS - INFO_START_ROW) * ROW_WIDTH - 512
    bne !loop2-

    // Row 12: Title
    ldx #Display_Title_X
    ldy #Display_Title_Y
    jsr SetCursor
    lda #<SongName
    ldy #>SongName
    ldx #Display_Title_Colour
    jsr PrintString

    // Row 13: Artist
    ldx #Display_Artist_X
    ldy #Display_Artist_Y
    jsr SetCursor
    lda #<ArtistName
    ldy #>ArtistName
    ldx #Display_Artist_Colour
    jsr PrintString

    // Row 14: Copyright
    ldx #Display_Copyright_X
    ldy #Display_Copyright_Y
    jsr SetCursor
    lda #<CopyrightInfo
    ldy #>CopyrightInfo
    ldx #Display_Copyright_Colour
    jsr PrintString

    // Row 15: Separator
    ldx #0
    ldy #Display_Separator1_Y
    jsr DrawSeparator

    // Row 16: Memory (full row)
    ldx #Display_Memory_X
    ldy #Display_Memory_Y
    jsr SetCursor
    lda #<MemoryLabel
    ldy #>MemoryLabel
    ldx #Display_InfoTitles_Colour
    jsr PrintString
    ldx #Display_InfoValues_Colour
    lda #'$'
    jsr PrintChar
    lda LoadAddress+1
    jsr PrintHexByte
    lda LoadAddress
    jsr PrintHexByte
    lda #'-'
    jsr PrintChar
    lda #'$'
    jsr PrintChar
    lda EndAddress+1
    jsr PrintHexByte
    lda EndAddress
    jsr PrintHexByte

    // Row 17: Init (left) + Play (right)
    ldx #Display_Init_X
    ldy #Display_Init_Y
    jsr SetCursor
    lda #<InitLabel
    ldy #>InitLabel
    ldx #Display_InfoTitles_Colour
    jsr PrintString
    ldx #Display_InfoValues_Colour
    lda #'$'
    jsr PrintChar
    lda InitAddress+1
    jsr PrintHexByte
    lda InitAddress
    jsr PrintHexByte

    ldx #Display_Play_X
    ldy #Display_Play_Y
    jsr SetCursor
    lda #<PlayLabel
    ldy #>PlayLabel
    ldx #Display_InfoTitles_Colour
    jsr PrintString
    ldx #Display_InfoValues_Colour
    lda #'$'
    jsr PrintChar
    lda PlayAddress+1
    jsr PrintHexByte
    lda PlayAddress
    jsr PrintHexByte

    // Row 18: Songs (left) + Clock (right)
    ldx #Display_Songs_X
    ldy #Display_Songs_Y
    jsr SetCursor
    lda #<SongsLabel
    ldy #>SongsLabel
    ldx #Display_InfoTitles_Colour
    jsr PrintString
    ldx #Display_InfoValues_Colour
    lda NumSongs
    jsr PrintTwoDigits_NoPreZeros

    ldx #Display_Clock_X
    ldy #Display_Clock_Y
    jsr SetCursor
    lda #<ClockLabel
    ldy #>ClockLabel
    ldx #Display_InfoTitles_Colour
    jsr PrintString
    lda ClockType
    beq !pal+
    lda #<NTSCText
    ldy #>NTSCText
    jmp !printClock+
!pal:
    lda #<PALText
    ldy #>PALText
!printClock:
    ldx #Display_InfoValues_Colour
    jsr PrintString

    // Row 19: SID (left) + ZP (right)
    ldx #Display_SID_X
    ldy #Display_SID_Y
    jsr SetCursor
    lda #<SIDLabel
    ldy #>SIDLabel
    ldx #Display_InfoTitles_Colour
    jsr PrintString
    lda SIDModel
    beq !old+
    lda #<SID8580Text
    ldy #>SID8580Text
    jmp !printSID+
!old:
    lda #<SID6581Text
    ldy #>SID6581Text
!printSID:
    ldx #Display_InfoValues_Colour
    jsr PrintString

    ldx #Display_ZP_X
    ldy #Display_ZP_Y
    jsr SetCursor
    lda #<ZPLabel
    ldy #>ZPLabel
    ldx #Display_InfoTitles_Colour
    jsr PrintString
    ldx #Display_InfoValues_Colour
    lda #<ZPUsageData
    ldy #>ZPUsageData
    jsr PrintStringShort

    // Row 20: Separator
    ldx #0
    ldy #Display_Separator2_Y
    jsr DrawSeparator

    // Row 21: Time (left) + Song (right, only if multi-song)
    ldx #Display_Time_X
    ldy #Display_Time_Y
    jsr SetCursor
    lda #<TimeLabel
    ldy #>TimeLabel
    ldx #Display_InfoTitles_Colour
    jsr PrintString

    lda NumSongs
    cmp #2
    bcc !skipSong+

    ldx #Display_Song_X
    ldy #Display_Song_Y
    jsr SetCursor
    lda #<CurrentSongLabel
    ldy #>CurrentSongLabel
    ldx #Display_InfoTitles_Colour
    jsr PrintString

!skipSong:
    // Row 22: Separator
    ldx #0
    ldy #Display_Separator3_Y
    jsr DrawSeparator

    // Rows 23-24: Controls (compact, 2 lines)
    jmp DrawControls

// =============================================================================
// DRAW SEPARATOR LINE
// =============================================================================

DrawSeparator:

    jsr SetCursor

    ldy #39
    ldx #Display_Separators_Colour
!loop:
    lda #$2d
    jsr PrintChar
    dey
    bpl !loop-
    rts

// =============================================================================
// DRAW CONTROLS (compact)
// =============================================================================

DrawControls:

    ldx #Display_Controls_Line1_X
    ldy #Display_Controls_Line1_Y
    jsr SetCursor
    lda #<ControlsLine1
    ldy #>ControlsLine1
    ldx #Display_ControlsInfo_Colour
    jsr PrintString

    lda NumSongs
    cmp #2
    bcc !done+

    ldx #Display_Controls_Line2_X
    ldy #Display_Controls_Line2_Y
    jsr SetCursor
    lda #<ControlsLine2
    ldy #>ControlsLine2
    ldx #Display_ControlsInfo_Colour
    jsr PrintString

!done:
    rts

// =============================================================================
// UPDATE DYNAMIC INFO
// =============================================================================

UpdateDynamicInfo:
    // Time value at col 14 (Display_Time_X=8 + "Time: "=6 chars)
    ldx #14
    ldy #Display_Time_Y
    jsr SetCursor

    ldx #Display_InfoValues_Colour
    lda TimerMinutes
    jsr PrintTwoDigits
    lda #':'
    jsr PrintChar
    lda TimerSeconds
    jsr PrintTwoDigits

    lda NumSongs
    cmp #2
    bcc !skip+

    // Song value at col 30 (Display_Song_X=24 + "Song: "=6 chars)
    ldx #30
    ldy #Display_Song_Y
    jsr SetCursor

    ldx #Display_InfoValues_Colour
    lda CurrentSong
    clc
    adc #1
    jsr PrintTwoDigits
    lda #'/'
    jsr PrintChar
    lda NumSongs
    jsr PrintTwoDigits

!skip:
    rts

// =============================================================================
// TIMER UPDATE
// =============================================================================

UpdateTimer:
    inc FrameCounter

    lda FrameCounter
    cmp FramesPerSecond
    bcc !done+

    lda #0
    sta FrameCounter

    inc TimerSeconds
    lda TimerSeconds
    cmp #60
    bcc !done+

    lda #0
    sta TimerSeconds
    inc TimerMinutes

    lda TimerMinutes
    cmp #100
    bcc !done+
    lda #99
    sta TimerMinutes
    lda #59
    sta TimerSeconds

!done:
    rts

// =============================================================================
// PRINT ROUTINES
// =============================================================================

ClearScreen:
    ldx #0
!loop:
    lda #' '
    sta SCREEN_RAM,x
    sta SCREEN_RAM+256,x
    sta SCREEN_RAM+512,x
    sta SCREEN_RAM+768,x
    inx
    bne !loop-
    rts

ScreenLinePtrsLo:    .fill 25, <(SCREEN_RAM + (i * 40))
ScreenLinePtrsHi:    .fill 25, >(SCREEN_RAM + (i * 40))

SetCursor:

    txa
    clc
    adc ScreenLinePtrsLo, y
    sta PrintPtr + 1
    sta ColorPtr + 1

    lda ScreenLinePtrsHi, y
    adc #0
    sta PrintPtr + 2
    and #$03
    ora #$d8
    sta ColorPtr + 2

    rts

PrintString:
    sta StringReadPtr + 1
    sty StringReadPtr + 2

    ldy #0
!loop:
StringReadPtr:
    lda $abcd,y
    beq !done+

    jsr PrintChar

    iny
    cpy #32
    bne !loop-

!done:
    rts

// Short string print (max 10 chars) for squeezed ZP usage display
PrintStringShort:
    sta StringReadPtr2 + 1
    sty StringReadPtr2 + 2

    ldy #0
!loop:
StringReadPtr2:
    lda $abcd,y
    beq !done+

    jsr PrintChar

    iny
    cpy #10
    bne !loop-

!done:
    rts

PrintChar:

PrintPtr:
    sta $abcd

ColorPtr:
    stx $abcd

    inc PrintPtr + 1
    bne !skip+
    inc PrintPtr + 2
!skip:

    inc ColorPtr + 1
    bne !skip+
    inc ColorPtr + 2
!skip:

    rts

PrintHexByte:
    pha
    lsr
    lsr
    lsr
    lsr
    jsr PrintHexNibble
    pla
    and #$0f
    jmp PrintHexNibble

PrintHexNibble:
    cmp #10
    bcc !digit+
    clc
    adc #'A'-10
    jmp !print+
!digit:
    clc
    adc #'0'
!print:
    jmp PrintChar

TopDigit: .fill 100, (i / 10) + '0'
BottomDigit: .fill 100, mod(i, 10) + '0'

PrintTwoDigits:
    tay
    lda TopDigit, y
    jsr PrintChar

    lda BottomDigit, y
    jmp PrintChar

PrintTwoDigits_NoPreZeros:
    tay
    lda TopDigit, y
    cmp #$30
    beq !skip+
    jsr PrintChar
!skip:

    lda BottomDigit, y
    jmp PrintChar

// =============================================================================
// INTERRUPT HANDLERS - Two-part IRQ for D018 split
// =============================================================================

// TopIRQ fires during vblank (rasterline 250)
// Sets D018 for the logo area and plays music
TopIRQ:
    pha
    txa
    pha
    tya
    pha

    // Set D018 for logo area (PETSCII charset)
LogoD018Value:
    lda #D018_LOGO_LOWERCASE    // Self-modified at init based on charset type
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
    lda FFCallCounter
    bne !ffCallLoop-

    jsr UpdateTimer
    jsr UpdateDynamicInfo

    jsr CheckSpaceKey
    lda FastForwardActive
    bne !ffFrameLoop-

    lda #$00
    sta $d020
    sta callCount + 1
    jmp !done+

!normalPlay:
callCount:
    ldx #0
    inx
    cpx NumCallsPerFrame
    bne !justPlay+

    jsr UpdateTimer
    jsr UpdateDynamicInfo
    ldx #0

!justPlay:
    stx callCount + 1

    jsr JustPlayMusic

!done:
    // Set up the split IRQ at the row 12 boundary
    lda #SPLIT_RASTERLINE
    sta $d012
    lda $d011
    and #$7f
    sta $d011

    lda #<SplitIRQ
    sta $fffe
    lda #>SplitIRQ
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

// SplitIRQ fires at the boundary between logo and info area
// Switches D018 to the info charset
SplitIRQ:
    pha
    txa
    pha
    tya
    pha

    // Small delay to ensure we're past the boundary
    ldx #2
!delay:
    dex
    bpl !delay-

    // Switch to info charset
    lda #D018_INFO
    sta $d018

    // Set up the top IRQ again for next frame (rasterline 250)
    lda #250
    sta $d012
    lda $d011
    and #$7f
    ora #$00
    sta $d011

    lda #<TopIRQ
    sta $fffe
    lda #>TopIRQ
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

// =============================================================================
// TEXT DATA (compact labels for squeezed layout)
// =============================================================================

MemoryLabel:        .text "Memory: "
                    .byte 0
InitLabel:          .text "Init: "
                    .byte 0
PlayLabel:          .text "Play: "
                    .byte 0
ZPLabel:            .text "ZP: "
                    .byte 0
SongsLabel:         .text "Songs: "
                    .byte 0
ClockLabel:         .text "Clock: "
                    .byte 0
SIDLabel:           .text "SID: "
                    .byte 0
PALText:            .text "PAL"
                    .byte 0
NTSCText:           .text "NTSC"
                    .byte 0
SID6581Text:        .text "6581"
                    .byte 0
SID8580Text:        .text "8580"
                    .byte 0
TimeLabel:          .text "Time: "
                    .byte 0
CurrentSongLabel:   .text "Song: "
                    .byte 0

// Control labels (2 lines)
ControlsLine1:      .text "F1=Timing Bar  SPACE=Fast Fwd"
                    .byte 0
ControlsLine2:      .text "+/-=Next/Prev 1-9,A-Z=Select"
                    .byte 0

// =============================================================================
// LOGO DATA at fixed offsets (filled at build time by prg-builder.js)
// Placed at known addresses so the web app can inject converted PETSCII data.
// =============================================================================

* = LOAD_ADDRESS + $0D00 "Logo Screen Data"
LogoScreenData:
    .fill LOGO_CELLS, $20              // 480 bytes of screen codes (default: spaces)

* = LOAD_ADDRESS + $0EE0 "Logo Color Data"
LogoColorData:
    .fill LOGO_CELLS, $00              // 480 bytes of color data (default: black)

// =============================================================================
// END OF FILE
// =============================================================================
