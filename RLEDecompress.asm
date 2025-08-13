.var UncompressedDataStartPtr = $081a
.var CompressedDataEndPtr = $081c
.var FinalJumpPtr = $081e

.var TopAddressForDecompressData = $fff0

.var ZP_ADDR = $f0

.var ZP_COPY_SrcPtr					= ZP_ADDR + 0
.var ZP_COPY_DstPtr					= ZP_ADDR + 2
.var ZP_RLE_SrcPtr					= ZP_ADDR + 2 //; nb. the RLE source is the same as the copy destination
.var ZP_RLE_DstPtr					= ZP_ADDR + 4
.var ZP_RLE_CurrentBlockSizePtr		= ZP_ADDR + 6

* = $081a

	.byte $00, $08 //; <UncompressedDataStart, >UncompressedDataStart
	.byte $00, $20 //; <CompressedDataEnd, >CompressedDataEnd
	.byte $00, $41 //; <FinalJMP, >FinalJMP

	sei

!wait:
	lda $d011
	bpl !wait-
!wait:
	lda $d011
	bmi !wait-
	lda #$00
	sta $d020
	sta $d011
	sta $d418

	lda $01
	pha
	lda #$34
	sta $01

	lda FinalJumpPtr + 0
	sta FinalJMP + 1
	lda FinalJumpPtr + 1
	sta FinalJMP + 2

	ldy #(rledecompress_code_end - rledecompress_code_start - 1)
!loop:
	lda rledecompress_code_start, y
	sta $0200, y
	dey
	bpl !loop-

	lda CompressedDataEndPtr + 0
	sta ZP_COPY_SrcPtr + 0
	lda CompressedDataEndPtr + 1
	sta ZP_COPY_SrcPtr + 1

	lda #<TopAddressForDecompressData
	sta ZP_COPY_DstPtr + 0
	lda #>TopAddressForDecompressData
	sta ZP_COPY_DstPtr + 1

	ldy #$00

!loop:
	ldx ZP_COPY_SrcPtr + 0
	bne !skip+
	dec ZP_COPY_SrcPtr + 1
!skip:
	dec ZP_COPY_SrcPtr + 0

	ldx ZP_COPY_DstPtr + 0
	bne !skip+
	dec ZP_COPY_DstPtr + 1
!skip:
	dec ZP_COPY_DstPtr + 0

	lda (ZP_COPY_SrcPtr), y
	sta (ZP_RLE_SrcPtr), y

	lda ZP_COPY_SrcPtr + 0
	cmp #<rledecompress_code_end
	bne !loop-
	lda ZP_COPY_SrcPtr + 1
	cmp #>rledecompress_code_end
	bne !loop-

	// no need here to set ZP_RLE_SrcPtr as it is the same as ZP_COPY_DstPtr - which should be at the correct position already

	lda UncompressedDataStartPtr + 0
	sta ZP_RLE_DstPtr + 0
	lda UncompressedDataStartPtr + 1
	sta ZP_RLE_DstPtr + 1
	
	jmp $0200	//; start depacking!

	
rledecompress_code_start:

	ldy #$00

grab_next_block:
	lda (ZP_RLE_SrcPtr), y
	inc ZP_RLE_SrcPtr + 0
	bne !skip+
	inc ZP_RLE_SrcPtr + 1
!skip:
	sta ZP_RLE_CurrentBlockSizePtr + 0

	lda (ZP_RLE_SrcPtr), y
	inc ZP_RLE_SrcPtr + 0
	bne !skip+
	inc ZP_RLE_SrcPtr + 1
!skip:
	tax
	and #$7f
	sta ZP_RLE_CurrentBlockSizePtr + 1

	ora ZP_RLE_CurrentBlockSizePtr + 0
	bne !skip+
jump_out:
	pla
	sta $01
	cli
FinalJMP:
	jmp $abcd	//; finished - we will fill this address later
!skip:
	
	txa
	bmi do_repeats

do_literals:
literals_loop:
	lda (ZP_RLE_SrcPtr), y
	inc ZP_RLE_SrcPtr + 0
	bne !skip+
	inc ZP_RLE_SrcPtr + 1
!skip:
	sta (ZP_RLE_DstPtr), y
	inc ZP_RLE_DstPtr + 0
	bne !skip+
	inc ZP_RLE_DstPtr + 1
!skip:
	dec ZP_RLE_CurrentBlockSizePtr + 0
	bne literals_loop
	dec ZP_RLE_CurrentBlockSizePtr + 1
	bpl literals_loop
	bmi grab_next_block

do_repeats:
	lda (ZP_RLE_SrcPtr), y
	inc ZP_RLE_SrcPtr + 0
	bne !skip+
	inc ZP_RLE_SrcPtr + 1
!skip:
repeats_loop:
	sta (ZP_RLE_DstPtr), y
	inc ZP_RLE_DstPtr + 0
	bne !skip+
	inc ZP_RLE_DstPtr + 1
!skip:
	dec ZP_RLE_CurrentBlockSizePtr + 0
	bne repeats_loop
	dec ZP_RLE_CurrentBlockSizePtr + 1
	bpl repeats_loop
	bmi grab_next_block

rledecompress_code_end:
