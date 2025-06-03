// New file: src/PointerBasedSelfModificationDetector.h
#pragma once

#include "Common.h"
#include <vector>
#include <map>
#include <set>

namespace sidwinder {

    struct ComparisonRecord {
        u16 pc;                    // Address of comparison instruction
        char reg;                  // Register being compared ('A', 'X', 'Y')
        u8 compareValue;           // Value being compared against
        u16 sourceAddr;            // Address where comparison value came from
        bool isMemorySource;       // True if from memory, false if immediate
        u16 nextPC;               // PC after this comparison
    };

    struct SelfModificationRecord {
        u16 pc;                    // Address of instruction doing the modification
        u16 targetAddr;            // Address being modified
        u8 newValue;               // Value being written
        u16 sourceAddr;            // Where the new value came from
        u16 instrStart;            // Start of instruction being modified
        int offset;                // Offset within instruction (1=low byte, 2=high byte)
    };

    struct ConditionalModificationPattern {
        std::vector<ComparisonRecord> comparisons;     // Sequence of comparisons
        std::vector<SelfModificationRecord> modifications; // Resulting modifications
        u16 startPC;               // Start of pattern
        u16 endPC;                 // End of pattern
        bool isComplete;           // Whether pattern is fully analyzed
    };

    class PointerBasedSelfModificationDetector {
    public:
        PointerBasedSelfModificationDetector();

        // Called during emulation
        void recordComparison(const ComparisonRecord& record);
        void recordSelfModification(const SelfModificationRecord& record);
        void recordBranch(u16 fromPC, u16 toPC, bool taken);

        // Called after emulation to analyze patterns
        void analyzePatterns();

        // Get detected patterns for relocation
        const std::vector<ConditionalModificationPattern>& getPatterns() const;

        // Check if an address needs relocation due to pointer-based patterns
        bool needsRelocation(u16 addr, u8& relocationType) const;

    private:
        std::vector<ComparisonRecord> comparisons_;
        std::vector<SelfModificationRecord> modifications_;
        std::map<u16, std::vector<u16>> branchTargets_; // PC -> list of branch targets
        std::vector<ConditionalModificationPattern> detectedPatterns_;

        // Analysis methods
        void findComparisonSequences();
        void correlateComparisonsWithModifications();
        void validatePatterns();

        // Helper methods
        bool isPointerComparison(const ComparisonRecord& comp) const;
        bool isInstructionModification(const SelfModificationRecord& mod) const;
        std::vector<u16> getExecutionPath(u16 startPC, u16 endPC) const;
    };

} // namespace sidwinder