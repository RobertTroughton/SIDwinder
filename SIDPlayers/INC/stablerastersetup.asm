//; =============================================================================
//;                       STABLE RASTER INTERRUPT SETUP
//; Cycle-exact raster stabilisation for jitter-free interrupts using CIA
//; timer B to absorb the variable-length instruction at IRQ entry.
//; =============================================================================

#importonce

//; =============================================================================
//; SetupStableRaster
//; Page-aligned to avoid page-crossing penalties on the timing-critical loop.
//; Technique from Spindle by lft (www.linusakesson.net/software/spindle/).
//; Clobbers: A, X, Y
//; =============================================================================

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
