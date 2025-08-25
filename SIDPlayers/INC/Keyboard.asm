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

// Keyboard matrix lookup table
// Each byte represents one key in the 8x8 matrix
// Bit 7-3: column (0-7), Bit 2-0: row (0-7)
KeyMatrix:
    // Row 0: DEL, Return, Cursor R/L, F7, F1, F3, F5, Cursor U/D
    .byte $14, $01, $02, $03, $04, $05, $06, $07
    // Row 1: 3, W, A, 4, Z, S, E, Shift
    .byte '3', 'W', 'A', '4', 'Z', 'S', 'E', $00
    // Row 2: 5, R, D, 6, C, F, T, X
    .byte '5', 'R', 'D', '6', 'C', 'F', 'T', 'X'
    // Row 3: 7, Y, G, 8, B, H, U, V
    .byte '7', 'Y', 'G', '8', 'B', 'H', 'U', 'V'
    // Row 4: 9, I, J, 0, M, K, O, N
    .byte '9', 'I', 'J', '0', 'M', 'K', 'O', 'N'
    // Row 5: +, P, L, -, ., :, @, ,
    .byte '+', 'P', 'L', '-', '.', ':', '@', ','
    // Row 6: £, *, ;, Home, Shift, =, ↑, /
    .byte $5c, '*', ';', $13, $00, '=', $5e, '/'
    // Row 7: 1, ←, Control, 2, Space, C=, Q, Run/Stop
    .byte '1', $5f, $00, '2', ' ', $00, 'Q', $03

// Special key codes
.const KEY_F1 = $04
.const KEY_F3 = $05
.const KEY_F5 = $06
.const KEY_F7 = $03
.const KEY_RETURN = $01
.const KEY_DELETE = $14
.const KEY_HOME = $13
.const KEY_RUNSTOP = $03
.const KEY_CURSOR_UD = $07
.const KEY_CURSOR_LR = $02
.const KEY_SHIFT_LEFT = $0f
.const KEY_SHIFT_RIGHT = $34
.const KEY_CONTROL = $3a
.const KEY_COMMODORE = $3d

// Variables for keyboard handling
KeyboardState:      .fill 8, 0  // Current state of each row
LastKeyboardState:  .fill 8, 0  // Previous state for edge detection
CurrentKey:         .byte 0     // Currently pressed key
LastKey:            .byte 0     // Last pressed key
KeyRepeatCounter:   .byte 0     // Counter for key repeat
KeyRepeatDelay:     .byte 30    // Initial delay before repeat
KeyRepeatRate:      .byte 4     // Rate of repeat

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
    ldx #7
!loop:
    lda #0
    sta KeyboardState,x
    sta LastKeyboardState,x
    dex
    bpl !loop-
    
    lda #0
    sta CurrentKey
    sta LastKey
    sta KeyRepeatCounter
    
    rts

// =============================================================================
// Scan keyboard matrix
// Called once per frame
// Returns: A = key code (0 if no key), X = raw scancode
// =============================================================================
ScanKeyboard:
    // Save current state to last state
    ldx #7
!loop:
    lda KeyboardState,x
    sta LastKeyboardState,x
    dex
    bpl !loop-
    
    // Scan all columns
    ldx #0
    lda #$fe  // Start with column 0 active (bit 0 = 0)
    
!scanLoop:
    sta CIA1_PRA     // Select column
    lda CIA1_PRB     // Read rows
    eor #$ff         // Invert (pressed keys read as 0)
    sta KeyboardState,x
    
    inx
    cpx #8
    beq !scanDone+
    
    // Rotate to next column
    lda CIA1_PRA
    sec
    rol
    jmp !scanLoop-
    
!scanDone:
    // Reset keyboard to neutral state
    lda #$00
    sta CIA1_PRA
    
    // Process the scan results
    jmp ProcessKeyboard

// =============================================================================
// Process keyboard scan results
// Returns: A = ASCII key code or special key code
// =============================================================================
ProcessKeyboard:
    lda #0
    sta CurrentKey
    
    // Check each column for pressed keys
    ldx #0
!columnLoop:
    lda KeyboardState,x
    beq !nextColumn+
    
    // Found pressed key(s) in this column
    ldy #0
!rowLoop:
    lsr
    bcc !nextRow+
    
    // Key is pressed - calculate matrix position
    pha
    txa
    asl
    asl
    asl
    sta CurrentKey  // Column * 8
    tya
    ora CurrentKey  // Add row
    sta CurrentKey
    pla
    
!nextRow:
    iny
    cpy #8
    bne !rowLoop-
    
!nextColumn:
    inx
    cpx #8
    bne !columnLoop-
    
    // Convert matrix position to key code
    lda CurrentKey
    beq !noKey+
    
    // Check for special keys
    jsr TranslateMatrixToKey
    sta CurrentKey
    
    // Handle key repeat
    jsr HandleKeyRepeat
    rts
    
!noKey:
    lda #0
    sta KeyRepeatCounter
    sta LastKey
    rts

// =============================================================================
// Translate matrix position to key code
// Input: A = matrix position (col*8 + row)
// Output: A = ASCII or special key code
// =============================================================================
TranslateMatrixToKey:
    // Save matrix position
    tax
    
    // Special case handling for function keys
    cpx #$07  // F1
    bne !notF1+
    lda #KEY_F1
    rts
!notF1:
    cpx #$06  // F3
    bne !notF3+
    lda #KEY_F3
    rts
!notF3:
    cpx #$05  // F5
    bne !notF5+
    lda #KEY_F5
    rts
!notF5:
    cpx #$04  // F7
    bne !notF7+
    lda #KEY_F7
    rts
!notF7:
    
    // Check shift key state for character modification
    lda #$fd  // Column 1 (left shift)
    sta CIA1_PRA
    lda CIA1_PRB
    and #$80  // Row 7
    sta ShiftPressed
    
    lda #$bf  // Column 6 (right shift)
    sta CIA1_PRA
    lda CIA1_PRB
    and #$10  // Row 4
    ora ShiftPressed
    sta ShiftPressed
    
    // Reset keyboard
    lda #0
    sta CIA1_PRA
    
    // Get base character from matrix
    lda KeyMatrix,x
    
    // Apply shift if needed
    ldx ShiftPressed
    beq !noShift+
    
    // Simple shift mapping for letters
    cmp #'A'
    bcc !checkNumbers+
    cmp #'Z'+1
    bcs !checkNumbers+
    rts  // Already uppercase
    
!checkNumbers:
    // Number row shift characters
    cmp #'0'
    bne !not0+
    lda #')'
    rts
!not0:
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
    lda #$27  // Single quote
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
    
!noShift:
    // Convert uppercase to lowercase if shift not pressed
    ldx ShiftPressed
    bne !done+
    
    cmp #'A'
    bcc !done+
    cmp #'Z'+1
    bcs !done+
    ora #$20  // Convert to lowercase
    
!done:
    rts

ShiftPressed: .byte 0

// =============================================================================
// Handle key repeat
// =============================================================================
HandleKeyRepeat:
    // Check if same key as last time
    lda CurrentKey
    cmp LastKey
    beq !sameKey+
    
    // New key pressed
    sta LastKey
    lda KeyRepeatDelay
    sta KeyRepeatCounter
    lda CurrentKey
    rts
    
!sameKey:
    // Same key - handle repeat
    dec KeyRepeatCounter
    bne !noRepeat+
    
    // Repeat this key
    lda KeyRepeatRate
    sta KeyRepeatCounter
    lda CurrentKey
    rts
    
!noRepeat:
    lda #0  // Don't return key yet
    rts

// =============================================================================
// Get single key press (waits for key release)
// Returns: A = key code
// =============================================================================
GetKeyPress:
    jsr ScanKeyboard
    sta TempKey
    beq GetKeyPress  // Wait for key press
    
!waitRelease:
    jsr ScanKeyboard
    bne !waitRelease-  // Wait for key release
    
    lda TempKey
    rts

TempKey: .byte 0

// =============================================================================
// Check if specific key is pressed
// Input: A = key code to check
// Returns: A = 0 if not pressed, non-zero if pressed
// =============================================================================
IsKeyPressed:
    sta CheckKey
    jsr ScanKeyboard
    cmp CheckKey
    beq !pressed+
    lda #0
    rts
!pressed:
    lda #1
    rts

CheckKey: .byte 0