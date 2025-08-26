//; =============================================================================
//; StableRasterSetup.asm - Stable Raster Interrupt Setup
//; Part of the SIDwinder visualization framework
//;
//; This module provides cycle-exact raster stabilization for jitter-free
//; interrupts. Essential for smooth visual effects and precise timing.
//; =============================================================================

#importonce

//; =============================================================================
//; SetupStableRaster - Initialize stable raster interrupts
//; 
//; This routine must be aligned to avoid page-crossing penalties during
//; critical timing loops. It uses CIA timer B to compensate for interrupt
//; jitter, ensuring pixel-perfect raster effects.
//;
//; Based on the technique from Spindle by lft (www.linusakesson.net/software/spindle/)
//;
//; Registers: Corrupts A, X, Y
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
