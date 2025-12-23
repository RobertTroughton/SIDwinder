// sid_processor.cpp - Extended WASM module with SID file processing
// Works with cpu6510_wasm.cpp to provide complete SID analysis

#include <emscripten/emscripten.h>
#include <cstdint>
#include <cstring>
#include <vector>
#include <algorithm>
#include <set>
#include <string>
#include "opcodes.h"  // Use the existing opcodes.h

// Helper function to clean a string from the SID header (C++ function, not exported)
static std::string cleanSIDString(const char* str, size_t maxLen) {
    std::string result;
    result.reserve(maxLen);

    for (size_t i = 0; i < maxLen; i++) {
        if (str[i] == '\0') {
            break; // Stop at null terminator
        }
        // Only include printable ASCII characters
        if (str[i] >= 32 && str[i] <= 126) {
            result.push_back(str[i]);
        }
    }

    // Remove trailing spaces
    while (!result.empty() && result.back() == ' ') {
        result.pop_back();
    }

    return result;
}

extern "C" {

    // SID Header structure matching the original format
    // CRITICAL: Must be packed to match file format exactly
#pragma pack(push, 1)
    struct SIDHeader {
        char magicID[4];     // 'PSID' or 'RSID'  // Offset 0x00
        uint16_t version;                          // Offset 0x04
        uint16_t dataOffset;                       // Offset 0x06
        uint16_t loadAddress;                      // Offset 0x08
        uint16_t initAddress;                      // Offset 0x0A
        uint16_t playAddress;                      // Offset 0x0C
        uint16_t songs;                            // Offset 0x0E
        uint16_t startSong;                        // Offset 0x10
        uint32_t speed;                            // Offset 0x12 (NOT aligned!)
        char name[32];                             // Offset 0x16
        char author[32];                           // Offset 0x36
        char copyright[32];                        // Offset 0x56
        uint16_t flags;      // Version 2+ only    // Offset 0x76
        uint8_t startPage;   // Version 2+ only    // Offset 0x78
        uint8_t pageLength;  // Version 2+ only    // Offset 0x79
        uint8_t secondSIDAddress; // Version 3+    // Offset 0x7A
        uint8_t thirdSIDAddress;  // Version 4+    // Offset 0x7B
    };
#pragma pack(pop)

    // Analysis results structure
    struct AnalysisResults {
        // Memory usage
        std::set<uint16_t> modifiedAddresses;
        std::set<uint8_t> zeroPageUsed;

        // SID register usage
        uint32_t sidRegisterWrites[32];

        // Code vs data analysis
        uint32_t codeBytes;
        uint32_t dataBytes;

        // Pattern detection
        bool hasPattern;
        uint32_t patternPeriod;
        uint32_t initFrames;

		// Timing analysis
        uint8_t numCallsPerFrame;
        uint16_t ciaTimerValue;
        bool ciaTimerDetected;
        uint32_t maxCycles;
    };

    // Global state
    struct {
        SIDHeader header;
        uint8_t* fileBuffer;
        uint32_t fileSize;
        uint32_t dataStart;
        AnalysisResults analysis;
        bool isLoaded;

        // Store cleaned strings separately
        std::string cleanName;
        std::string cleanAuthor;
        std::string cleanCopyright;
        std::string cleanMagicID;
    } sidState;

    // External CPU functions (from cpu6510_wasm.cpp)
    extern void cpu_init();
    extern void cpu_set_tracking(bool enabled);
    extern void cpu_write_memory(uint16_t address, uint8_t value);
    extern int cpu_execute_function(uint16_t address, uint32_t maxCycles);
    extern uint8_t cpu_get_memory_access(uint16_t address);
    extern uint32_t cpu_get_sid_writes(uint8_t reg);
    extern uint32_t cpu_get_sid_chip_count();
    extern uint16_t cpu_get_sid_chip_address(uint32_t index);
    extern uint32_t cpu_get_zp_writes(uint8_t addr);
    extern void cpu_set_record_writes(bool record);
    extern void cpu_save_memory(uint8_t* buffer);
    extern void cpu_restore_memory(uint8_t* buffer);
    extern void cpu_reset_state_only();
    extern uint32_t cpu_get_last_execution_cycles();

    // Helper function to swap endianness
    uint16_t swap16(uint16_t value) {
        return ((value & 0xFF) << 8) | ((value >> 8) & 0xFF);
    }

    uint32_t swap32(uint32_t value) {
        return ((value & 0xFF) << 24) |
            ((value & 0xFF00) << 8) |
            ((value & 0xFF0000) >> 8) |
            ((value & 0xFF000000) >> 24);
    }

    // Initialize SID processor
    EMSCRIPTEN_KEEPALIVE
        void sid_init() {
        // Clear header (POD type, safe to memset)
        memset(&sidState.header, 0, sizeof(sidState.header));

        // Clear other POD members
        sidState.fileBuffer = nullptr;
        sidState.fileSize = 0;
        sidState.dataStart = 0;
        sidState.isLoaded = false;

        // Clear strings
        sidState.cleanName.clear();
        sidState.cleanAuthor.clear();
        sidState.cleanCopyright.clear();
        sidState.cleanMagicID.clear();

        // Clear analysis results (C++ objects will be properly initialized)
        sidState.analysis.modifiedAddresses.clear();
        sidState.analysis.zeroPageUsed.clear();
        memset(sidState.analysis.sidRegisterWrites, 0, sizeof(sidState.analysis.sidRegisterWrites));
        sidState.analysis.codeBytes = 0;
        sidState.analysis.dataBytes = 0;
        sidState.analysis.hasPattern = false;
        sidState.analysis.patternPeriod = 0;
        sidState.analysis.initFrames = 0;
        sidState.analysis.maxCycles = 0;

        cpu_init();
    }

    // Load and parse SID file
    EMSCRIPTEN_KEEPALIVE
        int sid_load(uint8_t* data, uint32_t size) {
        // Verify the header size is what we expect (124 bytes for v2+, 120 for v1)
        if (size < 120) {
            return -1; // File too small for even v1 header
        }

        // Copy header
        memcpy(&sidState.header, data, sizeof(SIDHeader));

        // Clean and store the magic ID (4 characters, no null terminator in file)
        sidState.cleanMagicID = std::string(sidState.header.magicID, 4);

        // Check magic ID
        if (sidState.cleanMagicID != "PSID" && sidState.cleanMagicID != "RSID") {
            return -2; // Invalid magic ID
        }

        // RSID not supported
        if (sidState.cleanMagicID == "RSID") {
            return -3; // RSID not supported
        }

        // Fix endianness
        sidState.header.version = swap16(sidState.header.version);
        sidState.header.dataOffset = swap16(sidState.header.dataOffset);
        sidState.header.loadAddress = swap16(sidState.header.loadAddress);
        sidState.header.initAddress = swap16(sidState.header.initAddress);
        sidState.header.playAddress = swap16(sidState.header.playAddress);
        sidState.header.songs = swap16(sidState.header.songs);
        sidState.header.startSong = swap16(sidState.header.startSong);
        sidState.header.speed = swap32(sidState.header.speed);

        if (sidState.header.version >= 2) {
            sidState.header.flags = swap16(sidState.header.flags);
        }

        // Check version
        if (sidState.header.version < 1 || sidState.header.version > 4) {
            return -4; // Unsupported version
        }

        // Verify expected data offset
        uint16_t expectedOffset = (sidState.header.version == 1) ? 0x76 : 0x7C;
        if (sidState.header.dataOffset != expectedOffset) {
            // Log warning but continue
        }

        // Clean and store the strings
        sidState.cleanName = cleanSIDString(sidState.header.name, 32);
        sidState.cleanAuthor = cleanSIDString(sidState.header.author, 32);
        sidState.cleanCopyright = cleanSIDString(sidState.header.copyright, 32);

        // Handle load address
        sidState.dataStart = sidState.header.dataOffset;
        if (sidState.header.loadAddress == 0) {
            // Load address is in first two bytes of data
            if (size < sidState.dataStart + 2) {
                return -5; // Missing load address
            }
            uint8_t lo = data[sidState.dataStart];
            uint8_t hi = data[sidState.dataStart + 1];
            sidState.header.loadAddress = lo | (hi << 8);
            sidState.dataStart += 2;
        }

        // Store file data
        sidState.fileSize = size;
        if (sidState.fileBuffer) {
            free(sidState.fileBuffer);
        }
        sidState.fileBuffer = (uint8_t*)malloc(size);
        memcpy(sidState.fileBuffer, data, size);

        // Load music data into CPU memory
        uint32_t musicSize = size - sidState.dataStart;
        uint8_t* musicData = data + sidState.dataStart;

        cpu_init(); // Reset CPU
        cpu_set_tracking(false); // Disable tracking for loading

        for (uint32_t i = 0; i < musicSize; i++) {
            cpu_write_memory(sidState.header.loadAddress + i, musicData[i]);
        }

        sidState.isLoaded = true;
        return 0; // Success
    }

    // Run analysis (emulation)
    EMSCRIPTEN_KEEPALIVE
        int sid_analyze(uint32_t frameCount, void (*progressCallback)(uint32_t, uint32_t)) {
        if (!sidState.isLoaded) {
            return -1;
        }

        // Clear previous analysis
        sidState.analysis.modifiedAddresses.clear();
        sidState.analysis.zeroPageUsed.clear();
        memset(sidState.analysis.sidRegisterWrites, 0, sizeof(sidState.analysis.sidRegisterWrites));
        sidState.analysis.codeBytes = 0;
        sidState.analysis.dataBytes = 0;
        sidState.analysis.hasPattern = false;
        sidState.analysis.patternPeriod = 0;
        sidState.analysis.initFrames = 0;
        sidState.analysis.numCallsPerFrame = 1;
        sidState.analysis.ciaTimerValue = 0;
        sidState.analysis.ciaTimerDetected = false;
        sidState.analysis.maxCycles = 0;

        // Create a clean memory snapshot after initial load
        uint8_t* cleanMemorySnapshot = (uint8_t*)malloc(65536);

        // First, init with clean memory
        cpu_init();
        cpu_set_tracking(false);

        // Load music data
        uint32_t musicSize = sidState.fileSize - sidState.dataStart;
        uint8_t* musicData = sidState.fileBuffer + sidState.dataStart;
        for (uint32_t i = 0; i < musicSize; i++) {
            cpu_write_memory(sidState.header.loadAddress + i, musicData[i]);
        }

        // Save this clean state
        cpu_save_memory(cleanMemorySnapshot);

        // Determine how many songs to analyze
        uint16_t songsToAnalyze = sidState.header.songs;

        // Iterate through songs
        for (uint16_t songNum = 1; songNum <= songsToAnalyze; songNum++) {
            // RESTORE COMPLETE MEMORY STATE
            cpu_restore_memory(cleanMemorySnapshot);

            // Reset CPU state but keep the restored memory
            cpu_reset_state_only();

            // Set the song number in accumulator, X and Y registers
            extern void cpu_set_accumulator(uint8_t value);
            extern void cpu_set_xreg(uint8_t value);
            extern void cpu_set_yreg(uint8_t value);
            cpu_set_accumulator(songNum - 1);
            cpu_set_xreg(songNum - 1);
            cpu_set_yreg(songNum - 1);

            // Enable tracking
            cpu_set_tracking(true);

            // Execute init
            if (!cpu_execute_function(sidState.header.initAddress, 100000)) {
                continue; // Skip this song if init fails
            }

            // Enable write recording for pattern detection (optional)
            cpu_set_record_writes(true);

            // Execute play routine for this song
            for (uint32_t frame = 0; frame < frameCount; frame++) {
                if (!cpu_execute_function(sidState.header.playAddress, 20000)) {
                    break;
                }
                
                uint32_t cycles = cpu_get_last_execution_cycles();
                if (cycles > sidState.analysis.maxCycles) {
                    sidState.analysis.maxCycles = cycles;
                }

                // Progress callback
                if (progressCallback && (frame % 100 == 0)) {
                    uint32_t totalProgress = (songNum - 1) * frameCount + frame;
                    uint32_t totalFrames = songsToAnalyze * frameCount;
                    progressCallback(totalProgress, totalFrames);
                }
            }

            // ACCUMULATE analysis results for THIS song before resetting
            for (uint32_t addr = 0; addr < 65536; addr++) {
                uint8_t access = cpu_get_memory_access(addr);

                // Track modified addresses
                if (access & 0x04) { // Write flag
                    sidState.analysis.modifiedAddresses.insert(addr);

                    if (addr < 256) {
                        sidState.analysis.zeroPageUsed.insert(addr);
                    }
                }

                // Track code vs data (only for the SID's loaded range)
                if (addr >= sidState.header.loadAddress &&
                    addr < sidState.header.loadAddress + musicSize) {
                    if (access & 0x01) { // Execute flag
                        sidState.analysis.codeBytes++;
                    }
                    else {
                        sidState.analysis.dataBytes++;
                    }
                }
            }

            // Accumulate SID register usage
            for (int reg = 0; reg < 32; reg++) {
                sidState.analysis.sidRegisterWrites[reg] += cpu_get_sid_writes(reg);
            }

            // Check for CIA timer (only need to detect once)
            if (!sidState.analysis.ciaTimerDetected) {
                extern uint8_t cpu_get_cia_timer_lo();
                extern uint8_t cpu_get_cia_timer_hi();
                extern bool cpu_get_cia_timer_written();

                if (cpu_get_cia_timer_written()) {
                    uint8_t ciaTimerLo = cpu_get_cia_timer_lo();
                    uint8_t ciaTimerHi = cpu_get_cia_timer_hi();

                    if (ciaTimerLo != 0 || ciaTimerHi != 0) {
                        uint16_t timerValue = ciaTimerLo | (ciaTimerHi << 8);
                        // PAL: 312 lines * 63 cycles = 19656 cycles per frame
                        // NTSC: 263 lines * 65 cycles = 17095 cycles per frame
                        double cyclesPerFrame = 19656.0; // Default PAL

                        // Check if NTSC
                        if (sidState.header.version >= 2) {
                            uint16_t flags = sidState.header.flags;
                            if ((flags & 0x0C) == 0x08) { // NTSC flag
                                cyclesPerFrame = 17095.0;
                            }
                        }

                        double freq = cyclesPerFrame / timerValue;
                        sidState.analysis.numCallsPerFrame = (uint8_t)std::min(16, std::max(1, (int)(freq + 0.5)));
                        sidState.analysis.ciaTimerValue = timerValue;
                        sidState.analysis.ciaTimerDetected = true;
                    }
                }
            }
        }

        // Clean up
        free(cleanMemorySnapshot);

        return 0; // Success
    }

    // Get header field
    EMSCRIPTEN_KEEPALIVE
        const char* sid_get_header_string(int field) {
        if (!sidState.isLoaded) return "";

        switch (field) {
        case 0: return sidState.cleanName.c_str();
        case 1: return sidState.cleanAuthor.c_str();
        case 2: return sidState.cleanCopyright.c_str();
        case 3: return sidState.cleanMagicID.c_str();
        default: return "";
        }
    }

    EMSCRIPTEN_KEEPALIVE
        uint16_t sid_get_header_value(int field) {
        if (!sidState.isLoaded) return 0;

        switch (field) {
        case 0: return sidState.header.version;
        case 1: return sidState.header.loadAddress;
        case 2: return sidState.header.initAddress;
        case 3: return sidState.header.playAddress;
        case 4: return sidState.header.songs;
        case 5: return sidState.header.startSong;
        case 6: return sidState.header.flags;
        case 7: return sidState.fileSize - sidState.dataStart;
        default: return 0;
        }
    }

    // Update header strings
    EMSCRIPTEN_KEEPALIVE
        void sid_set_header_string(int field, const char* value) {
        if (!sidState.isLoaded) return;

        char* target = nullptr;
        std::string* cleanTarget = nullptr;

        switch (field) {
        case 0:
            target = sidState.header.name;
            cleanTarget = &sidState.cleanName;
            break;
        case 1:
            target = sidState.header.author;
            cleanTarget = &sidState.cleanAuthor;
            break;
        case 2:
            target = sidState.header.copyright;
            cleanTarget = &sidState.cleanCopyright;
            break;
        default:
            return;
        }

        if (target && cleanTarget) {
            // Clear the buffer
            memset(target, 0, 32);

            // Copy the new value (up to 31 chars to leave room for null terminator)
            strncpy(target, value, 31);

            // Update the clean version
            *cleanTarget = cleanSIDString(target, 32);
        }
    }

    // Create modified SID file
    EMSCRIPTEN_KEEPALIVE
        uint8_t* sid_create_modified(uint32_t* outSize) {
        if (!sidState.isLoaded || !sidState.fileBuffer) {
            *outSize = 0;
            return nullptr;
        }

        uint8_t* newBuffer = (uint8_t*)malloc(sidState.fileSize);
        memcpy(newBuffer, sidState.fileBuffer, sidState.fileSize);

        SIDHeader tempHeader = sidState.header;

        uint16_t originalLoadAddress = swap16(*(uint16_t*)&sidState.fileBuffer[0x08]);

        tempHeader.version = swap16(tempHeader.version);
        tempHeader.dataOffset = swap16(tempHeader.dataOffset);

        if (originalLoadAddress == 0x0000) {
            tempHeader.loadAddress = 0x0000;
        }
        else {
            tempHeader.loadAddress = swap16(tempHeader.loadAddress);
        }

        tempHeader.initAddress = swap16(tempHeader.initAddress);
        tempHeader.playAddress = swap16(tempHeader.playAddress);
        tempHeader.songs = swap16(tempHeader.songs);
        tempHeader.startSong = swap16(tempHeader.startSong);
        tempHeader.speed = swap32(tempHeader.speed);
        if (sidState.header.version >= 2) {
            tempHeader.flags = swap16(tempHeader.flags);
        }

        memcpy(newBuffer, &tempHeader, sizeof(SIDHeader));

        *outSize = sidState.fileSize;
        return newBuffer;
    }

    // Get analysis results
    EMSCRIPTEN_KEEPALIVE
        uint32_t sid_get_modified_count() {
        return sidState.analysis.modifiedAddresses.size();
    }

    EMSCRIPTEN_KEEPALIVE
        uint32_t sid_get_modified_address(uint32_t index) {
        if (index >= sidState.analysis.modifiedAddresses.size()) {
            return 0xFFFF;
        }

        auto it = sidState.analysis.modifiedAddresses.begin();
        std::advance(it, index);
        return *it;
    }

    EMSCRIPTEN_KEEPALIVE
        uint32_t sid_get_zp_count() {
        return sidState.analysis.zeroPageUsed.size();
    }

    EMSCRIPTEN_KEEPALIVE
        uint8_t sid_get_zp_address(uint32_t index) {
        if (index >= sidState.analysis.zeroPageUsed.size()) {
            return 0xFF;
        }

        auto it = sidState.analysis.zeroPageUsed.begin();
        std::advance(it, index);
        return *it;
    }

    EMSCRIPTEN_KEEPALIVE
        uint32_t sid_get_code_bytes() {
        return sidState.analysis.codeBytes;
    }

    EMSCRIPTEN_KEEPALIVE
        uint32_t sid_get_data_bytes() {
        return sidState.analysis.dataBytes;
    }

    EMSCRIPTEN_KEEPALIVE
        uint32_t sid_get_sid_writes(uint8_t reg) {
        if (reg < 32) {
            return sidState.analysis.sidRegisterWrites[reg];
        }
        return 0;
    }

    // Get the number of SID chips used
    EMSCRIPTEN_KEEPALIVE
        uint32_t sid_get_sid_chip_count() {
        return cpu_get_sid_chip_count();
    }

    // Get the base address of the Nth SID chip used (0-indexed)
    EMSCRIPTEN_KEEPALIVE
        uint16_t sid_get_sid_chip_address(uint32_t index) {
        return cpu_get_sid_chip_address(index);
    }

    // Get clock type from flags
    EMSCRIPTEN_KEEPALIVE
        const char* sid_get_clock_type() {
        if (!sidState.isLoaded || sidState.header.version < 2) {
            return "PAL";
        }

        uint16_t flags = sidState.header.flags;
        if ((flags & 0x0C) == 0x04) return "PAL";
        if ((flags & 0x0C) == 0x08) return "NTSC";
        if ((flags & 0x0C) == 0x0C) return "PAL/NTSC";
        return "Unknown";
    }

    // Get SID model from flags
    EMSCRIPTEN_KEEPALIVE
        const char* sid_get_sid_model() {
        if (!sidState.isLoaded || sidState.header.version < 2) {
            return "6581";
        }

        uint16_t flags = sidState.header.flags;
        if ((flags & 0x30) == 0x10) return "6581";
        if ((flags & 0x30) == 0x20) return "8580";
        if ((flags & 0x30) == 0x30) return "6581/8580";
        return "Unknown";
    }

    EMSCRIPTEN_KEEPALIVE
        uint8_t sid_get_num_calls_per_frame() {
        return sidState.analysis.numCallsPerFrame;
    }

    EMSCRIPTEN_KEEPALIVE
        bool sid_get_cia_timer_detected() {
        return sidState.analysis.ciaTimerDetected;
    }

    EMSCRIPTEN_KEEPALIVE
        uint16_t sid_get_cia_timer_value() {
        return sidState.analysis.ciaTimerValue;
    }

    EMSCRIPTEN_KEEPALIVE
        uint32_t sid_get_max_cycles() {
        return sidState.analysis.maxCycles;
    }

    // Clean up
    EMSCRIPTEN_KEEPALIVE
        void sid_cleanup() {
        if (sidState.fileBuffer) {
            free(sidState.fileBuffer);
            sidState.fileBuffer = nullptr;
        }
        sidState.isLoaded = false;
        sidState.cleanName.clear();
        sidState.cleanAuthor.clear();
        sidState.cleanCopyright.clear();
        sidState.cleanMagicID.clear();
    }

} // extern "C"
