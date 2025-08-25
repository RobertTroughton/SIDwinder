// default.asm - Text-based SID information display visualizer
// =============================================================================
//                             TEXT INFO PLAYER
//                   Text-based SID Information Display for C64
// =============================================================================
// Part of the SIDwinder player collection
// A minimalist text display showing SID file information and playback controls
// =============================================================================

* = $4100 "Main Code"

.var MainAddress = * - $100

    jmp InitIRQ

.var Display_Title_Colour           = $01
.var Display_Artist_Colour          = $0f
.var Display_Copyright_Colour       = $0c
.var Display_ReleaseData_Colour     = $0c
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

.var Display_ReleaseData_X          = 4
.var Display_ReleaseData_Y          = 4

.var Display_Separator1_Y           = 6

.var Display_Memory_X               = 9 + 2
.var Display_Memory_Y               = 7

.var Display_InitLabel_X            = 9 + 4
.var Display_InitLabel_Y            = 8

.var Display_PlayLabel_X            = 9 + 4
.var Display_PlayLabel_Y            = 9

.var Display_ZP_X                   = 9 + 0
.var Display_ZP_Y                   = 10
.var Display_Songs_X                = 9 + 3
.var Display_Songs_Y                = 11
.var Display_Clock_X                = 9 + 3
.var Display_Clock_Y                = 12
.var Display_SID_X                  = 9 + 5
.var Display_SID_Y                  = 13

.var Display_Separator2_Y           = 14

.var Display_Time_X                 = 9 + 4
.var Display_Time_Y                 = 15
.var Display_Song_X                 = 9 + 4
.var Display_Song_Y                 = 16

.var Display_Separator3_Y           = 17

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

.var SIDInit = MainAddress + 0
.var SIDPlay = MainAddress + 3
.var BackupSIDMemory = MainAddress + 6
.var RestoreSIDMemory = MainAddress + 9
.var NumCallsPerFrame = MainAddress + 12
//;.var BorderColour = MainAddress + 13
//;.var BackgroundColour = MainAddress + 14
.var SongNumber = MainAddress + 15
.var SongName = MainAddress + 16
.var ArtistName = MainAddress + 16 + 32
.var CopyrightInfo = MainAddress + 16 + 64  // Extended data area
.var ReleaseDate = MainAddress + 16 + 96  // 0x4070

// Additional metadata that we'll need to populate from analysis
.var LoadAddress = $40C0
.var InitAddress = $40C2
.var PlayAddress = $40C4
.var EndAddress = $40C6
.var NumSongs = $40C8
.var ClockType = $40C9     // 0=PAL, 1=NTSC
.var SIDModel = $40CA      // 0=6581, 1=8580
.var ZPUsageData = $40E0   // Will store formatted ZP usage string

// Constants
.const SCREEN_RAM = $0400
.const COLOR_RAM = $d800
.const ROW_WIDTH = 40

// Import the keyboard scanner module
.import source "../INC/keyboard.asm"

// =============================================================================
// INITIALIZATION ENTRY POINT
// =============================================================================

InitIRQ:
    sei

    // Configure memory mapping
    lda #$35
    sta $01

    // Initialize keyboard scanning
    jsr InitKeyboard

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
    
    lda #$00
    sta $d020
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

FastForwardActive:  .byte $00
FFCallCounter:      .byte $00

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
    ldx #Display_Title_X
    ldy #Display_Title_Y
    jsr SetCursor
    lda #<SongName
    ldy #>SongName
    ldx #Display_Title_Colour
    jsr PrintString

    // Author - centered
    ldx #Display_Artist_X
    ldy #Display_Artist_Y
    jsr SetCursor
    lda #<ArtistName
    ldy #>ArtistName
    ldx #Display_Artist_Colour
    jsr PrintString

    // Copyright - centered
    ldx #Display_Copyright_X
    ldy #Display_Copyright_Y
    jsr SetCursor
    lda #<CopyrightInfo
    ldy #>CopyrightInfo
    ldx #Display_Copyright_Colour
    jsr PrintString

    ldx #Display_ReleaseData_X
    ldy #Display_ReleaseData_Y
    jsr SetCursor
    lda #<ReleaseDate
    ldy #>ReleaseDate
    ldx #Display_ReleaseData_Colour
    jsr PrintString
    
    // Draw separator using proper screen codes
    ldx #0
    ldy #Display_Separator1_Y
    jsr DrawSeparator

    // Memory range - properly formatted
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

    // Init address
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

    // Play address - on same line, column 20
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

    // Zero page usage
    ldx #Display_ZP_X
    ldy #Display_ZP_Y
    jsr SetCursor
    lda #<ZPLabel
    ldy #>ZPLabel
    ldx #Display_InfoTitles_Colour
    jsr PrintString
    
    ldx #Display_InfoValues_Colour
    jsr PrintZPUsage

    // Songs, Clock, and SID Model
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

    // Draw separator
    ldx #0
    ldy #Display_Separator2_Y
    jsr DrawSeparator

    // Time label
    ldx #Display_Time_X
    ldy #Display_Time_Y
    jsr SetCursor
    lda #<TimeLabel
    ldy #>TimeLabel
    ldx #Display_InfoTitles_Colour
    jsr PrintString

    // Song label (only if multiple songs)
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
    // Draw separator before controls
    ldx #0
    ldy #Display_Separator3_Y
    jsr DrawSeparator

    // Draw controls info
    jmp DrawControls

// =============================================================================
// DRAW SEPARATOR LINE
// =============================================================================

DrawSeparator:

    jsr SetCursor

    ldy #39
    ldx #Display_Separators_Colour
!loop:
    lda #$2d  // Screen code for '-'
    jsr PrintChar
    dey
    bpl !loop-
    rts

// =============================================================================
// DRAW CONTROLS
// =============================================================================

DrawControls:
    
    // Controls header
    ldx #Display_ControlsTitle_X
    ldy #Display_ControlsTitle_Y
    jsr SetCursor
    lda #<ControlsLabel
    ldy #>ControlsLabel
    ldx #Display_ControlsTitle_Colour
    jsr PrintString

    // F1 for raster bars
    ldx #Display_Controls_F1_X
    ldy #Display_Controls_F1_Y
    jsr SetCursor
    lda #<F1Text
    ldy #>F1Text
    ldx #Display_ControlsInfo_Colour
    jsr PrintString

    // SPACE for fast-forward
    ldx #Display_Controls_SPACE_X
    ldy #Display_Controls_SPACE_Y
    jsr SetCursor
    lda #<SpaceText
    ldy #>SpaceText
    ldx #Display_ControlsInfo_Colour
    jsr PrintString
    
    // Check if we have multiple songs
    lda NumSongs
    cmp #2
    bcs !multipleSongs+
    rts

!multipleSongs:
    // Multiple songs - show selection keys
    ldx #Display_Controls_SongSelectKeys_X
    ldy #Display_Controls_SongSelectKeys_Y
    jsr SetCursor
    
    // Determine range to show
    lda NumSongs
    cmp #10  // Changed from 11 to 10
    bcc !under10+
    
    // 10+ songs - show "1-9, A-?"
    lda #<Select19Text  // Changed from Select09Text
    ldy #>Select19Text
    ldx #Display_ControlsInfo_Colour
    jsr PrintString
    
    // Check if we need letters too
    lda NumSongs
    cmp #10
    beq !nav+  // Exactly 9 songs, no letters needed
    
    lda #<CommaSpace
    ldy #>CommaSpace
    ldx #Display_ControlsInfo_Colour
    jsr PrintString
    
    // Show A-? range
    lda #<AThru
    ldy #>AThru
    ldx #Display_ControlsInfo_Colour
    jsr PrintString
    
    // Calculate last letter (A = song 10, B = song 11, etc.)
    lda NumSongs
    sec
    sbc #9  // Convert to letter offset
    cmp #27  // More than 26 letters?
    bcc !letter+
    lda #26  // Cap at Z
!letter:
    clc
    adc #'A'-1
    jsr PrintChar
    
    jmp !nav+

!under10:
    // Under 10 songs - show "1-X"
    lda #<OneThru  // Changed from ZeroThru
    ldy #>OneThru
    ldx #Display_ControlsInfo_Colour
    jsr PrintString
    
    lda NumSongs
    clc
    adc #'0'  // Convert to ASCII digit (1-9)
    jsr PrintChar
    
    lda #<SelectSuffix
    ldy #>SelectSuffix
    ldx #Display_ControlsInfo_Colour
    jsr PrintString

!nav:
    // Navigation keys
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
    // Update timer display
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

    // Update current song (if multiple)
    lda NumSongs
    cmp #2
    bcc !skip+

    ldx #Display_Song_X + 6
    ldy #Display_Song_Y
    jsr SetCursor
    
    ldx #Display_InfoValues_Colour
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
// KEYBOARD HANDLER (Now using hardware scanning with proper debouncing)
// =============================================================================

CheckKeyboard:
    // Check SPACE key (already working)
    jsr CheckSpaceKey
    
    // Check F1 key directly
    jsr CheckF1Key
    lda F1KeyPressed
    beq !notF1+
    lda F1KeyReleased
    beq !notF1+  // Still held from last time
    
    // F1 was just pressed
    lda #0
    sta F1KeyReleased
    lda ShowRasterBars
    eor #$01
    sta ShowRasterBars
    jmp !done+
    
!notF1:
    lda F1KeyPressed
    bne !stillF1+
    lda #1
    sta F1KeyReleased  // F1 released, ready for next press
!stillF1:

    // Only check song selection keys if we have multiple songs
    lda NumSongs
    cmp #2
    bcs !skip+
    rts
!skip:
    
    // Check + key directly
    jsr CheckPlusKey
    lda PlusKeyPressed
    beq !notPlus+
    lda PlusKeyReleased
    beq !notPlus+  // Still held from last time
    
    // + was just pressed
    lda #0
    sta PlusKeyReleased
    jsr NextSong
    jmp !done+
    
!notPlus:
    lda PlusKeyPressed
    bne !stillPlus+
    lda #1
    sta PlusKeyReleased  // + released, ready for next press
!stillPlus:

    // Check - key directly
    jsr CheckMinusKey
    lda MinusKeyPressed
    beq !notMinus+
    lda MinusKeyReleased
    beq !notMinus+  // Still held from last time
    
    // - was just pressed
    lda #0
    sta MinusKeyReleased
    jsr PrevSong
    jmp !done+
    
!notMinus:
    lda MinusKeyPressed
    bne !stillMinus+
    lda #1
    sta MinusKeyReleased  // - released, ready for next press
!stillMinus:

    // For letter/number keys, use the general scanner
    jsr ScanKeyboard
    
    // Check if we got a key (0 means no key or still debouncing)
    cmp #0
    beq !done+
    
    // We have a debounced key press
    sta TempStorage
    
    // Get the key with shift detection for letters
    lda TempStorage
    jsr GetKeyWithShift
    sta TempStorage
    
    lda TempStorage
    
    // Check 1-9 (for songs 1-9)
    cmp #'1'
    bcc !notDigit+
    cmp #':'  // '9'+1
    bcs !notDigit+
    
    // Convert 1-9 to 0-8 (internal song numbers)
    sec
    sbc #'1'  // '1' becomes 0, '2' becomes 1, etc.
    cmp NumSongs
    bcs !done+
    
    jsr SelectSong
    jmp !done+
    
!notDigit:
    // Check A-Z (uppercase) for songs 10-35
    cmp #'A'
    bcc !checkLowercase+
    cmp #'['  // 'Z'+1
    bcs !checkLowercase+
    
    // Uppercase letter - A=song 10 (index 9)
    sec
    sbc #'A'-9  // 'A' becomes 9, 'B' becomes 10, etc.
    cmp NumSongs
    bcs !done+
    
    jsr SelectSong
    jmp !done+
    
!checkLowercase:
    // Check a-z (lowercase) for songs 10-35
    cmp #'a'
    bcc !done+
    cmp #'{'  // 'z'+1
    bcs !done+
    
    // Lowercase letter - a=song 10 (index 9)
    sec
    sbc #'a'-9  // 'a' becomes 9, 'b' becomes 10, etc.
    cmp NumSongs
    bcs !done+
    
    jsr SelectSong
    
!done:
    rts

// Direct hardware key checks
CheckSpaceKey:
    ldx #$00
    lda #%01111111  // Row 7
    sta $DC00
    lda $DC01
    and #%00010000  // Column 4 (SPACE)
    eor #%00010000
    sta FastForwardActive
    rts

CheckF1Key:
    lda #%11111110  // Row 0
    sta $DC00
    lda $DC01
    and #%00010000  // Column 4 (F1)
    eor #%00010000
    sta F1KeyPressed
    rts

CheckPlusKey:
    lda #%11011111  // Row 5
    sta $DC00
    lda $DC01
    and #%00000001  // Column 0 (+)
    eor #%00000001
    sta PlusKeyPressed
    rts

CheckMinusKey:
    lda #%11011111  // Row 5
    sta $DC00
    lda $DC01
    and #%00001000  // Column 3 (-)
    eor #%00001000
    sta MinusKeyPressed
    rts

// Key state variables
F1KeyPressed:    .byte 0
F1KeyReleased:   .byte 1
PlusKeyPressed:  .byte 0
PlusKeyReleased: .byte 1
MinusKeyPressed: .byte 0
MinusKeyReleased:.byte 1

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
    beq !skip+
    lda #$02
    sta $d020
!skip:

    // Check if we're in fast-forward mode
    lda FastForwardActive
    beq !normalPlay+
    
    // === FAST FORWARD MODE ===
    // We need to call SIDPlay NumCallsPerFrame times to simulate one frame
    // Then check for space release and update timer
    
!ffFrameLoop:
    // Call SIDPlay the required number of times for one frame
    lda NumCallsPerFrame
    sta FFCallCounter
    
!ffCallLoop:
    jsr SIDPlay
    inc $d020  // Visual feedback
    dec FFCallCounter
    lda FFCallCounter
    bne !ffCallLoop-
    
    // One complete "frame" worth of calls done
    jsr UpdateTimer
    jsr UpdateDynamicInfo
    
    // Check if space is still held
    jsr CheckSpaceKey
    lda FastForwardActive
    bne !ffFrameLoop-  // Continue fast-forward
    
    // Space released - exit fast-forward
    lda #$00
    sta $d020
    
    // Reset the call counter for normal operation
    lda #0
    sta callCount + 1
    
    jmp !done+

!normalPlay:
    // === NORMAL PLAY MODE ===
callCount:
    ldx #0
    inx
    cpx NumCallsPerFrame
    bne !justPlay+
    
    // Frame boundary - all calls for this frame complete
    jsr UpdateTimer
    jsr UpdateDynamicInfo
    ldx #0

!justPlay:
    stx callCount + 1
    
    // Play music once
    jsr SIDPlay
    
    lda ShowRasterBars
    beq !skip+
    lda #$00
    sta $d020
!skip:

!done:
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

// Raster tables
.var FrameHeight = 312

D011_Values_1Call: .byte 0
D012_Values_1Call: .byte 128
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