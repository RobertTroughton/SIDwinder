// rle_compressor.cpp - RLE compression for SIDwinder with detailed logging
// Compile with the other WASM modules

#include <emscripten/emscripten.h>
#include <cstdint>
#include <cstring>
#include <vector>
#include <algorithm>
#include <cstdio>

extern "C" {

    // RLE Compression state
    struct RLECompressor {
        std::vector<uint8_t> compressed;
        uint32_t originalSize;
        uint32_t compressedSize;
        bool enableLogging;

        // Compression parameters
        static const uint32_t MIN_REPEAT_LENGTH = 8;  // Minimum bytes needed for repeat encoding

        // Decompressor stub data
        static const uint8_t decompressorStub[241];
        static const uint16_t stubSize = 241;
        static const uint16_t stubLoadAddress = 0x0801;
        static const uint16_t stubEndAddress = 0x08EF;
        static const uint16_t compressedDataStart = 0x08F0;

        // Offsets for patching values into stub
        static const uint16_t offset_UncompressedStart_Lo = 0x19 + 2;
        static const uint16_t offset_UncompressedStart_Hi = 0x1A + 2;
        static const uint16_t offset_CompressedEnd_Lo = 0x1B + 2;
        static const uint16_t offset_CompressedEnd_Hi = 0x1C + 2;
        static const uint16_t offset_Execute_Lo = 0x1D + 2;
        static const uint16_t offset_Execute_Hi = 0x1E + 2;
    };

    // The decompressor stub data
    const uint8_t RLECompressor::decompressorStub[241] = {
        0x01, 0x08, 0x15, 0x08, 0x01, 0x00, 0x9e, 0x32, 0x30, 0x38, 0x30, 0x20, 0x53, 0x49, 0x44, 0x57, 0x49, 0x4e,
        0x44, 0x45, 0x52, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x20, 0x00, 0x41, 0x78,
        0xAD, 0x11, 0xD0, 0x10, 0xFB, 0xAD, 0x11, 0xD0, 0x30, 0xFB, 0xA9, 0x00, 0x8D, 0x20, 0xD0, 0x8D,
        0x11, 0xD0, 0x8D, 0x18, 0xD4, 0xA5, 0x01, 0x48, 0xA9, 0x34, 0x85, 0x01, 0xAD, 0x1E, 0x08, 0x8D,
        0xB7, 0x08, 0xAD, 0x1F, 0x08, 0x8D, 0xB8, 0x08, 0xA0, 0x5A, 0xB9, 0x95, 0x08, 0x99, 0x00, 0x02,
        0x88, 0x10, 0xF7, 0xAD, 0x1C, 0x08, 0x85, 0xF0, 0xAD, 0x1D, 0x08, 0x85, 0xF1, 0xA9, 0xF0, 0x85,
        0xF2, 0xA9, 0xFF, 0x85, 0xF3, 0xA0, 0x00, 0xA6, 0xF0, 0xD0, 0x02, 0xC6, 0xF1, 0xC6, 0xF0, 0xA6,
        0xF2, 0xD0, 0x02, 0xC6, 0xF3, 0xC6, 0xF2, 0xB1, 0xF0, 0x91, 0xF2, 0xA5, 0xF0, 0xC9, 0xF0, 0xD0,
        0xE6, 0xA5, 0xF1, 0xC9, 0x08, 0xD0, 0xE0, 0xAD, 0x1A, 0x08, 0x85, 0xF4, 0xAD, 0x1B, 0x08, 0x85,
        0xF5, 0x4C, 0x00, 0x02, 0xA0, 0x00, 0xB1, 0xF2, 0xE6, 0xF2, 0xD0, 0x02, 0xE6, 0xF3, 0x85, 0xF6,
        0xB1, 0xF2, 0xE6, 0xF2, 0xD0, 0x02, 0xE6, 0xF3, 0xAA, 0x29, 0x7F, 0x85, 0xF7, 0x05, 0xF6, 0xD0,
        0x07, 0x68, 0x85, 0x01, 0x58, 0x4C, 0xCD, 0xAB, 0x8A, 0x30, 0x1A, 0xB1, 0xF2, 0xE6, 0xF2, 0xD0,
        0x02, 0xE6, 0xF3, 0x91, 0xF4, 0xE6, 0xF4, 0xD0, 0x02, 0xE6, 0xF5, 0xC6, 0xF6, 0xD0, 0xEC, 0xC6,
        0xF7, 0x10, 0xE8, 0x30, 0xC1, 0xB1, 0xF2, 0xE6, 0xF2, 0xD0, 0x02, 0xE6, 0xF3, 0x91, 0xF4, 0xE6,
        0xF4, 0xD0, 0x02, 0xE6, 0xF5, 0xC6, 0xF6, 0xD0, 0xF4, 0xC6, 0xF7, 0x10, 0xF0, 0x30, 0xA7
    };

    // Global RLE compressor instance
    RLECompressor rleCompressor;

    // JavaScript callback for logging
    typedef void (*LogCallback)(const char*);
    LogCallback jsLogCallback = nullptr;

    // Set JavaScript logging callback
    EMSCRIPTEN_KEEPALIVE
        void rle_set_log_callback(LogCallback callback) {
        jsLogCallback = callback;
    }

    // Helper function to log to console
    void log_message(const char* format, ...) {
        if (!rleCompressor.enableLogging) return;

        char buffer[512];
        va_list args;
        va_start(args, format);
        vsnprintf(buffer, sizeof(buffer), format, args);
        va_end(args);

        // Use printf which Emscripten redirects to console
        printf("[RLE] %s\n", buffer);
    }



    // Initialize RLE compressor
    EMSCRIPTEN_KEEPALIVE
        void rle_init() {
        rleCompressor.compressed.clear();
        rleCompressor.originalSize = 0;
        rleCompressor.compressedSize = 0;
        rleCompressor.enableLogging = true;  // Enable logging by default
    }

    // Enable/disable logging
    EMSCRIPTEN_KEEPALIVE
        void rle_set_logging(int enable) {
        rleCompressor.enableLogging = (enable != 0);

        // Test log to confirm it's working
        if (rleCompressor.enableLogging) {
            printf("[RLE] Logging enabled\n");
            EM_ASM({
                console.log('[RLE] Logging enabled via EM_ASM');
                });
        }
        else {
            printf("[RLE] Logging disabled\n");
        }
    }

    // Test function to verify logging works
    EMSCRIPTEN_KEEPALIVE
        void rle_test_logging() {
        printf("[RLE] Test: printf logging\n");

        EM_ASM({
            console.log('[RLE] Test: EM_ASM logging');
            });

        bool oldState = rleCompressor.enableLogging;
        rleCompressor.enableLogging = true;
        log_message("Test: log_message with state=%d", oldState);
        rleCompressor.enableLogging = oldState;
    }

    // Helper function to log hex data
    void log_hex_data(const char* prefix, const uint8_t* data, uint32_t size, uint32_t maxBytes = 16) {
        if (!rleCompressor.enableLogging) return;

        char buffer[512];
        char* p = buffer;
        p += sprintf(p, "%s: ", prefix);

        uint32_t bytesToShow = size > maxBytes ? maxBytes : size;
        for (uint32_t i = 0; i < bytesToShow; i++) {
            p += sprintf(p, "%02X ", data[i]);
        }

        if (size > maxBytes) {
            p += sprintf(p, "... (%u bytes total)", size);
        }

        log_message("%s", buffer);
    }

    // Helper function to add a run to compressed data
    void add_run(bool isRepeat, uint16_t length, const uint8_t* data, uint32_t blockNum, uint32_t inputOffset) {
        if (length == 0) return;

        uint32_t startSize = rleCompressor.compressed.size();

        // Set high bit if repeat
        uint16_t lengthWord = length;
        if (isRepeat) {
            lengthWord |= 0x8000;
        }

        // Add length (little endian)
        rleCompressor.compressed.push_back(lengthWord & 0xFF);
        rleCompressor.compressed.push_back((lengthWord >> 8) & 0xFF);

        // Add data
        if (isRepeat) {
            // For repeat runs, just add the single value
            rleCompressor.compressed.push_back(data[0]);

            log_message("Block %u @ 0x%04X, Len 0x%04X, REPEAT 0x%02X",
                blockNum, inputOffset, length, data[0]);
        }
        else {
            // For non-repeat runs, add all values
            for (uint16_t i = 0; i < length; i++) {
                rleCompressor.compressed.push_back(data[i]);
            }

            log_message("Block %u @ 0x%04X, Len 0x%04X, LITERAL",
                blockNum, inputOffset, length);
        }
    }

    // Compress PRG data using RLE
    EMSCRIPTEN_KEEPALIVE
        uint8_t* rle_compress_prg(uint8_t* data, uint32_t size,
            uint16_t uncompressedStart,
            uint16_t executeAddress,
            uint32_t* outSize) {
        rle_init();

        log_message("========================================");
        log_message("RLE Compression Start");
        log_message("========================================");
        log_message("Input size: %u bytes", size);
        log_message("Uncompressed start address: $%04X", uncompressedStart);
        log_message("Execute address: $%04X", executeAddress);
        log_message("Repeat threshold: %u bytes minimum", RLECompressor::MIN_REPEAT_LENGTH);
        log_message("Decompressor stub: $%04X-$%04X (%u bytes)",
            RLECompressor::stubLoadAddress,
            RLECompressor::stubEndAddress,
            RLECompressor::stubSize);
        log_message("Compressed data will start at: $%04X", RLECompressor::compressedDataStart);
        log_message("");

        // We'll build the compressed data first
        std::vector<uint8_t> tempCompressed;
        uint32_t blockCount = 0;

        uint32_t pos = 0;
        while (pos < size) {
            uint32_t blockStartPos = pos;

            // Look for repeating bytes
            uint32_t repeatStart = pos;
            uint8_t repeatValue = data[pos];
            uint32_t repeatCount = 1;

            while (pos + repeatCount < size &&
                data[pos + repeatCount] == repeatValue &&
                repeatCount < 0x7FFF) { // Max 15-bit length
                repeatCount++;
            }

            // Check if it's worth encoding as a repeat
            if (repeatCount >= RLECompressor::MIN_REPEAT_LENGTH) {
                // Encode as repeat
                add_run(true, repeatCount, &repeatValue, blockCount++, blockStartPos);
                pos += repeatCount;
            }
            else {
                // Look for non-repeating sequence
                uint32_t nonRepeatStart = pos;
                uint32_t nonRepeatCount = 0;

                while (pos < size && nonRepeatCount < 0x7FFF) {
                    // Check if we're about to hit a long repeat sequence
                    if (pos + RLECompressor::MIN_REPEAT_LENGTH - 1 < size) {
                        bool foundLongRepeat = true;
                        uint8_t checkValue = data[pos];
                        for (uint32_t i = 1; i < RLECompressor::MIN_REPEAT_LENGTH; i++) {
                            if (data[pos + i] != checkValue) {
                                foundLongRepeat = false;
                                break;
                            }
                        }
                        if (foundLongRepeat) {
                            break;
                        }
                    }
                    pos++;
                    nonRepeatCount++;
                }

                if (nonRepeatCount > 0) {
                    add_run(false, nonRepeatCount, &data[nonRepeatStart], blockCount++, blockStartPos);
                }
            }
        }

        // Add terminator (0x00, 0x00)
        log_message("");
        log_message("Adding terminator: 0x00 0x00 at offset 0x%04X",
            rleCompressor.compressed.size());
        rleCompressor.compressed.push_back(0x00);
        rleCompressor.compressed.push_back(0x00);

        // Calculate compressed end address
        uint16_t compressedEnd = RLECompressor::compressedDataStart + rleCompressor.compressed.size();

        log_message("");
        log_message("Compression complete:");
        log_message("  Total blocks: %u", blockCount);
        log_message("  Compressed data size: %u bytes", rleCompressor.compressed.size());
        log_message("  Compressed data range: $%04X-$%04X",
            RLECompressor::compressedDataStart,
            compressedEnd - 1);

        // Now build the final output with stub + compressed data
        std::vector<uint8_t> finalOutput;

        // Copy decompressor stub
        finalOutput.insert(finalOutput.end(),
            RLECompressor::decompressorStub,
            RLECompressor::decompressorStub + RLECompressor::stubSize);

        // Patch the stub with our values
        log_message("");
        log_message("Patching decompressor stub:");
        log_message("  Uncompressed start: $%04X (bytes: %02X %02X)",
            uncompressedStart,
            uncompressedStart & 0xFF,
            (uncompressedStart >> 8) & 0xFF);
        log_message("  Compressed end: $%04X (bytes: %02X %02X)",
            compressedEnd,
            compressedEnd & 0xFF,
            (compressedEnd >> 8) & 0xFF);
        log_message("  Execute address: $%04X (bytes: %02X %02X)",
            executeAddress,
            executeAddress & 0xFF,
            (executeAddress >> 8) & 0xFF);

        finalOutput[RLECompressor::offset_UncompressedStart_Lo] = uncompressedStart & 0xFF;
        finalOutput[RLECompressor::offset_UncompressedStart_Hi] = (uncompressedStart >> 8) & 0xFF;
        finalOutput[RLECompressor::offset_CompressedEnd_Lo] = compressedEnd & 0xFF;
        finalOutput[RLECompressor::offset_CompressedEnd_Hi] = (compressedEnd >> 8) & 0xFF;
        finalOutput[RLECompressor::offset_Execute_Lo] = executeAddress & 0xFF;
        finalOutput[RLECompressor::offset_Execute_Hi] = (executeAddress >> 8) & 0xFF;

        // Add compressed data
        finalOutput.insert(finalOutput.end(),
            rleCompressor.compressed.begin(),
            rleCompressor.compressed.end());

        // Create output buffer
        uint8_t* output = (uint8_t*)malloc(finalOutput.size());
        memcpy(output, finalOutput.data(), finalOutput.size());

        *outSize = finalOutput.size();

        // Store statistics
        rleCompressor.originalSize = size;
        rleCompressor.compressedSize = finalOutput.size();

        log_message("");
        log_message("Final output:");
        log_message("  Total size: %u bytes", finalOutput.size());
        log_message("  Compression ratio: %.2f%%",
            (float)finalOutput.size() / (float)size * 100.0f);
        log_message("  Space saved: %d bytes", (int)size - (int)finalOutput.size());
        log_message("========================================");

        return output;
    }

    // Get compression statistics
    EMSCRIPTEN_KEEPALIVE
        uint32_t rle_get_original_size() {
        return rleCompressor.originalSize;
    }

    EMSCRIPTEN_KEEPALIVE
        uint32_t rle_get_compressed_size() {
        return rleCompressor.compressedSize;
    }

    EMSCRIPTEN_KEEPALIVE
        float rle_get_compression_ratio() {
        if (rleCompressor.originalSize == 0) return 0.0f;
        return (float)rleCompressor.compressedSize / (float)rleCompressor.originalSize;
    }

} // extern "C"