#include "MemorySubsystem.h"
#include "CPU6510Impl.h"
#include <algorithm>
#include <iomanip>
#include <iostream>

/**
 * @brief Constructor for MemorySubsystem
 *
 * @param cpu Reference to the CPU implementation
 */
MemorySubsystem::MemorySubsystem(CPU6510Impl& cpu) : cpu_(cpu) {
    reset();
}

/**
 * @brief Reset the memory subsystem
 *
 * Initializes tracking arrays and clears memory access flags.
 */
void MemorySubsystem::reset() {
    lastWriteToAddr_.resize(65536, 0);
    writeSourceInfo_.resize(65536);

    // Reset memory access tracking
    std::fill(memoryAccess_.begin(), memoryAccess_.end(), 0);

    // Memory contents are not reset to allow loading programs
}

/**
 * @brief Read a byte from memory with tracking
 *
 * @param addr Memory address to read from
 * @return The byte at the specified address
 */
u8 MemorySubsystem::readMemory(u16 addr) {
    markMemoryAccess(addr, MemoryAccessFlag::Read);
    return memory_[addr];
}

/**
 * @brief Write a byte to memory without tracking
 *
 * @param addr Memory address to write to
 * @param value Byte value to write
 */
void MemorySubsystem::writeByte(u16 addr, u8 value) {
    memory_[addr] = value;
}

/**
 * @brief Write a byte to memory with tracking
 *
 * @param addr Memory address to write to
 * @param value Byte value to write
 * @param sourcePC Program counter of the instruction doing the write
 */
void MemorySubsystem::writeMemory(u16 addr, u8 value, u16 sourcePC) {
    markMemoryAccess(addr, MemoryAccessFlag::Write);
    memory_[addr] = value;
    lastWriteToAddr_[addr] = sourcePC;
}

/**
 * @brief Copy multiple bytes to memory
 *
 * @param start Starting memory address
 * @param data Span of bytes to copy
 */
void MemorySubsystem::copyMemoryBlock(u16 start, std::span<const u8> data) {
    for (size_t i = 0; i < data.size(); ++i) {
        const auto idx = static_cast<u16>(i);
        if (start + idx < memory_.size()) {
            memory_[start + idx] = data[i];
        }
    }
}

/**
 * @brief Mark a memory access type
 *
 * @param addr Memory address
 * @param flag Type of access
 */
void MemorySubsystem::markMemoryAccess(u16 addr, MemoryAccessFlag flag) {
    memoryAccess_[addr] |= static_cast<u8>(flag);
}

/**
 * @brief Get direct access to a memory byte
 *
 * @param addr Memory address
 * @return The byte at the specified address
 */
u8 MemorySubsystem::getMemoryAt(u16 addr) const {
    return memory_[addr];
}

/**
 * @brief Dump memory access information to a file
 *
 * @param filename Path to the output file
 */
void MemorySubsystem::dumpMemoryAccess(const std::string& filename) {
    std::ofstream file(filename);
    if (!file) {
        return;
    }

    for (u32 addr = 0; addr < 65536; ++addr) {
        if (memoryAccess_[addr] != 0) {
            file << std::hex << std::setw(4) << std::setfill('0') << addr << ": ";

            file << ((memoryAccess_[addr] & static_cast<u8>(MemoryAccessFlag::Execute)) ? "E" : ".");
            file << ((memoryAccess_[addr] & static_cast<u8>(MemoryAccessFlag::OpCode)) ? "1" : ".");
            file << ((memoryAccess_[addr] & static_cast<u8>(MemoryAccessFlag::Read)) ? "R" : ".");
            file << ((memoryAccess_[addr] & static_cast<u8>(MemoryAccessFlag::Write)) ? "W" : ".");
            file << ((memoryAccess_[addr] & static_cast<u8>(MemoryAccessFlag::JumpTarget)) ? "J" : ".");

            file << "\n";
        }
    }
}

/**
 * @brief Get a span of CPU memory
 *
 * @return Span of memory data
 */
std::span<const u8> MemorySubsystem::getMemory() const {
    return std::span<const u8>(memory_.data(), memory_.size());
}

/**
 * @brief Get a span of memory access flags
 *
 * @return Span of memory access flags
 */
std::span<const u8> MemorySubsystem::getMemoryAccess() const {
    return std::span<const u8>(memoryAccess_.data(), memoryAccess_.size());
}

/**
 * @brief Get the program counter of the last instruction that wrote to an address
 *
 * @param addr Memory address to check
 * @return Program counter of the last instruction that wrote to the address
 */
u16 MemorySubsystem::getLastWriteTo(u16 addr) const {
    return lastWriteToAddr_[addr];
}

/**
 * @brief Get the full last-write-to-address tracking vector
 *
 * @return Reference to the vector containing PC values of last write to each memory address
 */
const std::vector<u16>& MemorySubsystem::getLastWriteToAddr() const {
    return lastWriteToAddr_;
}

/**
 * @brief Get the source information for a memory write
 *
 * @param addr Memory address to check
 * @return Register source information for the last write to the address
 */
RegisterSourceInfo MemorySubsystem::getWriteSourceInfo(u16 addr) const {
    return writeSourceInfo_[addr];
}

/**
 * @brief Set write source info
 *
 * @param addr Memory address
 * @param info Register source info
 */
void MemorySubsystem::setWriteSourceInfo(u16 addr, const RegisterSourceInfo& info) {
    writeSourceInfo_[addr] = info;

    // Update data flow if this is a memory-to-memory copy and not a self-reference
    if (info.type == RegisterSourceInfo::SourceType::Memory && info.address != addr) {
        u16 sourceAddr = info.address;

        // Check if this source is already recorded
        auto& sources = dataFlow_.memoryWriteSources[addr];
        bool alreadyExists = false;

        for (const auto& existingSource : sources) {
            if (existingSource == sourceAddr) {
                alreadyExists = true;
                break;
            }
        }

        // Only add if it's not already in the list
        if (!alreadyExists) {
            sources.push_back(sourceAddr);
        }
    }
}

const MemoryDataFlow& MemorySubsystem::getMemoryDataFlow() const {
    return dataFlow_;
}
