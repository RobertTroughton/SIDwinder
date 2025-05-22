// SIDWriteTracker.cpp
#include "SIDWriteTracker.h"
#include "SIDwinderUtils.h"
#include <algorithm>
#include <sstream>
#include <set>
#include <iomanip>

namespace sidwinder {

    SIDWriteTracker::SIDWriteTracker() {
    }

    void SIDWriteTracker::recordWrite(u16 addr, u8 value) {
        // Extract the register number (offset from SID base)
        u8 reg = addr & 0x1F;

        // Only track actual SID registers (0x00-0x18)
        if (reg <= 0x18) {
            // Record this register in the current frame sequence if not already there
            if (std::find(currentFrameSequence_.begin(), currentFrameSequence_.end(), reg)
                == currentFrameSequence_.end()) {
                currentFrameSequence_.push_back(reg);
            }

            // Mark this register as used
            registersUsed_[reg] = true;

            // Increment write count for this register
            registerWriteCounts_[reg]++;
        }
    }

    void SIDWriteTracker::endFrame() {
        // If we have writes in this frame, add to the sequence list
        if (!currentFrameSequence_.empty()) {
            frameSequences_.push_back(currentFrameSequence_);
            currentFrameSequence_.clear();
            frameCount_++;
        }
    }

    void SIDWriteTracker::reset() {
        frameSequences_.clear();
        currentFrameSequence_.clear();
        writeOrder_.clear();
        consistentPattern_ = false;
        frameCount_ = 0;

        // Reset register usage tracking
        std::fill(registersUsed_.begin(), registersUsed_.end(), false);
        std::fill(registerWriteCounts_.begin(), registerWriteCounts_.end(), 0);
    }

    bool SIDWriteTracker::analyzePattern() {
        // Need at least a few frames to detect a pattern
        if (frameSequences_.size() < 10) {
            return false;
        }

        // Check if all frames follow the same pattern
        bool samePattern = true;
        const auto& firstSeq = frameSequences_[0];

        // Check the pattern from frame 10 onwards (skip initialization frames)
        for (size_t i = 10; i < frameSequences_.size(); i++) {
            if (frameSequences_[i] != firstSeq) {
                samePattern = false;
                break;
            }
        }

        // If all frames after the tenth have the same pattern, we have a consistent order
        if (samePattern && !firstSeq.empty()) {
            writeOrder_ = firstSeq;
            consistentPattern_ = true;
            return true;
        }

        // No consistent pattern found, see if we can derive one from register usage
        std::set<u8> usedRegs;
        for (u8 i = 0; i <= 0x18; i++) {
            if (registersUsed_[i]) {
                usedRegs.insert(i);
            }
        }

        // If registers are used, create an ordered list
        if (!usedRegs.empty()) {
            writeOrder_.clear();
            writeOrder_.insert(writeOrder_.end(), usedRegs.begin(), usedRegs.end());
            return true;
        }

        return false;
    }

    std::string SIDWriteTracker::getWriteOrderString() const {
        std::stringstream ss;

        // Return empty string if no order found
        if (writeOrder_.empty()) {
            return ".var SIDRegisterCount = 0\n.var SIDRegisterOrder = List()\n";
        }

        // Create a List in KickAssembler
        ss << ".var SIDRegisterOrder = List()";

        for (size_t i = 0; i < writeOrder_.size(); i++) {
            ss << ".add($" << util::byteToHex(writeOrder_[i]) << ")";
        }

        ss << "\n.var SIDRegisterCount = SIDRegisterOrder.size()\n\n";

        return ss.str();
    }

    std::string SIDWriteTracker::getRegisterUsageStats() const {
        std::stringstream ss;

        ss << "SID Register Usage Statistics:\n";
        ss << "-----------------------------\n";
        ss << "Total frames analyzed: " << frameCount_ << "\n\n";

        ss << "Register | Used | Write Count | Avg Writes/Frame\n";
        ss << "---------+------+-------------+----------------\n";

        for (u8 i = 0; i <= 0x18; i++) {
            if (registersUsed_[i]) {
                float avgWrites = frameCount_ > 0 ?
                    static_cast<float>(registerWriteCounts_[i]) / frameCount_ : 0;

                ss << "$" << util::byteToHex(i) << "     | Yes  | "
                    << std::setw(11) << registerWriteCounts_[i] << " | "
                    << std::fixed << std::setprecision(2) << avgWrites << "\n";
            }
        }

        return ss.str();
    }

} // namespace sidwinder