// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#pragma once

#include "Common.h"
#include "SIDFileFormat.h"

#include <cstring>
#include <memory>
#include <string>
#include <string_view>
#include <vector>

/**
 * @file SIDLoader.h
 * @brief Loads and manages SID music files
 *
 * Provides facilities for loading SID, PRG, and BIN files containing
 * C64 music data and managing them for playback and analysis.
 */

 // Forward declarations
class CPU6510;

/**
 * @class SIDLoader
 * @brief Handles loading and processing SID music files for the C64
 *
 * This class can load SID (PSID format only), PRG, and BIN files containing C64 music data,
 * and manages loading them into a CPU6510 emulator for playback and analysis.
 * Supports all versions (1-4) of the PSID file format.
 */
class SIDLoader {
public:
    /**
     * @brief Construct a new SIDLoader
     *
     * Initializes a SID loader with default settings.
     */
    SIDLoader();

    /**
     * @brief Set the CPU instance to use for loading music data
     * @param cpu Pointer to a CPU6510 instance
     *
     * Connects the SIDLoader to a CPU instance for loading and executing music.
     */
    void setCPU(CPU6510* cpu);

    /**
     * @brief Override the init address in the SID header
     * @param address New init address
     */
    void setInitAddress(u16 address);

    /**
     * @brief Override the play address in the SID header
     * @param address New play address
     */
    void setPlayAddress(u16 address);

    /**
     * @brief Override the load address in the SID header
     * @param address New load address
     */
    void setLoadAddress(u16 address);

    /**
     * @brief Set the title in the SID header
     * @param title New title string
     */
    void setTitle(const std::string& title) {
        strncpy(header_.name, title.c_str(), sizeof(header_.name) - 1);
        header_.name[sizeof(header_.name) - 1] = '\0';
    }

    /**
     * @brief Set the author in the SID header
     * @param author New author string
     */
    void setAuthor(const std::string& author) {
        strncpy(header_.author, author.c_str(), sizeof(header_.author) - 1);
        header_.author[sizeof(header_.author) - 1] = '\0';
    }

    /**
     * @brief Set the copyright in the SID header
     * @param copyright New copyright string
     */
    void setCopyright(const std::string& copyright) {
        strncpy(header_.copyright, copyright.c_str(), sizeof(header_.copyright) - 1);
        header_.copyright[sizeof(header_.copyright) - 1] = '\0';
    }

    /**
     * @brief Load a SID file
     * @param filename Path to the SID file
     * @return true if loading succeeded, false otherwise
     *
     * Loads a SID file into memory and parses its header information.
     * Supports PSID format only, versions 1-4. RSID files are not supported
     * as they require a true C64 environment.
     */
    bool loadSID(const std::string& filename);

    /**
     * @brief Get the SID file format version
     * @return Version number (1-4)
     */
    u16 getVersion() const { return header_.version; }

    /**
     * @brief Get the SID chip model used in this file
     * @return String representation of SID model(s)
     */
    std::string getSIDModel() const;

    /**
     * @brief Get the clock speed used in this file
     * @return String representation of clock speed
     */
    std::string getClockSpeed() const;

    // Accessor methods

    /**
     * @brief Get the initialization address
     * @return Initialization address
     */
    u16 getInitAddress() const { return header_.initAddress; }

    /**
     * @brief Get the play address
     * @return Play address
     */
    u16 getPlayAddress() const { return header_.playAddress; }

    /**
     * @brief Get the load address
     * @return Load address
     */
    u16 getLoadAddress() const { return header_.loadAddress; }

    /**
     * @brief Get the size of the loaded data
     * @return Data size in bytes
     */
    u16 getDataSize() const { return dataSize_; }

    /**
     * @brief Get the SID header
     * @return Reference to the SID header
     */
    const SIDHeader& getHeader() const { return header_; }

    /**
     * @brief Get the original memory data
     * @return Reference to the original memory data
     */
    const std::vector<u8>& getOriginalMemory() const { return originalMemory_; }

    /**
     * @brief Get the base address of the original memory
     * @return Original memory base address
     */
    u16 getOriginalMemoryBase() const { return originalMemoryBase_; }

    /**
     * @brief Get the number of times the play routine should be called per frame
     * @return Number of calls per frame
     */
    int getNumPlayCallsPerFrame() const { return numPlayCallsPerFrame_; }

    /**
     * @brief Set the number of times the play routine should be called per frame
     * @param num Number of calls per frame
     */
    void setNumPlayCallsPerFrame(int num) { numPlayCallsPerFrame_ = num; }

    /**
     * @brief Backup the current memory to allow restoration later
     * @return True if backup succeeded
     *
     * Creates a snapshot of the CPU memory for later restoration.
     */
    bool backupMemory();

    /**
     * @brief Restore memory from backup
     * @return True if restoration succeeded
     *
     * Restores the CPU memory from a previously created backup.
     */
    bool restoreMemory();

private:
    /**
     * @brief Copy music data to CPU memory
     * @param data Pointer to the music data
     * @param size Size of the data in bytes
     * @param loadAddr Memory address to load the data
     * @return true if copying succeeded
     *
     * Loads music data into the CPU memory at the specified address.
     */
    bool copyMusicToMemory(const u8* data, u16 size, u16 loadAddr);

    /**
     * @brief Fix SID header endianness (SID files use big-endian)
     * @param header Reference to the header to fix
     *
     * Swaps endianness of multi-byte values in the SID header.
     */
    void fixHeaderEndianness(SIDHeader& header);

    // Member variables
    SIDHeader header_;          // SID file header
    u16 dataSize_ = 0;          // Size of music data
    CPU6510* cpu_ = nullptr;    // Pointer to CPU instance

    // Keep a copy of the original loaded data
    std::vector<u8> originalMemory_;    // Original music data
    u16 originalMemoryBase_ = 0;        // Base address of original data

    // Playback configuration
    u8 numPlayCallsPerFrame_ = 1;       // Number of play calls per frame

    // Backup of memory for analysis pass
    std::vector<u8> memoryBackup_;      // Backup of CPU memory
};