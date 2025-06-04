// MemoryConstants.h
#pragma once

#include "Common.h"

namespace sidwinder {

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