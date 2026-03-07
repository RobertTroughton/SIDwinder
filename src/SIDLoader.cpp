// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#include "cpu6510.h"
#include "SIDLoader.h"
#include "SIDwinderUtils.h"

#include <algorithm>
#include <cstring>
#include <fstream>
#include <iostream>
#include <stdexcept>

using namespace sidwinder;

/**
 * @brief Constructor for SIDLoader
 *
 * Initializes a SID loader with default settings and empty header.
 */
SIDLoader::SIDLoader() {
    std::memset(&header_, 0, sizeof(header_));
}

/**
 * @brief Set the CPU instance to use for loading music data
 *
 * @param cpuPtr Pointer to a CPU6510 instance
 */
void SIDLoader::setCPU(CPU6510* cpuPtr) {
    cpu_ = cpuPtr;
}

/**
 * @brief Override the init address in the SID header
 *
 * @param address New init address
 */
void SIDLoader::setInitAddress(u16 address) {
    header_.initAddress = address;
}

/**
 * @brief Override the play address in the SID header
 *
 * @param address New play address
 */
void SIDLoader::setPlayAddress(u16 address) {
    header_.playAddress = address;
}

/**
 * @brief Override the load address in the SID header
 *
 * @param address New load address
 */
void SIDLoader::setLoadAddress(u16 address) {
    header_.loadAddress = address;
}

/**
 * @brief Load a SID file
 *
 * Reads a SID file, parses its header, and loads the music data into memory.
 *
 * @param filename Path to the SID file
 * @return true if loading succeeded, false otherwise
 */
bool SIDLoader::loadSID(const std::string& filename) {
    if (!cpu_) {
        return false;
    }

    // Read entire SID file
    auto fileData = util::readBinaryFile(filename);
    if (!fileData) {
        return false; // Error already logged
    }

    if (fileData->size() < sizeof(SIDHeader)) {
        util::Logger::error("SID file too small to contain a valid header!");
        return false;
    }

    // Copy and validate header
    std::memcpy(&header_, fileData->data(), sizeof(header_));

    // Check file format
    if (std::string(header_.magicID, 4) == "RSID") {
        util::Logger::error("RSID file format detected: \"" + filename + "\"");
        util::Logger::error("RSID files require a true C64 environment and cannot be emulated by SIDwinder.");
        util::Logger::error("Please use a PSID formatted file instead.");
        return false;
    }

    if (std::string(header_.magicID, 4) != "PSID") {
        util::Logger::error("Invalid SID file: Expected 'PSID' magic ID, found '" +
            std::string(header_.magicID, 4) + "'");
        return false;
    }

    // Fix header endianness
    util::fixSIDHeaderEndianness(header_);

    // Validate version
    if (header_.version < 1 || header_.version > 4) {
        util::Logger::error("Unsupported SID version: " + std::to_string(header_.version) +
            ". Supported versions are 1-4.");
        return false;
    }

    // Log version-specific info
    if (header_.version >= 3) {
        if (header_.secondSIDAddress != 0) {
            u16 secondSIDAddr = header_.secondSIDAddress << 4;
        }
        if (header_.version >= 4 && header_.thirdSIDAddress != 0) {
            u16 thirdSIDAddr = header_.thirdSIDAddress << 4;
        }
    }

    // Validate data offset
    u16 expectedOffset = (header_.version == 1) ? 0x76 : 0x7C;
    if (header_.dataOffset != expectedOffset) {
        util::Logger::warning("Unexpected dataOffset value: " + std::to_string(header_.dataOffset) +
            ", expected: " + std::to_string(expectedOffset));
    }

    // Handle embedded or explicit load address
    u16 dataStart = header_.dataOffset;
    if (header_.loadAddress == 0) {
        if (fileData->size() < header_.dataOffset + 2) {
            util::Logger::error("SID file corrupt (missing embedded load address)!");
            return false;
        }

        const u8 lo = (*fileData)[header_.dataOffset];
        const u8 hi = (*fileData)[header_.dataOffset + 1];
        header_.loadAddress = static_cast<u16>(lo | (hi << 8));
        dataStart += 2;
        util::Logger::debug("Using embedded load address: $" + util::wordToHex(header_.loadAddress));
    }

    // Calculate and validate data size
    dataSize_ = static_cast<u16>(fileData->size() - dataStart);
    if (dataSize_ <= 0) {
        util::Logger::error("SID file contains no music data!");
        return false;
    }

    if (header_.loadAddress + dataSize_ > 65536) {
        util::Logger::error("SID file data exceeds C64 memory limits! (Load address: $" +
            util::wordToHex(header_.loadAddress) + ", Size: " + std::to_string(dataSize_) + " bytes)");
        return false;
    }

    // Copy music data to CPU memory
    const u8* musicData = fileData->data() + dataStart;
    if (!copyMusicToMemory(musicData, dataSize_, header_.loadAddress)) {
        util::Logger::error("Failed to copy music data to memory!");
        return false;
    }

    return true;
}

/**
 * @brief Copy music data to CPU memory
 *
 * Loads music data into the CPU's memory at the specified address
 * and stores a copy for later reference.
 *
 * @param data Pointer to the music data
 * @param size Size of the data in bytes
 * @param loadAddr Memory address to load the data
 * @return true if copying succeeded
 */
bool SIDLoader::copyMusicToMemory(const u8* data, u16 size, u16 loadAddr) {
    if (!cpu_) {
        std::cerr << "CPU not set!\n";
        return false;
    }

    if (size == 0 || loadAddr + size > 65536) {
        std::cerr << "Invalid data size or load address!\n";
        return false;
    }

    // Load data into CPU memory
    for (u32 i = 0; i < size; ++i) {
        cpu_->writeByte(loadAddr + i, data[i]);
    }

    dataSize_ = size;

    // Save original copy for later reference
    originalMemory_.assign(data, data + size);
    originalMemoryBase_ = loadAddr;

    return true;
}

/**
 * @brief Backup the current memory to allow restoration later
 *
 * Creates a snapshot of the CPU memory for later restoration.
 *
 * @return True if backup succeeded
 */
bool SIDLoader::backupMemory() {
    if (!cpu_) {
        util::Logger::error("CPU not set for memory backup!");
        return false;
    }

    // Get the entire CPU memory
    auto cpuMemory = cpu_->getMemory();

    // Make a copy
    memoryBackup_.assign(cpuMemory.begin(), cpuMemory.end());

    return true;
}

/**
 * @brief Restore memory from backup
 *
 * Restores the CPU memory from a previously created backup.
 *
 * @return True if restoration succeeded
 */
bool SIDLoader::restoreMemory() {
    if (!cpu_) {
        return false;
    }

    if (memoryBackup_.empty()) {
        return false;  // Return false but don't log as error - this is expected in some workflows
    }

    // Copy the backup back to CPU memory
    // Use size_t to avoid overflow with large memory sizes
    for (size_t addr = 0; addr < memoryBackup_.size(); ++addr) {
        // Cast to u16 is safe for addressing CPU memory (which is limited to 64K)
        cpu_->writeByte(static_cast<u16>(addr), memoryBackup_[addr]);
    }

    return true;
}

bool SIDLoader::extractPrgFromSid(const fs::path& sidFile, const fs::path& outputPrg) {
    // 1. Read entire SID file
    auto sidData = util::readBinaryFile(sidFile);
    if (!sidData) {
        util::Logger::error("Failed to read SID file: " + sidFile.string());
        return false;
    }

    // 2. Parse header to get offsets
    SIDHeader header;
    std::memcpy(&header, sidData->data(), sizeof(header));
    util::fixSIDHeaderEndianness(header);

    // Validate it's a SID file
    if (std::string(header.magicID, 4) != "PSID") {
        util::Logger::error("Not a valid PSID file: " + sidFile.string());
        return false;
    }

    // 3. Calculate where music data starts
    u16 dataOffset = header.dataOffset;
    u16 loadAddress = header.loadAddress;

    if (loadAddress == 0) {
        // Embedded load address
        if (sidData->size() < dataOffset + 2) {
            util::Logger::error("SID file too small for embedded load address");
            return false;
        }
        loadAddress = sidData->at(dataOffset) | (sidData->at(dataOffset + 1) << 8);
        dataOffset += 2;
    }

    // 4. Build PRG data in memory
    std::vector<u8> prgData;
    prgData.push_back(loadAddress & 0xFF);        // Low byte
    prgData.push_back((loadAddress >> 8) & 0xFF); // High byte

    // 5. Copy music data
    if (dataOffset < sidData->size()) {
        prgData.insert(prgData.end(),
            sidData->begin() + dataOffset,
            sidData->end());
    }

    // 6. Write result
    return util::writeBinaryFile(outputPrg, prgData);
}