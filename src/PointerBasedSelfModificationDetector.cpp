// PointerBasedSelfModificationDetector.cpp
#include "PointerBasedSelfModificationDetector.h"
#include "SIDwinderUtils.h"
#include <algorithm>
#include <sstream>
#include <functional>
#include <unordered_map>

namespace sidwinder {

    PointerBasedSelfModificationDetector::PointerBasedSelfModificationDetector() {
    }

    void PointerBasedSelfModificationDetector::recordComparison(const ComparisonRecord& record) {
        comparisons_.push_back(record);
    }

    void PointerBasedSelfModificationDetector::recordSelfModification(const SelfModificationRecord& record) {
        modifications_.push_back(record);
    }

    void PointerBasedSelfModificationDetector::recordBranch(u16 fromPC, u16 toPC, bool taken) {
        if (taken) {
            branchTargets_[fromPC].push_back(toPC);
        }
    }

    void PointerBasedSelfModificationDetector::analyzePatterns() {
        findComparisonSequences();
        correlateComparisonsWithModifications();
        validatePatterns();
    }

    void PointerBasedSelfModificationDetector::findComparisonSequences() {
        // Group comparisons that are likely testing pointer values
        std::map<u16, std::vector<ComparisonRecord>> comparisonsByRegion;

        // Group comparisons within 32-byte regions (likely related)
        for (const auto& comp : comparisons_) {
            u16 region = comp.pc & 0xFFE0; // 32-byte alignment
            comparisonsByRegion[region].push_back(comp);
        }

        // Look for patterns like:
        // 1. Compare high byte of pointer
        // 2. Branch if not equal
        // 3. Compare low byte of pointer  
        // 4. Branch if not equal
        // 5. Perform self-modification

        for (const auto& [region, comps] : comparisonsByRegion) {
            if (comps.size() >= 2) {
                // Look for sequential comparisons that might be testing a 16-bit value
                for (size_t i = 0; i < comps.size() - 1; i++) {
                    const auto& comp1 = comps[i];
                    const auto& comp2 = comps[i + 1];

                    // Check if these could be high/low byte comparisons
                    if (std::abs(static_cast<int>(comp2.pc) - static_cast<int>(comp1.pc)) < 20) {
                        ConditionalModificationPattern pattern;
                        pattern.comparisons.push_back(comp1);
                        pattern.comparisons.push_back(comp2);
                        pattern.startPC = std::min(comp1.pc, comp2.pc);
                        pattern.endPC = std::max(comp1.nextPC, comp2.nextPC);
                        pattern.isComplete = false;

                        detectedPatterns_.push_back(pattern);
                    }
                }
            }
        }
    }

    void PointerBasedSelfModificationDetector::correlateComparisonsWithModifications() {
        // For each potential pattern, find modifications that occur after the comparisons
        for (auto& pattern : detectedPatterns_) {
            if (pattern.comparisons.empty()) continue;

            u16 patternEnd = pattern.endPC;

            // Look for self-modifications within 100 bytes of the comparison sequence
            for (const auto& mod : modifications_) {
                if (mod.pc >= patternEnd && mod.pc <= patternEnd + 100) {
                    // Check if this modification is likely controlled by the comparisons
                    if (isInstructionModification(mod)) {
                        pattern.modifications.push_back(mod);
                        pattern.endPC = std::max(static_cast<int>(pattern.endPC), mod.pc + 3); // Account for instruction size
                    }
                }
            }

            // Mark pattern as complete if we found modifications
            pattern.isComplete = !pattern.modifications.empty();
        }
    }

    void PointerBasedSelfModificationDetector::validatePatterns() {
        // Remove patterns that don't look like genuine pointer-based self-modification
        auto it = std::remove_if(detectedPatterns_.begin(), detectedPatterns_.end(),
            [this](const ConditionalModificationPattern& pattern) {
                // Pattern must have at least 2 comparisons and 1 modification
                if (pattern.comparisons.size() < 2 || pattern.modifications.empty()) {
                    return true;
                }

                // At least one comparison should look like a pointer test
                bool hasPointerComparison = false;
                for (const auto& comp : pattern.comparisons) {
                    if (isPointerComparison(comp)) {
                        hasPointerComparison = true;
                        break;
                    }
                }

                return !hasPointerComparison;
            });

        detectedPatterns_.erase(it, detectedPatterns_.end());
    }

    bool PointerBasedSelfModificationDetector::isPointerComparison(const ComparisonRecord& comp) const {
        // Heuristics to identify pointer comparisons:
        // 1. Comparing against values that look like high bytes (0x10-0x9F typically)
        // 2. Part of a sequence with another comparison shortly after
        // 3. Followed by conditional branches

        return (comp.compareValue >= 0x10 && comp.compareValue <= 0x9F);
    }

    bool PointerBasedSelfModificationDetector::isInstructionModification(const SelfModificationRecord& mod) const {
        // Check if this is modifying an instruction (offset 1 or 2 from instruction start)
        return (mod.offset >= 1 && mod.offset <= 2);
    }

    const std::vector<ConditionalModificationPattern>& PointerBasedSelfModificationDetector::getPatterns() const {
        return detectedPatterns_;
    }

} // namespace sidwinder