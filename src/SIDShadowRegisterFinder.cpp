// SIDShadowRegisterFinder.cpp
#include "SIDShadowRegisterFinder.h"
#include "SIDwinderUtils.h"
#include "MemoryConstants.h"

#include <algorithm>
#include <sstream>
#include <iomanip>

namespace sidwinder {

    SIDShadowRegisterFinder::SIDShadowRegisterFinder() {
        reset();
    }

    void SIDShadowRegisterFinder::reset() {
        currentSIDValues_.fill(0);
        frameCount_ = 0;
    }

    void SIDShadowRegisterFinder::recordSIDWrite(u16 addr, u8 value) {
        if (MemoryConstants::isSID(addr)) {
            u8 reg = MemoryConstants::getSIDRegister(addr);
            currentSIDValues_[reg] = value;
        }
    }

    void SIDShadowRegisterFinder::checkMemoryForShadowRegisters(std::span<const u8> memory) {
        frameCount_++;
        if (frameCount_ < WARMUP_FRAMES)
            return;

        if (frameCount_ == WARMUP_FRAMES) {
            // First frame: find all possible shadows
            for (u8 reg = 0; reg <= 0x18; reg++) {
                u8 value = currentSIDValues_[reg];

                for (u32 addr = 2; addr < 0x10000; addr++) {
                    if (MemoryConstants::isIO(addr)) {
                        continue;
                    }
                    if (memory[addr] == value) {
                        possibleShadows_[reg].push_back(addr);
                    }
                }
            }
        }
        else {
            // Subsequent frames: filter out non-matching addresses
            for (u8 reg = 0; reg <= 0x18; reg++) {
                u8 value = currentSIDValues_[reg];
                auto& candidates = possibleShadows_[reg];

                // Remove addresses that don't match anymore
                candidates.erase(
                    std::remove_if(candidates.begin(), candidates.end(),
                        [&memory, value](u16 addr) {
                            return memory[addr] != value;
                        }),
                    candidates.end()
                );
            }
        }
        frameCount_++;
    }

    std::string SIDShadowRegisterFinder::generateHelpfulDataSection() const {
        std::stringstream ss;

        bool bFirst = true;
        for (u8 reg = 0; reg <= 0x18; reg++) {
            u16 addr = 0xFFFF;
            const auto& candidates = possibleShadows_[reg];
            if (candidates.size() >= 1) {
                addr = candidates[0];
            }
            if (addr != 0xFFFF) {
                if (bFirst)
                {
                    ss << "// SID Shadow Register mapping\n";
                    bFirst = false;
                }
                ss << "#define D4" << util::byteToHex(reg) << "_SHADOW\n";
                ss << ".var D4" << util::byteToHex(reg) << "_SHADOW_REGISTER = $" << util::wordToHex(addr) << "\n";
            }
        }

        if (!bFirst)
        {
            ss << "\n";
        }

        return ss.str();
    }

} // namespace sidwinder