#importonce

.var SIDInit						= DATA_ADDRESS + $00 // 3-byte JMP
.var SIDPlay						= DATA_ADDRESS + $03 // 3-byte JMP
.var BackupSIDMemory				= DATA_ADDRESS + $06 // 3-byte JMP
.var RestoreSIDMemory				= DATA_ADDRESS + $09 // 3-byte JMP
.var NumCallsPerFrame				= DATA_ADDRESS + $0c // 1 byte
.var BorderColour					= DATA_ADDRESS + $0d // 1 byte
.var BitmapScreenColour				= DATA_ADDRESS + $0e // 1 byte
.var SongNumber						= DATA_ADDRESS + $0f // 1 byte
.var SongName						= DATA_ADDRESS + $10 // 32-byte string
.var ArtistName						= DATA_ADDRESS + $30 // 32-byte string
.var CopyrightInfo					= DATA_ADDRESS + $50 // 32-byte string

.var LoadAddress					= DATA_ADDRESS + $c0 // 2-byte vector
.var InitAddress					= DATA_ADDRESS + $c2 // 2-byte vector
.var PlayAddress					= DATA_ADDRESS + $c4 // 2-byte vector
.var EndAddress						= DATA_ADDRESS + $c6 // 2-byte vector
.var NumSongs						= DATA_ADDRESS + $c8 // 1 byte
.var ClockType						= DATA_ADDRESS + $c9 // 1 byte, 0=PAL, 1=NTSC
.var SIDModel						= DATA_ADDRESS + $ca // 1 byte, 0=6581, 1=8580
// $CB-$CC reserved for modifiedCount (set by prg-builder.js)
.var NumSIDChips					= DATA_ADDRESS + $cd // 1 byte, 1-4 SID chips supported
.var ZPUsageData					= DATA_ADDRESS + $e0 // 32-byte string

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


//; =============================================================================
//; D011/D012 raster timing bar support
//; =============================================================================

#if INCLUDE_RASTER_TIMING_CODE
.var FrameHeight = 312

D011_Values_1Call:  .fill 1, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 1), 312))) * $80
D012_Values_1Call:  .fill 1, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 1), 312)))
D011_Values_2Calls: .fill 2, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 2), 312))) * $80
D012_Values_2Calls: .fill 2, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 2), 312)))
D011_Values_3Calls: .fill 3, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 3), 312))) * $80
D012_Values_3Calls: .fill 3, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 3), 312)))
D011_Values_4Calls: .fill 4, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 4), 312))) * $80
D012_Values_4Calls: .fill 4, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 4), 312)))
D011_Values_5Calls: .fill 5, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 5), 312))) * $80
D012_Values_5Calls: .fill 5, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 5), 312)))
D011_Values_6Calls: .fill 6, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 6), 312))) * $80
D012_Values_6Calls: .fill 6, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 6), 312)))
D011_Values_7Calls: .fill 7, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 7), 312))) * $80
D012_Values_7Calls: .fill 7, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 7), 312)))
D011_Values_8Calls: .fill 8, (>(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 8), 312))) * $80
D012_Values_8Calls: .fill 8, (<(mod(DEFAULT_RASTERTIMING_Y + ((FrameHeight * i) / 8), 312)))

D011_Values_Lookup_Lo: .byte <D011_Values_1Call, <D011_Values_1Call, <D011_Values_2Calls, <D011_Values_3Calls, <D011_Values_4Calls, <D011_Values_5Calls, <D011_Values_6Calls, <D011_Values_7Calls, <D011_Values_8Calls
D011_Values_Lookup_Hi: .byte >D011_Values_1Call, >D011_Values_1Call, >D011_Values_2Calls, >D011_Values_3Calls, >D011_Values_4Calls, >D011_Values_5Calls, >D011_Values_6Calls, >D011_Values_7Calls, >D011_Values_8Calls
D012_Values_Lookup_Lo: .byte <D012_Values_1Call, <D012_Values_1Call, <D012_Values_2Calls, <D012_Values_3Calls, <D012_Values_4Calls, <D012_Values_5Calls, <D012_Values_6Calls, <D012_Values_7Calls, <D012_Values_8Calls
D012_Values_Lookup_Hi: .byte >D012_Values_1Call, >D012_Values_1Call, >D012_Values_2Calls, >D012_Values_3Calls, >D012_Values_4Calls, >D012_Values_5Calls, >D012_Values_6Calls, >D012_Values_7Calls, >D012_Values_8Calls

init_D011_D012_values:
    ldx NumCallsPerFrame
    lda D011_Values_Lookup_Lo, x
    sta d011_values_ptr + 1
    lda D011_Values_Lookup_Hi, x
    sta d011_values_ptr + 2
    lda D012_Values_Lookup_Lo, x
    sta d012_values_ptr + 1
    lda D012_Values_Lookup_Hi, x
    sta d012_values_ptr + 2
    rts

set_d011_and_d012:
d012_values_ptr:
    lda $abcd, x
    sta $d012
    lda $d011
    and #$7f
d011_values_ptr:
    ora $abcd, x
    sta $d011
    rts

#endif // INCLUDE_RASTER_TIMING_CODE