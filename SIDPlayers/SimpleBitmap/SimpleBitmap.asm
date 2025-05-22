* = PlayerADDR

.var BitmapMAPFile = LoadBinary("bitmap.map")
.var BitmapSCRFile = LoadBinary("bitmap.scr")
.var BitmapCOLFile = LoadBinary("bitmap.col")

.var BitmapMAPData = $a000
.var BitmapCOLData = $8800
.var BitmapSCRData = $8c00

InitIRQ:

    sei

    lda #$35
    sta $01

    jsr VSync

	lda #$00
	sta $d011
	sta $d020
	sta $d021
    jsr SIDInit

    jsr VSync

    jsr NMIFix

    ldy #$00
!loop:
    lda BitmapCOLData + (0 * 256), y
    sta $d800         + (0 * 256), y
    lda BitmapCOLData + (1 * 256), y
    sta $d800         + (1 * 256), y
    lda BitmapCOLData + (2 * 256), y
    sta $d800         + (2 * 256), y
    lda BitmapCOLData + (3 * 256), y
    sta $d800         + (3 * 256), y
    iny
    bne !loop-

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

    jsr VSync

    ldx #0
    jsr SetNextRaster

    lda #$01
    sta $dd00
    lda #$3e
    sta $dd02
    lda #$38
    sta $d018
    lda #$18
    sta $d016
    lda #$00
    sta $d015

    lda $d011
    and #$80
    ora #$3b
    sta $d011

    cli

Forever:
    jmp Forever

VSync:
	bit	$d011
	bpl	*-3
	bit	$d011
	bmi	*-3
    rts

SetNextRaster:
    lda D012_Values, x
    sta $d012
    lda $d011
    and #$7f
    ora D011_Values, x
    sta $d011
    rts

MusicIRQ:
callCount:
    ldx #0
    inx
    cpx #NumCallsPerFrame
    bne JustPlayMusic
    ldx #0

JustPlayMusic:
    stx callCount + 1

    jsr SIDPlay

    ldx callCount + 1
    jsr SetNextRaster

    asl $d019
    rti

.import source "../INC/NMIFix.asm"
.import source "../INC/RasterLineTiming.asm"

* = BitmapMAPData "Bitmap MAP"
	.fill BitmapMAPFile.getSize(), BitmapMAPFile.get(i)

* = BitmapSCRData "Bitmap SCR"
	.fill BitmapSCRFile.getSize(), BitmapSCRFile.get(i)

* = BitmapCOLData "Bitmap COL"
	.fill BitmapCOLFile.getSize(), BitmapCOLFile.get(i)
