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

.const RELEASE_RATE_SCALE = 1.0
.const RELEASE_RATE_EXTRA = 64.0

.const REL_DIV0  = 1.5   * 0.7
.const REL_DIV1  = 3.0   * 0.7
.const REL_DIV2  = 6.0   * 0.7
.const REL_DIV3  = 9.4   * 0.7
.const REL_DIV4  = 13.4  * 0.7
.const REL_DIV5  = 19.0  * 0.7
.const REL_DIV6  = 26.8  * 0.7
.const REL_DIV7  = 49    * 0.7
.const REL_DIV8  = 62    * 0.7
.const REL_DIV9  = 70    * 0.7
.const REL_DIV10 = 75.0  * 0.7
.const REL_DIV11 = 80.0  * 0.7
.const REL_DIV12 = 85.4  * 0.7
.const REL_DIV13 = 90.0  * 0.7
.const REL_DIV14 = 95.0  * 0.7
.const REL_DIV15 = 100.0 * 0.7

releaseRateLo:
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV0 ) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV1 ) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV2 ) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV3 ) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV4 ) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV5 ) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV6 ) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV7 ) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV8 ) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV9 ) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV10) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV11) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV12) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV13) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV14) + RELEASE_RATE_EXTRA)
    .byte <((MAX_BAR_HEIGHT * 256.0 / REL_DIV15) + RELEASE_RATE_EXTRA)

releaseRateHi:
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV0 ) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV1 ) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV2 ) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV3 ) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV4 ) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV5 ) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV6 ) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV7 ) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV8 ) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV9 ) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV10) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV11) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV12) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV13) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV14) + RELEASE_RATE_EXTRA)
    .byte >((MAX_BAR_HEIGHT * RELEASE_RATE_SCALE * 256.0 / REL_DIV15) + RELEASE_RATE_EXTRA)