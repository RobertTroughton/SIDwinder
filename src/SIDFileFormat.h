// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#pragma once

#include "Common.h"

/**
 * @file SIDFileFormat.h
 * @brief Definitions for SID file format structures
 *
 * Contains the structures and constants for PSID file format,
 * supporting versions 1-4 of the specification.
 */

 /**
  * @struct SIDHeader
  * @brief Header structure for SID files
  *
  * Defines the binary format of a SID file header according to the
  * specification. Handles PSID format files for all versions (1-4).
  * Note: RSID files are not supported as they require a true C64 environment.
  */
#pragma pack(push, 1)
struct SIDHeader {
    // ----- v1 Fields (offset 0x00-0x75) -----
    char magicID[4];     // 'PSID'                                                      //; $00-03
    u16 version;         // 1-4                                                         //; $04-05
    u16 dataOffset;      // Offset to binary data (0x76 for v1, 0x7C for v2+)           //; $06-07
    u16 loadAddress;     // C64 memory load address (0 for embedded address)            //; $08-09
    u16 initAddress;     // Init routine address                                        //; $0a-0b
    u16 playAddress;     // Play routine address                                        //; $0c-0d
    u16 songs;           // Number of songs                                             //; $0e-0f
    u16 startSong;       // Default starting song (1-based)                             //; $10-11
    u32 speed;           // Song speed flags (each bit represents a song)               //; $12-15
    char name[32];       // Module name, null-terminated ASCII                          //; $16-35
    char author[32];     // Author name, null-terminated ASCII                          //; $36-55
    char copyright[32];  // Copyright/release info, null-terminated ASCII               //; $56-75

    // ----- v2+ Fields (offset 0x76-0x7B) -----
    u16 flags;           // Flags for v2+                                               //; $76-77
    // bit 0: MUS data (0=built-in player, 1=MUS format)
    // bit 1: PlaySID specific (PSID) or BASIC flag (RSID)
    // bits 2-3: Clock speed (0=Unknown, 1=PAL, 2=NTSC, 3=PAL/NTSC)
    // bits 4-5: SID model (0=Unknown, 1=6581, 2=8580, 3=both)
    // bits 6-15: reserved
    u8 startPage;        // Relocation address start page (v2+)
    u8 pageLength;       // Relocation address page length (v2+)

    // ----- v3+ Fields (offset 0x7A-0x7B) -----
    u8 secondSIDAddress; // Second SID address (v3+) - upper 4 bits used, 0=none
    // Values: 0=None, 1=0xD420, 2=0xD440, ..., 15=0xD7E0

// ----- v4+ Fields -----
    u8 thirdSIDAddress;  // Third SID address (v4+) - upper 4 bits used, 0=none
    // Values: 0=None, 1=0xD420, 2=0xD440, ..., 15=0xD7E0
};
#pragma pack(pop)

/**
 * @enum SIDModel
 * @brief Defines the SID chip models
 */
enum class SIDModel {
    UNKNOWN = 0,
    MOS6581 = 1,    // Original SID chip
    MOS8580 = 2,    // Revised SID chip
    ANY = 3     // Either model can be used
};

/**
 * @enum ClockSpeed
 * @brief Defines the supported clock speeds for SID playback
 */
enum class ClockSpeed {
    UNKNOWN = 0,
    PAL = 1,    // 50Hz (European)
    NTSC = 2,    // 60Hz (North American/Japanese)
    ANY = 3     // Both PAL and NTSC
};

// Constants for flag bits
constexpr u16 SID_FLAG_MUS_DATA = 0x0001;  // Bit 0: MUS data format
constexpr u16 SID_FLAG_PSID_SPECIFIC = 0x0002;  // Bit 1: PlaySID specific (PSID)
constexpr u16 SID_FLAG_CLOCK_PAL = 0x0004;  // Bit 2: PAL clock
constexpr u16 SID_FLAG_CLOCK_NTSC = 0x0008;  // Bit 3: NTSC clock
constexpr u16 SID_FLAG_SID_6581 = 0x0010;  // Bit 4: MOS6581 SID model
constexpr u16 SID_FLAG_SID_8580 = 0x0020;  // Bit 5: MOS8580 SID model

// Version 3/4 SID Addressing
constexpr u16 SID_BASE_ADDRESS = 0xD400; // Base address of the SID chip
constexpr u8 SID_ADDRESS_OFFSET = 0x20;  // 32-byte offset between SIDs (for 2nd/3rd SID)

/**
 * @brief Calculate memory address for secondary/tertiary SID chips
 *
 * @param addressByte Address byte from SID header (upper 4 bits used)
 * @return Actual memory address or 0 if not present
 */
inline u16 getSIDMemoryAddress(u8 addressByte) {
    // The upper 4 bits of the address byte encode the address
    u8 addressValue = (addressByte >> 4) & 0x0F;

    // If value is 0, no SID is present
    if (addressValue == 0) {
        return 0;
    }

    // Otherwise, calculate the address
    // Base address is $D400, and each secondary SID is at $D420, $D440, etc.
    return SID_BASE_ADDRESS + (addressValue * SID_ADDRESS_OFFSET);
}