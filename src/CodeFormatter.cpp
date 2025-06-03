// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#include "CodeFormatter.h"
#include "cpu6510.h"
#include "DisassemblyWriter.h"

#include <algorithm>
#include <sstream>

namespace sidwinder {

    /**
     * @brief Constructor for CodeFormatter
     *
     * Initializes the code formatter with references to the CPU, label generator,
     * and memory data.
     *
     * @param cpu Reference to the CPU
     * @param labelGenerator Reference to the label generator
     * @param memory Span of memory data
     */
    CodeFormatter::CodeFormatter(
        const CPU6510& cpu,
        const LabelGenerator& labelGenerator,
        std::span<const u8> memory)
        : cpu_(cpu),
        labelGenerator_(labelGenerator),
        memory_(memory),
        removeCIAWrites_(false) {
    }

    /**
     * @brief Format a disassembled instruction
     *
     * Converts a machine code instruction at PC into assembly language.
     * Updates PC to point to the next instruction.
     *
     * @param pc Program counter (will be updated to point after instruction)
     * @return Formatted instruction string
     */
    std::string CodeFormatter::formatInstruction(u16& pc) const {
        std::ostringstream line;

        const u8 opcode = memory_[pc];
        const std::string mnemonic = std::string(cpu_.getMnemonic(opcode));
        const auto mode = cpu_.getAddressingMode(opcode);
        const int size = cpu_.getInstructionSize(opcode);

        // Save the start PC for comment
        const u16 startPC = pc;

        // Check for CIA timer patch
        if (removeCIAWrites_ && static_cast<int>(mode) == static_cast<int>(AddressingMode::Absolute)) {
            const u16 absAddr = memory_[pc + 1] | (memory_[pc + 2] << 8);
            if (isCIAStorePatch(opcode, static_cast<int>(mode), absAddr, mnemonic)) {
                std::ostringstream patched;
                patched << "    bit $abcd   //; disabled " << mnemonic << " $"
                    << util::wordToHex(absAddr) << " (CIA Timer)";
                pc += size;
                return patched.str();
            }
        }

        // Format instruction with mnemonic
        line << "    " << mnemonic;

        // Add operand if needed
        if (size > 1) {
            line << " " << formatOperand(pc, static_cast<int>(mode));
        }

        // Update PC
        pc += size;

        // Calculate the end PC
        u16 endPC = startPC + size - 1;

        // Pad to fixed column and add address comment
        std::string lineStr = line.str();
        int padding = std::max(0, 97 - static_cast<int>(lineStr.length())); // Adjusted to column 97

        return lineStr + std::string(padding, ' ') + "//; $" +
            util::wordToHex(startPC) + " - " +
            util::wordToHex(endPC);
    }

    /**
     * @brief Format data bytes
     *
     * Outputs data bytes in assembly format (.byte directives).
     * Handles relocation entries and unused bytes.
     * Enhanced to include memory address ranges in comments with proper alignment.
     *
     * @param file Output stream
     * @param pc Program counter (will be updated)
     * @param originalMemory Original memory data
     * @param originalBase Base address of original memory
     * @param endAddress End address
     * @param relocationBytes Map of relocation bytes
     * @param memoryTags Memory type tags
     */
    void CodeFormatter::formatDataBytes(
        std::ostream& file,
        u16& pc,
        std::span<const u8> originalMemory,
        u16 originalBase,
        u16 endAddress,
        const std::map<u16, RelocationEntry>& relocationBytes,
        std::span<const MemoryType> memoryTags) const {

        const int commentColumn = 97; // Target column for alignment of comments (adjusted +1)

        while (pc < endAddress && (memoryTags[pc] & MemoryType::Data)) {
            // Emit label if present
            const std::string label = labelGenerator_.getLabel(pc);
            if (!label.empty()) {
                file << label << ":\n";
            }

            // Check for relocation byte
            auto relocIt = relocationBytes.find(pc);
            if (relocIt != relocationBytes.end()) {
                const u16 target = relocIt->second.targetAddress;
                const std::string targetLabel = labelGenerator_.formatAddress(target);

                // Store the current PC for comment
                const u16 startPC = pc;
                const u16 endPC = pc; // For relocation entries, end = start (1 byte)

                // Build the line in a string stream
                std::ostringstream lineSS;
                lineSS << "    .byte ";
                if (relocIt->second.type == RelocationEntry::Type::Low) {
                    lineSS << "<(" << targetLabel << ")";
                }
                else {
                    lineSS << ">(" << targetLabel << ")";
                }

                // Get the line as a string
                std::string line = lineSS.str();

                // Output the line with properly aligned comment
                file << line;

                // Calculate padding needed
                int padding = std::max(0, commentColumn - static_cast<int>(line.length()));
                file << std::string(padding, ' ') << "//; $"
                    << util::wordToHex(startPC) << " - "
                    << util::wordToHex(endPC) << "\n";

                ++pc;
                continue;
            }

            u16 lineStartPC = pc; // Remember line start for comment

            // Build the line in a string stream
            std::ostringstream lineSS;
            lineSS << "    .byte ";

            int count = 0;
            while (pc < endAddress && (memoryTags[pc] & MemoryType::Data)) {

                // Stop at relocation bytes
                if (relocationBytes.count(pc)) {
                    break;
                }

                // Add comma if not the first byte
                if (count > 0) {
                    lineSS << ", ";
                }

                // Get the byte from original memory if possible
                u8 byte;
                if (pc - originalBase < originalMemory.size()) {
                    byte = originalMemory[pc - originalBase];
                }
                else {
                    // Use memory from the CPU instead
                    byte = memory_[pc];
                }

                // Check if unused (not accessed)
                bool isUnused = !(memoryTags[pc] & (MemoryType::Accessed | MemoryType::LabelTarget));
                if (isUnused) {
                    byte = 0;  // Always zero out unused bytes to help with compression
                }

                lineSS << "$" << util::byteToHex(byte);

                ++pc;
                ++count;

                // Stop at code or label
                if ((memoryTags[pc] & MemoryType::Code) || !labelGenerator_.getLabel(pc).empty()) {
                    break;
                }

                // Line break after 16 bytes
                if (count == 16) {
                    // Get the full line as a string
                    std::string line = lineSS.str();

                    // Calculate end address for range
                    const u16 lineEndPC = pc - 1; // Last byte processed

                    // Output the line with properly aligned comment
                    file << line;

                    // Calculate padding needed
                    int padding = std::max(0, commentColumn - static_cast<int>(line.length()));
                    file << std::string(padding, ' ') << "//; $"
                        << util::wordToHex(lineStartPC) << " - "
                        << util::wordToHex(lineEndPC) << "\n";

                    // Start a new line if there are more bytes
                    if (pc < endAddress && (memoryTags[pc] & MemoryType::Data)) {
                        lineSS.str("");  // Clear the string stream
                        lineSS << "    .byte ";
                        count = 0;
                    }

                    lineStartPC = pc;
                }
            }

            // Output last line if anything remains
            if (count > 0) {
                // Calculate end address for the final line
                const u16 lineEndPC = pc - 1; // Last byte processed

                // Get the full line as a string
                std::string line = lineSS.str();

                // Output the line with properly aligned comment
                file << line;

                // Calculate padding needed
                int padding = std::max(0, commentColumn - static_cast<int>(line.length()));
                file << std::string(padding, ' ') << "//; $"
                    << util::wordToHex(lineStartPC) << " - "
                    << util::wordToHex(lineEndPC) << "\n";
            }
        }
    }

    /**
     * @brief Check if a store instruction is a CIA timer patch
     *
     * Detects writes to CIA timer registers that should be handled specially.
     *
     * @param opcode Instruction opcode
     * @param mode Addressing mode
     * @param operand Operand address
     * @param mnemonic Instruction mnemonic
     * @return True if this is a CIA timer patch
     */
    bool CodeFormatter::isCIAStorePatch(
        u8 opcode,
        int mode,
        u16 operand,
        std::string_view mnemonic) const {

        if (mode != static_cast<int>(AddressingMode::Absolute)) {
            return false;
        }

        if (operand != 0xDC04 && operand != 0xDC05) {
            return false;
        }

        return mnemonic == "sta" || mnemonic == "stx" || mnemonic == "sty";
    }

    /**
     * @brief Format an instruction operand
     *
     * Handles different addressing modes and formats operands appropriately,
     * including resolving labels and symbolic addresses.
     *
     * @param pc Program counter
     * @param mode Addressing mode
     * @return Formatted operand string
     */
    std::string CodeFormatter::formatOperand(u16 pc, int mode) const {
        const auto addressingMode = static_cast<AddressingMode>(mode);

        switch (addressingMode) {
        case AddressingMode::Immediate: {
            return "#$" + util::byteToHex(memory_[pc + 1]);
        }

        case AddressingMode::ZeroPage: {
            const u8 zp = memory_[pc + 1];
            return labelGenerator_.formatZeroPage(zp);
        }

        case AddressingMode::ZeroPageX: {
            const u8 zp = memory_[pc + 1];
            const std::string baseAddr = labelGenerator_.formatZeroPage(zp);
            return baseAddr + ",X";
        }

        case AddressingMode::ZeroPageY: {
            const u8 zp = memory_[pc + 1];
            const std::string baseAddr = labelGenerator_.formatZeroPage(zp);
            return baseAddr + ",Y";
        }

        case AddressingMode::IndirectX: {
            const u8 zp = memory_[pc + 1];
            const std::string baseAddr = labelGenerator_.formatZeroPage(zp);
            return "(" + baseAddr + ",X)";
        }

        case AddressingMode::IndirectY: {
            const u8 zp = memory_[pc + 1];
            const std::string baseAddr = labelGenerator_.formatZeroPage(zp);
            return "(" + baseAddr + "),Y";
        }

        case AddressingMode::Absolute: {
            const u16 accessAddr = memory_[pc + 1] | (memory_[pc + 2] << 8);
            return labelGenerator_.formatAddress(accessAddr);
        }

        case AddressingMode::AbsoluteX: {
            const u16 baseAddr = memory_[pc + 1] | (memory_[pc + 2] << 8);
            const auto [minIndex, maxIndex] = cpu_.getIndexRange(pc + 1);
            return formatIndexedAddressWithMinOffset(baseAddr, minIndex, 'X');
        }

        case AddressingMode::AbsoluteY: {
            const u16 baseAddr = memory_[pc + 1] | (memory_[pc + 2] << 8);
            const auto [minIndex, maxIndex] = cpu_.getIndexRange(pc + 1);
            return formatIndexedAddressWithMinOffset(baseAddr, minIndex, 'Y');
        }

        case AddressingMode::Indirect: {
            const u16 accessAddr = memory_[pc + 1] | (memory_[pc + 2] << 8);
            return "($" + util::wordToHex(accessAddr) + ")";
        }

        case AddressingMode::Relative: {
            const i8 offset = static_cast<i8>(memory_[pc + 1]);
            const u16 dest = pc + 2 + offset;
            return labelGenerator_.formatAddress(dest);
        }

        default:
            return "";
        }
    }

    /**
     * @brief Format an indexed address with minimum offset
     *
     * Formats addresses with index registers, accounting for offsets.
     * Uses label-based expressions when appropriate.
     *
     * @param baseAddr Base address
     * @param minOffset Minimum offset
     * @param indexReg Index register ('X' or 'Y')
     * @return Formatted address string
     */
    std::string CodeFormatter::formatIndexedAddressWithMinOffset(
        u16 baseAddr,
        u8 minOffset,
        char indexReg) const {

        const u16 targetAddr = baseAddr + minOffset;
        const std::string label = labelGenerator_.getLabel(targetAddr);

        if (!label.empty()) {
            if (minOffset == 0) {
                return label + "," + indexReg;
            }
            else {
                return label + "-" + std::to_string(minOffset) + "," + indexReg;
            }
        }

        return labelGenerator_.formatAddress(baseAddr) + "," + indexReg;
    }

    void CodeFormatter::setCIAWriteRemoval(bool removeCIAWrites) const
    {
        removeCIAWrites_ = removeCIAWrites;
    }


} // namespace sidwinder