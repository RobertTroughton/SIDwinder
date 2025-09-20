import struct
import math

NUM_FREQS_ON_SCREEN = 40  # Assuming this constant based on the array size

def generate_freq_lookups(freq_bin_filename):
    """Generate frequency lookup tables for bar visualization."""
    
    # Generate 40 logarithmic thresholds
    bar_thresholds = [0] * (NUM_FREQS_ON_SCREEN + 1)
    MIN_FREQ = 0x0100
    MAX_FREQ = 0xFFFF
    
    bar_thresholds[0] = 0
    for freq_index in range(NUM_FREQS_ON_SCREEN):
        factor = math.pow(MAX_FREQ / MIN_FREQ, 
                         (freq_index + 1) / NUM_FREQS_ON_SCREEN)
        bar_thresholds[freq_index + 1] = int(MIN_FREQ * factor + 0.5)
    
    # Create three tables for different frequency ranges
    freq_to_bar_lo = [0] * 256   # For freq < 0x1000 (high byte 0-15)
    freq_to_bar_mid = [0] * 256  # For freq 0x1000-0x3FFF (high byte 16-63)
    freq_to_bar_hi = [0] * 256   # For freq >= 0x4000 (high byte 64-255)
    
    # Low frequency table - for properly fixed assembly
    # The fixed assembly creates index as: (high_byte << 4) | (low_byte >> 4)
    # This gives us indices 0-255 representing frequencies 0x000-0xFFF
    for index in range(256):
        # Each index represents a 16-frequency range
        # Index = (freq >> 4), so freq_mid = (index << 4) + 8
        freq_mid = (index << 4) + 8  # midpoint of 16-frequency range
        
        bar_index = 0
        for bar in range(NUM_FREQS_ON_SCREEN):
            if (freq_mid >= bar_thresholds[bar] and 
                freq_mid < bar_thresholds[bar + 1]):
                bar_index = bar
                break
        freq_to_bar_lo[index] = bar_index
    
    # Mid frequency table - FIXED!
    # Assembly can only generate indices 0-191:
    # index = ((high_byte - 0x10) << 2) | (low_byte >> 6)
    # Max index = (0x3F - 0x10) << 2 | 3 = 0x2F << 2 | 3 = 191
    for index in range(192):  # Only 192 valid indices!
        # Map indices 0-191 to frequencies 0x1000-0x3FFF
        # Range is 12288 frequencies, so each index covers 64 frequencies
        freq_mid = 0x1000 + (index * 64) + 32  # midpoint of 64-frequency range
        
        bar_index = 0
        for bar in range(NUM_FREQS_ON_SCREEN):
            if (freq_mid >= bar_thresholds[bar] and 
                freq_mid < bar_thresholds[bar + 1]):
                bar_index = bar
                break
        freq_to_bar_mid[index] = bar_index
    
    # Fill unused entries (192-255) with 0 or last valid value
    # These will never be accessed by the assembly code
    for index in range(192, 256):
        freq_to_bar_mid[index] = 0
    
    # High frequency table - direct high byte mapping
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
    
    # Write all three tables (768 bytes total)
    all_tables = bytearray()
    all_tables.extend(freq_to_bar_lo)
    all_tables.extend(freq_to_bar_mid)
    all_tables.extend(freq_to_bar_hi)
    
    write_binary_file(freq_bin_filename, all_tables)
    
    # Debug output
    print(f"Bar thresholds (hex):")
    for i in range(NUM_FREQS_ON_SCREEN):
        print(f"  Bar {i:2d}: 0x{bar_thresholds[i]:04X} - 0x{bar_thresholds[i+1]-1:04X}")
    
    # Show which bars are covered by each table
    bars_lo = set(freq_to_bar_lo[:256])
    bars_mid = set(freq_to_bar_mid[:192])  # Only first 192 entries are valid
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