// SIDPatternFinder.h
#pragma once

#include "Common.h"
#include <vector>
#include <string>
#include <optional>

namespace sidwinder {

    /**
     * @class SIDPatternFinder
     * @brief Analyzes SID register writes to find repeating patterns
     *
     * This class tracks SID register writes per frame and identifies when patterns start
     * repeating, accounting for possible initialization frames at the beginning.
     */
    class SIDPatternFinder {
    public:
        /**
         * @brief Constructor
         */
        SIDPatternFinder();

        /**
         * @brief Reset the pattern finder to its initial state
         */
        void reset();

        /**
         * @brief Record a SID register write
         * @param addr SID register address
         * @param value Value written to the register
         */
        void recordWrite(u16 addr, u8 value);

        /**
         * @brief Mark the end of a frame
         */
        void endFrame();

        /**
         * @brief Analyze the recorded frames to find repeating patterns
         * @param maxInitFrames Maximum number of initialization frames to consider
         * @return True if a pattern was found
         */
        bool analyzePattern(int maxInitFrames = 15);

        /**
         * @brief Get the detected pattern period (number of frames per repetition)
         * @return Pattern period, or 0 if no pattern detected
         */
        size_t getPatternPeriod() const { return patternPeriod_; }

        /**
         * @brief Get the number of initialization frames detected
         * @return Number of initialization frames, or 0 if no pattern detected
         */
        size_t getInitFramesCount() const { return initFramesCount_; }

        /**
         * @brief Get a string representation of the pattern analysis
         * @return Description of the pattern
         */
        std::string getPatternDescription() const;

    private:
        // Helper struct to represent a single SID register write
        struct SIDWrite {
            u16 addr;
            u8 value;

            bool operator==(const SIDWrite& other) const {
                return addr == other.addr && value == other.value;
            }
        };

        // Vector of frames, each containing a vector of SID writes
        std::vector<std::vector<SIDWrite>> frames_;

        // Current frame's writes
        std::vector<SIDWrite> currentFrame_;

        // Detected pattern information
        size_t patternPeriod_ = 0;
        size_t initFramesCount_ = 0;
        bool patternFound_ = false;

        /**
         * @brief Calculate hash for a frame (for faster comparison)
         * @param frame Vector of SID writes in a frame
         * @return Hash value
         */
        size_t hashFrame(const std::vector<SIDWrite>& frame) const;

        /**
         * @brief Check if frames are identical
         * @param frame1 First frame
         * @param frame2 Second frame
         * @return True if frames contain identical SID writes
         */
        bool framesEqual(const std::vector<SIDWrite>& frame1, const std::vector<SIDWrite>& frame2) const;

        /**
         * @brief Find the smallest repeating pattern with given init frames
         * @param initFrames Number of initialization frames to skip
         * @return Period of the pattern, or 0 if none found
         */
        size_t findSmallestPeriod(size_t initFrames) const;

        /**
         * @brief Verify that a potential pattern repeats throughout the data
         * @param initFrames Number of initialization frames to skip
         * @param period Potential pattern period to verify
         * @return True if the pattern is valid
         */
        bool verifyPattern(size_t initFrames, size_t period) const;
    };

} // namespace sidwinder