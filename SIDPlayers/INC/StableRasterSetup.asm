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

.align 128									//; Critical for timing accuracy

SetupStableRaster: {
	//; Wait for vertical blank to ensure clean start
	bit $d011
	bmi *-3

	bit $d011
	bpl *-3

	//; Get current raster line
	ldx $d012
	inx

ResyncLoop:
	//; Wait for exact raster line match
	cpx $d012
	bne *-3

	//; Initialize CIA timer B for jitter compensation
	ldy #0
	sty $dc07								//; Timer B high byte = 0
	lda #62									//; Timer B low byte = 62
	sta $dc06								//; Total = 63 cycles

	//; Configure interrupts
	iny										//; Y = 1
	sty $d01a								//; Enable raster interrupts
	dey
	dey										//; Y = 255
	sty $dc02								//; Data direction register

	//; Waste exact cycles for synchronization
	cmp (0,x)								//; 6 cycles
	cmp (0,x)								//; 6 cycles
	cmp (0,x)								//; 6 cycles

	//; Start timer B in one-shot mode
	lda #$11
	sta $dc0f

	//; Check if we're still on the expected line
	txa
	inx
	inx
	cmp $d012
	bne ResyncLoop							//; If not, try again

	//; Disable all CIA interrupts
	lda #$7f
	sta $dc0d								//; CIA 1
	sta $dd0d								//; CIA 2

	//; Clear any pending interrupts
	lda $dc0d
	lda $dd0d

	//; Final synchronization
	bit $d011
	bpl *-3
	bit $d011
	bmi *-3

	//; Enable raster interrupts
	lda #$01
	sta $d01a

	rts
}

//; =============================================================================
//; TECHNICAL NOTES:
//; ----------------
//; This routine achieves stable rasters by:
//; 1. Synchronizing to a specific raster line
//; 2. Using CIA timer B to measure and compensate for jitter
//; 3. Carefully counting cycles to ensure consistent timing
//;
//; The alignment to 128 bytes prevents timing variations from page crossings
//; in branch instructions, which would add an extra cycle and break the
//; synchronization.
//; =============================================================================