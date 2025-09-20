import struct
import math

NUM_FREQS_ON_SCREEN = 40  # Assuming this constant based on the array size

def generate_freq_lookups(freq_bin_filename):
    """Generate frequency lookup tables for bar visualization."""
    
    # Generate 40 logarithmic thresholds
    bar_thresholds = [0] * (NUM_FREQS_ON_SCREEN + 1)
    MIN_FREQ = 0x0080
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
    
    # Low frequency table - use more precision
    for index in range(256):
        # Map 0-255 to frequencies 0x0000-0x0FFF
        freq_mid = (index << 4) + 8  # index * 16 + midpoint
        
        bar_index = 0
        for bar in range(NUM_FREQS_ON_SCREEN):
            if (freq_mid >= bar_thresholds[bar] and 
                freq_mid < bar_thresholds[bar + 1]):
                bar_index = bar
                break
        freq_to_bar_lo[index] = bar_index
    
    # Mid frequency table
    for index in range(256):
        # Map 0-255 to frequencies 0x1000-0x3FFF
        freq_mid = 0x1000 + (index << 5) + 16  # 0x1000 + index * 32
        
        bar_index = 0
        for bar in range(NUM_FREQS_ON_SCREEN):
            if (freq_mid >= bar_thresholds[bar] and 
                freq_mid < bar_thresholds[bar + 1]):
                bar_index = bar
                break
        freq_to_bar_mid[index] = bar_index
    
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

def write_binary_file(filename, data):
    """Write binary data to a file."""
    with open(filename, 'wb') as f:
        f.write(bytes(data))

def main():
    import os
    
    generate_freq_lookups("SIDPlayers/INC/FreqTable.bin")
    print(f"Generated frequency lookup table: SIDPlayers/INC/FreqTable.bin")

if __name__ == "__main__":
    main()