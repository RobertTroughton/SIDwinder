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
         * @brief Constructor
         */
        SIDShadowRegisterFinder();

        /**
         * @brief Reset the finder to initial state
         */
        void reset();

        /**
         * @brief Record a SID register write
         * @param addr SID register address
         * @param value Value written
         */
        void recordSIDWrite(u16 addr, u8 value);

        /**
         * @brief Check memory for shadow registers after a play routine call
         * @param memory CPU memory to scan
         */
        void checkMemoryForShadowRegisters(std::span<const u8> memory);

        /**
         * @brief Generate the shadow register data for HelpfulData.asm
         * @return KickAssembler code to append to HelpfulData.asm
         */
        std::string generateHelpfulDataSection() const;

    private:
        // Current SID register values
        std::array<u8, 0x19> currentSIDValues_;

        // Current addresses that might be a shadow for each SID register
        std::array<std::vector<u16>, 0x19> possibleShadows_;

        // Frame counter for tracking when to start checking
        int frameCount_ = 0;
        static constexpr int WARMUP_FRAMES = 3;  // Skip first frames
    };

} // namespace sidwinder