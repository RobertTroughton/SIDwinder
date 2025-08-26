#importonce

.var SIDInit						= BASE_ADDRESS + $00 // 3-byte JMP
.var SIDPlay						= BASE_ADDRESS + $03 // 3-byte JMP
.var BackupSIDMemory				= BASE_ADDRESS + $06 // 3-byte JMP
.var RestoreSIDMemory				= BASE_ADDRESS + $09 // 3-byte JMP
.var NumCallsPerFrame				= BASE_ADDRESS + $0c // 1 byte
.var BorderColour					= BASE_ADDRESS + $0d // 1 byte
.var BitmapScreenColour				= BASE_ADDRESS + $0e // 1 byte
.var SongNumber						= BASE_ADDRESS + $0f // 1 byte
.var SongName						= BASE_ADDRESS + $10 // 32-byte string
.var ArtistName						= BASE_ADDRESS + $30 // 32-byte string
.var CopyrightInfo					= BASE_ADDRESS + $50 // 32-byte string

.var LoadAddress					= BASE_ADDRESS + $c0 // 2-byte vector
.var InitAddress					= BASE_ADDRESS + $c2 // 2-byte vector
.var PlayAddress					= BASE_ADDRESS + $c4 // 2-byte vector
.var EndAddress						= BASE_ADDRESS + $c6 // 2-byte vector
.var NumSongs						= BASE_ADDRESS + $c8 // 1 byte
.var ClockType						= BASE_ADDRESS + $c9 // 1 byte, 0=PAL, 1=NTSC
.var SIDModel						= BASE_ADDRESS + $ca // 1 byte, 0=6581, 1=8580
.var ZPUsageData					= BASE_ADDRESS + $e0 // 32-byte string

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

