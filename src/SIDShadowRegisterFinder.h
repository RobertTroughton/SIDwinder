// SIDShadowRegisterFinder.h
#pragma once

#include "Common.h"

#include <array>
#include <map>
#include <optional>
#include <set>
#include <span>
#include <vector>

namespace sidwinder {

    /**
     * @class SIDShadowRegisterFinder
     * @brief Finds memory locations that consistently mirror SID register values
     *
     * This class tracks memory locations that always contain the same values as
     * written to SID registers, allowing visualizers to read these "shadow registers"
     * instead of the write-only SID registers.
     */
    class SIDShadowRegisterFinder {
    public:
        /**
         * @struct ShadowRegisterInfo
         * @brief Information about a potential shadow register location
         */
        struct ShadowRegisterInfo {
            u16 address;              ///< Memory address
            u8 sidRegister;           ///< SID register it mirrors ($00-$18)
            int matchCount = 0;       ///< Number of times it matched
            int totalChecks = 0;      ///< Total number of checks performed
            bool isReliable = false;  ///< Whether this is a reliable shadow register

            float getReliability() const {
                return totalChecks > 0 ? (float)matchCount / totalChecks : 0.0f;
            }
        };

        /**
         * @brief Constructor
         */
        SIDShadowRegisterFinder();

        /**
         * @brief Reset the finder to initial state
         */
        void reset();

        /**
         * @brief Record a SID register write
         * @param addr SID register address ($D400-$D418)
         * @param value Value written
         */
        void recordSIDWrite(u16 addr, u8 value);

        /**
         * @brief Check memory for shadow registers after a play routine call
         * @param memory CPU memory to scan
         */
        void checkMemoryForShadowRegisters(std::span<const u8> memory);

        /**
         * @brief Analyze results and determine reliable shadow registers
         * @param reliabilityThreshold Minimum reliability percentage (0.95 = 95%)
         */
        void analyzeResults(float reliabilityThreshold = 0.95f);

        /**
         * @brief Get shadow register address for a specific SID register
         * @param sidRegister SID register offset ($00-$18)
         * @return Shadow register address, or 0xFFFF if none found
         */
        u16 getShadowRegisterForSID(u8 sidRegister) const;

        /**
         * @brief Get count of shadow registers found
         * @return Number of SID registers that have shadow registers
         */
        int getShadowRegisterCount() const;

        /**
         * @brief Generate the shadow register data for HelpfulData.asm
         * @return KickAssembler code to append to HelpfulData.asm
         */
        std::string generateHelpfulDataSection() const;

        /**
         * @brief Get a summary of findings
         * @return Human-readable summary
         */
        std::string getSummary() const;

    private:
        // Current SID register values
        std::array<u8, 0x19> currentSIDValues_;
        std::array<bool, 0x19> sidRegisterActive_;  // Whether we've seen non-zero

        // Map from SID register to potential shadow registers
        // Key: SID register offset, Value: map of memory addresses to info
        std::map<u8, std::map<u16, ShadowRegisterInfo>> potentialShadowRegisters_;

        // Final shadow register mapping (one per SID register)
        std::array<u16, 0x19> shadowRegisterMap_;  // 0xFFFF = no shadow register

        // Frame counter for tracking when to start checking
        int frameCount_ = 0;
        static constexpr int WARMUP_FRAMES = 10;  // Skip first frames

        // Memory ranges to exclude from search (SID, I/O, etc.)
        static constexpr u16 EXCLUDE_RANGES[][2] = {
            {0xD000, 0xDFFF},  // VIC, SID, Color, CIA etc
        };

        /**
         * @brief Check if an address should be excluded from search
         * @param addr Address to check
         * @return True if address should be excluded
         */
        bool isExcludedAddress(u16 addr) const;
    };

} // namespace sidwinder