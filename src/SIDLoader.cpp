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
    util::Logger::debug("SID init address overridden: $" + util::wordToHex(address));
}

/**
 * @brief Override the play address in the SID header
 *
 * @param address New play address
 */
void SIDLoader::setPlayAddress(u16 address) {
    header_.playAddress = address;
    util::Logger::debug("SID play address overridden: $" + util::wordToHex(address));
}

/**
 * @brief Override the load address in the SID header
 *
 * @param address New load address
 */
void SIDLoader::setLoadAddress(u16 address) {
    header_.loadAddress = address;
    util::Logger::debug("SID load address overridden: $" + util::wordToHex(address));
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
        std::cerr << "CPU not set!\n";
        return false;
    }

    std::ifstream file(filename, std::ios::binary);
    if (!file) {
        std::cerr << "Failed to open file: " << filename << "\n";
        return false;
    }

    // Get file size
    file.seekg(0, std::ios::end);
    std::streamsize fileSize = file.tellg();
    file.seekg(0, std::ios::beg);

    if (fileSize <= 0) {
        std::cerr << "File is empty: " << filename << "\n";
        return false;
    }

    // Read the entire file into a buffer
    std::vector<u8> buffer(static_cast<size_t>(fileSize));
    if (!file.read(reinterpret_cast<char*>(buffer.data()), fileSize)) {
        std::cerr << "Failed to read file: " << filename << "\n";
        return false;
    }

    // Check if file is large enough to contain a header
    if (fileSize < sizeof(SIDHeader)) {
        std::cerr << "SID file too small to contain a valid header!\n";
        return false;
    }

    // Copy header data
    std::memcpy(&header_, buffer.data(), sizeof(header_));

    // Check for RSID files, which we don't support
    if (std::string(header_.magicID, 4) == "RSID") {
        std::cerr << "RSID file format detected: \"" << filename << "\"\n";
        std::cerr << "RSID files require a true C64 environment and cannot be emulated by SIDwinder.\n";
        std::cerr << "Please use a PSID formatted file instead.\n";
        return false;
    }

    // Check for PSID magic ID
    if (std::string(header_.magicID, 4) != "PSID") {
        std::cerr << "Invalid SID file: Expected 'PSID' magic ID, found '"
            << std::string(header_.magicID, 4) << "'\n";
        return false;
    }

    // Fix endianness (SID files are big-endian)
    fixHeaderEndianness(header_);

    // Validate version number
    if (header_.version < 1 || header_.version > 4) {
        std::cerr << "Unsupported SID version: " << header_.version
            << ". Supported versions are 1-4.\n";
        return false;
    }

    // Handle multi-SID configurations for v3+ files
    if (header_.version >= 3) {
        util::Logger::info("SID file version " + std::to_string(header_.version) +
            " (supports multiple SID chips)");

        if (header_.secondSIDAddress != 0) {
            // Address for the second SID is encoded in the secondSIDAddress field
            u16 secondSIDAddr = header_.secondSIDAddress << 4;  // Convert to actual address
            util::Logger::info("Second SID chip at address: $" + util::wordToHex(secondSIDAddr));
            // Your code to set up the second SID chip would go here
        }

        if (header_.version >= 4 && header_.thirdSIDAddress != 0) {
            // Address for the third SID is encoded in the thirdSIDAddress field (v4 only)
            u16 thirdSIDAddr = header_.thirdSIDAddress << 4;  // Convert to actual address
            util::Logger::info("Third SID chip at address: $" + util::wordToHex(thirdSIDAddr));
            // Your code to set up the third SID chip would go here
        }
    }

    // Determine the data offset based on version
    u16 expectedOffset = (header_.version == 1) ? 0x76 : 0x7C;
    if (header_.dataOffset != expectedOffset) {
        util::Logger::warning("Unexpected dataOffset value: " + std::to_string(header_.dataOffset) +
            ", expected: " + std::to_string(expectedOffset));
    }

    // Handle embedded load address if needed
    if (header_.loadAddress == 0) {
        if (fileSize < header_.dataOffset + 2) {
            std::cerr << "SID file corrupt (missing embedded load address)!\n";
            return false;
        }
        const u8 lo = buffer[header_.dataOffset];
        const u8 hi = buffer[header_.dataOffset + 1];
        header_.loadAddress = static_cast<u16>(lo | (hi << 8));
        header_.dataOffset += 2;
        util::Logger::debug("Using embedded load address: $" + util::wordToHex(header_.loadAddress));
    }

    // Calculate data size
    dataSize_ = static_cast<u16>(fileSize - header_.dataOffset);

    if (dataSize_ <= 0) {
        std::cerr << "SID file contains no music data!\n";
        return false;
    }

    if (header_.loadAddress + dataSize_ > 65536) {
        std::cerr << "SID file data exceeds C64 memory limits! (Load address: $"
            << util::wordToHex(header_.loadAddress) << ", Size: " << dataSize_ << " bytes)\n";
        return false;
    }

    // Copy music data to CPU memory
    const u8* musicData = &buffer[header_.dataOffset];
    if (!copyMusicToMemory(musicData, dataSize_, header_.loadAddress)) {
        std::cerr << "Failed to copy music data to memory!\n";
        return false;
    }

    // Log SID file details
    util::Logger::info("Loaded PSID v" + std::to_string(header_.version) +
        " file: " + std::string(header_.name));
    util::Logger::info("Songs: " + std::to_string(header_.songs) +
        ", Start song: " + std::to_string(header_.startSong));
    util::Logger::info("Author: " + std::string(header_.author));
    util::Logger::info("Released: " + std::string(header_.copyright));
    util::Logger::debug("Load address: $" + util::wordToHex(header_.loadAddress) +
        ", Init: $" + util::wordToHex(header_.initAddress) +
        ", Play: $" + util::wordToHex(header_.playAddress));

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
 * @brief Fix SID header endianness
 *
 * SID files store multi-byte values in big-endian format, but the CPU
 * uses little-endian. This function swaps the byte order as needed.
 *
 * @param header Header to fix
 */
void SIDLoader::fixHeaderEndianness(SIDHeader& header) {
    // SID files store multi-byte values in big-endian format
    auto swapEndian = [](u16 value) -> u16 {
        return (value >> 8) | (value << 8);
        };
    auto swapEndian32 = [](u32 value) -> u32 {
        return  ((value & 0xff000000) >> 24)
            | ((value & 0x00ff0000) >> 8)
            | ((value & 0x0000ff00) << 8)
            | ((value & 0x000000ff) << 24);
        };

    // Swap multi-byte header fields
    header.version = swapEndian(header.version);
    header.dataOffset = swapEndian(header.dataOffset);
    header.loadAddress = swapEndian(header.loadAddress);
    header.initAddress = swapEndian(header.initAddress);
    header.playAddress = swapEndian(header.playAddress);
    header.songs = swapEndian(header.songs);
    header.startSong = swapEndian(header.startSong);
    header.speed = swapEndian32(header.speed);
    header.flags = swapEndian(header.flags);

    // Log version information
    util::Logger::debug("SID format version " + std::to_string(header.version) + " detected");
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

/**
 * @brief Get the SID chip model used in this file
 *
 * @return String representation of SID model(s)
 */
std::string SIDLoader::getSIDModel() const {
    // Extract model info from flags (bits 4-5 in v2+ files)
    if (header_.version >= 2) {
        u16 flags = header_.flags;
        u8 model = (flags >> 4) & 0x03;

        switch (model) {
        case 0: return "Unknown";
        case 1: return "6581 (MOS6581)";
        case 2: return "8580 (MOS8580)";
        case 3: return "6581 or 8580";
        default: return "Unknown";
        }
    }

    return "Unknown (not specified in v1 files)";
}

/**
 * @brief Get the clock speed used in this file
 *
 * @return String representation of clock speed
 */
std::string SIDLoader::getClockSpeed() const {
    // Extract clock info from flags (bits 2-3 in v2+ files)
    if (header_.version >= 2) {
        u16 flags = header_.flags;
        u8 clock = (flags >> 2) & 0x03;

        switch (clock) {
        case 0: return "Unknown";
        case 1: return "PAL (50Hz)";
        case 2: return "NTSC (60Hz)";
        case 3: return "PAL and NTSC";
        default: return "Unknown";
        }
    }

    return "Unknown (not specified in v1 files)";
}