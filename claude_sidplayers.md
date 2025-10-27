# SIDPlayers Assembly Files

Total players found: 9


## Player: Default
Files: 1

### FILE: SIDPlayers/Default/Default.asm
*Original size: 17025 bytes, Cleaned: 14165 bytes (reduced by 16.8%)*
```asm
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
#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR
#define INCLUDE_RASTER_TIMING_CODE
.var DEFAULT_RASTERTIMING_Y = 250
.import source "../INC/Common.asm"
.import source "../INC/keyboard.asm"
.import source "../INC/musicplayback.asm"
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
TimerSeconds:     .byte $00
TimerMinutes:     .byte $00
FrameCounter:     .byte $00
FramesPerSecond:  .byte $32
TempStorage:      .byte $00
CursorX:          .byte $00
CursorY:          .byte $00
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
```


## Player: INC
Files: 6

### FILE: SIDPlayers/INC/Common.asm
*Original size: 4960 bytes, Cleaned: 3995 bytes (reduced by 19.5%)*
```asm
#importonce
.var SIDInit						= DATA_ADDRESS + $00
.var SIDPlay						= DATA_ADDRESS + $03
.var BackupSIDMemory				= DATA_ADDRESS + $06
.var RestoreSIDMemory				= DATA_ADDRESS + $09
.var NumCallsPerFrame				= DATA_ADDRESS + $0c
.var BorderColour					= DATA_ADDRESS + $0d
.var BitmapScreenColour				= DATA_ADDRESS + $0e
.var SongNumber						= DATA_ADDRESS + $0f
.var SongName						= DATA_ADDRESS + $10
.var ArtistName						= DATA_ADDRESS + $30
.var CopyrightInfo					= DATA_ADDRESS + $50
.var LoadAddress					= DATA_ADDRESS + $c0
.var InitAddress					= DATA_ADDRESS + $c2
.var PlayAddress					= DATA_ADDRESS + $c4
.var EndAddress						= DATA_ADDRESS + $c6
.var NumSongs						= DATA_ADDRESS + $c8
.var ClockType						= DATA_ADDRESS + $c9
.var SIDModel						= DATA_ADDRESS + $ca
.var ZPUsageData					= DATA_ADDRESS + $e0
NMIFix:
		lda #$35
		sta $01
		lda #<!JustRTI+
		sta $FFFA
		lda #>!JustRTI+
		sta $FFFB
		lda #$00
		sta $DD0E
		sta $DD04
		sta $DD05
		lda #$81
		sta $DD0D
		lda #$01
		sta $DD0E
		rts
	!JustRTI:
		rti
VSync:
    bit $d011
    bpl *-3
    bit $d011
    bmi *-3
    rts
#if INCLUDE_RASTER_TIMING_CODE
.var FrameHeight = 312
D011_Values_1Call:  .fill 1, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 1), 312))) * $80
D012_Values_1Call:  .fill 1, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 1), 312)))
D011_Values_2Calls: .fill 2, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 2), 312))) * $80
D012_Values_2Calls: .fill 2, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 2), 312)))
D011_Values_3Calls: .fill 3, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 3), 312))) * $80
D012_Values_3Calls: .fill 3, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 3), 312)))
D011_Values_4Calls: .fill 4, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 4), 312))) * $80
D012_Values_4Calls: .fill 4, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 4), 312)))
D011_Values_5Calls: .fill 5, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 5), 312))) * $80
D012_Values_5Calls: .fill 5, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 5), 312)))
D011_Values_6Calls: .fill 6, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 6), 312))) * $80
D012_Values_6Calls: .fill 6, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 6), 312)))
D011_Values_7Calls: .fill 7, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 7), 312))) * $80
D012_Values_7Calls: .fill 7, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 7), 312)))
D011_Values_8Calls: .fill 8, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 8), 312))) * $80
D012_Values_8Calls: .fill 8, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 8), 312)))
D011_Values_Lookup_Lo: .byte <D011_Values_1Call, <D011_Values_1Call, <D011_Values_2Calls, <D011_Values_3Calls, <D011_Values_4Calls, <D011_Values_5Calls, <D011_Values_6Calls, <D011_Values_7Calls, <D011_Values_8Calls
D011_Values_Lookup_Hi: .byte >D011_Values_1Call, >D011_Values_1Call, >D011_Values_2Calls, >D011_Values_3Calls, >D011_Values_4Calls, >D011_Values_5Calls, >D011_Values_6Calls, >D011_Values_7Calls, >D011_Values_8Calls
D012_Values_Lookup_Lo: .byte <D012_Values_1Call, <D012_Values_1Call, <D012_Values_2Calls, <D012_Values_3Calls, <D012_Values_4Calls, <D012_Values_5Calls, <D012_Values_6Calls, <D012_Values_7Calls, <D012_Values_8Calls
D012_Values_Lookup_Hi: .byte >D012_Values_1Call, >D012_Values_1Call, >D012_Values_2Calls, >D012_Values_3Calls, >D012_Values_4Calls, >D012_Values_5Calls, >D012_Values_6Calls, >D012_Values_7Calls, >D012_Values_8Calls
init_D011_D012_values:
    ldx NumCallsPerFrame
    lda D011_Values_Lookup_Lo, x
    sta d011_values_ptr + 1
    lda D011_Values_Lookup_Hi, x
    sta d011_values_ptr + 2
    lda D012_Values_Lookup_Lo, x
    sta d012_values_ptr + 1
    lda D012_Values_Lookup_Hi, x
    sta d012_values_ptr + 2
    rts
set_d011_and_d012:
d012_values_ptr:
    lda $abcd, x
    sta $d012
    lda $d011
    and #$7f
d011_values_ptr:
    ora $abcd, x
    sta $d011
    rts
#endif
```

### FILE: SIDPlayers/INC/FreqTable.asm
*Original size: 2363 bytes, Cleaned: 2159 bytes (reduced by 8.6%)*
```asm
.var file_freqTable = LoadBinary("FreqTable.bin")
.align 256
FreqToBarLo: .fill 256, file_freqTable.get(i + 0)
FreqToBarMid: .fill 256, file_freqTable.get(i + 256)
FreqToBarHi: .fill 256, file_freqTable.get(i + 512)
.const SUSTAIN_MIN = MAX_BAR_HEIGHT / 6
.const SUSTAIN_MAX = MAX_BAR_HEIGHT
sustainToHeight:
    .fill 16, SUSTAIN_MIN + (i * (SUSTAIN_MAX - SUSTAIN_MIN)) / 15.0
releaseRateLo:				.byte <((MAX_BAR_HEIGHT * 256.0 / 1.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 2.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 3.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 4.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 6.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 9.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 11.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 12.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 15.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 38.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 75.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 120.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 150.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 450.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 750.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 1200.0) + 64.0)
releaseRateHi:				.byte >((MAX_BAR_HEIGHT * 256.0 / 1.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 2.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 3.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 4.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 6.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 9.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 11.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 12.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 15.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 38.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 75.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 120.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 150.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 450.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 750.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 1200.0) + 64.0)
```

### FILE: SIDPlayers/INC/Keyboard.asm
*Original size: 14209 bytes, Cleaned: 7595 bytes (reduced by 46.5%)*
```asm
#importonce
.const CIA1_PRA = $dc00
.const CIA1_PRB = $dc01
.const CIA1_DDRA = $dc02
.const CIA1_DDRB = $dc03
.const KEY_F1 = $85
.const KEY_F3 = $86
.const KEY_F5 = $87
.const KEY_F7 = $88
.const KEY_RETURN = $0d
.const KEY_DELETE = $14
.const KEY_HOME = $13
.const KEY_RUNSTOP = $03
.const KEY_CURSOR_UD = $11
.const KEY_CURSOR_LR = $1d
.const KEY_SHIFT = $00
.const KEY_CONTROL = $00
.const KEY_COMMODORE = $00
CurrentKeyMatrix:   .byte 0
CurrentKey:         .byte 0
LastKey:            .byte 0
KeyReleased:        .byte 1
DebounceCounter:    .byte 0
.const DEBOUNCE_DELAY = 5
CurrentSong:        .byte $00
ShowRasterBars:     .byte $00
#if INCLUDE_SPACE_FASTFORWARD
FastForwardActive:  .byte $00
FFCallCounter:      .byte $00
#endif
#if INCLUDE_F1_SHOWRASTERTIMINGBAR
F1KeyPressed:       .byte 0
F1KeyReleased:      .byte 1
#endif
#if INCLUDE_PLUS_MINUS_SONGCHANGE
PlusKeyPressed:     .byte 0
PlusKeyReleased:    .byte 1
MinusKeyPressed:    .byte 0
MinusKeyReleased:   .byte 1
#endif
CheckKeyboard:
    #if INCLUDE_SPACE_FASTFORWARD
    jsr CheckSpaceKey
    #endif
    #if INCLUDE_F1_SHOWRASTERTIMINGBAR
    jsr CheckF1Key
    lda F1KeyPressed
    beq !notF1+
    lda F1KeyReleased
    beq !notF1+
    lda #0
    sta F1KeyReleased
    lda ShowRasterBars
    eor #$01
    sta ShowRasterBars
    jmp !checkSongKeys+
!notF1:
    lda F1KeyPressed
    bne !stillF1+
    lda #1
    sta F1KeyReleased
!stillF1:
    #endif
!checkSongKeys:
    lda NumSongs
    cmp #2
    bcs !multiSong+
    rts
!multiSong:
    #if INCLUDE_PLUS_MINUS_SONGCHANGE
    jsr CheckPlusKey
    lda PlusKeyPressed
    beq !notPlus+
    lda PlusKeyReleased
    beq !notPlus+
    lda #0
    sta PlusKeyReleased
    jsr NextSong
    jmp !done+
!notPlus:
    lda PlusKeyPressed
    bne !stillPlus+
    lda #1
    sta PlusKeyReleased
!stillPlus:
    jsr CheckMinusKey
    lda MinusKeyPressed
    beq !notMinus+
    lda MinusKeyReleased
    beq !notMinus+
    lda #0
    sta MinusKeyReleased
    jsr PrevSong
    jmp !done+
!notMinus:
    lda MinusKeyPressed
    bne !stillMinus+
    lda #1
    sta MinusKeyReleased
!stillMinus:
    #endif
    #if INCLUDE_09ALPHA_SONGCHANGE
    jsr ScanKeyboard
    cmp #0
    beq !done+
    jsr GetKeyWithShift
    cmp #'1'
    bcc !done+
    cmp #':'
    bcs !checkLetters+
    sec
    sbc #'1'
    cmp NumSongs
    bcs !done+
    jsr SelectSong
    jmp !done+
!checkLetters:
    cmp #'A'
    bcc !checkLower+
    cmp #'['
    bcs !checkLower+
    sec
    sbc #'A'-9
    cmp NumSongs
    bcs !done+
    jsr SelectSong
    jmp !done+
!checkLower:
    cmp #'a'
    bcc !done+
    cmp #'{'
    bcs !done+
    sec
    sbc #'a'-9
    cmp NumSongs
    bcs !done+
    jsr SelectSong
    #endif
!done:
    rts
InitKeyboard:
    lda #$ff
    sta CIA1_DDRA
    lda #$00
    sta CIA1_DDRB
    lda #0
    sta CurrentKeyMatrix
    sta CurrentKey
    sta LastKey
    sta DebounceCounter
    sta CurrentSong
    sta ShowRasterBars
    lda #1
    sta KeyReleased
    #if INCLUDE_SPACE_FASTFORWARD
    lda #0
    sta FastForwardActive
    sta FFCallCounter
    #endif
    rts
#if INCLUDE_SPACE_FASTFORWARD
CheckSpaceKey:
    lda #%01111111
    sta $DC00
    lda $DC01
    and #%00010000
    eor #%00010000
    sta FastForwardActive
    rts
#endif
#if INCLUDE_F1_SHOWRASTERTIMINGBAR
CheckF1Key:
    lda #%11111110
    sta $DC00
    lda $DC01
    and #%00010000
    eor #%00010000
    sta F1KeyPressed
    rts
#endif
#if INCLUDE_PLUS_MINUS_SONGCHANGE
CheckPlusKey:
    lda #%11011111
    sta $DC00
    lda $DC01
    and #%00000001
    eor #%00000001
    sta PlusKeyPressed
    rts
CheckMinusKey:
    lda #%11011111
    sta $DC00
    lda $DC01
    and #%00001000
    eor #%00001000
    sta MinusKeyPressed
    rts
#endif
SelectSong:
    sta CurrentSong
    tax
    tay
    jsr SIDInit
    rts
#if INCLUDE_PLUS_MINUS_SONGCHANGE
NextSong:
    lda CurrentSong
    clc
    adc #1
    cmp NumSongs
    bcc !ok+
    lda #0
!ok:
    jsr SelectSong
    rts
PrevSong:
    lda CurrentSong
    bne !ok+
    lda NumSongs
!ok:
    sec
    sbc #1
    jsr SelectSong
    rts
#endif
ScanKeyboard:
    jsr DetectKeyPress
    cmp #0
    bne !keyPressed+
    lda #1
    sta KeyReleased
    lda #0
    sta DebounceCounter
    sta CurrentKey
    sta LastKey
    rts
!keyPressed:
    sta CurrentKeyMatrix
    lda KeyReleased
    bne !newPress+
    lda #0
    rts
!newPress:
    lda CurrentKeyMatrix
    cmp LastKey
    beq !sameKey+
    lda CurrentKeyMatrix
    sta LastKey
    lda #DEBOUNCE_DELAY
    sta DebounceCounter
    lda #0
    rts
!sameKey:
    dec DebounceCounter
    bne !stillDebouncing+
    lda #0
    sta KeyReleased
    lda CurrentKeyMatrix
    jsr ConvertMatrixToASCII
    sta CurrentKey
    rts
!stillDebouncing:
    lda #0
    rts
DetectKeyPress:
    ldy #0
!scanRow:
    lda RowSelectTable,y
    sta CIA1_PRA
    lda CIA1_PRB
    cmp #$ff
    bne !foundKey+
    iny
    cpy #8
    bne !scanRow-
    lda #0
    rts
!foundKey:
    eor #$ff
    ldx #0
!findColumn:
    lsr
    bcs !gotColumn+
    inx
    cpx #8
    bne !findColumn-
    lda #0
    rts
!gotColumn:
    tya
    asl
    asl
    asl
    sta TempCalc
    txa
    clc
    adc TempCalc
    rts
TempCalc: .byte 0
RowSelectTable:
    .byte %11111110
    .byte %11111101
    .byte %11111011
    .byte %11110111
    .byte %11101111
    .byte %11011111
    .byte %10111111
    .byte %01111111
KeyMatrixTable:
    .byte KEY_DELETE
    .byte KEY_RETURN
    .byte KEY_CURSOR_LR
    .byte KEY_F7
    .byte KEY_F1
    .byte KEY_F3
    .byte KEY_F5
    .byte KEY_CURSOR_UD
    .byte '3'
    .byte 'w'
    .byte 'a'
    .byte '4'
    .byte 'z'
    .byte 's'
    .byte 'e'
    .byte KEY_SHIFT
    .byte '5'
    .byte 'r'
    .byte 'd'
    .byte '6'
    .byte 'c'
    .byte 'f'
    .byte 't'
    .byte 'x'
    .byte '7'
    .byte 'y'
    .byte 'g'
    .byte '8'
    .byte 'b'
    .byte 'h'
    .byte 'u'
    .byte 'v'
    .byte '9'
    .byte 'i'
    .byte 'j'
    .byte '0'
    .byte 'm'
    .byte 'k'
    .byte 'o'
    .byte 'n'
    .byte '+'
    .byte 'p'
    .byte 'l'
    .byte '-'
    .byte '.'
    .byte ':'
    .byte '@'
    .byte ','
    .byte $5c
    .byte '*'
    .byte ';'
    .byte KEY_HOME
    .byte KEY_SHIFT
    .byte '='
    .byte $5e
    .byte '/'
    .byte '1'
    .byte $5f
    .byte KEY_CONTROL
    .byte '2'
    .byte ' '
    .byte KEY_COMMODORE
    .byte 'q'
    .byte KEY_RUNSTOP
ConvertMatrixToASCII:
    tax
    lda KeyMatrixTable,x
    rts
IsKeyPressed:
    sta CheckKey
    jsr DetectKeyPress
    beq !notPressed+
    jsr ConvertMatrixToASCII
    cmp CheckKey
    beq !pressed+
!notPressed:
    lda #0
    rts
!pressed:
    lda #1
    rts
CheckKey: .byte 0
GetKeyWithShift:
    sta TempKey
    lda #%11111101
    sta CIA1_PRA
    lda CIA1_PRB
    and #%10000000
    beq !shiftPressed+
    lda #%10111111
    sta CIA1_PRA
    lda CIA1_PRB
    and #%00010000
    beq !shiftPressed+
    lda TempKey
    rts
!shiftPressed:
    lda TempKey
    cmp #'a'
    bcc !notLowercase+
    cmp #'z'+1
    bcs !notLowercase+
    and #$df
    rts
!notLowercase:
    cmp #'1'
    bne !not1+
    lda #'!'
    rts
!not1:
    cmp #'2'
    bne !not2+
    lda #'"'
    rts
!not2:
    cmp #'3'
    bne !not3+
    lda #'#'
    rts
!not3:
    cmp #'4'
    bne !not4+
    lda #'$'
    rts
!not4:
    cmp #'5'
    bne !not5+
    lda #'%'
    rts
!not5:
    cmp #'6'
    bne !not6+
    lda #'&'
    rts
!not6:
    cmp #'7'
    bne !not7+
    lda #$27
    rts
!not7:
    cmp #'8'
    bne !not8+
    lda #'('
    rts
!not8:
    cmp #'9'
    bne !not9+
    lda #')'
    rts
!not9:
    cmp #'0'
    bne !not0+
    lda #')'
    rts
!not0:
    lda TempKey
    rts
TempKey: .byte 0
```

### FILE: SIDPlayers/INC/MusicPlayback.asm
*Original size: 1782 bytes, Cleaned: 719 bytes (reduced by 59.7%)*
```asm
#importonce
JustPlayMusic:
    #if INCLUDE_F1_SHOWRASTERTIMINGBAR
    lda ShowRasterBars
    beq !skip+
    lda #$02
    sta $d020
!skip:
    #endif
    jsr SIDPlay
    #if INCLUDE_F1_SHOWRASTERTIMINGBAR
    lda ShowRasterBars
    beq !skip+
    lda #$00
    sta $d020
!skip:
    #endif
    rts
#if INCLUDE_MUSIC_ANALYSIS
AnalyseMusic:
    lda $01
    pha
    lda #$30
    sta $01
    jsr BackupSIDMemory
    jsr SIDPlay
    jsr RestoreSIDMemory
    ldy #24
!loop:
    lda $d400, y
    sta sidRegisterMirror, y
    dey
    bpl !loop-
    pla
    sta $01
    jmp AnalyzeSIDRegisters
sidRegisterMirror: .fill 25, 0
#endif
#if INCLUDE_MUSIC_ANALYSIS
PlayMusicWithAnalysis:
    jsr JustPlayMusic
    jmp AnalyseMusic
#endif
```

### FILE: SIDPlayers/INC/Spectrometer.asm
*Original size: 6903 bytes, Cleaned: 3420 bytes (reduced by 50.5%)*
```asm
#importonce
.align NUM_FREQUENCY_BARS
barHeightsLo:               .fill NUM_FREQUENCY_BARS, 0
.align NUM_FREQUENCY_BARS
barVoiceMap:                .fill NUM_FREQUENCY_BARS, $03
.align NUM_FREQUENCY_BARS
smoothedHeights:            .fill NUM_FREQUENCY_BARS, 0
.align NUM_FREQUENCY_BARS
targetBarHeights:           .fill NUM_FREQUENCY_BARS, 0
.align NUM_FREQUENCY_BARS + 4
.byte $00, $00
barHeights:                 .fill NUM_FREQUENCY_BARS, 0
.byte $00, $00
.align NUM_FREQUENCY_BARS + 4
.byte $00, $00
halfBarHeights:                 .fill NUM_FREQUENCY_BARS, 0
.byte $00, $00
.align 4
voiceReleaseHi:             .fill 3, 0
                            .byte BAR_DECREASE_RATE
.align 4
voiceReleaseLo:             .fill 3, 0
                            .byte 0
halfValues:                      .fill MAX_BAR_HEIGHT + 1, floor(i * 30.0 / 100.0)
AnalyzeSIDRegisters:
    .for (var voice = 0; voice < 3; voice++) {
    lda sidRegisterMirror + (voice * 7) + 4
    and #$08
    bne AnalyzeFrequency
    lda sidRegisterMirror + (voice * 7) + 4
    and #$01
    beq !skipVoice+
AnalyzeFrequency:
    ldy sidRegisterMirror + (voice * 7) + 1
    cpy #$40
    bcs !useHighTable+
    cpy #$10
    bcs !useMidTable+
    tya
    asl
    asl
    asl
    asl
    sta tempIndex + 1
    lda sidRegisterMirror + (voice * 7) + 0
    lsr
    lsr
    lsr
    lsr
tempIndex:
    ora #$00
    tax
    lda FreqToBarLo, x
    tax
    jmp !gotBar+
!useMidTable:
    tya
    sec
    sbc #$10
    asl
    asl
    sta tempIndex2 + 1
    lda sidRegisterMirror + (voice * 7) + 0
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
tempIndex2:
    ora #$00
    tax
    lda FreqToBarMid, x
    tax
    jmp !gotBar+
!useHighTable:
    lda FreqToBarHi, y
    tax
!gotBar:
        lda sidRegisterMirror + (voice * 7) + 6
        and #$0f
        tay
        lda releaseRateHi, y
        sta voiceReleaseHi + voice
        lda releaseRateLo, y
        sta voiceReleaseLo + voice
        lda sidRegisterMirror + (voice * 7) + 6
        lsr
        lsr
        lsr
        lsr
        tay
        lda sustainToHeight, y
        sta targetBarHeights, x
        lda #voice
        sta barVoiceMap, x
    !skipVoice:
    }
    rts
UpdateBars:
    ldx #0
!loop:
    lda targetBarHeights, x
    beq !decay+
    lda barHeights, x
    clc
    adc #BAR_INCREASE_RATE
    cmp targetBarHeights, x
    bcc !skip+
    ldy targetBarHeights, x
    lda #0
    sta targetBarHeights, x
    tya
!skip:
    sta barHeights, x
    jmp !next+
!decay:
    lda barHeights, x
    beq !next+
    ldy barVoiceMap, x
    sec
    lda barHeightsLo, x
    sbc voiceReleaseLo, y
    sta barHeightsLo, x
    lda barHeights, x
    sbc voiceReleaseHi, y
    bpl !skip+
    lda #$00
    sta barHeightsLo, x
!skip:
    sta barHeights, x
!next:
    inx
    cpx #NUM_FREQUENCY_BARS
    bne !loop-
    rts
ApplySmoothing:
    ldx #0
!loop:
    ldy barHeights, x
    lda halfValues, y
    sta halfBarHeights, x
    inx
    cpx #NUM_FREQUENCY_BARS
    bne !loop-
    ldx #0
!loop:
    clc
    lda barHeights + 0, x
    adc halfBarHeights - 1, x
    adc halfBarHeights + 1, x
    cmp #MAX_BAR_HEIGHT
    bcc !skip+
    lda #MAX_BAR_HEIGHT
!skip:
    sta smoothedHeights, x
    inx
    cpx #NUM_FREQUENCY_BARS
    bne !loop-
    rts
InitializeBarArrays:
    ldy #$00
    lda #$00
!loop:
    sta barHeights - 2, y
    sta smoothedHeights - 2, y
    iny
    cpy #NUM_FREQUENCY_BARS + 4
    bne !loop-
    rts
```

### FILE: SIDPlayers/INC/StableRasterSetup.asm
*Original size: 1417 bytes, Cleaned: 421 bytes (reduced by 70.3%)*
```asm
#importonce
.align 128
SetupStableRaster:
	bit $d011
	bmi *-3
	bit $d011
	bpl *-3
	ldx $d012
	inx
ResyncLoop:
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
	bne ResyncLoop
	lda #$7f
	sta $dc0d
	sta $dd0d
	lda $dc0d
	lda $dd0d
	bit $d011
	bpl *-3
	bit $d011
	bmi *-3
	lda #$01
	sta $d01a
	rts
```


## Player: RaistlinBars
Files: 1

### FILE: SIDPlayers/RaistlinBars/RaistlinBars.asm
*Original size: 18659 bytes, Cleaned: 13007 bytes (reduced by 30.3%)*
```asm
.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()
* = DATA_ADDRESS "Data Block"
    .fill $100, $00
* = CODE_ADDRESS "Main Code"
    jmp Initialize
.var VIC_BANK						= floor(LOAD_ADDRESS / $4000)
.var VIC_BANK_ADDRESS               = VIC_BANK * $4000
.var file_charsetData = LoadBinary("CharSet.map")
.var file_waterSpritesData = LoadBinary("WaterSprites.map")
.const NUM_FREQUENCY_BARS				= 40
.const TOP_SPECTRUM_HEIGHT				= 16
.const BOTTOM_SPECTRUM_HEIGHT			= 3
.const BAR_INCREASE_RATE				= ceil(TOP_SPECTRUM_HEIGHT * 1.3)
.const BAR_DECREASE_RATE				= ceil(TOP_SPECTRUM_HEIGHT * 0.2)
.const SONG_TITLE_LINE					= 0
.const ARTIST_NAME_LINE					= 23
.const SPECTRUM_START_LINE				= 3
.const REFLECTION_SPRITES_YVAL			= 50 + (SPECTRUM_START_LINE + TOP_SPECTRUM_HEIGHT) * 8 + 3
.eval setSeed(55378008)
.const SCREEN0_BANK						= 12
.const SCREEN1_BANK						= 13
.const CHARSET_BANK						= 7
.const SPRITE_BASE_INDEX				= $b8
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
#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR
#define INCLUDE_MUSIC_ANALYSIS
#define INCLUDE_RASTER_TIMING_CODE
.var DEFAULT_RASTERTIMING_Y = 108
.import source "../INC/Common.asm"
.import source "../INC/keyboard.asm"
.import source "../INC/musicplayback.asm"
.import source "../INC/StableRasterSetup.asm"
.import source "../INC/Spectrometer.asm"
.import source "../INC/FreqTable.asm"
.align NUM_FREQUENCY_BARS
previousHeightsScreen0:     .fill NUM_FREQUENCY_BARS, 255
.align NUM_FREQUENCY_BARS
previousHeightsScreen1:     .fill NUM_FREQUENCY_BARS, 255
.align NUM_FREQUENCY_BARS
previousColors:             .fill NUM_FREQUENCY_BARS, 255
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
SetupSystem:
	lda #$35
	sta $01
	lda #(63 - VIC_BANK)
	sta $dd00
	lda #VIC_BANK
	sta $dd02
	rts
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
	jsr UpdateBars
	jsr UpdateColors
	jsr UpdateSprites
	jsr AnalyseMusic
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
VICConfigStart:
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte $ff
	.byte $08
	.byte $00
	.byte D018_VALUE_0
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte $00
	.byte $00
	.byte $ff
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00, $00
	.byte $00, $00, $00
	.byte $00, $00, $00, $00
	.byte $00, $00, $00, $00
VICConfigEnd:
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
colorPalettes:
	.byte $09, $04, $05, $05, $0d, $0d, $0f, $01
	.byte $09, $06, $0e, $0e, $03, $03, $0f, $01
	.byte $09, $02, $0a, $0a, $07, $07, $0f, $01
colorPalettesLo:			.fill NUM_COLOR_PALETTES, <(colorPalettes + i * COLORS_PER_PALETTE)
colorPalettesHi:			.fill NUM_COLOR_PALETTES, >(colorPalettes + i * COLORS_PER_PALETTE)
heightToColorIndex:			.byte $ff
							.fill MAX_BAR_HEIGHT + 4, max(0, min(COLORS_PER_PALETTE - 1, floor((i * COLORS_PER_PALETTE) / MAX_BAR_HEIGHT)))
heightToColor:				.fill MAX_BAR_HEIGHT + 5, $0b
	.fill MAX_BAR_HEIGHT, 224
barCharacterMap:
	.fill 8, 225 + i
	.fill MAX_BAR_HEIGHT, 233
spriteSineTable:			.fill 128, 11.5 + 11.5*sin(toRadians(i*360/128))
* = SPRITES_ADDRESS "Water Sprites"
	.fill file_waterSpritesData.getSize(), file_waterSpritesData.get(i)
* = CHARSET_ADDRESS "Font"
	.fill min($700, file_charsetData.getSize()), file_charsetData.get(i)
* = CHARSET_ADDRESS + (224 * 8) "Bar Chars"
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $00, $00, $00, $00, $00, $00, $00, $7C
	.byte $00, $00, $00, $00, $00, $00, $7C, $BE
	.byte $00, $00, $00, $00, $00, $7C, $BE, $BE
	.byte $00, $00, $00, $00, $7C, $14, $BE, $BE
	.byte $00, $00, $00, $7C, $BE, $14, $BE, $BE
	.byte $00, $00, $7C, $BE, $BE, $14, $BE, $BE
	.byte $00, $7C, $BE, $BE, $BE, $14, $BE, $BE
	.byte $7C, $14, $BE, $BE, $BE, $14, $BE, $BE
	.byte $BE, $14, $BE, $BE, $BE, $14, $BE, $BE
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
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $aa, $00, $00, $00, $00, $00, $00, $00
	.byte $54, $aa, $00, $00, $00, $00, $00, $00
	.byte $aa, $54, $aa, $00, $00, $00, $00, $00
	.byte $54, $aa, $54, $aa, $00, $00, $00, $00
	.byte $aa, $54, $aa, $54, $aa, $00, $00, $00
	.byte $54, $aa, $54, $aa, $54, $aa, $00, $00
	.byte $aa, $54, $aa, $54, $aa, $54, $54, $00
	.byte $54, $aa, $54, $aa, $54, $aa, $54, $aa
	.byte $aa, $54, $aa, $54, $aa, $54, $aa, $54
* = SCREEN0_ADDRESS "Screen 0"
	.fill $400, $00
* = SCREEN1_ADDRESS "Screen 1"
	.fill $400, $00
```


## Player: RaistlinBarsWithLogo
Files: 1

### FILE: SIDPlayers/RaistlinBarsWithLogo/RaistlinBarsWithLogo.asm
*Original size: 18134 bytes, Cleaned: 12530 bytes (reduced by 30.9%)*
```asm
.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()
* = DATA_ADDRESS "Data Block"
    .fill $100, $00
* = CODE_ADDRESS "Main Code"
    jmp Initialize
.var VIC_BANK						= floor(LOAD_ADDRESS / $4000)
.var VIC_BANK_ADDRESS               = VIC_BANK * $4000
.var file_charsetData = LoadBinary("CharSet.map")
.var file_waterSpritesData = LoadBinary("WaterSprites.map")
.const NUM_FREQUENCY_BARS				= 40
.const LOGO_HEIGHT						= 10
.const TOP_SPECTRUM_HEIGHT				= 9
.const BOTTOM_SPECTRUM_HEIGHT			= 3
.const BAR_INCREASE_RATE				= ceil(TOP_SPECTRUM_HEIGHT * 1.3)
.const BAR_DECREASE_RATE				= ceil(TOP_SPECTRUM_HEIGHT * 0.2)
.const SONG_TITLE_LINE					= 23
.const SPECTRUM_START_LINE				= 11
.const REFLECTION_SPRITES_YVAL			= 50 + (SPECTRUM_START_LINE + TOP_SPECTRUM_HEIGHT) * 8 + 3
.eval setSeed(55378008)
.const DD00Value                        = 3 - VIC_BANK
.const DD02Value                        = 60 + VIC_BANK
.const SCREEN0_BANK						= 12
.const SCREEN1_BANK						= 13
.const CHARSET_BANK						= 7
.const BITMAP_BANK						= 1
.const SPRITE_BASE_INDEX				= $B8
.const BITMAP_ADDRESS					= VIC_BANK_ADDRESS + (BITMAP_BANK * $2000)
.const SCREEN0_ADDRESS					= VIC_BANK_ADDRESS + (SCREEN0_BANK * $400)
.const SCREEN1_ADDRESS					= VIC_BANK_ADDRESS + (SCREEN1_BANK * $400)
.const BITMAP_COL_DATA					= SCREEN1_ADDRESS
.const CHARSET_ADDRESS					= VIC_BANK_ADDRESS + (CHARSET_BANK * $800)
.const SPRITES_ADDRESS					= VIC_BANK_ADDRESS + (SPRITE_BASE_INDEX * $40)
.const SPRITE_POINTERS_0				= SCREEN0_ADDRESS + $3F8
.const SPRITE_POINTERS_1				= SCREEN1_ADDRESS + $3F8
.const D018_VALUE_0						= (SCREEN0_BANK * 16) + (CHARSET_BANK * 2)
.const D018_VALUE_1						= (SCREEN1_BANK * 16) + (CHARSET_BANK * 2)
.const D018_VALUE_BITMAP				= (SCREEN0_BANK * 16) + (BITMAP_BANK * 8)
.const MAX_BAR_HEIGHT					= TOP_SPECTRUM_HEIGHT * 8 - 1
.const WATER_REFLECTION_HEIGHT			= BOTTOM_SPECTRUM_HEIGHT * 8
.const MAIN_BAR_OFFSET					= MAX_BAR_HEIGHT - 7
.const REFLECTION_OFFSET				= WATER_REFLECTION_HEIGHT - 7
.const NUM_COLOR_PALETTES				= 3
.const COLORS_PER_PALETTE				= 8
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR
#define INCLUDE_MUSIC_ANALYSIS
.import source "../INC/Common.asm"
.import source "../INC/keyboard.asm"
.import source "../INC/musicplayback.asm"
.import source "../INC/StableRasterSetup.asm"
.import source "../INC/Spectrometer.asm"
.import source "../INC/FreqTable.asm"
.align NUM_FREQUENCY_BARS
previousHeightsScreen0:     .fill NUM_FREQUENCY_BARS, 255
.align NUM_FREQUENCY_BARS
previousHeightsScreen1:     .fill NUM_FREQUENCY_BARS, 255
.align NUM_FREQUENCY_BARS
previousColors:             .fill NUM_FREQUENCY_BARS, 255
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
	jsr DrawScreens
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
SetupSystem:
	lda #$35
	sta $01
	lda #(63 - VIC_BANK)
	sta $dd00
	lda #VIC_BANK
	sta $dd02
	rts
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
	jsr UpdateColors
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
	lda #$01
	sta $d800 + ((SONG_TITLE_LINE + 0) * 40) + 4, y
	sta $d800 + ((SONG_TITLE_LINE + 1) * 40) + 4, y
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
VICConfigStart:
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00, REFLECTION_SPRITES_YVAL
	.byte $00
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte $ff
	.byte $18
	.byte $00
	.byte D018_VALUE_BITMAP
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte $00
	.byte $00
	.byte $ff
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00, $00
	.byte $00, $00, $00
	.byte $00, $00, $00, $00
	.byte $00, $00, $00, $00
VICConfigEnd:
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
colorPalettes:
	.byte $09, $04, $05, $05, $0d, $0d, $0f, $01
	.byte $09, $06, $0e, $0e, $03, $03, $0f, $01
	.byte $09, $02, $0a, $0a, $07, $07, $0f, $01
colorPalettesLo:			.fill NUM_COLOR_PALETTES, <(colorPalettes + i * COLORS_PER_PALETTE)
colorPalettesHi:			.fill NUM_COLOR_PALETTES, >(colorPalettes + i * COLORS_PER_PALETTE)
heightToColorIndex:			.byte $ff
							.fill MAX_BAR_HEIGHT + 4, max(0, min(floor(((i * COLORS_PER_PALETTE) + (random() * (MAX_BAR_HEIGHT * 0.8) - (MAX_BAR_HEIGHT * 0.4))) / MAX_BAR_HEIGHT), COLORS_PER_PALETTE - 1))
heightToColor:				.fill MAX_BAR_HEIGHT + 5, $0b
	.fill MAX_BAR_HEIGHT, 224
barCharacterMap:
	.fill 8, 225 + i
	.fill MAX_BAR_HEIGHT, 233
spriteSineTable:			.fill 128, 11.5 + 11.5*sin(toRadians(i*360/128))
* = SPRITES_ADDRESS "Water Sprites"
	.fill file_waterSpritesData.getSize(), file_waterSpritesData.get(i)
* = CHARSET_ADDRESS "Font"
	.fill min($700, file_charsetData.getSize()), file_charsetData.get(i)
* = CHARSET_ADDRESS + (224 * 8) "Bar Chars"
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $00, $00, $00, $00, $00, $00, $00, $7C
	.byte $00, $00, $00, $00, $00, $00, $7C, $BE
	.byte $00, $00, $00, $00, $00, $7C, $BE, $BE
	.byte $00, $00, $00, $00, $7C, $14, $BE, $BE
	.byte $00, $00, $00, $7C, $BE, $14, $BE, $BE
	.byte $00, $00, $7C, $BE, $BE, $14, $BE, $BE
	.byte $00, $7C, $BE, $BE, $BE, $14, $BE, $BE
	.byte $7C, $14, $BE, $BE, $BE, $14, $BE, $BE
	.byte $BE, $14, $BE, $BE, $BE, $14, $BE, $BE
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
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $aa, $00, $00, $00, $00, $00, $00, $00
	.byte $54, $aa, $00, $00, $00, $00, $00, $00
	.byte $aa, $54, $aa, $00, $00, $00, $00, $00
	.byte $54, $aa, $54, $aa, $00, $00, $00, $00
	.byte $aa, $54, $aa, $54, $aa, $00, $00, $00
	.byte $54, $aa, $54, $aa, $54, $aa, $00, $00
	.byte $aa, $54, $aa, $54, $aa, $54, $54, $00
	.byte $54, $aa, $54, $aa, $54, $aa, $54, $aa
	.byte $aa, $54, $aa, $54, $aa, $54, $aa, $54
* = SCREEN0_ADDRESS "Screen 0"
	.fill LOGO_HEIGHT * 40, $00
	.fill $400 - (LOGO_HEIGHT * 40), $20
* = SCREEN1_ADDRESS "Screen 1"
	.fill LOGO_HEIGHT * 40, $00
	.fill $400 - (LOGO_HEIGHT * 40), $20
* = BITMAP_ADDRESS "Bitmap"
	.fill $C80, $00
```


## Player: RaistlinMirrorBars
Files: 1

### FILE: SIDPlayers/RaistlinMirrorBars/RaistlinMirrorBars.asm
*Original size: 13690 bytes, Cleaned: 9046 bytes (reduced by 33.9%)*
```asm
.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()
* = DATA_ADDRESS "Data Block"
    .fill $100, $00
* = CODE_ADDRESS "Main Code"
    jmp Initialize
.var VIC_BANK						= floor(LOAD_ADDRESS / $4000)
.var VIC_BANK_ADDRESS               = VIC_BANK * $4000
.var file_charsetData = LoadBinary("CharSet.map")
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
#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR
#define INCLUDE_MUSIC_ANALYSIS
#define INCLUDE_RASTER_TIMING_CODE
.var DEFAULT_RASTERTIMING_Y = 140
.import source "../INC/Common.asm"
.import source "../INC/keyboard.asm"
.import source "../INC/musicplayback.asm"
.import source "../INC/StableRasterSetup.asm"
.import source "../INC/Spectrometer.asm"
.import source "../INC/FreqTable.asm"
.align NUM_FREQUENCY_BARS
previousHeightsScreen0:     .fill NUM_FREQUENCY_BARS, 255
.align NUM_FREQUENCY_BARS
previousHeightsScreen1:     .fill NUM_FREQUENCY_BARS, 255
.align NUM_FREQUENCY_BARS
previousColors:             .fill NUM_FREQUENCY_BARS, 255
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
SetupSystem:
	lda #$35
	sta $01
	lda #(63 - VIC_BANK)
	sta $dd00
	lda #VIC_BANK
	sta $dd02
	rts
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
	jsr UpdateBars
	jsr AnalyseMusic
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
VICConfigStart:
	.byte $00, $00
	.byte $00, $00
	.byte $00, $00
	.byte $00, $00
	.byte $00, $00
	.byte $00, $00
	.byte $00, $00
	.byte $00, $00
	.byte $00
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte $00
	.byte $08
	.byte $00
	.byte D018_VALUE_0
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00, $00
	.byte $00, $00, $00
	.byte $00, $00, $00, $00
	.byte $00, $00, $00, $00
VICConfigEnd:
visualizationUpdateFlag:	.byte $00
frameCounter:				.byte $00
frame256Counter:			.byte $00
currentScreenBuffer:		.byte $00
D018Values:					.byte D018_VALUE_0, D018_VALUE_1
heightColorTable:
	.fill 2, $0B
	.fill 12, $09
	.fill 12, $06
	.fill 12, $04
	.fill 11, $0E
	.fill 11, $0D
	.fill 12, $07
	.fill MAX_BAR_HEIGHT, 224
barCharacterMap:
	.fill 8, 225 + i
	.fill MAX_BAR_HEIGHT, 233
* = CHARSET_ADDRESS "Font"
	.fill min($700, file_charsetData.getSize()), file_charsetData.get(i)
* = CHARSET_ADDRESS + (224 * 8) "Bar Chars"
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $00, $00, $00, $00, $00, $00, $00, $7C
	.byte $00, $00, $00, $00, $00, $00, $7C, $BE
	.byte $00, $00, $00, $00, $00, $7C, $BE, $BE
	.byte $00, $00, $00, $00, $7C, $BE, $BE, $BE
	.byte $00, $00, $00, $7C, $BE, $BE, $BE, $BE
	.byte $00, $00, $7C, $BE, $BE, $BE, $BE, $BE
	.byte $00, $7C, $BE, $BE, $BE, $BE, $BE, $BE
	.byte $7C, $BE, $BE, $BE, $BE, $BE, $BE, $BE
	.byte $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $7C, $00, $00, $00, $00, $00, $00, $00
	.byte $BE, $7C, $00, $00, $00, $00, $00, $00
	.byte $BE, $BE, $7C, $00, $00, $00, $00, $00
	.byte $BE, $BE, $BE, $7C, $00, $00, $00, $00
	.byte $BE, $BE, $BE, $BE, $7C, $00, $00, $00
	.byte $BE, $BE, $BE, $BE, $BE, $7C, $00, $00
	.byte $BE, $BE, $BE, $BE, $BE, $BE, $7C, $00
	.byte $BE, $BE, $BE, $BE, $BE, $BE, $BE, $7C
	.byte $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE
* = SCREEN0_ADDRESS "Screen 0"
	.fill $400, $00
* = SCREEN1_ADDRESS "Screen 1"
	.fill $400, $00
```


## Player: RaistlinMirrorBarsWithLogo
Files: 1

### FILE: SIDPlayers/RaistlinMirrorBarsWithLogo/RaistlinMirrorBarsWithLogo.asm
*Original size: 13224 bytes, Cleaned: 8686 bytes (reduced by 34.3%)*
```asm
.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()
* = DATA_ADDRESS "Data Block"
    .fill $100, $00
* = CODE_ADDRESS "Main Code"
    jmp Initialize
.var VIC_BANK						= floor(LOAD_ADDRESS / $4000)
.var VIC_BANK_ADDRESS               = VIC_BANK * $4000
.var file_charsetData = LoadBinary("CharSet.map")
.const NUM_FREQUENCY_BARS				= 40
.const LOGO_HEIGHT						= 10
.const TOP_SPECTRUM_HEIGHT				= 6
.const TOTAL_SPECTRUM_HEIGHT			= TOP_SPECTRUM_HEIGHT * 2
.const BAR_INCREASE_RATE				= (TOP_SPECTRUM_HEIGHT * 1.3)
.const BAR_DECREASE_RATE				= (TOP_SPECTRUM_HEIGHT * 0.2)
.const SONG_TITLE_LINE					= 23
.const SPECTRUM_START_LINE				= 11
.eval setSeed(55378008)
.const SCREEN0_BANK						= 12
.const SCREEN1_BANK						= 13
.const CHARSET_BANK						= 7
.const BITMAP_BANK						= 1
.const BITMAP_ADDRESS					= VIC_BANK_ADDRESS + (BITMAP_BANK * $2000)
.const SCREEN0_ADDRESS					= VIC_BANK_ADDRESS + (SCREEN0_BANK * $400)
.const SCREEN1_ADDRESS					= VIC_BANK_ADDRESS + (SCREEN1_BANK * $400)
.const BITMAP_COL_DATA					= SCREEN1_ADDRESS
.const CHARSET_ADDRESS					= VIC_BANK_ADDRESS + (CHARSET_BANK * $800)
.const D018_VALUE_0						= (SCREEN0_BANK * 16) + (CHARSET_BANK * 2)
.const D018_VALUE_1						= (SCREEN1_BANK * 16) + (CHARSET_BANK * 2)
.const D018_VALUE_BITMAP				= (SCREEN0_BANK * 16) + (BITMAP_BANK * 8)
.const MAX_BAR_HEIGHT					= TOP_SPECTRUM_HEIGHT * 8 - 1
.const MAIN_BAR_OFFSET					= MAX_BAR_HEIGHT - 7
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR
#define INCLUDE_MUSIC_ANALYSIS
.import source "../INC/Common.asm"
.import source "../INC/keyboard.asm"
.import source "../INC/musicplayback.asm"
.import source "../INC/StableRasterSetup.asm"
.import source "../INC/Spectrometer.asm"
.import source "../INC/FreqTable.asm"
.align NUM_FREQUENCY_BARS
previousHeightsScreen0:     .fill NUM_FREQUENCY_BARS, 255
.align NUM_FREQUENCY_BARS
previousHeightsScreen1:     .fill NUM_FREQUENCY_BARS, 255
.align NUM_FREQUENCY_BARS
previousColors:             .fill NUM_FREQUENCY_BARS, 255
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
	jsr DrawScreens
	ldy #$00
	lda #$00
!loop:
	sta barHeights - 2, y
	sta smoothedHeights - 2, y
	iny
	cpy #NUM_FREQUENCY_BARS + 4
	bne !loop-
	jsr SetupMusic
	lda #<MainIRQ
	sta $fffe
	lda #>MainIRQ
	sta $ffff
	lda #251
	sta $d012
	lda #$7b
	sta $d011
	lda #$01
	sta $d01a
	sta $d019
	lda BitmapScreenColour
	sta $d021
	jsr VSync
	lda BorderColour
	sta $d020
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
SetupSystem:
	lda #$35
	sta $01
	lda #(63 - VIC_BANK)
	sta $dd00
	lda #VIC_BANK
	sta $dd02
	rts
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
RenderBars:
	ldy #NUM_FREQUENCY_BARS
!colorLoop:
	dey
	bmi !colorsDone+
	ldx smoothedHeights, y
	lda heightColorTable, x
	cmp previousColors, y
	beq !colorLoop-
	sta previousColors, y
	.for (var line = 0; line < TOTAL_SPECTRUM_HEIGHT; line++) {
		sta $d800 + ((SPECTRUM_START_LINE + line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
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
		sta SCREEN1_ADDRESS + ((SPECTRUM_START_LINE + (TOP_SPECTRUM_HEIGHT * 2 - 1) - line) * 40) + ((40 - NUM_FREQUENCY_BARS) / 2), y
	}
	jmp !loop-
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
	lda #$01
	sta $d800 + ((SONG_TITLE_LINE + 0) * 40) + 4, y
	sta $d800 + ((SONG_TITLE_LINE + 1) * 40) + 4, y
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
VICConfigStart:
	.byte $00, $00
	.byte $00, $00
	.byte $00, $00
	.byte $00, $00
	.byte $00, $00
	.byte $00, $00
	.byte $00, $00
	.byte $00, $00
	.byte $00
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte $00
	.byte $18
	.byte $00
	.byte D018_VALUE_BITMAP
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00, $00
	.byte $00, $00, $00
	.byte $00, $00, $00, $00
	.byte $00, $00, $00, $00
VICConfigEnd:
visualizationUpdateFlag:	.byte $00
frameCounter:				.byte $00
frame256Counter:			.byte $00
currentScreenBuffer:		.byte $00
colorUpdateIndex:			.byte $00
currentPalette:				.byte $00
D018Values:					.byte D018_VALUE_0, D018_VALUE_1
heightColorTable:
	.fill 2, $0B
	.fill 4, $09
	.fill 4, $02
	.fill 4, $06
	.fill 4, $08
	.fill 4, $04
	.fill 4, $05
	.fill 5, $0E
	.fill 5, $0A
	.fill 6, $0D
	.fill 7, $07
	.fill MAX_BAR_HEIGHT, 224
barCharacterMap:
	.fill 8, 225 + i
	.fill MAX_BAR_HEIGHT, 233
* = CHARSET_ADDRESS "Font"
	.fill min($700, file_charsetData.getSize()), file_charsetData.get(i)
* = CHARSET_ADDRESS + (224 * 8) "Bar Chars"
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $00, $00, $00, $00, $00, $00, $00, $7C
	.byte $00, $00, $00, $00, $00, $00, $7C, $BE
	.byte $00, $00, $00, $00, $00, $7C, $BE, $BE
	.byte $00, $00, $00, $00, $7C, $BE, $BE, $BE
	.byte $00, $00, $00, $7C, $BE, $BE, $BE, $BE
	.byte $00, $00, $7C, $BE, $BE, $BE, $BE, $BE
	.byte $00, $7C, $BE, $BE, $BE, $BE, $BE, $BE
	.byte $7C, $BE, $BE, $BE, $BE, $BE, $BE, $BE
	.byte $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE
	.byte $00, $00, $00, $00, $00, $00, $00, $00
	.byte $7C, $00, $00, $00, $00, $00, $00, $00
	.byte $BE, $7C, $00, $00, $00, $00, $00, $00
	.byte $BE, $BE, $7C, $00, $00, $00, $00, $00
	.byte $BE, $BE, $BE, $7C, $00, $00, $00, $00
	.byte $BE, $BE, $BE, $BE, $7C, $00, $00, $00
	.byte $BE, $BE, $BE, $BE, $BE, $7C, $00, $00
	.byte $BE, $BE, $BE, $BE, $BE, $BE, $7C, $00
	.byte $BE, $BE, $BE, $BE, $BE, $BE, $BE, $7C
	.byte $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE
* = SCREEN0_ADDRESS "Screen 0"
	.fill LOGO_HEIGHT * 40, $00
	.fill $400 - (LOGO_HEIGHT * 40), $20
* = SCREEN1_ADDRESS "Screen 1"
	.fill LOGO_HEIGHT * 40, $00
	.fill $400 - (LOGO_HEIGHT * 40), $20
* = BITMAP_ADDRESS "Bitmap"
	.fill $C80, $00
```


## Player: SimpleBitmap
Files: 1

### FILE: SIDPlayers/SimpleBitmap/SimpleBitmap.asm
*Original size: 4392 bytes, Cleaned: 3266 bytes (reduced by 25.6%)*
```asm
.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()
* = DATA_ADDRESS "Data Block"
    .fill $100, $00
* = CODE_ADDRESS "Main Code"
    jmp Initialize
.var VIC_BANK						= floor(LOAD_ADDRESS / $4000)
.var VIC_BANK_ADDRESS               = VIC_BANK * $4000
.var BITMAP_BANK                    = 1
.var SCREEN_BANK                    = 2
.var COLOUR_BANK                    = 3
.const DD00Value                        = 3 - VIC_BANK
.const DD02Value                        = 60 + VIC_BANK
.const D018Value                        = (SCREEN_BANK * 16) + (BITMAP_BANK * 8)
.const BITMAP_MAP_DATA                  = VIC_BANK_ADDRESS + (BITMAP_BANK * $2000)
.const BITMAP_SCREEN_DATA               = VIC_BANK_ADDRESS + (SCREEN_BANK * $0400)
.const BITMAP_COLOUR_DATA               = VIC_BANK_ADDRESS + (COLOUR_BANK * $0400)
#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR
#define INCLUDE_RASTER_TIMING_CODE
.var DEFAULT_RASTERTIMING_Y = 250
.import source "../INC/Common.asm"
.import source "../INC/keyboard.asm"
.import source "../INC/musicplayback.asm"
Initialize:
    sei
    lda #$35
    sta $01
    jsr VSync
    lda #$00
    sta $d011
    sta $d020
    sta $d021
    jsr InitKeyboard
    lda SongNumber
    sta CurrentSong
    lda NumSongs
    bne !skip+
    lda #1
    sta NumSongs
!skip:
    lda #0
    sta ShowRasterBars
    lda CurrentSong
    tax
    tay
    jsr SIDInit
    jsr NMIFix
    ldy #$00
!loop:
    .for (var i = 0; i < 4; i++)
    {
        lda BITMAP_COLOUR_DATA + (i * 256), y
        sta $d800 + (i * 256), y
    }
    iny
    bne !loop-
    lda BitmapScreenColour
    sta $d021
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
    lda #DD00Value
    sta $dd00
    lda #DD02Value
    sta $dd02
    lda #D018Value
    sta $d018
    lda #$18
    sta $d016
    lda #$00
    sta $d015
    jsr VSync
    lda BorderColour
    sta $d020
    lda #$3b
    sta $d011
    ldx #0
    jsr set_d011_and_d012
    cli
MainLoop:
    jsr CheckKeyboard
    jmp MainLoop
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
    jsr CheckSpaceKey
    lda FastForwardActive
    bne !ffFrameLoop-
    lda BorderColour
    sta $d020
    lda #$00
    sta callCount + 1
    jmp !done+
!normalPlay:
callCount:
    ldx #0
    inx
    cpx NumCallsPerFrame
    bne !justPlay+
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
* = BITMAP_MAP_DATA "Bitmap MAP Data"
    .fill $2000, $00
* = BITMAP_SCREEN_DATA "Bitmap SCR Data"
    .fill $400, $00
* = BITMAP_COLOUR_DATA "Bitmap COL Data"
    .fill $400, $00
```


## Player: SimpleBitmapWithScroller
Files: 1

### FILE: SIDPlayers/SimpleBitmapWithScroller/SimpleBitmapWithScroller.asm
*Original size: 9939 bytes, Cleaned: 7573 bytes (reduced by 23.8%)*
```asm
.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()
* = DATA_ADDRESS "Data Block"
    .fill $100, $00
* = CODE_ADDRESS "Main Code"
    jmp Initialize
.var VIC_BANK						= floor(LOAD_ADDRESS / $4000)
.var VIC_BANK_ADDRESS               = VIC_BANK * $4000
.var BITMAP_BANK                    = 1
.var SCREEN_BANK                    = 2
.var COLOUR_BANK                    = 3
.var SPRITES_INDEX                  = 0
.var ScrollColour					= DATA_ADDRESS + $80
.const DD00Value                        = 3 - VIC_BANK
.const DD02Value                        = 60 + VIC_BANK
.const D018Value                        = (SCREEN_BANK * 16) + (BITMAP_BANK * 8)
.const BITMAP_MAP_DATA                  = VIC_BANK_ADDRESS + (BITMAP_BANK * $2000)
.const BITMAP_SCREEN_DATA               = VIC_BANK_ADDRESS + (SCREEN_BANK * $0400)
.const BITMAP_COLOUR_DATA               = VIC_BANK_ADDRESS + (COLOUR_BANK * $0400)
.const SPRITES_DATA                     = VIC_BANK_ADDRESS + (SPRITES_INDEX * 64)
.const SCROLLTEXT_ADDR                  = VIC_BANK_ADDRESS - $1800
#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_F1_SHOWRASTERTIMINGBAR
#define INCLUDE_RASTER_TIMING_CODE
.var DEFAULT_RASTERTIMING_Y = 250
.import source "../INC/Common.asm"
.import source "../INC/keyboard.asm"
.import source "../INC/musicplayback.asm"
Initialize:
    sei
    lda #$35
    sta $01
    jsr VSync
    lda #$00
    sta $d011
    sta $d020
    jsr InitializeVIC
    lda BitmapScreenColour
    sta $d021
    jsr InitKeyboard
    jsr CopyROMFont
    lda SongNumber
    sta CurrentSong
    lda NumSongs
    bne !skip+
    lda #1
    sta NumSongs
!skip:
    lda #0
    sta ShowRasterBars
    lda CurrentSong
    tax
    tay
    jsr SIDInit
    jsr NMIFix
    ldy #$00
!loop:
    .for (var i = 0; i < 4; i++)
    {
        lda BITMAP_COLOUR_DATA + (i * 256), y
        sta $d800 + (i * 256), y
    }
    iny
    bne !loop-
    ldy #$07
!loop:
    lda ScrollColour
    sta $d027, y
    dex
    dey
    bpl !loop-
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
    lda #DD00Value
    sta $dd00
    lda #DD02Value
    sta $dd02
    lda #D018Value
    sta $d018
    jsr VSync
    lda BorderColour
    sta $d020
    lda #$3b
    sta $d011
    ldx #0
    jsr set_d011_and_d012
    cli
MainLoop:
    jsr CheckKeyboard
    jmp MainLoop
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
    jsr CheckSpaceKey
    lda FastForwardActive
    bne !ffFrameLoop-
    lda BorderColour
    sta $d020
    lda #$00
    sta callCount + 1
    jmp !done+
!normalPlay:
callCount:
    ldx #0
    inx
    cpx NumCallsPerFrame
    bne !justPlay+
    ldx #0
!justPlay:
    stx callCount + 1
    jsr JustPlayMusic
!done:
    jsr SpriteScroller
    ldx callCount + 1
    jsr set_d011_and_d012
    asl $d019
    pla
    tay
    pla
    tax
    pla
    rti
SpriteScroller:
    ldx #$0e
    dex
    dex
    bpl !skip+
    jsr ScrollSprites
    ldx #$0f
!skip:
    stx SpriteScroller + 1
    txa
    clc
    sta $d000
    adc #$30
    sta $d002
    adc #$30
    sta $d004
    adc #$30
    sta $d006
    adc #$30
    sta $d008
    adc #$30
    sta $d00a
    adc #$30
    sta $d00c
    eor #$70
    sta $d00e
    rts
ScrollSprites:
    ldy #$00
!loop:
    lda SPRITES_DATA + (0 * 64) + 1, y
    sta SPRITES_DATA + (0 * 64) + 0, y
    lda SPRITES_DATA + (0 * 64) + 2, y
    sta SPRITES_DATA + (0 * 64) + 1, y
    lda SPRITES_DATA + (1 * 64) + 0, y
    sta SPRITES_DATA + (0 * 64) + 2, y
    lda SPRITES_DATA + (1 * 64) + 1, y
    sta SPRITES_DATA + (1 * 64) + 0, y
    lda SPRITES_DATA + (1 * 64) + 2, y
    sta SPRITES_DATA + (1 * 64) + 1, y
    lda SPRITES_DATA + (2 * 64) + 0, y
    sta SPRITES_DATA + (1 * 64) + 2, y
    lda SPRITES_DATA + (2 * 64) + 1, y
    sta SPRITES_DATA + (2 * 64) + 0, y
    lda SPRITES_DATA + (2 * 64) + 2, y
    sta SPRITES_DATA + (2 * 64) + 1, y
    lda SPRITES_DATA + (3 * 64) + 0, y
    sta SPRITES_DATA + (2 * 64) + 2, y
    lda SPRITES_DATA + (3 * 64) + 1, y
    sta SPRITES_DATA + (3 * 64) + 0, y
    lda SPRITES_DATA + (3 * 64) + 2, y
    sta SPRITES_DATA + (3 * 64) + 1, y
    lda SPRITES_DATA + (4 * 64) + 0, y
    sta SPRITES_DATA + (3 * 64) + 2, y
    lda SPRITES_DATA + (4 * 64) + 1, y
    sta SPRITES_DATA + (4 * 64) + 0, y
    lda SPRITES_DATA + (4 * 64) + 2, y
    sta SPRITES_DATA + (4 * 64) + 1, y
    lda SPRITES_DATA + (5 * 64) + 0, y
    sta SPRITES_DATA + (4 * 64) + 2, y
    lda SPRITES_DATA + (5 * 64) + 1, y
    sta SPRITES_DATA + (5 * 64) + 0, y
    lda SPRITES_DATA + (5 * 64) + 2, y
    sta SPRITES_DATA + (5 * 64) + 1, y
    lda SPRITES_DATA + (6 * 64) + 0, y
    sta SPRITES_DATA + (5 * 64) + 2, y
    lda SPRITES_DATA + (6 * 64) + 1, y
    sta SPRITES_DATA + (6 * 64) + 0, y
    lda SPRITES_DATA + (6 * 64) + 2, y
    sta SPRITES_DATA + (6 * 64) + 1, y
    lda SPRITES_DATA + (7 * 64) + 0, y
    sta SPRITES_DATA + (6 * 64) + 2, y
    lda SPRITES_DATA + (7 * 64) + 1, y
    sta SPRITES_DATA + (7 * 64) + 0, y
    lda SPRITES_DATA + (7 * 64) + 2, y
    sta SPRITES_DATA + (7 * 64) + 1, y
    iny
    iny
    iny
    cpy #(8 * 3)
    beq !finished+
    jmp !loop-
!finished:
ReadScroller:
    lda SCROLLTEXT_ADDR
    bne !notEnd+
    lda #<SCROLLTEXT_ADDR
    sta ReadScroller + 1
    lda #>SCROLLTEXT_ADDR
    sta ReadScroller + 2
    bne ReadScroller
!notEnd:
    tax
    lsr
    lsr
    lsr
    lsr
    lsr
    ora #$58
    sta InCharPtr + 2
    txa
    asl
    asl
    asl
    sta InCharPtr + 1
    ldx #7
    ldy #(7 * 3)
InCharPtr:
    lda $abcd, x
    sta SPRITES_DATA + (7 * 64) + 2, y
    dey
    dey
    dey
    dex
    bpl InCharPtr
    inc ReadScroller + 1
    bne !skip+
    inc ReadScroller + 2
!skip:
    rts
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
CopyROMFont:
    lda $01
    pha
    lda #$33
    sta $01
    ldx #$08
    ldy #$00
InPtr:
    lda $d800, y
OutPtr:
    sta $5800, y
    iny
    bne InPtr
    inc InPtr + 2
    inc OutPtr + 2
    dex
    bne InPtr
    pla
    sta $01
    rts
VICConfigStart:
	.byte $00, $ea
	.byte $00, $ea
	.byte $00, $ea
	.byte $00, $ea
	.byte $00, $ea
	.byte $00, $ea
	.byte $00, $ea
	.byte $00, $ea
	.byte $c0
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte $ff
	.byte $18
	.byte $ff
	.byte D018Value
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte $00
	.byte $00
	.byte $ff
	.byte $00
	.byte $00
	.byte SKIP_REGISTER
	.byte SKIP_REGISTER
	.byte $00, $00
	.byte $00, $00, $00
	.byte $01, $01, $01, $01
	.byte $01, $01, $01, $01
VICConfigEnd:
* = SCROLLTEXT_ADDR "ScrollText"
    .byte $53, $49, $44, $17, $09, $0e, $04, $05, $12, $20, $20, $2d, $2d, $2d, $20, $20, $00
* = SPRITES_DATA "Sprite Data"
    .fill $200, $00
* = BITMAP_MAP_DATA "Bitmap MAP Data"
    .fill $2000, $00
* = BITMAP_SCREEN_DATA "Bitmap SCR Data"
    .fill $3f8, $00
    .fill 8, SPRITES_INDEX + i
* = BITMAP_COLOUR_DATA "Bitmap COL Data"
    .fill $400, $00
```


## Player: SimpleRaster
Files: 1

### FILE: SIDPlayers/SimpleRaster/SimpleRaster.asm
*Original size: 4302 bytes, Cleaned: 2032 bytes (reduced by 52.8%)*
```asm
.var LOAD_ADDRESS                   = cmdLineVars.get("loadAddress").asNumber()
.var CODE_ADDRESS                   = cmdLineVars.get("sysAddress").asNumber()
.var DATA_ADDRESS                   = cmdLineVars.get("dataAddress").asNumber()
* = DATA_ADDRESS "Data Block"
    .fill $100, $00
* = CODE_ADDRESS "Main Code"
    jmp Initialize
#define INCLUDE_SPACE_FASTFORWARD
#define INCLUDE_PLUS_MINUS_SONGCHANGE
#define INCLUDE_09ALPHA_SONGCHANGE
#define INCLUDE_RASTER_TIMING_CODE
.var DEFAULT_RASTERTIMING_Y = 250
.import source "../INC/Common.asm"
.import source "../INC/keyboard.asm"
.import source "../INC/musicplayback.asm"
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
    lda NumSongs
    bne !skip+
    lda #1
    sta NumSongs
!skip:
    lda CurrentSong
    tax
    tay
    jsr SIDInit
    jsr VSync
    jsr NMIFix
    jsr init_D011_D012_values
    lda #<MusicIRQ
    sta $fffe
    lda #>MusicIRQ
    sta $ffff
    ldx #0
	jsr set_d011_and_d012
    lda #$7f
    sta $dc0d
    lda $dc0d
    lda #$01
    sta $d01a
    lda #$01
    sta $d019
    cli
Forever:
    jsr CheckKeyboard
    jmp Forever
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
    jsr CheckSpaceKey
    lda FastForwardActive
    bne !ffFrameLoop-
    lda #$00
    sta $d020
    lda #0
    sta callCount + 1
    jmp !done+
!normalPlay:
callCount:
    ldx #0
    inx
    cpx NumCallsPerFrame
    bne !justPlay+
ColChangeFrame:
    ldy #$c0
    iny
    bne !skip2+
    inc $d020
    ldy #$c0
!skip2:
    sty ColChangeFrame + 1
    ldx #0
!justPlay:
    stx callCount + 1
    inc $d020
    jsr SIDPlay
    dec $d020
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
```
