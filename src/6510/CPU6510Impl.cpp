#include "CPU6510Impl.h"
#include "SIDwinderUtils.h"

#include <algorithm>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <set>
#include <sstream>

/**
 * @brief Default constructor for CPU6510Impl
 *
 * Initializes the CPU components and resets the CPU state.
 */
CPU6510Impl::CPU6510Impl()
    : cpuState_(*this),
    memory_(*this),
    instructionExecutor_(*this),
    addressingModes_(*this)
{
    reset();
}

/**
 * @brief Reset the CPU to its initial state
 *
 * Initializes memory tracking arrays, resets registers to their default values,
 * sets the status register to default flags, and resets the cycle counter.
 */
void CPU6510Impl::reset() {
    // Reset CPU state
    cpuState_.reset();

    // Reset memory
    memory_.reset();

    // Reset program counter
    originalPc_ = 0;

    // Clear any existing callbacks
    onIndirectReadCallback_ = nullptr;
    onWriteMemoryCallback_ = nullptr;
    onCIAWriteCallback_ = nullptr;
    onSIDWriteCallback_ = nullptr;
    onVICWriteCallback_ = nullptr;
}

void CPU6510Impl::resetRegistersAndFlags() {
    // Reset A, X, Y registers to 0
    cpuState_.setA(0);
    cpuState_.setX(0);
    cpuState_.setY(0);

    // Reset status register to default value
    // Keep Unused flag set (bit 5), set Interrupt flag
    cpuState_.setStatus(static_cast<u8>(StatusFlag::Interrupt) | static_cast<u8>(StatusFlag::Unused));
}

/**
 * @brief Execute a single CPU instruction
 *
 * Fetches the opcode at the current program counter, increments the program counter,
 * executes the instruction, and updates the cycle count.
 */
void CPU6510Impl::step() {
    originalPc_ = cpuState_.getPC();

    const u8 opcode = fetchOpcode(cpuState_.getPC());
    cpuState_.incrementPC();

    const OpcodeInfo& info = opcodeTable_[opcode];

    instructionExecutor_.execute(info.instruction, info.mode);

    cpuState_.addCycles(info.cycles);
}

/**
 * @brief Execute a function at the specified address
 *
 * Simulates a JSR (Jump to Subroutine) call to the specified address and
 * executes instructions until the matching RTS (Return from Subroutine) is reached.
 * Includes various safety checks to prevent infinite loops and detect problematic jumps.
 *
 * @param address The memory address to execute from
 */
bool CPU6510Impl::executeFunction(u32 address) {
    // Maximum number of steps to prevent infinite loops
    const int MAX_STEPS = DEFAULT_SID_EMULATION_FRAMES;
    int stepCount = 0;

    // Track the last few PCs to detect tight loops
    const int HISTORY_SIZE = 8;
    u32 pcHistory[HISTORY_SIZE] = { 0 };
    int historyIndex = 0;

    // Track potentially dangerous jump targets
    bool jumpToZeroPageTracked = false;
    std::set<u32> reportedProblematicJumps;

    // Simulate JSR manually
    const u32 returnAddress = cpuState_.getPC() - 1; // What JSR would have pushed (the address of the last byte of JSR instruction)

    push((returnAddress >> 8) & 0xFF); // Push high byte
    push(returnAddress & 0xFF);         // Push low byte

    cpuState_.setPC(address);

    const u8 targetSP = cpuState_.getSP(); // After pushing return address (so after manual JSR)

    while (stepCount < MAX_STEPS) {
        const u32 currentPC = cpuState_.getPC();

        // Track PC history for loop detection
        pcHistory[historyIndex] = currentPC;
        historyIndex = (historyIndex + 1) % HISTORY_SIZE;

        // Check for problematic PC values
        if (currentPC < 0x0002) {  // $00 or $01 is definitely a problem
            sidwinder::util::Logger::error("CRITICAL: Execution at $" +
                sidwinder::util::wordToHex(currentPC) +
                " detected - illegal jump target");
            // Break to avoid immediate crash
            return false;
        }
        else if (currentPC < 0x0100 && !jumpToZeroPageTracked) {  // Any zero page execution
            jumpToZeroPageTracked = true; // Only log once to avoid spam
        }

        // Fetch the opcode
        const u8 opcode = fetchOpcode(currentPC);

        // Special handling for key instructions even when tracing is disabled
        const auto mode = getAddressingMode(opcode);
        const int size = getInstructionSize(opcode);

        // Track JMP and JSR instructions to potentially problematic addresses
        if (size == 3 && (opcode == 0x4C || opcode == 0x20)) { // JMP or JSR
            const u32 operand = memory_.getMemoryAt(currentPC + 1) |
                (memory_.getMemoryAt(currentPC + 2) << 8);

            // Check for jumps to very low addresses
            if (operand < 0x0002 &&
                reportedProblematicJumps.find(operand) == reportedProblematicJumps.end()) {

                sidwinder::util::Logger::error("CRITICAL: " + std::string(getMnemonic(opcode)) +
                    " at $" + sidwinder::util::wordToHex(currentPC) +
                    " to illegal address $" +
                    sidwinder::util::wordToHex(operand));
                reportedProblematicJumps.insert(operand);
                return false;
            }
            else if (operand < 0x0100 &&
                reportedProblematicJumps.find(operand) == reportedProblematicJumps.end()) {
                reportedProblematicJumps.insert(operand);
            }
        }

        // Execute the instruction
        step();
        stepCount++;

        // Check if we've returned from the function
        if (opcode == 0x60) { // RTS
            if (cpuState_.getSP() == targetSP + 2) { // Stack unwound
                break;
            }
        }
    }

    // Check if we hit the step limit
    if (stepCount >= MAX_STEPS) {
        sidwinder::util::Logger::error("Function execution aborted after " + std::to_string(MAX_STEPS) +
            " steps - possible infinite loop");
        sidwinder::util::Logger::error("Last PC: $" + sidwinder::util::wordToHex(cpuState_.getPC()) +
            ", SP: $" + sidwinder::util::byteToHex(cpuState_.getSP()));

        // Dump more diagnostic info
        std::ostringstream pcHistoryStr;
        pcHistoryStr << "Recent PC history: ";
        for (int i = 0; i < HISTORY_SIZE; i++) {
            int idx = (historyIndex + i) % HISTORY_SIZE;
            pcHistoryStr << "$" << sidwinder::util::wordToHex(pcHistory[idx]) << " ";
        }
        sidwinder::util::Logger::error(pcHistoryStr.str());
        return false;
    }
    return true;
}

/**
 * @brief Jump to a specified memory address
 *
 * Updates the program counter to the specified address.
 *
 * @param address The target memory address to jump to
 */
void CPU6510Impl::jumpTo(u32 address) {
    cpuState_.setPC(address);
}

/**
 * @brief Read a byte from memory
 *
 * Delegates to the memory subsystem.
 *
 * @param addr Memory address to read from
 * @return The byte at the specified address
 */
u8 CPU6510Impl::readMemory(u32 addr) {
    return memory_.readMemory(addr);
}

/**
 * @brief Write a byte to memory (without tracking)
 *
 * Delegates to the memory subsystem.
 *
 * @param addr Memory address to write to
 * @param value Byte value to write
 */
void CPU6510Impl::writeByte(u32 addr, u8 value) {
    memory_.writeByte(addr, value);
}

/**
 * @brief Write a byte to memory with tracking
 *
 * Delegates to the memory subsystem.
 *
 * @param addr Memory address to write to
 * @param value Byte value to write
 */
void CPU6510Impl::writeMemory(u32 addr, u8 value) {
    memory_.writeMemory(addr, value, originalPc_);

    // Call the write callbacks if registered
    if (onWriteMemoryCallback_) {
        onWriteMemoryCallback_(addr, value);
    }

    if (onCIAWriteCallback_ && (addr >= 0xdc00) && (addr <= 0xdcff)) {
        onCIAWriteCallback_(addr, value);
    }

    if (onSIDWriteCallback_ && (addr >= 0xd400) && (addr <= 0xd7ff)) {
        onSIDWriteCallback_(addr, value);
    }

    if (onVICWriteCallback_ && (addr >= 0xd000) && (addr <= 0xd3ff)) {
        onVICWriteCallback_(addr, value);
    }
}

/**
 * @brief Copy a block of data to memory
 *
 * Delegates to the memory subsystem.
 *
 * @param start Starting memory address
 * @param data Span of bytes to copy to memory
 */
void CPU6510Impl::copyMemoryBlock(u32 start, std::span<const u8> data) {
    memory_.copyMemoryBlock(start, data);
}

/**
 * @brief Load binary data from a file into memory
 *
 * Reads a binary file and loads its contents into memory starting at
 * the specified address.
 *
 * @param filename Path to the binary file to load
 * @param loadAddress Starting memory address to load the data
 * @throws std::runtime_error if file cannot be opened or data exceeds memory bounds
 */
void CPU6510Impl::loadData(const std::string& filename, u32 loadAddress) {
    std::ifstream file(filename, std::ios::binary);
    if (!file) {
        throw std::runtime_error("Failed to open file: " + filename);
    }

    u32 addr = loadAddress;
    u8 byte;
    while (file.read(reinterpret_cast<char*>(&byte), 1)) {
        memory_.writeByte(addr++, byte);
    }
}

/**
 * @brief Set the program counter to a specific address
 *
 * Delegates to the CPU state component.
 *
 * @param address The new program counter value
 */
void CPU6510Impl::setPC(u32 address) {
    cpuState_.setPC(address);
}

/**
 * @brief Get the current program counter value
 *
 * Delegates to the CPU state component.
 *
 * @return The current program counter value
 */
u32 CPU6510Impl::getPC() const {
    return cpuState_.getPC();
}

/**
 * @brief Set the stack pointer to a specific value
 *
 * Delegates to the CPU state component.
 *
 * @param sp The new stack pointer value
 */
void CPU6510Impl::setSP(u8 sp) {
    cpuState_.setSP(sp);
}

/**
 * @brief Get the current stack pointer value
 *
 * Delegates to the CPU state component.
 *
 * @return The current stack pointer value
 */
u8 CPU6510Impl::getSP() const {
    return cpuState_.getSP();
}

/**
 * @brief Get the total number of CPU cycles elapsed
 *
 * Delegates to the CPU state component.
 *
 * @return The current cycle count
 */
u64 CPU6510Impl::getCycles() const {
    return cpuState_.getCycles();
}

/**
 * @brief Set the CPU cycle counter to a specific value
 *
 * Delegates to the CPU state component.
 *
 * @param newCycles The new cycle count value
 */
void CPU6510Impl::setCycles(u64 newCycles) {
    cpuState_.setCycles(newCycles);
}

/**
 * @brief Reset the CPU cycle counter to zero
 *
 * Delegates to the CPU state component.
 */
void CPU6510Impl::resetCycles() {
    cpuState_.resetCycles();
}

/**
 * @brief Fetch an opcode from memory
 *
 * Reads a byte from memory at the specified address and marks it as an executed opcode
 * in the memory access tracking.
 *
 * @param addr Memory address to fetch the opcode from
 * @return The opcode byte at the specified address
 */
u8 CPU6510Impl::fetchOpcode(u32 addr) {
    memory_.markMemoryAccess(addr, MemoryAccessFlag::Execute);
    memory_.markMemoryAccess(addr, MemoryAccessFlag::OpCode);
    return memory_.getMemoryAt(addr);
}

/**
 * @brief Fetch an operand from memory
 *
 * Reads a byte from memory at the specified address and marks it as executed
 * in the memory access tracking.
 *
 * @param addr Memory address to fetch the operand from
 * @return The operand byte at the specified address
 */
u8 CPU6510Impl::fetchOperand(u32 addr) {
    memory_.markMemoryAccess(addr, MemoryAccessFlag::Execute);
    return memory_.getMemoryAt(addr);
}

/**
 * @brief Read a byte using the specified addressing mode
 *
 * Reads a byte from memory using the appropriate access method based on the addressing mode.
 *
 * @param addr The target memory address
 * @param mode The addressing mode to use
 * @return The byte read from memory
 */
u8 CPU6510Impl::readByAddressingMode(u32 addr, AddressingMode mode) {
    switch (mode) {
    case AddressingMode::Indirect:
    case AddressingMode::Immediate:
        return fetchOperand(addr);
    default:
        return readMemory(addr);
    }
}

/**
 * @brief Push a byte onto the stack
 *
 * Writes a byte to the stack at the current stack pointer location
 * and decrements the stack pointer.
 *
 * @param value Byte value to push onto the stack
 */
void CPU6510Impl::push(u8 value) {
    memory_.writeByte(0x0100 + cpuState_.getSP(), value);
    cpuState_.decrementSP();
}

/**
 * @brief Pop a byte from the stack
 *
 * Increments the stack pointer and reads a byte from the stack
 * at the updated stack pointer location.
 *
 * @return The byte popped from the stack
 */
u8 CPU6510Impl::pop() {
    cpuState_.incrementSP();
    return memory_.getMemoryAt(0x0100 + cpuState_.getSP());
}

/**
 * @brief Read a 16-bit word from memory
 *
 * Reads two consecutive bytes from memory and combines them into a 16-bit word
 * (little-endian: low byte first, then high byte).
 *
 * @param addr Starting memory address
 * @return The 16-bit word read from memory
 */
u16 CPU6510Impl::readWord(u32 addr) {
    const u8 low = readMemory(addr);
    const u8 high = readMemory(addr + 1);
    return static_cast<u16>(low) | (static_cast<u16>(high) << 8);
}

/**
 * @brief Read a 16-bit word from the zero page
 *
 * Reads two bytes from the zero page with address wrapping and combines them
 * into a 16-bit word (little-endian).
 *
 * @param addr Zero page starting address (0-255)
 * @return The 16-bit word read from the zero page
 */
u16 CPU6510Impl::readWordZeroPage(u8 addr) {
    const u8 low = readMemory(addr);
    const u8 high = readMemory((addr + 1) & 0xFF); // wrap around zero page
    return static_cast<u16>(low) | (static_cast<u16>(high) << 8);
}

/**
 * @brief Get the mnemonic string for an opcode
 *
 * @param opcode The opcode value (0-255)
 * @return A string view of the mnemonic for the opcode
 */
std::string_view CPU6510Impl::getMnemonic(u8 opcode) const {
    return opcodeTable_[opcode].mnemonic;
}

/**
 * @brief Get the size of an instruction in bytes
 *
 * Determines the number of bytes an instruction occupies in memory
 * based on its addressing mode.
 *
 * @param opcode The opcode value (0-255)
 * @return The instruction size in bytes (1-3)
 */
u8 CPU6510Impl::getInstructionSize(u8 opcode) const {
    const AddressingMode mode = opcodeTable_[opcode].mode;
    switch (mode) {
    case AddressingMode::Immediate:
    case AddressingMode::ZeroPage:
    case AddressingMode::ZeroPageX:
    case AddressingMode::ZeroPageY:
    case AddressingMode::Relative:
    case AddressingMode::IndirectX:
    case AddressingMode::IndirectY:
        return 2;
    case AddressingMode::Absolute:
    case AddressingMode::AbsoluteX:
    case AddressingMode::AbsoluteY:
    case AddressingMode::Indirect:
        return 3;
    case AddressingMode::Accumulator:
    case AddressingMode::Implied:
    default:
        return 1;
    }
}

/**
 * @brief Get the addressing mode for an opcode
 *
 * @param opcode The opcode value (0-255)
 * @return The addressing mode for the opcode
 */
AddressingMode CPU6510Impl::getAddressingMode(u8 opcode) const {
    return opcodeTable_[opcode].mode;
}

/**
 * @brief Check if an instruction is an illegal/undocumented opcode
 *
 * @param opcode The opcode value (0-255)
 * @return True if the opcode is an illegal instruction, false otherwise
 */
bool CPU6510Impl::isIllegalInstruction(u8 opcode) const {
    return opcodeTable_[opcode].illegal;
}

/**
 * @brief Record the index offset used for a memory access
 *
 * Tracks the range of index values used with a particular instruction,
 * useful for disassembly and memory analysis.
 *
 * @param pc Program counter of the instruction
 * @param offset Index offset value (X or Y register)
 */
void CPU6510Impl::recordIndexOffset(u32 pc, u8 offset) {
    pcIndexRanges_[pc].update(offset);
}

/**
 * @brief Get the range of index offsets used with an instruction
 *
 * @param pc Program counter of the instruction
 * @return A pair containing the minimum and maximum index offsets used
 */
std::pair<u8, u8> CPU6510Impl::getIndexRange(u32 pc) const {
    auto it = pcIndexRanges_.find(pc);
    if (it == pcIndexRanges_.end()) {
        return { 0, 0 };
    }
    return it->second.getRange();
}

/**
 * @brief Dump memory access information to a file
 *
 * Writes information about how each memory location was accessed
 * (read, write, execute, jump target) to a file for analysis.
 *
 * @param filename Path to the output file
 */
void CPU6510Impl::dumpMemoryAccess(const std::string& filename) {
    memory_.dumpMemoryAccess(filename);
}

/**
 * @brief Get a span of CPU memory
 *
 * @return Span of memory data
 */
std::span<const u8> CPU6510Impl::getMemory() const {
    return memory_.getMemory();
}

/**
 * @brief Get a span of memory access flags
 *
 * @return Span of memory access flags
 */
std::span<const u8> CPU6510Impl::getMemoryAccess() const {
    return memory_.getMemoryAccess();
}

/**
 * @brief Get the program counter of the last instruction that wrote to an address
 *
 * @param addr Memory address to check
 * @return Program counter of the last instruction that wrote to the address
 */
u32 CPU6510Impl::getLastWriteTo(u32 addr) const {
    return memory_.getLastWriteTo(addr);
}

/**
 * @brief Get the full last-write-to-address tracking vector
 *
 * @return Reference to the vector containing PC values of last write to each memory address
 */
const std::vector<u32>& CPU6510Impl::getLastWriteToAddr() const {
    return memory_.getLastWriteToAddr();
}

/**
 * @brief Get the source information for the A register
 *
 * @return Register source information for the accumulator
 */
RegisterSourceInfo CPU6510Impl::getRegSourceA() const {
    return cpuState_.getRegSourceA();
}

/**
 * @brief Get the source information for the X register
 *
 * @return Register source information for the X index register
 */
RegisterSourceInfo CPU6510Impl::getRegSourceX() const {
    return cpuState_.getRegSourceX();
}

/**
 * @brief Get the source information for the Y register
 *
 * @return Register source information for the Y index register
 */
RegisterSourceInfo CPU6510Impl::getRegSourceY() const {
    return cpuState_.getRegSourceY();
}

/**
 * @brief Get the source information for a memory write
 *
 * @param addr Memory address to check
 * @return Register source information for the last write to the address
 */
RegisterSourceInfo CPU6510Impl::getWriteSourceInfo(u32 addr) const {
    return memory_.getWriteSourceInfo(addr);
}

/**
 * @brief Set the callback for indirect memory reads
 *
 * @param callback Function to be called when an indirect memory read occurs
 */
void CPU6510Impl::setOnIndirectReadCallback(IndirectReadCallback callback) {
    onIndirectReadCallback_ = std::move(callback);
}

/**
 * @brief Set the callback for memory writes
 *
 * @param callback Function to be called when memory is written
 */
void CPU6510Impl::setOnWriteMemoryCallback(MemoryWriteCallback callback) {
    onWriteMemoryCallback_ = std::move(callback);
}

/**
 * @brief Set the callback for writes to CIA registers
 *
 * @param callback Function to be called when a CIA register is written
 */
void CPU6510Impl::setOnCIAWriteCallback(MemoryWriteCallback callback) {
    onCIAWriteCallback_ = std::move(callback);
}

/**
 * @brief Set the callback for writes to SID registers
 *
 * @param callback Function to be called when a SID register is written
 */
void CPU6510Impl::setOnSIDWriteCallback(MemoryWriteCallback callback) {
    onSIDWriteCallback_ = std::move(callback);
}

/**
 * @brief Set the callback for writes to VIC registers
 *
 * @param callback Function to be called when a VIC register is written
 */
void CPU6510Impl::setOnVICWriteCallback(MemoryWriteCallback callback) {
    onVICWriteCallback_ = std::move(callback);
}

void CPU6510Impl::setOnMemoryFlowCallback(MemoryFlowCallback callback) {
    onMemoryFlowCallback_ = std::move(callback);
}

void CPU6510Impl::setOnComparisonCallback(ComparisonCallback callback) {
    onComparisonCallback_ = std::move(callback);
}

const MemoryDataFlow& CPU6510Impl::getMemoryDataFlow() const {
    return memory_.getMemoryDataFlow();
}