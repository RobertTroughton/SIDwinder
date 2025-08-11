// sid_processor.cpp - Extended WASM module with SID file processing
// Works with cpu6510_wasm.cpp to provide complete SID analysis

#include <emscripten/emscripten.h>
#include <cstdint>
#include <cstring>
#include <vector>
#include <algorithm>
#include <set>
#include "opcodes.h"  // Use the existing opcodes.h

extern "C" {

    // SID Header structure matching the original format
    struct SIDHeader {
        char magicID[4];     // 'PSID' or 'RSID'
        uint16_t version;
        uint16_t dataOffset;
        uint16_t loadAddress;
        uint16_t initAddress;
        uint16_t playAddress;
        uint16_t songs;
        uint16_t startSong;
        uint32_t speed;
        char name[32];
        char author[32];
        char copyright[32];
        uint16_t flags;      // Version 2+ only
        uint8_t startPage;   // Version 2+ only
        uint8_t pageLength;  // Version 2+ only
        uint8_t secondSIDAddress; // Version 3+ only
        uint8_t thirdSIDAddress;  // Version 4+ only
    };

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
    };

    // Global state
    struct {
        SIDHeader header;
        uint8_t* fileBuffer;
        uint32_t fileSize;
        uint32_t dataStart;
        AnalysisResults analysis;
        bool isLoaded;
    } sidState;

    // External CPU functions (from cpu6510_wasm.cpp)
    extern void cpu_init();
    extern void cpu_set_tracking(bool enabled);
    extern void cpu_write_memory(uint16_t address, uint8_t value);
    extern int cpu_execute_function(uint16_t address, uint32_t maxCycles);
    extern uint8_t cpu_get_memory_access(uint16_t address);
    extern uint32_t cpu_get_sid_writes(uint8_t reg);
    extern uint32_t cpu_get_zp_writes(uint8_t addr);
    extern void cpu_set_record_writes(bool record);

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

        // Clear analysis results (C++ objects will be properly initialized)
        sidState.analysis.modifiedAddresses.clear();
        sidState.analysis.zeroPageUsed.clear();
        memset(sidState.analysis.sidRegisterWrites, 0, sizeof(sidState.analysis.sidRegisterWrites));
        sidState.analysis.codeBytes = 0;
        sidState.analysis.dataBytes = 0;
        sidState.analysis.hasPattern = false;
        sidState.analysis.patternPeriod = 0;
        sidState.analysis.initFrames = 0;

        cpu_init();
    }

    // Load and parse SID file
    EMSCRIPTEN_KEEPALIVE
        int sid_load(uint8_t* data, uint32_t size) {
        if (size < sizeof(SIDHeader)) {
            return -1; // File too small
        }

        // Copy header
        memcpy(&sidState.header, data, sizeof(SIDHeader));

        // Check magic ID
        if (memcmp(sidState.header.magicID, "PSID", 4) != 0 &&
            memcmp(sidState.header.magicID, "RSID", 4) != 0) {
            return -2; // Invalid magic ID
        }

        // RSID not supported
        if (memcmp(sidState.header.magicID, "RSID", 4) == 0) {
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

        // Reset CPU and reload data
        cpu_init();
        cpu_set_tracking(false);

        // Reload music data
        uint32_t musicSize = sidState.fileSize - sidState.dataStart;
        uint8_t* musicData = sidState.fileBuffer + sidState.dataStart;

        for (uint32_t i = 0; i < musicSize; i++) {
            cpu_write_memory(sidState.header.loadAddress + i, musicData[i]);
        }

        // Enable tracking
        cpu_set_tracking(true);

        // Execute init
        if (!cpu_execute_function(sidState.header.initAddress, 100000)) {
            return -2; // Init failed
        }

        // Enable write recording
        cpu_set_record_writes(true);

        // Execute play routine for specified frames
        for (uint32_t frame = 0; frame < frameCount; frame++) {
            if (!cpu_execute_function(sidState.header.playAddress, 20000)) {
                break; // Play routine failed, but continue
            }

            // Progress callback
            if (progressCallback && (frame % 100 == 0)) {
                progressCallback(frame, frameCount);
            }
        }

        // Gather analysis results

        // Modified addresses
        for (uint32_t addr = 0; addr < 65536; addr++) {
            uint8_t access = cpu_get_memory_access(addr);
            if (access & 0x04) { // Write flag
                sidState.analysis.modifiedAddresses.insert(addr);

                if (addr < 256) {
                    sidState.analysis.zeroPageUsed.insert(addr);
                }
            }

            // Code vs data
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

        // SID register usage
        for (int reg = 0; reg < 32; reg++) {
            sidState.analysis.sidRegisterWrites[reg] = cpu_get_sid_writes(reg);
        }

        return 0; // Success
    }

    // Get header field
    EMSCRIPTEN_KEEPALIVE
        const char* sid_get_header_string(int field) {
        if (!sidState.isLoaded) return "";

        switch (field) {
        case 0: return sidState.header.name;
        case 1: return sidState.header.author;
        case 2: return sidState.header.copyright;
        case 3: return sidState.header.magicID;
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
        switch (field) {
        case 0: target = sidState.header.name; break;
        case 1: target = sidState.header.author; break;
        case 2: target = sidState.header.copyright; break;
        default: return;
        }

        if (target) {
            memset(target, 0, 32);
            strncpy(target, value, 31);
        }
    }

    // Create modified SID file
    EMSCRIPTEN_KEEPALIVE
        uint8_t* sid_create_modified(uint32_t* outSize) {
        if (!sidState.isLoaded || !sidState.fileBuffer) {
            *outSize = 0;
            return nullptr;
        }

        // Create new buffer
        uint8_t* newBuffer = (uint8_t*)malloc(sidState.fileSize);
        memcpy(newBuffer, sidState.fileBuffer, sidState.fileSize);

        // Update header in the new buffer with fixed endianness
        SIDHeader tempHeader = sidState.header;

        // Fix endianness back for file format
        tempHeader.version = swap16(tempHeader.version);
        tempHeader.dataOffset = swap16(tempHeader.dataOffset);
        tempHeader.loadAddress = swap16(tempHeader.loadAddress);
        tempHeader.initAddress = swap16(tempHeader.initAddress);
        tempHeader.playAddress = swap16(tempHeader.playAddress);
        tempHeader.songs = swap16(tempHeader.songs);
        tempHeader.startSong = swap16(tempHeader.startSong);
        tempHeader.speed = swap32(tempHeader.speed);
        if (sidState.header.version >= 2) {
            tempHeader.flags = swap16(tempHeader.flags);
        }

        // Copy updated header
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

    // Clean up
    EMSCRIPTEN_KEEPALIVE
        void sid_cleanup() {
        if (sidState.fileBuffer) {
            free(sidState.fileBuffer);
            sidState.fileBuffer = nullptr;
        }
        sidState.isLoaded = false;
    }

} // extern "C"