// =============================================================================
//                         DEFAULT WITH LOGO
//           Text Details Player with 9-row PETSCII Logo at Top
// =============================================================================
//
// Memory Map:
//   DATA_ADDRESS + $000-$0FF  : Data Block (metadata, config)
//   CODE_ADDRESS              : Main Code
//   LOGO_SCREEN_ADDRESS       : PETSCII logo screen codes (360 bytes)
//   LOGO_COLOR_ADDRESS        : PETSCII logo color data (360 bytes)
//
// The logo occupies screen rows 0-8. Info text is in rows 9-24.
// An IRQ split at the row 9 boundary switches $d018 to change charset:
//   - Logo area uses the matched PETSCII charset (uppercase or lowercase ROM)
//   - Info area uses the lowercase/uppercase mixed ROM charset ($1800)
// =============================================================================

.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()

// =============================================================================
// CONFIGURATION
// =============================================================================

.const LOGO_ROWS                    = 9
.const LOGO_COLS                    = 40
.const LOGO_CELLS                   = LOGO_ROWS * LOGO_COLS // 360
.const INFO_START_ROW               = 9
.const TOTAL_ROWS                   = 25

// =============================================================================
// VIC BANK / SCREEN / CHARSET LAYOUT
//
// The player runs from whichever VIC bank its code was assembled into
// (LOAD_ADDRESS / $4000). The screen and both charsets (the logo charset and
// the info charset, switched by the raster split) live inside that bank, so a
// SID that loads as low as $0400 is never overwritten by the display.
//
//   Bank 0   : screen $0400        logo cs $2000  info cs $2800
//   Bank 1-3 : screen <bank>+$3000 logo cs <bank>+$2000  info cs <bank>+$2800
//
// Both charsets are copied into RAM at init (the character ROM is only
// VIC-visible in banks 0 and 2, so banks 1 and 3 need a copy). A custom info
// font, if injected, overwrites the info charset after the intro.
// =============================================================================

.var VIC_BANK           = floor(LOAD_ADDRESS / $4000)
.var VIC_BANK_ADDRESS   = VIC_BANK * $4000

.var SCREEN_RAM         = VIC_BANK_ADDRESS + $3000
.var LOGO_CHARSET_RAM   = VIC_BANK_ADDRESS + $2000
.var INFO_CHARSET_RAM   = VIC_BANK_ADDRESS + $2800
.var ScreenD018Nibble   = 12    // $3000 / $400
.if (VIC_BANK == 0) {
    .eval SCREEN_RAM       = $0400
    .eval ScreenD018Nibble = 1      // $0400 / $400
}
.var LogoCharsetNibble  = 4     // $2000 / $800
.var InfoCharsetNibble  = 5     // $2800 / $800
.var D018_LOGO          = (ScreenD018Nibble * 16) + (LogoCharsetNibble * 2)
.var D018_INFO          = (ScreenD018Nibble * 16) + (InfoCharsetNibble * 2)
.var D018_VALUE         = D018_INFO     // intro draws with the lowercase info charset

// Raster line where the split occurs (first visible line + rows * 8 pixels)
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
fontMode:
    .byte $00                           // Byte $71: 0=info uses ROM charset, 1=info uses injected RAM charset
    .fill $100 - $72, $00              // Fill rest

* = CODE_ADDRESS "Main Code"

    jmp Initialize

// =============================================================================
// DISPLAY LAYOUT - Info in rows 9-24 (16 rows, one item per line)
// =============================================================================
//
// All left-column colons aligned at col 14, values start at col 16.
// Right-column (row 21 only) colon at col 30, value at col 32.
//
//   Row  9:      Song Name (centered, 32 chars)
//   Row 10:      Artist (centered, 32 chars)
//   Row 11:      Copyright (centered, 32 chars)
//   Row 12: ----------------------------------------
//   Row 13:        Memory: $xxxx-$xxxx
//   Row 14:          Init: $xxxx
//   Row 15:          Play: $xxxx
//   Row 16:      ZP Usage: xxxxxxxxxxxxxxxxxxxxxxxx
//   Row 17:         Songs: xx
//   Row 18:         Clock: PAL
//   Row 19:           SID: 6581
//   Row 20: ----------------------------------------
//   Row 21:          Time: 00:00          Song: 01/xx
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

// Row positions - all colons at col 14, values at col 16
.var Display_Title_X                = 4
.var Display_Title_Y                = 9

.var Display_Artist_X               = 4
.var Display_Artist_Y               = 10

.var Display_Copyright_X            = 4
.var Display_Copyright_Y            = 11

.var Display_Separator1_Y           = 12

.var Display_Memory_X               = 8     // "Memory: " (8 chars) → colon at col 14
.var Display_Memory_Y               = 13

.var Display_Init_X                 = 10    // "Init: " (6 chars) → colon at col 14
.var Display_Init_Y                 = 14

.var Display_Play_X                 = 10    // "Play: " (6 chars) → colon at col 14
.var Display_Play_Y                 = 15

.var Display_ZP_X                   = 6     // "ZP Usage: " (10 chars) → colon at col 14
.var Display_ZP_Y                   = 16

.var Display_Songs_X                = 9     // "Songs: " (7 chars) → colon at col 14
.var Display_Songs_Y                = 17

.var Display_Clock_X                = 9     // "Clock: " (7 chars) → colon at col 14
.var Display_Clock_Y                = 18

.var Display_SID_X                  = 11    // "SID: " (5 chars) → colon at col 14
.var Display_SID_Y                  = 19

.var Display_Separator2_Y           = 20

.var Display_Time_X                 = 10    // "Time: " (6 chars) → colon at col 14
.var Display_Time_Y                 = 21

.var Display_Song_X                 = 26    // "Song: " (6 chars) → colon at col 30
.var Display_Song_Y                 = 21

.var Display_Separator3_Y           = 22

.var Display_Controls_Line1_X       = 3
.var Display_Controls_Line1_Y       = 23

.var Display_Controls_Line2_X       = 3
.var Display_Controls_Line2_Y       = 24

.const COLOR_RAM = $d800
.const ROW_WIDTH = 40

// =============================================================================
// INCLUDES
// =============================================================================

#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR
#define INCLUDE_TIMER

#define INCLUDE_RASTER_TIMING_CODE
.var DEFAULT_RASTERTIMING_Y = 250

// Make the shared intro effect draw into this player's in-bank screen/charset
// instead of the fixed bank-0 $0400 screen.
#define BANK_AWARE_EFFECT

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

    // Point the VIC at our bank and load the info charset before anything is
    // drawn, so the intro renders from in-bank RAM.
    jsr SetupVICBank
    jsr CopyInfoRomCharset
    lda #D018_VALUE
    sta $d018

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

    // Copy the requested (uppercase/lowercase) ROM charset into the logo
    // charset RAM. The logo always uses the in-bank D018_LOGO value.
    jsr CopyLogoRomCharset
    lda #D018_LOGO
    sta LogoD018Value + 1

    // Copy logo screen codes to screen RAM (rows 0-8)
    jsr CopyLogoToScreen

    // Copy logo color data to color RAM (rows 0-8)
    jsr CopyLogoColors

    // If a custom 1x1 font has been injected, copy it into VIC-bank-0 RAM at
    // $2000 and switch the info-area $d018 value over to it. Otherwise leave
    // the SplitIRQ defaults pointing at the lowercase ROM charset.
    jsr SetupCharset

    // Set initial D018 for logo area
    lda #D018_LOGO
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

    lda FastForwardActive
    beq MainLoop

    // Fast-forward mode: call SIDPlay multiple times from main loop
    // IRQs continue firing normally, so D018 splits keep working
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

    // Fast-forward ended
    lda #$00
    sta $d020
    sta callCount + 1

    jmp MainLoop

// =============================================================================
// COPY LOGO DATA TO SCREEN AND COLOR RAM
// =============================================================================

CopyLogoToScreen:
    // Copy 360 bytes of screen codes from staging to SCREEN_RAM
    // We do this in two chunks: 256 + 104
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
    // Copy 360 bytes of color data from staging to $D800
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
// DRAW STATIC INFO (rows 9-24, one item per line)
// =============================================================================

DrawStaticInfo:
    // Clear info area (rows 9-24 = 16 rows = 640 bytes)
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
    ldx #0
!loop2:
    lda #$20
    sta SCREEN_RAM + (INFO_START_ROW * ROW_WIDTH) + 512, x
    lda #0
    sta COLOR_RAM + (INFO_START_ROW * ROW_WIDTH) + 512, x
    inx
    cpx #(TOTAL_ROWS - INFO_START_ROW) * ROW_WIDTH - 512
    bne !loop2-

    // Row 9: Title
    ldx #Display_Title_X
    ldy #Display_Title_Y
    jsr SetCursor
    lda #<SongName
    ldy #>SongName
    ldx #Display_Title_Colour
    jsr PrintString

    // Row 10: Artist
    ldx #Display_Artist_X
    ldy #Display_Artist_Y
    jsr SetCursor
    lda #<ArtistName
    ldy #>ArtistName
    ldx #Display_Artist_Colour
    jsr PrintString

    // Row 11: Copyright
    ldx #Display_Copyright_X
    ldy #Display_Copyright_Y
    jsr SetCursor
    lda #<CopyrightInfo
    ldy #>CopyrightInfo
    ldx #Display_Copyright_Colour
    jsr PrintString

    // Row 12: Separator
    ldx #0
    ldy #Display_Separator1_Y
    jsr DrawSeparator

    // Row 13: Memory
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

    // Row 14: Init
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

    // Row 15: Play
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

    // Row 16: ZP Usage
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
    jsr PrintString

    // Row 17: Songs
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

    // Row 18: Clock
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

    // Row 19: SID
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

    // Rows 23-24: Controls
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
// DRAW CONTROLS
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
    // Time value at col 16 (Display_Time_X=10 + "Time: "=6 chars)
    ldx #16
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

    // Song value at col 32 (Display_Song_X=26 + "Song: "=6 chars)
    ldx #32
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
    lda #D018_LOGO             // Self-modified at init (kept for symmetry)
    sta $d018

    // Skip music playback if fast-forward is active (MainLoop handles it)
    lda FastForwardActive
    bne !done+

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
    // Set up the split IRQ at the row 9 boundary
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

    // Switch to info charset (immediate value self-modified by SetupCharset
    // when a custom RAM charset has been injected).
InfoD018Value:
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
// TEXT DATA
// =============================================================================

MemoryLabel:        .text "Memory: "
                    .byte 0
InitLabel:          .text "Init: "
                    .byte 0
PlayLabel:          .text "Play: "
                    .byte 0
ZPLabel:            .text "ZP Usage: "
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

// Control labels
ControlsLine1:      .text "F1=Timing Bar  SPACE=Fast Fwd"
                    .byte 0
ControlsLine2:      .text "+/-=Next/Prev 1-9,A-Z=Select"
                    .byte 0

// =============================================================================
// VIC BANK SETUP
//
// Switch the VIC to VIC_BANK by writing the (inverted) bank bits into the low
// two bits of CIA2 $dd00, after making sure those lines are outputs in $dd02.
// =============================================================================

SetupVICBank:
    lda $dd02
    ora #$03
    sta $dd02
    lda $dd00
    and #$fc
    ora #(3 - VIC_BANK)
    sta $dd00
    rts

// =============================================================================
// CHARSET SETUP
//
// The character ROM is only reachable while I/O is banked out, so each copy
// flips $01 to $33 (with interrupts already disabled) and back to $35.
//
//   CopyInfoRomCharset : lowercase ROM ($D800) -> INFO_CHARSET_RAM
//   CopyLogoRomCharset : uppercase ($D000) or lowercase ($D800) ROM, chosen by
//                        logoCharsetType, -> LOGO_CHARSET_RAM
//   SetupCharset       : overlay the injected custom font (fontMode != 0) on
//                        top of the info charset; ROM mode keeps the copy made
//                        by CopyInfoRomCharset.
// =============================================================================

CopyInfoRomCharset:
    lda #$33
    sta $01
    lda #$d8                    // lowercase ROM at $D800
    ldx #>INFO_CHARSET_RAM
    jsr Copy2K
    lda #$35
    sta $01
    rts

CopyLogoRomCharset:
    lda #$33
    sta $01
    lda logoCharsetType         // 0 = uppercase ($D000), non-zero = lowercase ($D800)
    bne !lower+
    lda #$d0
    jmp !go+
!lower:
    lda #$d8
!go:
    ldx #>LOGO_CHARSET_RAM
    jsr Copy2K
    lda #$35
    sta $01
    rts

// Copy 2K (8 pages) of page-aligned data. A = source high byte, X = dest high
// byte (both low bytes are $00). Self-modifying.
Copy2K:
    sta Copy2K_src + 2
    stx Copy2K_dst + 2
    ldy #8
!page:
    ldx #0
!byte:
Copy2K_src:
    lda $0000, x
Copy2K_dst:
    sta $0000, x
    inx
    bne !byte-
    inc Copy2K_src + 2
    inc Copy2K_dst + 2
    dey
    bne !page-
    rts

SetupCharset:
    lda fontMode
    beq !done+

    ldx #0
!loop:
    .for (var i = 0; i < 3; i++) {
        lda EmbeddedCharset + (i * 256), x
        sta INFO_CHARSET_RAM + (i * 256), x
    }
    inx
    bne !loop-
!done:
    rts

// =============================================================================
// LOGO DATA at fixed offsets (filled at build time by prg-builder.js)
// =============================================================================

* = LOAD_ADDRESS + $0D00 "Logo Screen Data"
LogoScreenData:
    .fill LOGO_CELLS, $20              // 360 bytes of screen codes (default: spaces)

* = LOAD_ADDRESS + $0E68 "Logo Color Data"
LogoColorData:
    .fill LOGO_CELLS, $00              // 360 bytes of color data (default: black)

// =============================================================================
// EMBEDDED CHARSET DATA (768 bytes; populated by prg-builder when not ROM mode)
// =============================================================================

* = LOAD_ADDRESS + $1000 "Embedded Charset"
EmbeddedCharset:
    .fill $300, $00

// =============================================================================
// END OF FILE
// =============================================================================
