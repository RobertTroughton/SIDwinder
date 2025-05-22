#pragma once

#include "cpu6510.h"
#include <array>
#include <span>
#include <vector>
#include <fstream>

// Forward declaration of implementation class
class CPU6510Impl;

/**
 * @brief Memory subsystem for the CPU6510
 *
 * Handles all memory operations and tracking for the CPU.
 */
class MemorySubsystem {
public:
    /**
     * @brief Constructor
     *
     * @param cpu Reference to the CPU implementation
     */
    explicit MemorySubsystem(CPU6510Impl& cpu);

    /**
     * @brief Reset the memory subsystem
     */
    void reset();

    /**
     * @brief Read a byte from memory with tracking
     *
     * @param addr Memory address to read from
     * @return The byte at the specified address
     */
    u8 readMemory(u16 addr);

    /**
     * @brief Write a byte to memory without tracking
     *
     * @param addr Memory address to write to
     * @param value Byte value to write
     */
    void writeByte(u16 addr, u8 value);

    /**
     * @brief Write a byte to memory with tracking
     *
     * @param addr Memory address to write to
     * @param value Byte value to write
     * @param sourcePC Program counter of the instruction doing the write
     */
    void writeMemory(u16 addr, u8 value, u16 sourcePC);

    /**
     * @brief Copy multiple bytes to memory
     *
     * @param start Starting memory address
     * @param data Span of bytes to copy
     */
    void copyMemoryBlock(u16 start, std::span<const u8> data);

    /**
     * @brief Mark a memory access type
     *
     * @param addr Memory address
     * @param flag Type of access
     */
    void markMemoryAccess(u16 addr, MemoryAccessFlag flag);

    /**
     * @brief Get direct access to a memory byte
     *
     * @param addr Memory address
     * @return The byte at the specified address
     */
    u8 getMemoryAt(u16 addr) const;

    /**
     * @brief Dump memory access information to a file
     *
     * @param filename Path to the output file
     */
    void dumpMemoryAccess(const std::string& filename);

    /**
     * @brief Get a span of CPU memory
     *
     * @return Span of memory data
     */
    std::span<const u8> getMemory() const;

    /**
     * @brief Get a span of memory access flags
     *
     * @return Span of memory access flags
     */
    std::span<const u8> getMemoryAccess() const;

    /**
     * @brief Get the program counter of the last instruction that wrote to an address
     *
     * @param addr Memory address to check
     * @return Program counter of the last instruction that wrote to the address
     */
    u16 getLastWriteTo(u16 addr) const;

    /**
     * @brief Get the full last-write-to-address tracking vector
     *
     * @return Reference to the vector containing PC values of last write to each memory address
     */
    const std::vector<u16>& getLastWriteToAddr() const;

    /**
     * @brief Get the source information for a memory write
     *
     * @param addr Memory address to check
     * @return Register source information for the last write to the address
     */
    RegisterSourceInfo getWriteSourceInfo(u16 addr) const;

    /**
     * @brief Set write source info
     *
     * @param addr Memory address
     * @param info Register source info
     */
    void setWriteSourceInfo(u16 addr, const RegisterSourceInfo& info);

    /**
     * @brief Get the memory data flow tracking information
     * @return Reference to the memory data flow tracking
     */
    const MemoryDataFlow& getMemoryDataFlow() const;

private:
    // Reference to CPU implementation
    CPU6510Impl& cpu_;

    // Memory array (64KB)
    std::array<u8, 65536> memory_;

    // Memory access tracking
    std::array<u8, 65536> memoryAccess_;

    // Track the source of writes to memory
    std::vector<u16> lastWriteToAddr_;
    std::vector<RegisterSourceInfo> writeSourceInfo_;

    MemoryDataFlow dataFlow_;  // Memory data flow tracking

};