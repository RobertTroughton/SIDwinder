// TextInfo.asm - Text-based SID information display visualizer
// =============================================================================
//                             TEXT INFO PLAYER
//                   Text-based SID Information Display for C64
// =============================================================================
// Part of the SIDwinder player collection
// A minimalist text display showing SID file information and playback controls
// =============================================================================

* = $4100 "Main Code"

.var MainAddress = * - $100
.var SIDInit = MainAddress + 0
.var SIDPlay = MainAddress + 3
.var BackupSIDMemory = MainAddress + 6
.var RestoreSIDMemory = MainAddress + 9
.var NumCallsPerFrame = MainAddress + 12
.var BorderColour = MainAddress + 13
.var BackgroundColour = MainAddress + 14
.var SongNumber = MainAddress + 15
.var SongName = MainAddress + 16
.var ArtistName = MainAddress + 16 + 32
.var CopyrightInfo = MainAddress + 16 + 64  // Extended data area

// Additional metadata that we'll need to populate from analysis
.var LoadAddress = $4080
.var InitAddress = $4082
.var PlayAddress = $4084
.var EndAddress = $4086
.var NumSongs = $4088
.var ClockType = $4089     // 0=PAL, 1=NTSC
.var SIDModel = $408A      // 0=6581, 1=8580
.var ZPUsageData = $408B   // Will store formatted ZP usage string

// Constants
.const SCREEN_RAM = $0400
.const COLOR_RAM = $d800
.const ROW_WIDTH = 40

// =============================================================================
// INITIALIZATION ENTRY POINT
// =============================================================================

InitIRQ:
    sei

    // Configure memory mapping
    lda #$35
    sta $01

    // Wait for stable raster
    jsr VSync

    // Blank screen during setup
    lda #$00
    sta $d011

    // Initialize variables
    lda SongNumber
    sta CurrentSong
    lda #0
    sta TimerSeconds
    sta TimerMinutes
    sta FrameCounter
    sta ShowRasterBars
    
    // Set frames per second based on clock type
    lda ClockType
    beq !pal+
    lda #60
    jmp !store+
!pal:
    lda #50
!store:
    sta FramesPerSecond

    // Clear screen and set colors
    jsr ClearScreen
    
    // Set border and background
    lda BorderColour
    sta $d020
    lda BackgroundColour
    sta $d021

    // Set to text mode with uppercase/lowercase charset
    lda #$16  // Screen at $0400, charset at ROM default (lowercase)
    sta $d018

    // Populate metadata fields (this would be done by the linker)
    jsr PopulateMetadata

    // Draw the static information
    jsr DrawStaticInfo
    
    // Initialize the music
    lda CurrentSong
    tax
    tay
    jsr SIDInit

    // Disable NMI
    jsr NMIFix

    jsr init_D011_D012_values

    // Set up interrupts
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

    // Configure first raster position
    ldx #0
    jsr set_d011_and_d012

    // Enable display
    lda #$1b  // Text mode, display on, 25 rows
    sta $d011

    cli

    // Main loop - handle keyboard input
MainLoop:
    jsr CheckKeyboard
    jmp MainLoop

// =============================================================================
// RUNTIME VARIABLES (stored as local data, not in zero page)
// =============================================================================

CurrentSong:      .byte $00
TimerSeconds:     .byte $00
TimerMinutes:     .byte $00
FrameCounter:     .byte $00
ShowRasterBars:   .byte $00
FramesPerSecond:  .byte $32  // Default to 50 (PAL)

// Temporary storage for print routines
TempStorage:      .byte $00
CursorX:          .byte $00
CursorY:          .byte $00

// =============================================================================
// POPULATE METADATA (called by linker or filled by PRG builder)
// =============================================================================

PopulateMetadata:
    // This is where the PRG builder would inject actual data
    // For now, we'll read from the SID header locations
    
    // Get actual addresses from SID
    lda SIDInit+1
    sta InitAddress
    lda SIDInit+2
    sta InitAddress+1
    
    lda SIDPlay+1
    sta PlayAddress
    lda SIDPlay+2
    sta PlayAddress+1
    
    // Load address would be passed by the linker
    // For now, assume it's at $1000
    lda #$00
    sta LoadAddress
    lda #$10
    sta LoadAddress+1
    
    // End address would be calculated
    lda #$FF
    sta EndAddress
    lda #$2F
    sta EndAddress+1
    
    // Default to 1 song if not set
    lda NumSongs
    bne !skip+
    lda #1
    sta NumSongs
!skip:
    
    // Default to PAL if not set
    // (ClockType already set by PRG builder)
    
    // Default to 6581 if not set
    // (SIDModel already set by PRG builder)
    
    rts

// =============================================================================
// DRAW STATIC INFORMATION
// =============================================================================

DrawStaticInfo:
    // Clear screen with proper screen codes
    ldx #0
!loop:
    lda #$20        // Screen code for space
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

    // Title - center at column 4 (32 char field + 4 = 36, centered in 40)
    ldx #4
    ldy #0
    jsr SetCursor
    lda #<SongName
    ldy #>SongName
    ldx #$01 //; white
    jsr PrintString

    // Author - centered
    ldx #4
    ldy #1
    jsr SetCursor
    lda #<ArtistName
    ldy #>ArtistName
    ldx #$0f //; off-white
    jsr PrintString

    // Copyright - centered
    ldx #4
    ldy #2
    jsr SetCursor
    lda #<CopyrightInfo
    ldy #>CopyrightInfo
    ldx #$0c //; light grey
    jsr PrintString

    // Draw separator using proper screen codes
    ldx #0
    ldy #3
    jsr DrawSeparator

    // Memory range - properly formatted
    ldx #0
    ldy #4
    jsr SetCursor
    lda #<MemoryLabel
    ldy #>MemoryLabel
    ldx #$03 //; cyan
    jsr PrintString
    
    ldx #$01 //; white
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

    // Init address
    ldx #0
    ldy #5
    jsr SetCursor
    lda #<InitLabel
    ldy #>InitLabel
    ldx #$03 //; cyan
    jsr PrintString
    
    ldx #$01 //; white
    lda #'$'
    jsr PrintChar
    lda InitAddress+1
    jsr PrintHexByte
    lda InitAddress
    jsr PrintHexByte

    // Play address - on same line, column 20
    ldx #0
    ldy #6
    jsr SetCursor
    lda #<PlayLabel
    ldy #>PlayLabel
    ldx #$03 //; cyan
    jsr PrintString
    
    ldx #$01 //; white
    lda #'$'
    jsr PrintChar
    lda PlayAddress+1
    jsr PrintHexByte
    lda PlayAddress
    jsr PrintHexByte

    // Zero page usage
    ldx #0
    ldy #7
    jsr SetCursor
    lda #<ZPLabel
    ldy #>ZPLabel
    ldx #$03 //; cyan
    jsr PrintString
    
    ldx #$01 //; white
    jsr PrintZPUsage

    // Songs, Clock, and SID Model
    ldx #0
    ldy #8
    jsr SetCursor
    lda #<SongsLabel
    ldy #>SongsLabel
    ldx #$03 //; cyan
    jsr PrintString
    
    ldx #$01 //; white
    lda NumSongs
    jsr PrintHexByte

    ldx #0
    ldy #9
    jsr SetCursor
    lda #<ClockLabel
    ldy #>ClockLabel
    ldx #$03 //; cyan
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
    ldx #$01 //; white
    jsr PrintString

    ldx #0
    ldy #10
    jsr SetCursor
    lda #<SIDLabel
    ldy #>SIDLabel
    ldx #$03 //; cyan
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
    ldx #$01 //; white
    jsr PrintString

    // Draw separator
    ldx #0
    ldy #11
    jsr DrawSeparator

    // Time label
    ldx #0
    ldy #13
    jsr SetCursor
    lda #<TimeLabel
    ldy #>TimeLabel
    ldx #$03 //; cyan
    jsr PrintString

    // Song label (only if multiple songs)
    lda NumSongs
    cmp #2
    bcc !skip+
    
    ldx #0
    ldy #14
    jsr SetCursor
    lda #<CurrentSongLabel
    ldy #>CurrentSongLabel
    ldx #$03 //; cyan
    jsr PrintString

!skip:
    // Draw separator before controls
    ldx #0
    ldy #15
    jsr DrawSeparator

    // Draw controls info
    jsr DrawControls

    rts

// =============================================================================
// DRAW SEPARATOR LINE
// =============================================================================

DrawSeparator:

    jsr SetCursor

    ldy #39
    ldx #$0b
!loop:
    lda #$2d  // Screen code for '-'
    jsr PrintChar
    dey
    bpl !loop-

// =============================================================================
// DRAW CONTROLS
// =============================================================================

DrawControls:
    
    // Controls header
    ldx #0
    ldy #17
    jsr SetCursor
    lda #<ControlsLabel
    ldy #>ControlsLabel
    ldx #$05    //; green
    jsr PrintString

    // F1 for raster bars
    ldx #0
    ldy #19
    jsr SetCursor
    lda #<F1Text
    ldy #>F1Text
    ldx #$0a //; pink
    jsr PrintString

    // Check if we have multiple songs
    lda NumSongs
    cmp #2
    bcs !multipleSongs+
    rts

!multipleSongs:
    // Multiple songs - show selection keys
    ldx #0
    ldy #21
    jsr SetCursor
    
    // Determine range to show
    lda NumSongs
    cmp #11
    bcc !under10+
    
    // 10+ songs
    lda #<Select09Text
    ldy #>Select09Text
    ldx #$0a //; pink
    jsr PrintString
    
    // Check if we need letters too
    lda NumSongs
    cmp #11
    beq !nav+  // Exactly 10, no letters needed
    
    lda #<CommaSpace
    ldy #>CommaSpace
    ldx #$0a //; pink
    jsr PrintString
    
    // Show A-? range
    lda #<AThru
    ldy #>AThru
    ldx #$0a //; pink
    jsr PrintString
    
    // Calculate last letter
    lda NumSongs
    sec
    sbc #10
    cmp #26
    bcc !letter+
    lda #26  // Cap at Z
!letter:
    clc
    adc #'A'-1
    jsr PrintChar
    
    jmp !nav+

!under10:
    // Under 10 songs
    lda #<ZeroThru
    ldy #>ZeroThru
    ldx #$0a //; pink
    jsr PrintString
    
    lda NumSongs
    clc
    adc #'0'-1
    jsr PrintChar
    
    lda #<SelectSuffix
    ldy #>SelectSuffix
    ldx #$0a //; pink
    jsr PrintString

!nav:
    // Navigation keys
    ldx #0
    ldy #20
    jsr SetCursor
    lda #<NavigationText
    ldy #>NavigationText
    ldx #$0a //; pink
    jmp PrintString

// =============================================================================
// UPDATE DYNAMIC INFO
// =============================================================================

UpdateDynamicInfo:
    // Update timer display
    ldx #6
    ldy #13
    jsr SetCursor
    
    ldx #$01 //; white
    lda TimerMinutes
    jsr PrintTwoDigits
    lda #':'
    jsr PrintChar
    lda TimerSeconds
    jsr PrintTwoDigits

    // Update current song (if multiple)
    lda NumSongs
    cmp #2
    bcc !skip+
    
    ldx #6
    ldy #14
    jsr SetCursor
    
    ldx #$01 //; white
    lda CurrentSong
    clc
    adc #1  // Convert to 1-based
    jsr PrintTwoDigits
    lda #'/'
    jsr PrintChar
    lda NumSongs
    jsr PrintTwoDigits

!skip:
    rts

// =============================================================================
// PRINT ZERO PAGE USAGE
// =============================================================================

PrintZPUsage:
    // Print the ZP usage data string that was populated by PRG builder
    lda #<ZPUsageData
    ldy #>ZPUsageData
    jmp PrintString

// =============================================================================
// TIMER UPDATE
// =============================================================================

UpdateTimer:
    inc FrameCounter
    
    lda FrameCounter
    cmp FramesPerSecond
    bcc !done+
    
    // One second elapsed
    lda #0
    sta FrameCounter
    
    inc TimerSeconds
    lda TimerSeconds
    cmp #60
    bcc !done+
    
    // One minute elapsed
    lda #0
    sta TimerSeconds
    inc TimerMinutes
    
    // Cap at 99:59
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
// KEYBOARD HANDLER
// =============================================================================

CheckKeyboard:
    rts

    jsr $ff9f  // SCNKEY
    jsr $ffe4  // GETIN
    
    beq !done+
    
    // Store key
    sta TempStorage
    
    // Check for F1 (133)
    cmp #133
    bne !notF1+
    lda ShowRasterBars
    eor #$01
    sta ShowRasterBars
    rts

!notF1:
    // Only process song selection if multiple songs
    lda NumSongs
    cmp #2
    bcc !done+
    
    lda TempStorage
    
    // Check + and -
    cmp #'+'
    bne !notPlus+
    jsr NextSong
    rts
    
!notPlus:
    cmp #'-'
    bne !notMinus+
    jsr PrevSong
    rts
    
!notMinus:
    // Check 0-9
    cmp #'0'
    bcc !notDigit+
    cmp #':'  // '9'+1
    bcs !notDigit+
    
    sec
    sbc #'0'
    cmp NumSongs
    bcs !done+
    
    jsr SelectSong
    rts
    
!notDigit:
    // Check A-Z (for songs 10-35)
    cmp #'A'
    bcc !notLetter+
    cmp #'['  // 'Z'+1
    bcs !notLetter+
    
    sec
    sbc #'A'-10
    cmp NumSongs
    bcs !done+
    
    jsr SelectSong
    
!notLetter:
!done:
    rts

// =============================================================================
// SONG SELECTION
// =============================================================================

SelectSong:
    sta CurrentSong
    
    // Re-init with new song
    tax
    tay
    jsr SIDInit
    
    // Reset timer
    lda #0
    sta TimerSeconds
    sta TimerMinutes
    sta FrameCounter
    
    rts

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
    // A/Y = string address (null terminated)
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
    // A = character to print (PETSCII)
    
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
    jsr PrintHexNibble
    rts

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

TopNibbleBytes: .fill 60, (i / 10) + '0'
BottomNibbleBytes: .fill 60, mod(i, 10) + '0'

PrintTwoDigits:
    tay
    lda TopNibbleBytes, y
    jsr PrintChar

    lda BottomNibbleBytes, y
    jmp PrintChar

// =============================================================================
// INTERRUPT HANDLERS
// =============================================================================

VSync:
    bit $d011
    bpl *-3
    bit $d011
    bmi *-3
    rts

MusicIRQ:
    pha
    txa
    pha
    tya
    pha

    // Show raster timing if enabled
    lda ShowRasterBars
    beq !noRaster+
    lda $d020
    lda #2  // Red
    sta $d020

!noRaster:
    // Track call count
callCount:
    ldx #0
    inx
    cpx NumCallsPerFrame
    bne !justPlay+
    
    // Frame boundary
    jsr UpdateTimer
    jsr UpdateDynamicInfo
    ldx #0

!justPlay:
    stx callCount + 1
    
    // Play music
    jsr SIDPlay
    
    // Restore border
    lda ShowRasterBars
    beq !noRestore+
    sta $d020

!noRestore:
    // Next interrupt
    ldx callCount + 1
    jsr set_d011_and_d012
    
    asl $d019
    pla
    tay
    pla
    tax
    pla
    rti

// Raster timing routines (same as SimpleBitmap)
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

// Control text
Select09Text:       .text "0-9"
                    .byte 0
ZeroThru:           .text "0-"
                    .byte 0
AThru:              .text "A-"
                    .byte 0
CommaSpace:         .text ", "
                    .byte 0
SelectSuffix:       .text " = Select Song"
                    .byte 0
NavigationText:     .text "+/- = Next/Prev Song"
                    .byte 0
SingleSongText:     .text "Single Song (No Selection)"
                    .byte 0
F1Text:             .text "F1 = Toggle Timing Bar(s)"
                    .byte 0

// Raster tables
.var FrameHeight = 312

D011_Values_1Call: .fill 1, (>(mod(250 + ((FrameHeight * i) / 1), 312))) * $80
D012_Values_1Call: .fill 1, (<(mod(250 + ((FrameHeight * i) / 1), 312)))
D011_Values_2Calls: .fill 2, (>(mod(250 + ((FrameHeight * i) / 2), 312))) * $80
D012_Values_2Calls: .fill 2, (<(mod(250 + ((FrameHeight * i) / 2), 312)))
D011_Values_3Calls: .fill 3, (>(mod(250 + ((FrameHeight * i) / 3), 312))) * $80
D012_Values_3Calls: .fill 3, (<(mod(250 + ((FrameHeight * i) / 3), 312)))
D011_Values_4Calls: .fill 4, (>(mod(250 + ((FrameHeight * i) / 4), 312))) * $80
D012_Values_4Calls: .fill 4, (<(mod(250 + ((FrameHeight * i) / 4), 312)))
D011_Values_5Calls: .fill 5, (>(mod(250 + ((FrameHeight * i) / 5), 312))) * $80
D012_Values_5Calls: .fill 5, (<(mod(250 + ((FrameHeight * i) / 5), 312)))
D011_Values_6Calls: .fill 6, (>(mod(250 + ((FrameHeight * i) / 6), 312))) * $80
D012_Values_6Calls: .fill 6, (<(mod(250 + ((FrameHeight * i) / 6), 312)))
D011_Values_7Calls: .fill 7, (>(mod(250 + ((FrameHeight * i) / 7), 312))) * $80
D012_Values_7Calls: .fill 7, (<(mod(250 + ((FrameHeight * i) / 7), 312)))
D011_Values_8Calls: .fill 8, (>(mod(250 + ((FrameHeight * i) / 8), 312))) * $80
D012_Values_8Calls: .fill 8, (<(mod(250 + ((FrameHeight * i) / 8), 312)))

D011_Values_Lookup_Lo: .byte <D011_Values_1Call, <D011_Values_1Call, <D011_Values_2Calls, <D011_Values_3Calls, <D011_Values_4Calls, <D011_Values_5Calls, <D011_Values_6Calls, <D011_Values_7Calls, <D011_Values_8Calls
D011_Values_Lookup_Hi: .byte >D011_Values_1Call, >D011_Values_1Call, >D011_Values_2Calls, >D011_Values_3Calls, >D011_Values_4Calls, >D011_Values_5Calls, >D011_Values_6Calls, >D011_Values_7Calls, >D011_Values_8Calls
D012_Values_Lookup_Lo: .byte <D012_Values_1Call, <D012_Values_1Call, <D012_Values_2Calls, <D012_Values_3Calls, <D012_Values_4Calls, <D012_Values_5Calls, <D012_Values_6Calls, <D012_Values_7Calls, <D012_Values_8Calls
D012_Values_Lookup_Hi: .byte >D012_Values_1Call, >D012_Values_1Call, >D012_Values_2Calls, >D012_Values_3Calls, >D012_Values_4Calls, >D012_Values_5Calls, >D012_Values_6Calls, >D012_Values_7Calls, >D012_Values_8Calls

// Include NMI fix
.import source "../INC/NMIFix.asm"

// =============================================================================
// END OF FILE
// =============================================================================