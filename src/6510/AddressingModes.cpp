#include "AddressingModes.h"
#include "CPU6510Impl.h"
#include <iostream>

/**
 * @brief Constructor for AddressingModes
 *
 * @param cpu Reference to the CPU implementation
 */
AddressingModes::AddressingModes(CPU6510Impl& cpu) : cpu_(cpu) {
}

/**
 * @brief Calculate the target address for a given addressing mode
 *
 * Computes the target memory address based on the addressing mode,
 * handling various indexing modes and their cycle penalties.
 * Also records index register offsets for tracking purposes.
 *
 * @param mode The addressing mode to use
 * @return The calculated target address
 */
u16 AddressingModes::getAddress(AddressingMode mode) {
    // Get CPU state reference to access registers
    CPUState& cpuState = cpu_.cpuState_;

    // Get memory subsystem reference for memory access
    MemorySubsystem& memory = cpu_.memory_;

    // Track index register usage if applicable
    if (mode == AddressingMode::AbsoluteX || mode == AddressingMode::AbsoluteY ||
        mode == AddressingMode::ZeroPageX || mode == AddressingMode::ZeroPageY ||
        mode == AddressingMode::IndirectX || mode == AddressingMode::IndirectY) {

        u8 index = 0;
        if (mode == AddressingMode::AbsoluteY || mode == AddressingMode::ZeroPageY || mode == AddressingMode::IndirectY) {
            index = cpuState.getY();
        }
        else if (mode == AddressingMode::AbsoluteX || mode == AddressingMode::ZeroPageX || mode == AddressingMode::IndirectX) {
            index = cpuState.getX();
        }
        recordIndexOffset(cpuState.getPC(), index);
    }

    switch (mode) {
    case AddressingMode::Immediate: {
        u16 addr = cpuState.getPC();
        cpuState.incrementPC();
        return addr;
    }

    case AddressingMode::ZeroPage: {
        u16 addr = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        return addr;
    }

    case AddressingMode::ZeroPageX: {
        u8 zeroPageAddr = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        return (zeroPageAddr + cpuState.getX()) & 0xFF;
    }

    case AddressingMode::ZeroPageY: {
        u8 zeroPageAddr = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        return (zeroPageAddr + cpuState.getY()) & 0xFF;
    }

    case AddressingMode::Absolute: {
        u16 addr = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        addr |= (cpu_.fetchOperand(cpuState.getPC()) << 8);
        cpuState.incrementPC();
        return addr;
    }

    case AddressingMode::AbsoluteX: {
        const u16 base = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        const u16 highByte = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        const u16 baseAddr = base | (highByte << 8);
        const u16 addr = baseAddr + cpuState.getX();

        // Page boundary crossing adds a cycle
        if ((baseAddr & 0xFF00) != (addr & 0xFF00)) {
            cpuState.addCycles(1);
        }
        return addr;
    }

    case AddressingMode::AbsoluteY: {
        const u16 base = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        const u16 highByte = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        const u16 baseAddr = base | (highByte << 8);
        const u16 addr = baseAddr + cpuState.getY();

        // Page boundary crossing adds a cycle
        if ((baseAddr & 0xFF00) != (addr & 0xFF00)) {
            cpuState.addCycles(1);
        }
        return addr;
    }

    case AddressingMode::Indirect: {
        const u16 ptr = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        const u16 highByte = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        const u16 indirectAddr = ptr | (highByte << 8);

        // 6502 bug: JMP indirect does not handle page boundaries correctly
        const u8 low = memory.readMemory(indirectAddr);
        const u8 high = memory.readMemory((indirectAddr & 0xFF00) | ((indirectAddr + 1) & 0x00FF));

        return static_cast<u16>(low) | (static_cast<u16>(high) << 8);
    }

    case AddressingMode::IndirectX: {
        const u8 zp = (cpu_.fetchOperand(cpuState.getPC()) + cpuState.getX()) & 0xFF;
        cpuState.incrementPC();
        const u16 targetAddr = cpu_.readWordZeroPage(zp);

        // Notify callback if registered
        if (cpu_.onIndirectReadCallback_) {
            cpu_.onIndirectReadCallback_(cpu_.originalPc_, zp, targetAddr);
        }

        return targetAddr;
    }

    case AddressingMode::IndirectY: {
        const u8 zpAddr = cpu_.fetchOperand(cpuState.getPC());
        cpuState.incrementPC();
        const u16 base = cpu_.readWordZeroPage(zpAddr);
        const u16 addr = base + cpuState.getY();

        // Notify callback if registered
        if (cpu_.onIndirectReadCallback_) {
            cpu_.onIndirectReadCallback_(cpu_.originalPc_, zpAddr, addr);
        }

        // Page boundary crossing adds a cycle
        if ((base & 0xFF00) != (addr & 0xFF00)) {
            cpuState.addCycles(1);
        }
        return addr;
    }

    default:
        std::cout << "Unsupported addressing mode: " << static_cast<int>(mode) << std::endl;
        return 0;
    }
}

/**
 * @brief Record the index offset used for a memory access
 *
 * Delegates to the CPU implementation for tracking the range of index values.
 *
 * @param pc Program counter of the instruction
 * @param offset Index offset value (X or Y register)
 */
void AddressingModes::recordIndexOffset(u16 pc, u8 offset) {
    cpu_.recordIndexOffset(pc, offset);
}