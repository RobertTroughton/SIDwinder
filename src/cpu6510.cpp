#include "cpu6510.h"
#include "6510/CPU6510Impl.h"

/**
 * @brief Default constructor for CPU6510
 *
 * Creates a new CPU6510 instance with its implementation.
 */
CPU6510::CPU6510() : pImpl_(std::make_unique<CPU6510Impl>()) {
}

/**
 * @brief Destructor for CPU6510
 *
 * Required for proper handling of the pImpl unique_ptr.
 */
CPU6510::~CPU6510() = default;

/**
 * @brief Reset the CPU to its initial state
 *
 * Delegates to the implementation class.
 */
void CPU6510::reset() {
    pImpl_->reset();
}

void CPU6510::resetRegistersAndFlags() {
    pImpl_->resetRegistersAndFlags();
}

/**
 * @brief Execute a single CPU instruction
 *
 * Delegates to the implementation class.
 */
void CPU6510::step() {
    pImpl_->step();
}

/**
 * @brief Execute a function at the specified address
 *
 * Delegates to the implementation class.
 *
 * @param address The memory address to execute from
 */
bool CPU6510::executeFunction(u16 address) {
    return pImpl_->executeFunction(address);
}

/**
 * @brief Jump to a specified memory address
 *
 * Delegates to the implementation class.
 *
 * @param address The target memory address to jump to
 */
void CPU6510::jumpTo(u16 address) {
    pImpl_->jumpTo(address);
}

/**
 * @brief Read a byte from memory
 *
 * Delegates to the implementation class.
 *
 * @param addr Memory address to read from
 * @return The byte at the specified address
 */
u8 CPU6510::readMemory(u16 addr) {
    return pImpl_->readMemory(addr);
}

/**
 * @brief Write a byte to memory (without tracking)
 *
 * Delegates to the implementation class.
 *
 * @param addr Memory address to write to
 * @param value Byte value to write
 */
void CPU6510::writeByte(u16 addr, u8 value) {
    pImpl_->writeByte(addr, value);
}

/**
 * @brief Write a byte to memory with tracking
 *
 * Delegates to the implementation class.
 *
 * @param addr Memory address to write to
 * @param value Byte value to write
 */
void CPU6510::writeMemory(u16 addr, u8 value) {
    pImpl_->writeMemory(addr, value);
}

/**
 * @brief Copy a block of data to memory
 *
 * Delegates to the implementation class.
 *
 * @param start Starting memory address
 * @param data Span of bytes to copy to memory
 */
void CPU6510::copyMemoryBlock(u16 start, std::span<const u8> data) {
    pImpl_->copyMemoryBlock(start, data);
}

/**
 * @brief Load binary data from a file into memory
 *
 * Delegates to the implementation class.
 *
 * @param filename Path to the binary file to load
 * @param loadAddress Starting memory address to load the data
 */
void CPU6510::loadData(const std::string& filename, u16 loadAddress) {
    pImpl_->loadData(filename, loadAddress);
}

/**
 * @brief Set the program counter to a specific address
 *
 * Delegates to the implementation class.
 *
 * @param address The new program counter value
 */
void CPU6510::setPC(u16 address) {
    pImpl_->setPC(address);
}

/**
 * @brief Get the current program counter value
 *
 * Delegates to the implementation class.
 *
 * @return The current program counter value
 */
u16 CPU6510::getPC() const {
    return pImpl_->getPC();
}

/**
 * @brief Set the stack pointer to a specific value
 *
 * Delegates to the implementation class.
 *
 * @param sp The new stack pointer value
 */
void CPU6510::setSP(u8 sp) {
    pImpl_->setSP(sp);
}

/**
 * @brief Get the current stack pointer value
 *
 * Delegates to the implementation class.
 *
 * @return The current stack pointer value
 */
u8 CPU6510::getSP() const {
    return pImpl_->getSP();
}

/**
 * @brief Get the total number of CPU cycles elapsed
 *
 * Delegates to the implementation class.
 *
 * @return The current cycle count
 */
u64 CPU6510::getCycles() const {
    return pImpl_->getCycles();
}

/**
 * @brief Set the CPU cycle counter to a specific value
 *
 * Delegates to the implementation class.
 *
 * @param newCycles The new cycle count value
 */
void CPU6510::setCycles(u64 newCycles) {
    pImpl_->setCycles(newCycles);
}

/**
 * @brief Reset the CPU cycle counter to zero
 *
 * Delegates to the implementation class.
 */
void CPU6510::resetCycles() {
    pImpl_->resetCycles();
}

/**
 * @brief Get the mnemonic string for an opcode
 *
 * Delegates to the implementation class.
 *
 * @param opcode The opcode value (0-255)
 * @return A string view of the mnemonic for the opcode
 */
std::string_view CPU6510::getMnemonic(u8 opcode) const {
    return pImpl_->getMnemonic(opcode);
}

/**
 * @brief Get the size of an instruction in bytes
 *
 * Delegates to the implementation class.
 *
 * @param opcode The opcode value (0-255)
 * @return The instruction size in bytes (1-3)
 */
u8 CPU6510::getInstructionSize(u8 opcode) const {
    return pImpl_->getInstructionSize(opcode);
}

/**
 * @brief Get the addressing mode for an opcode
 *
 * Delegates to the implementation class.
 *
 * @param opcode The opcode value (0-255)
 * @return The addressing mode for the opcode
 */
AddressingMode CPU6510::getAddressingMode(u8 opcode) const {
    return pImpl_->getAddressingMode(opcode);
}

/**
 * @brief Check if an instruction is an illegal/undocumented opcode
 *
 * Delegates to the implementation class.
 *
 * @param opcode The opcode value (0-255)
 * @return True if the opcode is an illegal instruction, false otherwise
 */
bool CPU6510::isIllegalInstruction(u8 opcode) const {
    return pImpl_->isIllegalInstruction(opcode);
}

/**
 * @brief Dump memory access information to a file
 *
 * Delegates to the implementation class.
 *
 * @param filename Path to the output file
 */
void CPU6510::dumpMemoryAccess(const std::string& filename) {
    pImpl_->dumpMemoryAccess(filename);
}

/**
 * @brief Get the range of index offsets used with an instruction
 *
 * Delegates to the implementation class.
 *
 * @param pc Program counter of the instruction
 * @return A pair containing the minimum and maximum index offsets used
 */
std::pair<u8, u8> CPU6510::getIndexRange(u16 pc) const {
    return pImpl_->getIndexRange(pc);
}

/**
 * @brief Get a span of CPU memory
 *
 * Delegates to the implementation class.
 *
 * @return Span of memory data
 */
std::span<const u8> CPU6510::getMemory() const {
    return pImpl_->getMemory();
}

/**
 * @brief Get a span of memory access flags
 *
 * Delegates to the implementation class.
 *
 * @return Span of memory access flags
 */
std::span<const u8> CPU6510::getMemoryAccess() const {
    return pImpl_->getMemoryAccess();
}

/**
 * @brief Get the program counter of the last instruction that wrote to an address
 *
 * Delegates to the implementation class.
 *
 * @param addr Memory address to check
 * @return Program counter of the last instruction that wrote to the address
 */
u16 CPU6510::getLastWriteTo(u16 addr) const {
    return pImpl_->getLastWriteTo(addr);
}

/**
 * @brief Get the full last-write-to-address tracking vector
 *
 * Delegates to the implementation class.
 *
 * @return Reference to the vector containing PC values of last write to each memory address
 */
const std::vector<u16>& CPU6510::getLastWriteToAddr() const {
    return pImpl_->getLastWriteToAddr();
}

/**
 * @brief Get the source information for the A register
 *
 * Delegates to the implementation class.
 *
 * @return Register source information for the accumulator
 */
RegisterSourceInfo CPU6510::getRegSourceA() const {
    return pImpl_->getRegSourceA();
}

/**
 * @brief Get the source information for the X register
 *
 * Delegates to the implementation class.
 *
 * @return Register source information for the X index register
 */
RegisterSourceInfo CPU6510::getRegSourceX() const {
    return pImpl_->getRegSourceX();
}

/**
 * @brief Get the source information for the Y register
 *
 * Delegates to the implementation class.
 *
 * @return Register source information for the Y index register
 */
RegisterSourceInfo CPU6510::getRegSourceY() const {
    return pImpl_->getRegSourceY();
}

/**
 * @brief Get the source information for a memory write
 *
 * Delegates to the implementation class.
 *
 * @param addr Memory address to check
 * @return Register source information for the last write to the address
 */
RegisterSourceInfo CPU6510::getWriteSourceInfo(u16 addr) const {
    return pImpl_->getWriteSourceInfo(addr);
}

/**
 * @brief Set the callback for indirect memory reads
 *
 * Delegates to the implementation class.
 *
 * @param callback Function to be called when an indirect memory read occurs
 */
void CPU6510::setOnIndirectReadCallback(IndirectReadCallback callback) {
    pImpl_->setOnIndirectReadCallback(std::move(callback));
}

/**
 * @brief Set the callback for memory writes
 *
 * Delegates to the implementation class.
 *
 * @param callback Function to be called when memory is written
 */
void CPU6510::setOnWriteMemoryCallback(MemoryWriteCallback callback) {
    pImpl_->setOnWriteMemoryCallback(std::move(callback));
}

/**
 * @brief Set the callback for writes to CIA registers
 *
 * Delegates to the implementation class.
 *
 * @param callback Function to be called when a CIA register is written
 */
void CPU6510::setOnCIAWriteCallback(MemoryWriteCallback callback) {
    pImpl_->setOnCIAWriteCallback(std::move(callback));
}

/**
 * @brief Set the callback for writes to SID registers
 *
 * Delegates to the implementation class.
 *
 * @param callback Function to be called when a SID register is written
 */
void CPU6510::setOnSIDWriteCallback(MemoryWriteCallback callback) {
    pImpl_->setOnSIDWriteCallback(std::move(callback));
}

/**
 * @brief Set the callback for writes to VIC registers
 *
 * Delegates to the implementation class.
 *
 * @param callback Function to be called when a VIC register is written
 */
void CPU6510::setOnVICWriteCallback(MemoryWriteCallback callback) {
    pImpl_->setOnVICWriteCallback(std::move(callback));
}

const MemoryDataFlow& CPU6510::getMemoryDataFlow() const {
    return pImpl_->getMemoryDataFlow();
}