// =============================================================================
//                               DEFAULT
//                         Text Details Player
// =============================================================================

.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()

* = DATA_ADDRESS "Data Block"
    .fill $100, $00

* = CODE_ADDRESS "Main Code"

    jmp Initialize

.var Display_Title_Colour           = $01
.var Display_Artist_Colour          = $0c
.var Display_Copyright_Colour       = $0c
.var Display_Separators_Colour      = $0b
.var Display_InfoTitles_Colour      = $0e
.var Display_InfoValues_Colour      = $01
.var Display_ControlsTitle_Colour   = $02
.var Display_ControlsInfo_Colour    = $04

.var Display_Title_X                = 4    
.var Display_Title_Y                = 0

.var Display_Artist_X               = 4
.var Display_Artist_Y               = 1

.var Display_Copyright_X            = 4
.var Display_Copyright_Y            = 2

.var Display_Separator1_Y           = 5

.var Display_Memory_X               = 9 + 2
.var Display_Memory_Y               = 6

.var Display_InitLabel_X            = 9 + 4
.var Display_InitLabel_Y            = 7

.var Display_PlayLabel_X            = 9 + 4
.var Display_PlayLabel_Y            = 8

.var Display_ZP_X                   = 9 + 0
.var Display_ZP_Y                   = 9
.var Display_Songs_X                = 9 + 3
.var Display_Songs_Y                = 10
.var Display_Clock_X                = 9 + 3
.var Display_Clock_Y                = 11
.var Display_SID_X                  = 9 + 5
.var Display_SID_Y                  = 12

.var Display_Separator2_Y           = 13

.var Display_Time_X                 = 9 + 4
.var Display_Time_Y                 = 14
.var Display_Song_X                 = 9 + 4
.var Display_Song_Y                 = 15

.var Display_Separator3_Y           = 16

.var Display_ControlsTitle_X        = 13
.var Display_ControlsTitle_Y        = 19
.var Display_Controls_F1_X          = 8
.var Display_Controls_F1_Y          = 21
.var Display_Controls_SPACE_X       = 6
.var Display_Controls_SPACE_Y       = 22
.var Display_Controls_Navigation_X  = 8
.var Display_Controls_Navigation_Y  = 23
.var Display_Controls_SongSelectKeys_X = 8
.var Display_Controls_SongSelectKeys_Y = 24

.const SCREEN_RAM = $0400
.const COLOR_RAM = $d800
.const ROW_WIDTH = 40

//; =============================================================================
//; INCLUDES
//; =============================================================================

#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR

#define INCLUDE_RASTER_TIMING_CODE
.var DEFAULT_RASTERTIMING_Y = 250

.import source "../INC/Common.asm"
.import source "../INC/keyboard.asm"
.import source "../INC/musicplayback.asm"

// =============================================================================
// INITIALIZATION ENTRY POINT
// =============================================================================

Initialize:

    sei

    lda #$35
    sta $01

    jsr VSync

    lda #$00
    sta $d011
    sta $d020

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
    
    lda #$00
    sta $d020
    sta $d021

    lda #$16
    sta $d018

    jsr PopulateMetadata

    jsr DrawStaticInfo
    
    lda CurrentSong
    tax
    tay
    jsr SIDInit

    jsr NMIFix

    jsr init_D011_D012_values

    lda #<MusicIRQ
    sta $fffe
    lda #>MusicIRQ
    sta $ffff

    lda #$7f
    sta $dc0d
    lda $dc0d
    lda #$01
    sta $d01a
    lda #$01
    sta $d019

    ldx #0
    jsr set_d011_and_d012

    lda #$1b
    sta $d011

    cli

MainLoop:
    jsr CheckKeyboard
    jmp MainLoop

// =============================================================================
// RUNTIME VARIABLES (stored as local data, not in zero page)
// =============================================================================

TimerSeconds:     .byte $00
TimerMinutes:     .byte $00
FrameCounter:     .byte $00
FramesPerSecond:  .byte $32

TempStorage:      .byte $00
CursorX:          .byte $00
CursorY:          .byte $00

// =============================================================================
// POPULATE METADATA (called by linker or filled by PRG builder)
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
// DRAW STATIC INFORMATION
// =============================================================================

DrawStaticInfo:
    ldx #0
!loop:
    lda #$20
    sta SCREEN_RAM,x
    sta SCREEN_RAM+256,x
    sta SCREEN_RAM+512,x
    sta SCREEN_RAM+768,x
    lda #0
    sta COLOR_RAM,x
    sta COLOR_RAM+256,x
    sta COLOR_RAM+512,x
    sta COLOR_RAM+768,x
    inx
    bne !loop-

    ldx #Display_Title_X
    ldy #Display_Title_Y
    jsr SetCursor
    lda #<SongName
    ldy #>SongName
    ldx #Display_Title_Colour
    jsr PrintString

    ldx #Display_Artist_X
    ldy #Display_Artist_Y
    jsr SetCursor
    lda #<ArtistName
    ldy #>ArtistName
    ldx #Display_Artist_Colour
    jsr PrintString

    ldx #Display_Copyright_X
    ldy #Display_Copyright_Y
    jsr SetCursor
    lda #<CopyrightInfo
    ldy #>CopyrightInfo
    ldx #Display_Copyright_Colour
    jsr PrintString

    ldx #0
    ldy #Display_Separator1_Y
    jsr DrawSeparator

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

    ldx #Display_InitLabel_X
    ldy #Display_InitLabel_Y
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

    ldx #Display_PlayLabel_X
    ldy #Display_PlayLabel_Y
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
    jmp !print+
!pal:
    lda #<PALText
    ldy #>PALText
!print:
    ldx #Display_InfoValues_Colour
    jsr PrintString

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
    jmp !print+
!old:
    lda #<SID6581Text
    ldy #>SID6581Text
!print:
    ldx #Display_InfoValues_Colour
    jsr PrintString

    ldx #0
    ldy #Display_Separator2_Y
    jsr DrawSeparator

    ldx #Display_Time_X
    ldy #Display_Time_Y
    jsr SetCursor
    lda #<TimeLabel
    ldy #>TimeLabel
    ldx #Display_InfoTitles_Colour
    jsr PrintString

    lda NumSongs
    cmp #2
    bcc !skip+
    
    ldx #Display_Song_X
    ldy #Display_Song_Y
    jsr SetCursor
    lda #<CurrentSongLabel
    ldy #>CurrentSongLabel
    ldx #Display_InfoTitles_Colour
    jsr PrintString

!skip:
    ldx #0
    ldy #Display_Separator3_Y
    jsr DrawSeparator

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
    
    ldx #Display_ControlsTitle_X
    ldy #Display_ControlsTitle_Y
    jsr SetCursor
    lda #<ControlsLabel
    ldy #>ControlsLabel
    ldx #Display_ControlsTitle_Colour
    jsr PrintString

    ldx #Display_Controls_F1_X
    ldy #Display_Controls_F1_Y
    jsr SetCursor
    lda #<F1Text
    ldy #>F1Text
    ldx #Display_ControlsInfo_Colour
    jsr PrintString

    ldx #Display_Controls_SPACE_X
    ldy #Display_Controls_SPACE_Y
    jsr SetCursor
    lda #<SpaceText
    ldy #>SpaceText
    ldx #Display_ControlsInfo_Colour
    jsr PrintString
    
    lda NumSongs
    cmp #2
    bcs !multipleSongs+
    rts

!multipleSongs:
    ldx #Display_Controls_SongSelectKeys_X
    ldy #Display_Controls_SongSelectKeys_Y
    jsr SetCursor
    
    lda NumSongs
    cmp #10
    bcc !under10+
    
    lda #<Select19Text
    ldy #>Select19Text
    ldx #Display_ControlsInfo_Colour
    jsr PrintString
    
    lda NumSongs
    cmp #10
    beq !nav+
    
    lda #<CommaSpace
    ldy #>CommaSpace
    ldx #Display_ControlsInfo_Colour
    jsr PrintString
    
    lda #<AThru
    ldy #>AThru
    ldx #Display_ControlsInfo_Colour
    jsr PrintString
    
    lda NumSongs
    sec
    sbc #9
    cmp #27
    bcc !letter+
    lda #26
!letter:
    clc
    adc #'A'-1
    jsr PrintChar
    
    jmp !nav+

!under10:
    lda #<OneThru
    ldy #>OneThru
    ldx #Display_ControlsInfo_Colour
    jsr PrintString
    
    lda NumSongs
    clc
    adc #'0'
    jsr PrintChar
    
    lda #<SelectSuffix
    ldy #>SelectSuffix
    ldx #Display_ControlsInfo_Colour
    jsr PrintString

!nav:
    ldx #Display_Controls_Navigation_X
    ldy #Display_Controls_Navigation_Y
    jsr SetCursor
    lda #<NavigationText
    ldy #>NavigationText
    ldx #Display_ControlsInfo_Colour
    jmp PrintString

// =============================================================================
// UPDATE DYNAMIC INFO
// =============================================================================

UpdateDynamicInfo:
    ldx #Display_Time_X + 6
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

    ldx #Display_Song_X + 6
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
// INTERRUPT HANDLERS
// =============================================================================

MusicIRQ:
    pha
    txa
    pha
    tya
    pha

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
    ldx callCount + 1
    jsr set_d011_and_d012
    
    asl $d019
    pla
    tay
    pla
    tax
    pla
    rti

// =============================================================================
// TEXT DATA
// =============================================================================

ReleasedLabel:      .text "Released: "
                    .byte 0
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
ControlsLabel:      .text "== CONTROLS =="
                    .byte 0

Select19Text:       .text "1-9"
                    .byte 0
OneThru:            .text "1-"
                    .byte 0
AThru:              .text "A-"
                    .byte 0
CommaSpace:         .text ", "
                    .byte 0
SelectSuffix:       .text " = Select Song"
                    .byte 0
NavigationText:     .text "+/- = Next/Prev Song"
                    .byte 0
F1Text:             .text " F1 = Toggle Timing Bar(s)"
                    .byte 0

SpaceText:          .text "SPACE = Fast Forward (Hold)"
                    .byte 0
