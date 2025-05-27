// SIDShadowRegisterFinder.cpp
#include "SIDShadowRegisterFinder.h"
#include "SIDwinderUtils.h"
#include <algorithm>
#include <sstream>
#include <iomanip>

namespace sidwinder {

    SIDShadowRegisterFinder::SIDShadowRegisterFinder() {
        reset();
    }

    void SIDShadowRegisterFinder::reset() {
        currentSIDValues_.fill(0);
        sidRegisterActive_.fill(false);
        potentialShadowRegisters_.clear();
        shadowRegisterMap_.fill(0xFFFF);  // 0xFFFF indicates no shadow register
        frameCount_ = 0;
    }

    void SIDShadowRegisterFinder::recordSIDWrite(u16 addr, u8 value) {
        // Only track actual SID registers ($D400-$D418)
        if (addr >= 0xD400 && addr <= 0xD418) {
            u8 reg = addr & 0x1F;
            currentSIDValues_[reg] = value;
            sidRegisterActive_[reg] = true;
        }
    }

    void SIDShadowRegisterFinder::checkMemoryForShadowRegisters(std::span<const u8> memory) {
        frameCount_++;

        // Skip warmup frames AND the first play() call
        if (frameCount_ <= WARMUP_FRAMES) {  // Changed from < to <= to skip one more frame
            return;
        }

        // For each SID register (including those never written to)
        for (u8 reg = 0; reg <= 0x18; reg++) {
            if (!sidRegisterActive_[reg]) {
                continue;  // Skip registers we haven't seen written yet
            }

            u8 targetValue = currentSIDValues_[reg];
            auto& candidateMap = potentialShadowRegisters_[reg];

            // First pass: check existing candidates
            std::vector<u16> toRemove;
            for (auto& [addr, info] : candidateMap) {
                info.totalChecks++;
                if (memory[addr] == targetValue) {
                    info.matchCount++;
                }
                else {
                    // If reliability drops too low, mark for removal
                    if (info.getReliability() < 0.5f && info.totalChecks > 100) {
                        toRemove.push_back(addr);
                    }
                }
            }

            // Remove unreliable candidates
            for (u16 addr : toRemove) {
                candidateMap.erase(addr);
            }

            // Second pass: search for new candidates (only in early frames)
            if (frameCount_ < 100 && targetValue != 0) {  // Only search early on
                // Scan memory in chunks for efficiency
                for (u32 addr = 0; addr < 0x10000; addr += 256) {
                    // Quick check if this 256-byte page contains our value
                    bool foundInPage = false;
                    for (int i = 0; i < 256 && (addr + i) < 0x10000; i++) {
                        if (memory[addr + i] == targetValue) {
                            foundInPage = true;
                            break;
                        }
                    }

                    if (foundInPage) {
                        // Detailed scan of this page
                        for (int i = 0; i < 256 && (addr + i) < 0x10000; i++) {
                            u32 checkAddr = addr + i;

                            // Skip excluded addresses and already tracked addresses
                            if (isExcludedAddress(checkAddr) ||
                                candidateMap.find(checkAddr) != candidateMap.end()) {
                                continue;
                            }

                            if (memory[checkAddr] == targetValue) {
                                // Found a new candidate!
                                ShadowRegisterInfo info;
                                info.address = checkAddr;
                                info.sidRegister = reg;
                                info.matchCount = 1;
                                info.totalChecks = 1;
                                candidateMap[checkAddr] = info;
                            }
                        }
                    }
                }
            }
        }
    }

    bool SIDShadowRegisterFinder::isExcludedAddress(u16 addr) const {
        for (auto& range : EXCLUDE_RANGES) {
            if (addr >= range[0] && addr <= range[1]) {
                return true;
            }
        }
        return false;
    }

    void SIDShadowRegisterFinder::analyzeResults(float reliabilityThreshold) {
        // Reset the map
        shadowRegisterMap_.fill(0xFFFF);

        for (const auto& [reg, candidates] : potentialShadowRegisters_) {
            // Find the best candidate for this register
            u16 bestAddress = 0xFFFF;
            float bestReliability = 0.0f;

            for (const auto& [addr, info] : candidates) {
                // Need sufficient samples and high reliability
                if (info.totalChecks >= 50) {
                    float reliability = info.getReliability();
                    if (reliability >= reliabilityThreshold && reliability > bestReliability) {
                        bestReliability = reliability;
                        bestAddress = addr;
                    }
                }
            }

            if (bestAddress != 0xFFFF) {
                shadowRegisterMap_[reg] = bestAddress;
            }
        }
    }

    u16 SIDShadowRegisterFinder::getShadowRegisterForSID(u8 sidRegister) const {
        if (sidRegister <= 0x18) {
            return shadowRegisterMap_[sidRegister];
        }
        return 0xFFFF;
    }

    int SIDShadowRegisterFinder::getShadowRegisterCount() const {
        int count = 0;
        for (u8 reg = 0; reg <= 0x18; reg++) {
            if (shadowRegisterMap_[reg] != 0xFFFF && sidRegisterActive_[reg]) {
                count++;
            }
        }
        return count;
    }

    std::string SIDShadowRegisterFinder::generateHelpfulDataSection() const {
        std::stringstream ss;

        bool bFirst = true;

        // First output shadow registers for all SID registers
        for (u8 reg = 0; reg <= 0x18; reg++) {
            if (bFirst) {
                ss << "// SID Shadow Register mapping\n";
                bFirst = false;
            }

            // Check if this register was ever written to
            if (!sidRegisterActive_[reg]) {
                // Never written to
                ss << "#define D4" << util::byteToHex(reg) << "_SHADOW\n";
                ss << "#define D4" << util::byteToHex(reg) << "_SHADOW_NEVER_USED\n";
            }
            else {
                // Was written to
                u16 addr = shadowRegisterMap_[reg];
                if (addr != 0xFFFF) {
                    // Has a shadow register
                    ss << "#define D4" << util::byteToHex(reg) << "_SHADOW\n";
                    ss << ".var D4" << util::byteToHex(reg) << "_SHADOW_REGISTER = $" << util::wordToHex(addr) << "\n";
                }
                // If no shadow register found, don't output anything for this register
            }
        }

        if (!bFirst) {
            ss << "\n";
        }

        return ss.str();
    }

    std::string SIDShadowRegisterFinder::getSummary() const {
        std::stringstream ss;

        int count = getShadowRegisterCount();
        int neverUsedCount = 0;

        // Count never-used registers
        for (u8 reg = 0; reg <= 0x18; reg++) {
            if (!sidRegisterActive_[reg]) {
                neverUsedCount++;
            }
        }

        if (count == 0 && neverUsedCount == 0) {
            ss << "No shadow registers found.";
            return ss.str();
        }

        ss << "Shadow register analysis:\n";
        ss << "  Found shadow registers for " << count << " of 25 SID registers\n";
        if (neverUsedCount > 0) {
            ss << "  " << neverUsedCount << " SID registers were never written to\n";
        }
        ss << "\nDetails:\n";

        for (u8 reg = 0; reg <= 0x18; reg++) {
            if (!sidRegisterActive_[reg]) {
                ss << "  $D4" << util::byteToHex(reg) << " -> (never written)\n";
            }
            else {
                u16 addr = shadowRegisterMap_[reg];
                if (addr != 0xFFFF) {
                    ss << "  $D4" << util::byteToHex(reg) << " -> $"
                        << util::wordToHex(addr) << "\n";
                }
            }
        }

        return ss.str();
    }

} // namespace sidwinder