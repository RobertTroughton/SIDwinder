#include "CPUState.h"
#include "CPU6510Impl.h"

/**
 * @brief Constructor for CPUState
 *
 * @param cpu Reference to the CPU implementation
 */
CPUState::CPUState(CPU6510Impl& cpu) : cpu_(cpu) {
    reset();
}

/**
 * @brief Reset the CPU state
 *
 * Sets all registers to their default values.
 */
void CPUState::reset() {
    pc_ = 0;
    sp_ = 0xFD;
    regA_ = regX_ = regY_ = 0;
    statusReg_ = static_cast<u8>(StatusFlag::Interrupt) | static_cast<u8>(StatusFlag::Unused);
    cycles_ = 0;

    // Reset register source info
    regSourceA_ = regSourceX_ = regSourceY_ = RegisterSourceInfo{};
}

/**
 * @brief Get the current program counter
 *
 * @return The program counter value
 */
u16 CPUState::getPC() const {
    return pc_;
}

/**
 * @brief Set the program counter
 *
 * @param value New program counter value
 */
void CPUState::setPC(u16 value) {
    pc_ = value;
}

/**
 * @brief Increment the program counter
 */
void CPUState::incrementPC() {
    pc_++;
}

/**
 * @brief Get the current stack pointer
 *
 * @return The stack pointer value
 */
u8 CPUState::getSP() const {
    return sp_;
}

/**
 * @brief Set the stack pointer
 *
 * @param value New stack pointer value
 */
void CPUState::setSP(u8 value) {
    sp_ = value;
}

/**
 * @brief Increment the stack pointer
 */
void CPUState::incrementSP() {
    sp_++;
}

/**
 * @brief Decrement the stack pointer
 */
void CPUState::decrementSP() {
    sp_--;
}

/**
 * @brief Get the A register value
 *
 * @return The accumulator value
 */
u8 CPUState::getA() const {
    return regA_;
}

/**
 * @brief Set the A register value
 *
 * @param value New accumulator value
 */
void CPUState::setA(u8 value) {
    regA_ = value;
}

/**
 * @brief Get the X register value
 *
 * @return The X index register value
 */
u8 CPUState::getX() const {
    return regX_;
}

/**
 * @brief Set the X register value
 *
 * @param value New X index register value
 */
void CPUState::setX(u8 value) {
    regX_ = value;
}

/**
 * @brief Get the Y register value
 *
 * @return The Y index register value
 */
u8 CPUState::getY() const {
    return regY_;
}

/**
 * @brief Set the Y register value
 *
 * @param value New Y index register value
 */
void CPUState::setY(u8 value) {
    regY_ = value;
}

/**
 * @brief Get the status register value
 *
 * @return The status register value
 */
u8 CPUState::getStatus() const {
    return statusReg_;
}

/**
 * @brief Set the status register value
 *
 * @param value New status register value
 */
void CPUState::setStatus(u8 value) {
    statusReg_ = value;
}

/**
 * @brief Set a specific status flag
 *
 * @param flag The flag to set/clear
 * @param value True to set, false to clear
 */
void CPUState::setFlag(StatusFlag flag, bool value) {
    if (value) {
        statusReg_ |= static_cast<u8>(flag);
    }
    else {
        statusReg_ &= ~static_cast<u8>(flag);
    }
}

/**
 * @brief Test if a status flag is set
 *
 * @param flag The flag to test
 * @return True if the flag is set, false otherwise
 */
bool CPUState::testFlag(StatusFlag flag) const {
    return (statusReg_ & static_cast<u8>(flag)) != 0;
}

/**
 * @brief Set Zero and Negative flags based on a value
 *
 * @param value The value to check
 */
void CPUState::setZN(u8 value) {
    setFlag(StatusFlag::Zero, value == 0);
    setFlag(StatusFlag::Negative, (value & 0x80) != 0);
}

/**
 * @brief Get the CPU cycle count
 *
 * @return The current cycle count
 */
u64 CPUState::getCycles() const {
    return cycles_;
}

/**
 * @brief Set the CPU cycle count
 *
 * @param newCycles New cycle count value
 */
void CPUState::setCycles(u64 newCycles) {
    cycles_ = newCycles;
}

/**
 * @brief Add cycles to the cycle count
 *
 * @param cycles Number of cycles to add
 */
void CPUState::addCycles(u64 cycles) {
    cycles_ += cycles;
}

/**
 * @brief Reset the CPU cycle counter
 */
void CPUState::resetCycles() {
    cycles_ = 0;
}

/**
 * @brief Get the source information for the A register
 *
 * @return Register source information for the accumulator
 */
RegisterSourceInfo CPUState::getRegSourceA() const {
    return regSourceA_;
}

/**
 * @brief Set the source information for the A register
 *
 * @param info Register source information
 */
void CPUState::setRegSourceA(const RegisterSourceInfo& info) {
    regSourceA_ = info;
}

/**
 * @brief Get the source information for the X register
 *
 * @return Register source information for the X register
 */
RegisterSourceInfo CPUState::getRegSourceX() const {
    return regSourceX_;
}

/**
 * @brief Set the source information for the X register
 *
 * @param info Register source information
 */
void CPUState::setRegSourceX(const RegisterSourceInfo& info) {
    regSourceX_ = info;
}

/**
 * @brief Get the source information for the Y register
 *
 * @return Register source information for the Y register
 */
RegisterSourceInfo CPUState::getRegSourceY() const {
    return regSourceY_;
}

/**
 * @brief Set the source information for the Y register
 *
 * @param info Register source information
 */
void CPUState::setRegSourceY(const RegisterSourceInfo& info) {
    regSourceY_ = info;
}