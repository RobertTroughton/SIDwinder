#importonce

//; =============================================================================
//; NMI Fix Routine (prevent crashing on RESTORE key hitting)
//; =============================================================================

NMIFix:

		lda #$35
		sta $01
		lda #<!JustRTI+
		sta $FFFA
		lda #>!JustRTI+
		sta $FFFB
		lda #$00
		sta $DD0E
		sta $DD04
		sta $DD05
		lda #$81
		sta $DD0D
		lda #$01
		sta $DD0E

		rts

	!JustRTI:

		rti

//; =============================================================================
//; VERTICAL SYNC ROUTINE
//; =============================================================================

VSync:
    bit $d011
    bpl *-3
    bit $d011
    bmi *-3
    rts

