// =============================================================================
//                      SIMPLE BITMAP WITH SCROLLER PLAYER
//                   Bitmap Graphics SID Music Player for C64
// =============================================================================

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
.var SPRITES_INDEX                  = $00

.var ScrollColour					= DATA_ADDRESS + $80

.const DD00Value                        = 3 - VIC_BANK
.const DD02Value                        = 60 + VIC_BANK
.const D018Value                        = (SCREEN_BANK * 16) + (BITMAP_BANK * 8)

.const BITMAP_MAP_DATA                  = VIC_BANK_ADDRESS + (BITMAP_BANK * $2000)
.const BITMAP_SCREEN_DATA               = VIC_BANK_ADDRESS + (SCREEN_BANK * $0400)
.const BITMAP_COLOUR_DATA               = VIC_BANK_ADDRESS + (COLOUR_BANK * $0400)
.const SPRITES_DATA                     = VIC_BANK_ADDRESS + (SPRITES_INDEX * 64)

.const SCROLLTEXT_ADDR                  = VIC_BANK_ADDRESS - $1800

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
// INITIALIZATION ENTRY POINT
// =============================================================================

Initialize:
    sei

    lda #$35
    sta $01

    jsr RunLinkedWithEffect

    jsr VSync

    lda #$00
    sta $d011
    sta $d020

    jsr InitializeVIC

    lda BitmapScreenColour
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

// =============================================================================
// MAIN MUSIC INTERRUPT HANDLER
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
    sta $d000       //; $00-0F
    adc #$30
    sta $d002       //; $30-3F
    adc #$30
    sta $d004       //; $60-6F
    adc #$30
    sta $d006       //; $90-9F
    adc #$30
    sta $d008       //; $C0-CF
    adc #$30
    sta $d00a       //; $F0-FF
    adc #$30
    sta $d00c       //; $20-2F
    eor #$70
    sta $d00e       //; $50-5F

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
    ora #$d8            //; ROM Charset High Byte
    sta InCharPtr + 2
    txa
    asl
    asl
    asl
    sta InCharPtr + 1

    lda #$33
    sta $01

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

    lda #$35
    sta $01

    inc ReadScroller + 1
    bne !skip+
    inc ReadScroller + 2
!skip:

    rts
   

//; =============================================================================
//; VIC INITIALIZATION
//; =============================================================================

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

//; =============================================================================
//; DATA SECTION - VIC Configuration
//; =============================================================================

VICConfigStart:
	.byte $00, $ea						//; Sprite 0 X,Y
	.byte $00, $ea						//; Sprite 1 X,Y
	.byte $00, $ea						//; Sprite 2 X,Y
	.byte $00, $ea						//; Sprite 3 X,Y
	.byte $00, $ea						//; Sprite 4 X,Y
	.byte $00, $ea						//; Sprite 5 X,Y
	.byte $00, $ea						//; Sprite 6 X,Y
	.byte $00, $ea						//; Sprite 7 X,Y
	.byte $c0							//; Sprite X MSB
	.byte SKIP_REGISTER					//; D011
	.byte SKIP_REGISTER					//; D012
	.byte SKIP_REGISTER					//; D013
	.byte SKIP_REGISTER					//; D014
	.byte $ff							//; Sprite enable
	.byte $18							//; D016
	.byte $ff							//; Sprite Y expand
	.byte D018Value     				//; D018
	.byte SKIP_REGISTER					//; D019
	.byte SKIP_REGISTER					//; D01A
	.byte $00							//; Sprite priority
	.byte $00							//; Sprite multicolor
	.byte $ff							//; Sprite X expand
	.byte $00							//; Sprite-sprite collision
	.byte $00							//; Sprite-background collision
	.byte SKIP_REGISTER					//; Border color
	.byte SKIP_REGISTER     			//; Background color
	.byte $00, $00						//; Extra colors
	.byte $00, $00, $00					//; Sprite extra colors
	.byte $01, $01, $01, $01			//; Sprite colors 0-3
	.byte $01, $01, $01, $01			//; Sprite colors 4-7
VICConfigEnd:

// =============================================================================
// DATA SECTION - Placeholder screen and bitmap data
// =============================================================================

* = SCROLLTEXT_ADDR "ScrollText"

    .byte $53, $49, $44, $17, $09, $0e, $04, $05, $12, $20, $20, $2d, $2d, $2d, $20, $20, $00

* = BITMAP_MAP_DATA "Bitmap MAP Data"
    .fill $2000, $00

* = BITMAP_SCREEN_DATA "Bitmap SCR Data"
    .fill $3f8, $00
    .fill 8, SPRITES_INDEX + i

* = BITMAP_COLOUR_DATA "Bitmap COL Data"
    .fill $400, $00

* = SPRITES_DATA
    .fill $200, $00
