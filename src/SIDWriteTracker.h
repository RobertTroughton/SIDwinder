// SIDWriteTracker.h
#pragma once

#include "Common.h"
#include <vector>
#include <map>
#include <array>
#include <string>

namespace sidwinder {

    class SIDWriteTracker {
    public:
        SIDWriteTracker();

        // Record a SID register write
        void recordWrite(u16 addr, u8 value);

        // Process frame boundary
        void endFrame();

        // Analyze recorded writes to find a consistent pattern
        bool analyzePattern();

        // Reset the tracker state
        void reset();

        // Get the detected write order
        const std::vector<u8>& getWriteOrder() const { return writeOrder_; }

        // Get a string representation of the write order for ASM
        std::string getWriteOrderString() const;

        // Check if we found a consistent pattern
        bool hasConsistentPattern() const { return consistentPattern_; }

        // Get statistics about register usage
        std::string getRegisterUsageStats() const;

    private:
        // Store write sequences per frame
        std::vector<std::vector<u8>> frameSequences_;

        // Current frame's sequence
        std::vector<u8> currentFrameSequence_;

        // The detected consistent order (if any)
        std::vector<u8> writeOrder_;

        // Track which registers are written to
        std::array<bool, 0x19> registersUsed_ = { false };

        // Count writes to each register
        std::array<int, 0x19> registerWriteCounts_ = { 0 };

        // Whether we found a consistent pattern
        bool consistentPattern_ = false;

        // Number of total frames processed
        int frameCount_ = 0;
    };

} // namespace sidwinder