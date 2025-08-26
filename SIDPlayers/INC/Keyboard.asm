// keyboard.asm - Unified keyboard handling for SIDwinder visualizers
// =============================================================================
//                          KEYBOARD HANDLER MODULE
//                     Unified keyboard handling for all visualizers
// =============================================================================

#importonce

// CIA#1 Port registers
.const CIA1_PRA = $dc00  
.const CIA1_PRB = $dc01  
.const CIA1_DDRA = $dc02 
.const CIA1_DDRB = $dc03 

// Special key codes (non-ASCII) - ALL needed for the matrix table
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

// Variables for keyboard handling
CurrentKeyMatrix:   .byte 0     
CurrentKey:         .byte 0     
LastKey:            .byte 0     
KeyReleased:        .byte 1     
DebounceCounter:    .byte 0     
.const DEBOUNCE_DELAY = 5       

// Common variables (always allocated but conditionally used)
CurrentSong:        .byte $00
ShowRasterBars:     .byte $00

#if INCLUDE_SPACE_FASTFORWARD
FastForwardActive:  .byte $00
FFCallCounter:      .byte $00
#endif

// Key state tracking
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

// =============================================================================
// Main keyboard check routine
// =============================================================================
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
    // Check if we have multiple songs
    lda NumSongs
    cmp #2
    bcs !multiSong+
    rts
    
!multiSong:
    #if INCLUDE_PLUS_MINUS_SONGCHANGE
    // Check +/- keys
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
    // Check number/letter keys
    jsr ScanKeyboard
    cmp #0
    beq !done+
    
    jsr GetKeyWithShift
    
    // Check 1-9
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
    // Check A-Z
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

// =============================================================================
// Initialize keyboard scanning
// =============================================================================
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

// =============================================================================
// Direct key checks
// =============================================================================

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

// =============================================================================
// Song selection
// =============================================================================

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

// =============================================================================
// Scan keyboard matrix - with proper debouncing
// Returns: A = key code (0 if no key or still debouncing)
// =============================================================================
ScanKeyboard:
    // First, detect if any key is pressed
    jsr DetectKeyPress
    
    // A now contains the matrix position or 0 if no key
    cmp #0
    bne !keyPressed+
    
    // No key pressed
    lda #1
    sta KeyReleased
    lda #0
    sta DebounceCounter
    sta CurrentKey
    sta LastKey
    rts
    
!keyPressed:
    // A key is pressed - check if it's a new press
    sta CurrentKeyMatrix
    
    // Check if we already processed this key
    lda KeyReleased
    bne !newPress+
    
    // Key is being held - return 0 (no new key event)
    lda #0
    rts
    
!newPress:
    // New key press - implement debouncing
    lda CurrentKeyMatrix
    cmp LastKey
    beq !sameKey+
    
    // Different key - reset debounce counter
    lda CurrentKeyMatrix
    sta LastKey
    lda #DEBOUNCE_DELAY
    sta DebounceCounter
    lda #0
    rts
    
!sameKey:
    // Same key - check debounce counter
    dec DebounceCounter
    bne !stillDebouncing+
    
    // Debounce complete - process the key
    lda #0
    sta KeyReleased  // Mark key as processed
    
    // Convert matrix position to ASCII/special code
    lda CurrentKeyMatrix
    jsr ConvertMatrixToASCII
    sta CurrentKey
    rts
    
!stillDebouncing:
    lda #0
    rts

// =============================================================================
// Detect key press and return matrix position
// Returns: A = matrix position (row*8 + column), or 0 if no key
// =============================================================================
DetectKeyPress:
    // Scan the keyboard matrix
    ldy #0           // Row counter
    
!scanRow:
    lda RowSelectTable,y
    sta CIA1_PRA     // Write to Port A to select row
    lda CIA1_PRB     // Read columns from Port B
    cmp #$ff         // Check if any key pressed (active low)
    bne !foundKey+
    
    // No key in this row, try next
    iny
    cpy #8
    bne !scanRow-
    
    // No key found
    lda #0
    rts
    
!foundKey:
    // Found a key - determine which column
    eor #$ff         // Invert to make pressed keys = 1
    ldx #0
    
!findColumn:
    lsr
    bcs !gotColumn+  // Carry set = this column pressed
    inx
    cpx #8
    bne !findColumn-
    
    // Shouldn't get here, but return 0 if we do
    lda #0
    rts
    
!gotColumn:
    // Calculate matrix position: row * 8 + column
    tya              // Row in Y
    asl
    asl
    asl              // Row * 8
    sta TempCalc
    txa              // Column in X
    clc
    adc TempCalc     // Add column
    rts

TempCalc: .byte 0

// Row select patterns (one bit low for each row)
RowSelectTable:
    .byte %11111110  // Row 0
    .byte %11111101  // Row 1
    .byte %11111011  // Row 2
    .byte %11110111  // Row 3
    .byte %11101111  // Row 4
    .byte %11011111  // Row 5
    .byte %10111111  // Row 6
    .byte %01111111  // Row 7

// =============================================================================
// C64 Keyboard Matrix Table (CORRECTED)
// Based on the actual C64 matrix: rows (Port A output) x columns (Port B input)
// Each entry is row*8 + column
// =============================================================================
KeyMatrixTable:
    // Row 0 (PA0 = 0)
    .byte KEY_DELETE      // 0,0 = DEL/INST
    .byte KEY_RETURN      // 0,1 = Return
    .byte KEY_CURSOR_LR   // 0,2 = Cursor Right/Left
    .byte KEY_F7          // 0,3 = F7/F8
    .byte KEY_F1          // 0,4 = F1/F2
    .byte KEY_F3          // 0,5 = F3/F4
    .byte KEY_F5          // 0,6 = F5/F6
    .byte KEY_CURSOR_UD   // 0,7 = Cursor Down/Up
    
    // Row 1 (PA1 = 0)
    .byte '3'             // 1,0
    .byte 'w'             // 1,1
    .byte 'a'             // 1,2
    .byte '4'             // 1,3
    .byte 'z'             // 1,4
    .byte 's'             // 1,5
    .byte 'e'             // 1,6
    .byte KEY_SHIFT       // 1,7 = Left Shift
    
    // Row 2 (PA2 = 0)
    .byte '5'             // 2,0
    .byte 'r'             // 2,1
    .byte 'd'             // 2,2
    .byte '6'             // 2,3
    .byte 'c'             // 2,4
    .byte 'f'             // 2,5
    .byte 't'             // 2,6
    .byte 'x'             // 2,7
    
    // Row 3 (PA3 = 0)
    .byte '7'             // 3,0
    .byte 'y'             // 3,1
    .byte 'g'             // 3,2
    .byte '8'             // 3,3
    .byte 'b'             // 3,4
    .byte 'h'             // 3,5
    .byte 'u'             // 3,6
    .byte 'v'             // 3,7
    
    // Row 4 (PA4 = 0)
    .byte '9'             // 4,0
    .byte 'i'             // 4,1
    .byte 'j'             // 4,2
    .byte '0'             // 4,3
    .byte 'm'             // 4,4
    .byte 'k'             // 4,5
    .byte 'o'             // 4,6
    .byte 'n'             // 4,7
    
    // Row 5 (PA5 = 0)
    .byte '+'             // 5,0 = Plus
    .byte 'p'             // 5,1
    .byte 'l'             // 5,2
    .byte '-'             // 5,3 = Minus
    .byte '.'             // 5,4 = Period
    .byte ':'             // 5,5 = Colon (shift ;)
    .byte '@'             // 5,6
    .byte ','             // 5,7 = Comma
    
    // Row 6 (PA6 = 0)
    .byte $5c             // 6,0 = £
    .byte '*'             // 6,1
    .byte ';'             // 6,2
    .byte KEY_HOME        // 6,3 = CLR/HOME
    .byte KEY_SHIFT       // 6,4 = Right Shift
    .byte '='             // 6,5
    .byte $5e             // 6,6 = ↑ (up arrow)
    .byte '/'             // 6,7
    
    // Row 7 (PA7 = 0)
    .byte '1'             // 7,0
    .byte $5f             // 7,1 = ← (left arrow)
    .byte KEY_CONTROL     // 7,2 = Control
    .byte '2'             // 7,3
    .byte ' '             // 7,4 = Space
    .byte KEY_COMMODORE   // 7,5 = C=
    .byte 'q'             // 7,6
    .byte KEY_RUNSTOP     // 7,7 = Run/Stop

// =============================================================================
// Convert matrix position to ASCII/special key code
// Input: A = matrix position (column * 8 + row)
// Output: A = ASCII or special key code
// =============================================================================
ConvertMatrixToASCII:
    tax
    lda KeyMatrixTable,x
    rts

// =============================================================================
// Check if specific key is currently pressed (no debouncing)
// Input: A = key code to check
// Returns: A = 0 if not pressed, non-zero if pressed
// =============================================================================
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

// =============================================================================
// Get key with shift detection (for uppercase letters)
// Call after ScanKeyboard returns a key
// =============================================================================
GetKeyWithShift:
    // Save the key
    sta TempKey
    
    // Check if shift is pressed
    lda #%11111101    // Column 1 (left shift)
    sta CIA1_PRA
    lda CIA1_PRB
    and #%10000000    // Row 7
    beq !shiftPressed+
    
    lda #%10111111    // Column 6 (right shift)
    sta CIA1_PRA
    lda CIA1_PRB
    and #%00010000    // Row 4
    beq !shiftPressed+
    
    // No shift - return original key
    lda TempKey
    rts
    
!shiftPressed:
    // Shift pressed - convert if it's a letter
    lda TempKey
    cmp #'a'
    bcc !notLowercase+
    cmp #'z'+1
    bcs !notLowercase+
    
    // Convert to uppercase
    and #$df
    rts
    
!notLowercase:
    // Check for number to symbol conversion
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
    lda #$27  // Apostrophe
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
    
    // Return original key
    lda TempKey
    rts

TempKey: .byte 0