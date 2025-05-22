// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#pragma once

#include "MemoryAnalyzer.h"
#include "SIDwinderUtils.h"

#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

/**
 * @file LabelGenerator.h
 * @brief Generates and manages labels for disassembled code
 *
 * This module is responsible for creating meaningful labels for code, data,
 * and hardware registers in the disassembly output, making the assembly
 * more readable and maintainable.
 */

namespace sidwinder {

    /**
     * @struct DataBlock
     * @brief Represents a contiguous block of data in memory
     *
     * Used to track the boundaries and labels for data sections
     * identified during disassembly.
     */
    struct DataBlock {
        std::string label;  // Assigned name for this data block
        u16 start;          // Starting address of the block
        u16 end;            // Ending address of the block
    };

    /**
     * @brief Enumeration of hardware component types
     *
     * Used to categorize different hardware components when
     * generating labels for hardware registers.
     */
    enum class HardwareType {
        SID,    // SID sound chip
        VIC,    // VIC-II video chip
        CIA1,   // Complex Interface Adapter 1
        CIA2,   // Complex Interface Adapter 2
        Other   // Other hardware components
    };

    /**
     * @struct HardwareBase
     * @brief Information about a hardware component base address
     *
     * Used to track and label hardware components in the system, especially
     * when multiple instances of the same component exist (e.g., multiple SIDs).
     */
    struct HardwareBase {
        HardwareType type;  // Type of hardware component
        u16 address;        // Base address of the component
        int index;          // Index for multiple instances (e.g., SID0, SID1)
        std::string name;   // Name used in assembly output
    };

    /**
     * @class LabelGenerator
     * @brief Generates and manages labels for disassembled code
     *
     * This class analyzes code and data patterns to create meaningful labels
     * for jump targets, data blocks, and hardware registers. It also manages
     * the formatting of addresses and labels in the disassembly output.
     */
    class LabelGenerator {
    public:
        /**
         * @brief Constructor
         * @param analyzer Memory analyzer to use for code/data analysis
         * @param loadAddress Load address of the SID file
         * @param endAddress End address of the SID file
         */
        LabelGenerator(
            const MemoryAnalyzer& analyzer,
            u16 loadAddress,
            u16 endAddress);

        /**
         * @brief Generate labels for code and data regions
         *
         * Creates labels for jump targets, subroutines, and data blocks
         * based on the memory analysis.
         */
        void generateLabels();

        /**
         * @brief Get the label for a given address
         * @param addr Address to look up
         * @return Label for the address, or empty string if no label
         */
        std::string getLabel(u16 addr) const;

        /**
         * @brief Get all identified data blocks
         * @return Vector of data blocks
         */
        const std::vector<DataBlock>& getDataBlocks() const;

        /**
         * @brief Format an address with its label and offset
         * @param addr Address to format
         * @return Formatted string
         *
         * This converts numeric addresses to more readable symbols,
         * optionally with offsets (e.g., "Label+5").
         */
        std::string formatAddress(u16 addr) const;

        /**
         * @brief Format a zero page address with its label
         * @param addr Zero page address to format
         * @return Formatted string
         *
         * Converts zero page addresses to symbolic names when possible.
         */
        std::string formatZeroPage(u8 addr) const;

        /**
         * @brief Add a zero page variable definition
         * @param addr Zero page address
         * @param label Label for the variable
         */
        void addZeroPageVar(u8 addr, const std::string& label);

        /**
         * @brief Get all zero page variables
         * @return Map of zero page addresses to labels
         */
        const std::map<u8, std::string>& getZeroPageVars() const;

        /**
         * @brief Add a hardware component base
         * @param type Hardware type
         * @param address Base address
         * @param index Component index
         * @param name Component name
         *
         * Registers a hardware component for special handling in the disassembly.
         */
        void addHardwareBase(HardwareType type, u16 address, int index, const std::string& name);

        /**
         * @brief Get all hardware component bases
         * @return Vector of hardware bases
         */
        const std::vector<HardwareBase>& getHardwareBases() const;

        /**
         * @brief Add a subdivision to a data block
         * @param blockLabel Label of the data block
         * @param startOffset Start offset within the block
         * @param endOffset End offset within the block
         *
         * Subdivides a data block to improve the structure of the disassembly.
         */
        void addDataBlockSubdivision(
            const std::string& blockLabel,
            u16 startOffset,
            u16 endOffset);

        /**
         * @brief Add an address that should be considered for subdivision
         * @param addr Address to mark for subdivision
         *
         * Queues an address for potential subdivision during processing.
         */
        void addPendingSubdivisionAddress(u16 addr);

        /**
         * @brief Apply subdivisions to all data blocks
         *
         * Processes all pending subdivision requests and updates the data block
         * structure accordingly.
         */
        void applySubdivisions();

        /**
         * @brief Get the label map (address to label)
         * @return Map of addresses to labels
         */
        const std::map<u16, std::string>& getLabelMap() const;

    private:
        const MemoryAnalyzer& analyzer_;  // Reference to memory analyzer
        u16 loadAddress_;                 // Start of the memory region
        u16 endAddress_;                  // End of the memory region

        int codeLabelCounter_ = 0;        // Counter for generating unique code labels
        int dataLabelCounter_ = 0;        // Counter for generating unique data labels

        std::map<u16, std::string> labelMap_;          // Maps addresses to labels
        std::vector<DataBlock> dataBlocks_;            // List of data blocks
        std::map<u8, std::string> zeroPageVars_;       // Zero page variable names
        std::vector<HardwareBase> usedHardwareBases_;  // Hardware component bases

        // Data block subdivision structures
        struct AccessInfo {
            u16 offset;     // Offset within the data block
            u16 absAddr;    // Absolute memory address
            u16 pc;         // Program counter at time of access
            bool isWrite;   // Whether this was a write access
        };

        // Maps from block labels to access information and subdivision ranges
        std::unordered_map<std::string, std::vector<AccessInfo>> dataBlockAccessMap_;
        std::unordered_map<std::string, std::vector<std::pair<u16, u16>>> dataBlockSubdivisions_;
        std::set<u16> pendingSubdivisionAddresses_;  // Addresses pending subdivision
    };

} // namespace sidwinder