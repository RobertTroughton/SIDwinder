import struct
import math

NUM_FREQS_ON_SCREEN = 40

def generate_freq_lookups(freq_bin_filename):
    """Generate frequency-to-bar-index lookup tables for the bar visualizer.

    Builds 40 logarithmic thresholds spanning $0100..$FFFF, then writes three
    256-byte tables that map a SID frequency value to a bar index 0..39.
    """

    bar_thresholds = [0] * (NUM_FREQS_ON_SCREEN + 1)
    MIN_FREQ = 0x0100
    MAX_FREQ = 0xFFFF

    bar_thresholds[0] = 0
    for freq_index in range(NUM_FREQS_ON_SCREEN):
        factor = math.pow(MAX_FREQ / MIN_FREQ,
                         (freq_index + 1) / NUM_FREQS_ON_SCREEN)
        bar_thresholds[freq_index + 1] = int(MIN_FREQ * factor + 0.5)

    # Three tables cover non-overlapping frequency ranges with different
    # resolutions, matching how the assembly indexes them.
    freq_to_bar_lo = [0] * 256   # freq < $1000 (high byte 0-15)
    freq_to_bar_mid = [0] * 256  # freq $1000-$3FFF (high byte 16-63)
    freq_to_bar_hi = [0] * 256   # freq >= $4000 (high byte 64-255)

    # Low table: assembly forms index = (high_byte << 4) | (low_byte >> 4),
    # giving 256 indices over frequencies $000..$FFF (16-freq buckets).
    for index in range(256):
        freq_mid = (index << 4) + 8  # midpoint of the 16-frequency bucket

        bar_index = 0
        for bar in range(NUM_FREQS_ON_SCREEN):
            if (freq_mid >= bar_thresholds[bar] and
                freq_mid < bar_thresholds[bar + 1]):
                bar_index = bar
                break
        freq_to_bar_lo[index] = bar_index

    # Mid table: assembly forms index = ((high_byte - $10) << 2) | (low_byte >> 6),
    # so only indices 0..191 are reachable (max = ($3F-$10)<<2 | 3 = 191).
    # Each index covers 64 frequencies across $1000..$3FFF.
    for index in range(192):
        freq_mid = 0x1000 + (index * 64) + 32  # midpoint of 64-frequency bucket

        bar_index = 0
        for bar in range(NUM_FREQS_ON_SCREEN):
            if (freq_mid >= bar_thresholds[bar] and
                freq_mid < bar_thresholds[bar + 1]):
                bar_index = bar
                break
        freq_to_bar_mid[index] = bar_index

    # Entries 192-255 are unreachable from assembly; pad with 0.
    for index in range(192, 256):
        freq_to_bar_mid[index] = 0

    # High table: indexed directly by the high byte ($40..$FF range matters).
    for index in range(256):
        freq_mid = (index << 8) + 128

        bar_index = 0
        for bar in range(NUM_FREQS_ON_SCREEN):
            if (freq_mid >= bar_thresholds[bar] and
                freq_mid < bar_thresholds[bar + 1]):
                bar_index = bar
                break

        if freq_mid >= bar_thresholds[NUM_FREQS_ON_SCREEN]:
            bar_index = NUM_FREQS_ON_SCREEN - 1

        freq_to_bar_hi[index] = bar_index

    # Concatenated output is 768 bytes (3 * 256).
    all_tables = bytearray()
    all_tables.extend(freq_to_bar_lo)
    all_tables.extend(freq_to_bar_mid)
    all_tables.extend(freq_to_bar_hi)

    write_binary_file(freq_bin_filename, all_tables)

    print(f"Bar thresholds (hex):")
    for i in range(NUM_FREQS_ON_SCREEN):
        print(f"  Bar {i:2d}: 0x{bar_thresholds[i]:04X} - 0x{bar_thresholds[i+1]-1:04X}")

    bars_lo = set(freq_to_bar_lo[:256])
    bars_mid = set(freq_to_bar_mid[:192])  # only first 192 entries are reachable
    bars_hi = set(freq_to_bar_hi[:256])
    
    print(f"\nBars covered by tables:")
    print(f"  Low table (0x0000-0x0FFF): {sorted(bars_lo)}")
    print(f"  Mid table (0x1000-0x3FFF): {sorted(bars_mid)}")
    print(f"  High table (0x4000-0xFFFF): {sorted(bars_hi)}")
    
    all_bars = bars_lo | bars_mid | bars_hi
    unused = set(range(NUM_FREQS_ON_SCREEN)) - all_bars
    if unused:
        print(f"\nWARNING: Unused bars: {sorted(unused)}")
    else:
        print(f"\nAll {NUM_FREQS_ON_SCREEN} bars are covered!")

def write_binary_file(filename, data):
    """Write binary data to a file."""
    with open(filename, 'wb') as f:
        f.write(bytes(data))

def main():
    import os
    
    generate_freq_lookups("SIDPlayers/INC/FreqTable.bin")
    print(f"\nGenerated frequency lookup table: SIDPlayers/INC/FreqTable.bin")

if __name__ == "__main__":
    main()