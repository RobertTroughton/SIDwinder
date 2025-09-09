//; =============================================================================
//; DATA SECTION - Lookup Tables
//; =============================================================================

.var file_freqTable = LoadBinary("FreqTable.bin")

.align 256
FreqToBarLo: .fill 256, file_freqTable.get(i + 0)
FreqToBarMid: .fill 256, file_freqTable.get(i + 256)
FreqToBarHi: .fill 256, file_freqTable.get(i + 512)

.const SUSTAIN_MIN = MAX_BAR_HEIGHT / 6
.const SUSTAIN_MAX = MAX_BAR_HEIGHT
sustainToHeight:
    .fill 16, SUSTAIN_MIN + (i * (SUSTAIN_MAX - SUSTAIN_MIN)) / 15.0

releaseRateLo:				.byte <((MAX_BAR_HEIGHT * 256.0 / 1.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 2.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 3.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 4.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 6.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 9.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 11.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 12.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 15.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 38.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 75.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 120.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 150.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 450.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 750.0) + 64.0)
							.byte <((MAX_BAR_HEIGHT * 256.0 / 1200.0) + 64.0)

releaseRateHi:				.byte >((MAX_BAR_HEIGHT * 256.0 / 1.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 2.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 3.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 4.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 6.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 9.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 11.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 12.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 15.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 38.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 75.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 120.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 150.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 450.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 750.0) + 64.0)
							.byte >((MAX_BAR_HEIGHT * 256.0 / 1200.0) + 64.0)

