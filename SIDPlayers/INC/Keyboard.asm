// keyboard.asm - Non-kernel keyboard scanning routines
// =============================================================================
//                          KEYBOARD SCANNER MODULE
//                     Direct hardware keyboard scanning for C64
// =============================================================================
// Part of the SIDwinder player collection
// Provides kernel-independent keyboard scanning functionality
// =============================================================================

// CIA#1 Port A and B for keyboard scanning
.const CIA1_PRA = $dc00  // Port A (keyboard column write)
.const CIA1_PRB = $dc01  // Port B (keyboard row read)
.const CIA1_DDRA = $dc02 // Data direction register A
.const CIA1_DDRB = $dc03 // Data direction register B

// Special key codes (non-ASCII)
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
CurrentKeyMatrix:   .byte 0     // Currently detected matrix position
CurrentKey:         .byte 0     // Currently pressed key (ASCII/special)
LastKey:            .byte 0     // Last pressed key for debouncing
KeyReleased:        .byte 1     // Flag for key release detection
DebounceCounter:    .byte 0     // Debounce counter
.const DEBOUNCE_DELAY = 5       // Frames to wait for debounce

// =============================================================================
// Initialize keyboard scanning
// =============================================================================
InitKeyboard:
    // Set up CIA ports for keyboard scanning
    lda #$ff
    sta CIA1_DDRA  // Port A all outputs (columns)
    lda #$00
    sta CIA1_DDRB  // Port B all inputs (rows)
    
    // Clear keyboard state
    lda #0
    sta CurrentKeyMatrix
    sta CurrentKey
    sta LastKey
    sta DebounceCounter
    lda #1
    sta KeyReleased
    
    rts

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
    ldx #0           // Column counter
    lda #%11111110   // Start with column 0 active
    
!scanColumn:
    sta CIA1_PRA     // Select column
    lda CIA1_PRB     // Read rows
    cmp #$ff         // Check if any key pressed (active low)
    bne !foundKey+
    
    // No key in this column, try next
    lda CIA1_PRA
    sec
    rol              // Rotate to next column
    inx
    cpx #8
    bne !scanColumn-
    
    // No key found
    lda #0
    rts
    
!foundKey:
    // Found a key - determine which row
    eor #$ff         // Invert to make pressed keys = 1
    ldy #0
    
!findRow:
    lsr
    bcs !gotRow+     // Carry set = this row pressed
    iny
    cpy #8
    bne !findRow-
    
    // Shouldn't get here, but return 0 if we do
    lda #0
    rts
    
!gotRow:
    // Calculate matrix position: column * 8 + row
    txa              // Column in X
    asl
    asl
    asl              // Column * 8
    sta TempCalc
    tya              // Row in Y
    clc
    adc TempCalc     // Add row
    rts

TempCalc: .byte 0

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
// C64 Keyboard Matrix Table
// Organized by column (0-7) and row (0-7)
// Each entry is column*8 + row
// =============================================================================
KeyMatrixTable:
    // Column 0
    .byte KEY_DELETE      // 0,0 = DEL
    .byte KEY_RETURN      // 0,1 = Return
    .byte KEY_CURSOR_LR   // 0,2 = Cursor Right/Left
    .byte KEY_F7          // 0,3 = F7
    .byte KEY_F1          // 0,4 = F1
    .byte KEY_F3          // 0,5 = F3
    .byte KEY_F5          // 0,6 = F5
    .byte KEY_CURSOR_UD   // 0,7 = Cursor Down/Up
    
    // Column 1
    .byte '3'             // 1,0
    .byte 'w'             // 1,1
    .byte 'a'             // 1,2
    .byte '4'             // 1,3
    .byte 'z'             // 1,4
    .byte 's'             // 1,5
    .byte 'e'             // 1,6
    .byte KEY_SHIFT       // 1,7 = Left Shift
    
    // Column 2
    .byte '5'             // 2,0
    .byte 'r'             // 2,1
    .byte 'd'             // 2,2
    .byte '6'             // 2,3
    .byte 'c'             // 2,4
    .byte 'f'             // 2,5
    .byte 't'             // 2,6
    .byte 'x'             // 2,7
    
    // Column 3
    .byte '7'             // 3,0
    .byte 'y'             // 3,1
    .byte 'g'             // 3,2
    .byte '8'             // 3,3
    .byte 'b'             // 3,4
    .byte 'h'             // 3,5
    .byte 'u'             // 3,6
    .byte 'v'             // 3,7
    
    // Column 4
    .byte '9'             // 4,0
    .byte 'i'             // 4,1
    .byte 'j'             // 4,2
    .byte '0'             // 4,3
    .byte 'm'             // 4,4
    .byte 'k'             // 4,5
    .byte 'o'             // 4,6
    .byte 'n'             // 4,7
    
    // Column 5
    .byte '+'             // 5,0
    .byte 'p'             // 5,1
    .byte 'l'             // 5,2
    .byte '-'             // 5,3
    .byte '.'             // 5,4
    .byte ':'             // 5,5
    .byte '@'             // 5,6
    .byte ','             // 5,7
    
    // Column 6
    .byte $5c             // 6,0 = £
    .byte '*'             // 6,1
    .byte ';'             // 6,2
    .byte KEY_HOME        // 6,3 = CLR/HOME
    .byte KEY_SHIFT       // 6,4 = Right Shift
    .byte '='             // 6,5
    .byte $5e             // 6,6 = ↑
    .byte '/'             // 6,7
    
    // Column 7
    .byte '1'             // 7,0
    .byte $5f             // 7,1 = ←
    .byte KEY_CONTROL     // 7,2 = Control
    .byte '2'             // 7,3
    .byte ' '             // 7,4 = Space
    .byte KEY_COMMODORE   // 7,5 = C=
    .byte 'q'             // 7,6
    .byte KEY_RUNSTOP     // 7,7 = Run/Stop

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