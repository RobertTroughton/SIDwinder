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
