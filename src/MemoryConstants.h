// MemoryConstants.h
#pragma once

#include "Common.h"
#include <array>
#include <optional>

namespace sidwinder {

    /**
     * @brief Tracks which 256-byte pages are used in C64 memory
     *
     * Used to find free pages for placing generated code (e.g., save/restore routines)
     * without conflicting with the SID data or other used memory.
     */
    class MemoryPageTracker {
    public:
        static constexpr int NUM_PAGES = 256;  // 256 pages of 256 bytes each = 64KB

        MemoryPageTracker() {
            pages_.fill(false);
            // Mark I/O area as always used ($D000-$DFFF)
            for (int page = 0xD0; page <= 0xDF; ++page) {
                pages_[page] = true;
            }
            // Mark interrupt vectors as used ($FF00-$FFFF includes vectors)
            pages_[0xFF] = true;
        }

        /**
         * @brief Mark a memory range as used
         * @param startAddr Start address of the range
         * @param size Size of the range in bytes
         */
        void markRangeUsed(u16 startAddr, u16 size) {
            if (size == 0) return;
            u16 endAddr = startAddr + size - 1;
            // Handle wraparound (if startAddr + size > 0xFFFF)
            if (endAddr < startAddr) endAddr = 0xFFFF;

            int startPage = startAddr >> 8;
            int endPage = endAddr >> 8;
            for (int page = startPage; page <= endPage; ++page) {
                pages_[page] = true;
            }
        }

        /**
         * @brief Mark a single page as used
         * @param page Page number (0-255)
         */
        void markPageUsed(int page) {
            if (page >= 0 && page < NUM_PAGES) {
                pages_[page] = true;
            }
        }

        /**
         * @brief Check if a page is used
         * @param page Page number (0-255)
         * @return true if the page is used
         */
        bool isPageUsed(int page) const {
            return page >= 0 && page < NUM_PAGES && pages_[page];
        }

        /**
         * @brief Find a contiguous block of free pages
         * @param numPages Number of contiguous pages needed
         * @param preferHighMemory If true, search from high memory down; otherwise from low memory up
         * @return Start address of the free block, or std::nullopt if not found
         *
         * Searches for free pages, avoiding zero page, stack, and the I/O area.
         */
        std::optional<u16> findFreePages(int numPages, bool preferHighMemory = true) const {
            if (numPages <= 0 || numPages > NUM_PAGES) return std::nullopt;

            if (preferHighMemory) {
                // Search from high memory down (but before I/O area at $D0)
                // Start at $CF and work down, or start at $FE and work down
                // Actually, let's start just before I/O ($CF) and work down
                for (int startPage = 0xCF - numPages + 1; startPage >= 0x02; --startPage) {
                    if (arePagesAvailable(startPage, numPages)) {
                        return static_cast<u16>(startPage << 8);
                    }
                }
                // Also try after I/O area ($E0-$FE) if needed
                for (int startPage = 0xFE - numPages + 1; startPage >= 0xE0; --startPage) {
                    if (arePagesAvailable(startPage, numPages)) {
                        return static_cast<u16>(startPage << 8);
                    }
                }
            } else {
                // Search from low memory up (avoiding zero page and stack)
                for (int startPage = 0x02; startPage <= 0xCF - numPages + 1; ++startPage) {
                    if (arePagesAvailable(startPage, numPages)) {
                        return static_cast<u16>(startPage << 8);
                    }
                }
            }

            return std::nullopt;
        }

        /**
         * @brief Find a free address for storing a specific number of bytes
         * @param numBytes Number of bytes needed
         * @param preferHighMemory If true, prefer high memory locations
         * @return Start address for the storage, or std::nullopt if not found
         */
        std::optional<u16> findFreeSpace(int numBytes, bool preferHighMemory = true) const {
            int numPages = (numBytes + 255) / 256;  // Round up to full pages
            return findFreePages(numPages, preferHighMemory);
        }

    private:
        std::array<bool, NUM_PAGES> pages_;

        bool arePagesAvailable(int startPage, int numPages) const {
            for (int i = 0; i < numPages; ++i) {
                int page = startPage + i;
                if (page < 0 || page >= NUM_PAGES || pages_[page]) {
                    return false;
                }
            }
            return true;
        }
    };

    /**
     * @brief Central location for C64 memory map constants
     *
     * Eliminates magic numbers scattered throughout the codebase
     */
    struct MemoryConstants {
        // Zero Page
        static constexpr u16 ZERO_PAGE_START = 0x0000;
        static constexpr u16 ZERO_PAGE_END = 0x00FF;

        // Stack
        static constexpr u16 STACK_BASE = 0x0100;
        static constexpr u16 STACK_END = 0x01FF;
        static constexpr u8 STACK_INIT_VALUE = 0xFD;

        // I/O Area
        static constexpr u16 VIC_START = 0xD000;
        static constexpr u16 VIC_END = 0xD3FF;

        static constexpr u16 SID_START = 0xD400;
        static constexpr u16 SID_END = 0xD7FF;
        static constexpr u16 SID_SIZE = 0x20;  // 32 bytes per SID
        static constexpr u16 SID_REGISTER_COUNT = 0x19;  // 25 registers per SID

        static constexpr u16 COLOR_RAM_START = 0xD800;
        static constexpr u16 COLOR_RAM_END = 0xDBFF;

        static constexpr u16 CIA1_START = 0xDC00;
        static constexpr u16 CIA1_END = 0xDCFF;
        static constexpr u16 CIA1_TIMER_LO = 0xDC04;
        static constexpr u16 CIA1_TIMER_HI = 0xDC05;

        static constexpr u16 CIA2_START = 0xDD00;
        static constexpr u16 CIA2_END = 0xDDFF;

        static constexpr u16 IO_AREA_START = 0xD000;
        static constexpr u16 IO_AREA_END = 0xDFFF;

        // Interrupt vectors
        static constexpr u16 IRQ_VECTOR = 0xFFFE;
        static constexpr u16 RESET_VECTOR = 0xFFFC;
        static constexpr u16 NMI_VECTOR = 0xFFFA;

        // Memory size
        static constexpr u32 MEMORY_SIZE = 0x10000;  // 64KB

        // Helper functions
        static bool isZeroPage(u16 addr) {
            return addr <= ZERO_PAGE_END;
        }

        static bool isStack(u16 addr) {
            return addr >= STACK_BASE && addr <= STACK_END;
        }

        static bool isSID(u16 addr) {
            return addr >= SID_START && addr <= SID_END;
        }

        static bool isVIC(u16 addr) {
            return addr >= VIC_START && addr <= VIC_END;
        }

        static bool isCIA1(u16 addr) {
            return addr >= CIA1_START && addr <= CIA1_END;
        }

        static bool isCIA2(u16 addr) {
            return addr >= CIA2_START && addr <= CIA2_END;
        }

        static bool isCIA(u16 addr) {
            return isCIA1(addr) || isCIA2(addr);
        }

        static bool isIO(u16 addr) {
            return addr >= IO_AREA_START && addr <= IO_AREA_END;
        }

        static u16 getSIDBase(u16 addr) {
            if (!isSID(addr)) return 0;
            return addr & ~(SID_SIZE - 1);  // Align to 32-byte boundary
        }

        static u8 getSIDRegister(u16 addr) {
            if (!isSID(addr)) return 0xFF;
            return addr & (SID_SIZE - 1);  // Get offset within SID
        }
    };

} // namespace sidwinder