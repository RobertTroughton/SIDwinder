// SIDPatternFinder.cpp
#include "SIDPatternFinder.h"
#include "SIDwinderUtils.h"
#include "MemoryConstants.h"

#include <sstream>
#include <functional>
#include <algorithm>
#include <unordered_map>

namespace sidwinder {

    SIDPatternFinder::SIDPatternFinder() {
        reset();
    }

    void SIDPatternFinder::reset() {
        frames_.clear();
        currentFrame_.clear();
        patternPeriod_ = 0;
        initFramesCount_ = 0;
        patternFound_ = false;
    }

    void SIDPatternFinder::recordWrite(u16 addr, u8 value) {
        if (MemoryConstants::isSID(addr)) {
            bool alreadyWritten = false;
            for (const auto& write : currentFrame_) {
                if (write.addr == addr) {
                    alreadyWritten = true;
                    break;
                }
            }
            if (!alreadyWritten) {
                currentFrame_.push_back({ addr, value });
            }
        }
    }

    void SIDPatternFinder::endFrame() {
        // Only add frames that have some SID writes
        if (!currentFrame_.empty()) {
            frames_.push_back(currentFrame_);
            currentFrame_.clear();
        }
    }

    bool SIDPatternFinder::analyzePattern(int maxInitFrames) {
        // Need a minimum number of frames to detect patterns
        if (frames_.size() < 10) {
            return false;
        }

        // Try different numbers of initialization frames
        for (size_t initFrames = 0; initFrames <= std::min(static_cast<size_t>(maxInitFrames), frames_.size() / 2); initFrames++) {
            size_t period = findSmallestPeriod(initFrames);

            // If we found a repeating pattern
            if (period > 0 && period < (frames_.size() - initFrames) / 2) {
                patternPeriod_ = period;
                initFramesCount_ = initFrames;
                patternFound_ = true;
                return true;
            }
        }

        return false;
    }

    size_t SIDPatternFinder::hashFrame(const std::vector<SIDWrite>& frame) const {
        std::size_t hash = 0;

        // Sort the writes by address for consistent hashing
        std::vector<SIDWrite> sortedWrites = frame;
        std::sort(sortedWrites.begin(), sortedWrites.end(),
            [](const SIDWrite& a, const SIDWrite& b) { return a.addr < b.addr; });

        // Hash each write
        for (const auto& write : sortedWrites) {
            hash = hash * 31 + write.addr;
            hash = hash * 31 + write.value;
        }

        return hash;
    }

    bool SIDPatternFinder::framesEqual(const std::vector<SIDWrite>& frame1, const std::vector<SIDWrite>& frame2) const {
        if (frame1.size() != frame2.size()) {
            return false;
        }

        // Create sorted copies for comparison
        std::vector<SIDWrite> sorted1 = frame1;
        std::vector<SIDWrite> sorted2 = frame2;

        std::sort(sorted1.begin(), sorted1.end(),
            [](const SIDWrite& a, const SIDWrite& b) { return a.addr < b.addr; });
        std::sort(sorted2.begin(), sorted2.end(),
            [](const SIDWrite& a, const SIDWrite& b) { return a.addr < b.addr; });

        // Compare each write
        for (size_t i = 0; i < sorted1.size(); i++) {
            if (!(sorted1[i].addr == sorted2[i].addr && sorted1[i].value == sorted2[i].value)) {
                return false;
            }
        }

        return true;
    }

    size_t SIDPatternFinder::findSmallestPeriod(size_t initFrames) const {
        // Compute hashes for all frames after initialization
        std::vector<size_t> frameHashes;
        for (size_t i = initFrames; i < frames_.size(); i++) {
            frameHashes.push_back(hashFrame(frames_[i]));
        }

        // Look for repeating patterns in the hash values
        const size_t maxPeriod = frameHashes.size() / 2;

        for (size_t period = 1; period <= maxPeriod; period++) {
            // Check if this period is valid
            if (verifyPattern(initFrames, period)) {
                return period;
            }
        }

        // No pattern found
        return 0;
    }

    bool SIDPatternFinder::verifyPattern(size_t initFrames, size_t period) const {
        if (period == 0 || initFrames + period * 2 > frames_.size()) {
            return false;
        }

        // Check if frames repeat with this period
        for (size_t i = initFrames; i + period < frames_.size(); i++) {
            if (!framesEqual(frames_[i], frames_[i + period])) {
                return false;
            }
        }

        return true;
    }

    std::string SIDPatternFinder::getPatternDescription() const {
        std::stringstream ss;

        if (!patternFound_) {
            ss << "No repeating pattern detected in " << frames_.size() << " frames of SID register writes.";
            return ss.str();
        }

        ss << "Detected repeating pattern:\n";
        ss << "- " << initFramesCount_ << " initialization frame(s)\n";
        ss << "- Pattern repeats every " << patternPeriod_ << " frame(s)\n";
        ss << "- Total frames analyzed: " << frames_.size() << "\n";

        return ss.str();
    }

} // namespace sidwinder