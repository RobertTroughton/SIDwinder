// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#include "LabelGenerator.h"
#include "SIDwinderUtils.h"

#include <algorithm>
#include <sstream>

namespace sidwinder {

    /**
     * @brief Constructor for LabelGenerator
     *
     * Initializes the label generator with a memory analyzer and the
     * address range to process.
     *
     * @param analyzer Memory analyzer to use for code/data analysis
     * @param loadAddress Load address of the SID file
     * @param endAddress End address of the SID file
     */
    LabelGenerator::LabelGenerator(
        const MemoryAnalyzer& analyzer,
        u16 loadAddress,
        u16 endAddress)
        : analyzer_(analyzer),
        loadAddress_(loadAddress),
        endAddress_(endAddress) {
    }

    /**
     * @brief Generate labels for code and data regions
     *
     * Creates labels for jump targets, subroutines, and data blocks
     * based on the memory analysis results.
     */
    void LabelGenerator::generateLabels() {
        util::Logger::debug("Generating labels...");

        // First, generate labels for all jump targets
        std::vector<u16> labelTargets = analyzer_.findLabelTargets();
        for (u16 addr : labelTargets) {
            if (addr >= loadAddress_ && addr < endAddress_) {
                labelMap_[addr] = "Label_" + std::to_string(codeLabelCounter_++);
            }
        }

        // Then generate labels for data blocks
        std::vector<std::pair<u16, u16>> codeRanges = analyzer_.findCodeRanges();

        // Sort by start address to ensure we process them in order
        std::sort(codeRanges.begin(), codeRanges.end());

        // Find data blocks between code ranges
        u16 prevEnd = loadAddress_;
        for (const auto& [start, end] : codeRanges) {
            if (start > prevEnd) {
                // There's a data block between prevEnd and start
                std::string label = "DataBlock_" + std::to_string(dataLabelCounter_++);
                labelMap_[prevEnd] = label;
                dataBlocks_.push_back({ label, prevEnd, static_cast<u16>(start - 1) });
            }
            prevEnd = end + 1;
        }

        // Handle potential data block at the end
        if (prevEnd < endAddress_) {
            std::string label = "DataBlock_" + std::to_string(dataLabelCounter_++);
            labelMap_[prevEnd] = label;
            dataBlocks_.push_back({ label, prevEnd, static_cast<u16>(endAddress_ - 1) });
        }

        util::Logger::debug("Generated " + std::to_string(codeLabelCounter_) +
            " code labels and " + std::to_string(dataLabelCounter_) +
            " data block labels");
    }

    /**
     * @brief Get the label for a given address
     *
     * @param addr Address to look up
     * @return Label for the address, or empty string if no label
     */
    std::string LabelGenerator::getLabel(u16 addr) const {
        auto it = labelMap_.find(addr);
        return (it != labelMap_.end()) ? it->second : "";
    }

    /**
     * @brief Get all identified data blocks
     *
     * @return Vector of data blocks
     */
    const std::vector<DataBlock>& LabelGenerator::getDataBlocks() const {
        return dataBlocks_;
    }

    /**
     * @brief Format an address with its label and offset
     *
     * Converts a numeric address to a symbolic representation, using
     * labels and offsets as appropriate. Special handling is applied
     * for hardware registers.
     *
     * @param addr Address to format
     * @return Formatted string
     */
    std::string LabelGenerator::formatAddress(u16 addr) const {
        // Hardware component check - SID registers
        static const u16 sidBaseAddr = 0xD400;
        static const u16 sidEndAddr = 0xD7FF;

        if (addr >= sidBaseAddr && addr <= sidEndAddr) {
            const u16 base = addr & 0xFFE0; // Align to 32 bytes (SID base granularity)
            const u8 offset = addr & 0x1F;  // Offset within SID (0-31)

            // Find the SID index in the registered hardware bases
            for (const auto& hw : usedHardwareBases_) {
                if (hw.type == HardwareType::SID && hw.address == base) {
                    if (offset == 0) {
                        return hw.name; // Return just "SID0", "SID1", etc. for the base address
                    }
                    else {
                        return hw.name + "+" + std::to_string(offset); // "SID0+1", etc. for offsets
                    }
                }
            }

            // If not found in registered bases, use a default SID0 reference
            return "SID0+" + std::to_string(addr - sidBaseAddr);
        }

        // Future hardware components can be added here:
        // VIC-II check (0xD000-0xD3FF)
        // CIA check (0xDC00-0xDCFF for CIA1, 0xDD00-0xDDFF for CIA2)
        // etc.

        // Check for exact label match
        auto it = labelMap_.find(addr);
        if (it != labelMap_.end()) {
            return it->second;
        }

        // No exact match, try to find a label for an address range containing this address
        u16 bestBase = 0;
        std::string bestLabel;

        // First check if the address is within a labeled code or data block
        for (const auto& [labelAddr, label] : labelMap_) {
            // Only consider if this label is before our target address
            if (labelAddr <= addr) {
                // If this is closer to our target than the current best, update
                if (labelAddr > bestBase) {
                    bestBase = labelAddr;
                    bestLabel = label;
                }
            }
        }

        // If we found a label that's a good base for this address
        if (!bestLabel.empty()) {
            const u16 offset = addr - bestBase;
            if (offset == 0) {
                return bestLabel;
            }
            else {
                std::ostringstream oss;
                oss << bestLabel << " + $" << std::hex << std::uppercase << offset;
                return oss.str();
            }
        }

        // If we didn't find a label, check if it's within a data block
        for (const auto& block : dataBlocks_) {
            if (addr >= block.start && addr <= block.end) {
                u16 offset = addr - block.start;
                if (offset == 0) {
                    return block.label;
                }
                else {
                    std::ostringstream oss;
                    oss << block.label << " + $" << std::hex << std::uppercase << offset;
                    return oss.str();
                }
            }
        }

        // Default to hex
        return "$" + sidwinder::util::wordToHex(addr);
    }

    /**
     * @brief Format a zero page address with its label
     *
     * Converts a zero page address to a symbolic name when possible.
     *
     * @param addr Zero page address to format
     * @return Formatted string
     */
    std::string LabelGenerator::formatZeroPage(u8 addr) const {
        auto it = zeroPageVars_.find(addr);
        if (it != zeroPageVars_.end()) {
            return it->second;
        }

        return "$" + util::byteToHex(addr);
    }

    /**
     * @brief Add a zero page variable definition
     *
     * Registers a named zero page variable.
     *
     * @param addr Zero page address
     * @param label Label for the variable
     */
    void LabelGenerator::addZeroPageVar(u8 addr, const std::string& label) {
        zeroPageVars_[addr] = label;
    }

    /**
     * @brief Get all zero page variables
     *
     * @return Map of zero page addresses to labels
     */
    const std::map<u8, std::string>& LabelGenerator::getZeroPageVars() const {
        return zeroPageVars_;
    }

    /**
     * @brief Add a subdivision to a data block
     *
     * Subdivides a data block to create more granular structure.
     *
     * @param blockLabel Label of the data block
     * @param startOffset Start offset within the block
     * @param endOffset End offset within the block
     */
    void LabelGenerator::addDataBlockSubdivision(
        const std::string& blockLabel,
        u16 startOffset,
        u16 endOffset) {

        // Find the data block
        auto it = std::find_if(dataBlocks_.begin(), dataBlocks_.end(),
            [&](const DataBlock& b) { return b.label == blockLabel; });

        if (it == dataBlocks_.end()) {
            util::Logger::warning("Attempted to add subdivision to non-existent data block: " + blockLabel);
            return;
        }

        // Check if the range overlaps with existing ranges
        auto& ranges = dataBlockSubdivisions_[blockLabel];

        bool overlap = std::any_of(ranges.begin(), ranges.end(), [&](const auto& r) {
            return !(endOffset <= r.first || startOffset >= r.second);
            });

        if (!overlap) {
            ranges.emplace_back(startOffset, endOffset);

            // Create label for this subdivision
            const size_t subdivIndex = ranges.size();
            const u16 blockStart = it->start;
            const u16 realStart = blockStart + startOffset;
            const std::string subLabel = blockLabel + "_" + std::to_string(subdivIndex);

            // Add to label map
            labelMap_[realStart] = subLabel;
        }
    }

    /**
     * @brief Add an address that should be considered for subdivision
     *
     * Queues an address for potential subdivision during processing.
     *
     * @param addr Address to mark for subdivision
     */
    void LabelGenerator::addPendingSubdivisionAddress(u16 addr) {
        if (addr >= loadAddress_ && addr < endAddress_) {
            pendingSubdivisionAddresses_.insert(addr);
            util::Logger::debug("Added pending subdivision address: $" + util::wordToHex(addr));
        }
    }

    /**
     * @brief Apply subdivisions to all data blocks
     *
     * Processes all pending subdivision requests and updates the
     * data block structure accordingly.
     */
    void LabelGenerator::applySubdivisions() {
        util::Logger::debug("Applying data block subdivisions...");

        // Step 1: Deduplicate and sort addresses
        std::vector<u16> sorted(pendingSubdivisionAddresses_.begin(), pendingSubdivisionAddresses_.end());
        std::sort(sorted.begin(), sorted.end());

        if (!sorted.empty()) {
            util::Logger::debug("Processing " + std::to_string(sorted.size()) + " pending subdivision addresses");
        }

        // Step 2: Group by DataBlock
        std::map<std::string, std::vector<std::pair<u16, u16>>> blockRanges;

        for (size_t i = 0; i < sorted.size(); ) {
            u16 start = sorted[i];
            u16 end = start + 1;

            // Extend range while addresses are contiguous
            while ((i + 1) < sorted.size() && sorted[i + 1] == end) {
                ++end;
                ++i;
            }

            // Find which block it belongs to
            for (const auto& block : dataBlocks_) {
                if (start >= block.end || end <= block.start) {
                    continue;
                }

                const std::string label = block.label;
                const u16 offsetStart = std::max<u16>(start, block.start) - block.start;
                const u16 offsetEnd = std::min<u16>(end, block.end) - block.start;

                blockRanges[label].emplace_back(offsetStart, offsetEnd);
                util::Logger::debug("Found subdivision in " + label +
                    " from offset $" + util::wordToHex(offsetStart) +
                    " to $" + util::wordToHex(offsetEnd));
                break;
            }

            ++i;
        }

        // Step 3: Merge ranges into subdivisions
        for (const auto& [label, ranges] : blockRanges) {
            auto& existing = dataBlockSubdivisions_[label];

            // Merge in the new ranges
            for (const auto& [start, end] : ranges) {
                // Check if this range overlaps with any existing range
                bool overlap = std::any_of(existing.begin(), existing.end(),
                    [start, end](const auto& r) {  // Capture specific variables by value
                        return !(end <= r.first || start >= r.second);
                    });

                if (!overlap) {
                    existing.emplace_back(start, end);
                    util::Logger::debug("Added subdivision to " + label +
                        " from offset $" + util::wordToHex(start) +
                        " to $" + util::wordToHex(end));
                }
            }
        }

        // Create new subdivided blocks
        std::vector<DataBlock> newBlocks;

        for (auto& [label, ranges] : dataBlockSubdivisions_) {
            // Find the corresponding data block
            auto it = std::find_if(dataBlocks_.begin(), dataBlocks_.end(),
                [&](const DataBlock& b) { return b.label == label; });

            if (it == dataBlocks_.end()) {
                continue;
            }

            const u16 blockStart = it->start;

            // Sort ranges for consistent output
            std::sort(ranges.begin(), ranges.end());

            // Create new blocks for each subdivision
            for (size_t i = 0; i < ranges.size(); ++i) {
                const u16 startOffset = ranges[i].first;
                const u16 endOffset = ranges[i].second;
                const u16 realStart = blockStart + startOffset;
                const u16 realEnd = blockStart + endOffset - 1;
                const std::string subLabel = label + "_" + std::to_string(i + 1);

                // Add to label map and new blocks list
                labelMap_[realStart] = subLabel;
                newBlocks.push_back({ subLabel, realStart, realEnd });

                util::Logger::debug("Created subdivision " + subLabel +
                    " from $" + util::wordToHex(realStart) +
                    " to $" + util::wordToHex(realEnd));
            }

            // Rename original to _0
            const auto oldLabel = label;
            const auto newLabel = label + "_0";
            labelMap_[it->start] = newLabel;
            it->label = newLabel;

            util::Logger::debug("Renamed original block " + oldLabel + " to " + newLabel);
        }

        // Add the new subdivided blocks to the list
        dataBlocks_.insert(dataBlocks_.end(), newBlocks.begin(), newBlocks.end());

        util::Logger::debug("Applied " + std::to_string(newBlocks.size()) + " subdivisions");

        // Clear pending addresses after processing
        pendingSubdivisionAddresses_.clear();
    }

    /**
     * @brief Get the label map (address to label)
     *
     * @return Map of addresses to labels
     */
    const std::map<u16, std::string>& LabelGenerator::getLabelMap() const {
        return labelMap_;
    }

    /**
     * @brief Add a hardware component base
     *
     * Registers a hardware component for special handling in the disassembly.
     *
     * @param type Hardware type
     * @param address Base address
     * @param index Component index
     * @param name Component name
     */
    void LabelGenerator::addHardwareBase(
        HardwareType type,
        u16 address,
        int index,
        const std::string& name) {

        HardwareBase base;
        base.type = type;
        base.address = address;
        base.index = index;
        base.name = name;

        usedHardwareBases_.push_back(base);

        util::Logger::debug("Added hardware base: " + name + " at $" +
            util::wordToHex(address) + " (index " +
            std::to_string(index) + ")");
    }

    /**
     * @brief Get all hardware component bases
     *
     * @return Vector of hardware bases
     */
    const std::vector<HardwareBase>& LabelGenerator::getHardwareBases() const {
        return usedHardwareBases_;
    }

} // namespace sidwinder