#include "InstructionExecutor.h"
#include "CPU6510Impl.h"
#include <iostream>

/**
 * @brief Constructor for InstructionExecutor
 *
 * @param cpu Reference to the CPU implementation
 */
InstructionExecutor::InstructionExecutor(CPU6510Impl& cpu) : cpu_(cpu) {
}

/**
 * @brief Execute an instruction
 *
 * Main entry point for instruction execution.
 *
 * @param instr The instruction to execute
 * @param mode The addressing mode to use
 */
void InstructionExecutor::execute(Instruction instr, AddressingMode mode) {
    executeInstruction(instr, mode);
}

/**
 * @brief Execute an instruction based on its type
 *
 * Dispatches the instruction to the appropriate handler method based on its category.
 *
 * @param instr The instruction to execute
 * @param mode The addressing mode to use
 */
void InstructionExecutor::executeInstruction(Instruction instr, AddressingMode mode) {
    // Group instructions by function
    switch (instr) {
        // Load instructions
    case Instruction::LDA:
    case Instruction::LDX:
    case Instruction::LDY:
    case Instruction::LAX:
        executeLoad(instr, mode);
        break;

        // Store instructions
    case Instruction::STA:
    case Instruction::STX:
    case Instruction::STY:
    case Instruction::SAX:
        executeStore(instr, mode);
        break;

        // Arithmetic instructions
    case Instruction::ADC:
    case Instruction::SBC:
    case Instruction::INC:
    case Instruction::INX:
    case Instruction::INY:
    case Instruction::DEC:
    case Instruction::DEX:
    case Instruction::DEY:
        executeArithmetic(instr, mode);
        break;

        // Logical instructions
    case Instruction::AND:
    case Instruction::ORA:
    case Instruction::EOR:
    case Instruction::BIT:
        executeLogical(instr, mode);
        break;

        // Branch instructions
    case Instruction::BCC:
    case Instruction::BCS:
    case Instruction::BEQ:
    case Instruction::BMI:
    case Instruction::BNE:
    case Instruction::BPL:
    case Instruction::BVC:
    case Instruction::BVS:
        executeBranch(instr, mode);
        break;

        // Jump instructions
    case Instruction::JMP:
    case Instruction::JSR:
    case Instruction::RTS:
    case Instruction::RTI:
    case Instruction::BRK:
        executeJump(instr, mode);
        break;

        // Stack instructions
    case Instruction::PHA:
    case Instruction::PHP:
    case Instruction::PLA:
    case Instruction::PLP:
        executeStack(instr, mode);
        break;

        // Register transfer instructions
    case Instruction::TAX:
    case Instruction::TAY:
    case Instruction::TXA:
    case Instruction::TYA:
    case Instruction::TSX:
    case Instruction::TXS:
        executeRegister(instr, mode);
        break;

        // Flag instructions
    case Instruction::CLC:
    case Instruction::CLD:
    case Instruction::CLI:
    case Instruction::CLV:
    case Instruction::SEC:
    case Instruction::SED:
    case Instruction::SEI:
        executeFlag(instr, mode);
        break;

        // Shift instructions
    case Instruction::ASL:
    case Instruction::LSR:
    case Instruction::ROL:
    case Instruction::ROR:
        executeShift(instr, mode);
        break;

        // Compare instructions
    case Instruction::CMP:
    case Instruction::CPX:
    case Instruction::CPY:
        executeCompare(instr, mode);
        break;

        // NOP instruction
    case Instruction::NOP:
        // No operation, just consume cycles
        break;

        // Illegal instructions
    case Instruction::SLO:
    case Instruction::RLA:
    case Instruction::SRE:
    case Instruction::RRA:
    case Instruction::DCP:
    case Instruction::ISC:
    case Instruction::ANC:
    case Instruction::ALR:
    case Instruction::ARR:
    case Instruction::AXS:
    case Instruction::KIL:
    case Instruction::LAS:
    case Instruction::AHX:
    case Instruction::TAS:
    case Instruction::SHA:
    case Instruction::SHX:
    case Instruction::SHY:
    case Instruction::XAA:
        executeIllegal(instr, mode);
        break;

    default:
        std::cout << "Unimplemented instruction: " << static_cast<int>(instr) << std::endl;
        break;
    }
}

/**
 * @brief Execute load instructions (LDA, LDX, LDY, LAX)
 *
 * Handles all register load operations, updating the appropriate register
 * and processor status flags.
 *
 * @param instr The load instruction to execute
 * @param mode The addressing mode to use
 */
void InstructionExecutor::executeLoad(Instruction instr, AddressingMode mode) {
    // Get the target address
    const u16 addr = cpu_.addressingModes_.getAddress(mode);

    // Read the value using the appropriate method
    const u8 value = cpu_.readByAddressingMode(addr, mode);

    // Get index register value if applicable
    u8 index = 0;
    if (mode == AddressingMode::AbsoluteY || mode == AddressingMode::ZeroPageY || mode == AddressingMode::IndirectY) {
        index = cpu_.cpuState_.getY();
    }
    else if (mode == AddressingMode::AbsoluteX || mode == AddressingMode::ZeroPageX || mode == AddressingMode::IndirectX) {
        index = cpu_.cpuState_.getX();
    }

    // Create register source info
    RegisterSourceInfo sourceInfo = {
        RegisterSourceInfo::SourceType::Memory,
        addr,
        value,
        index
    };

    // Update appropriate register based on instruction
    switch (instr) {
    case Instruction::LDA:
        cpu_.cpuState_.setA(value);
        cpu_.cpuState_.setRegSourceA(sourceInfo);
        break;

    case Instruction::LDX:
        cpu_.cpuState_.setX(value);
        cpu_.cpuState_.setRegSourceX(sourceInfo);
        break;

    case Instruction::LDY:
        cpu_.cpuState_.setY(value);
        cpu_.cpuState_.setRegSourceY(sourceInfo);
        break;

    case Instruction::LAX:
        // LAX = LDA + LDX combined (illegal opcode)
        cpu_.cpuState_.setA(value);
        cpu_.cpuState_.setX(value);
        cpu_.cpuState_.setRegSourceA(sourceInfo);
        cpu_.cpuState_.setRegSourceX(sourceInfo);
        break;

    default:
        break;
    }

    // Set processor status flags
    if (instr == Instruction::LDX || instr == Instruction::LAX) {
        cpu_.cpuState_.setZN(cpu_.cpuState_.getX());
    }
    else if (instr == Instruction::LDY) {
        cpu_.cpuState_.setZN(cpu_.cpuState_.getY());
    }
    else {
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
    }
}

/**
 * @brief Execute store instructions (STA, STX, STY, SAX)
 *
 * Handles all register store operations, writing register values to memory
 * and updating tracking information.
 *
 * @param instr The store instruction to execute
 * @param mode The addressing mode to use
 */
void InstructionExecutor::executeStore(Instruction instr, AddressingMode mode) {
    const u16 addr = cpu_.addressingModes_.getAddress(mode);

    switch (instr) {
    case Instruction::STA:
        cpu_.writeMemory(addr, cpu_.cpuState_.getA());
        cpu_.memory_.setWriteSourceInfo(addr, cpu_.cpuState_.getRegSourceA());
        break;

    case Instruction::STX:
        cpu_.writeMemory(addr, cpu_.cpuState_.getX());
        cpu_.memory_.setWriteSourceInfo(addr, cpu_.cpuState_.getRegSourceX());
        break;

    case Instruction::STY:
        cpu_.writeMemory(addr, cpu_.cpuState_.getY());
        cpu_.memory_.setWriteSourceInfo(addr, cpu_.cpuState_.getRegSourceY());
        break;

    case Instruction::SAX:
        // SAX = Store A AND X (illegal opcode)
        cpu_.writeMemory(addr, cpu_.cpuState_.getA() & cpu_.cpuState_.getX());
        break;

    default:
        break;
    }
}

/**
 * @brief Execute arithmetic instructions
 *
 * Handles all arithmetic operations (ADC, SBC, INC, DEC, etc.),
 * updating registers, memory, and processor status flags.
 *
 * @param instr The arithmetic instruction to execute
 * @param mode The addressing mode to use
 */
void InstructionExecutor::executeArithmetic(Instruction instr, AddressingMode mode) {
    switch (instr) {
    case Instruction::ADC: {
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);

        if (cpu_.cpuState_.testFlag(StatusFlag::Decimal)) {
            // BCD arithmetic in decimal mode
            u8 al = (cpu_.cpuState_.getA() & 0x0F) + (value & 0x0F) + (cpu_.cpuState_.testFlag(StatusFlag::Carry) ? 1 : 0);
            u8 ah = (cpu_.cpuState_.getA() >> 4) + (value >> 4);

            if (al > 9) {
                al -= 10;
                ah++;
            }

            if (ah > 9) {
                ah -= 10;
                cpu_.cpuState_.setFlag(StatusFlag::Carry, true);
            }
            else {
                cpu_.cpuState_.setFlag(StatusFlag::Carry, false);
            }

            const u8 result = (ah << 4) | (al & 0x0F);
            cpu_.cpuState_.setA(result);
            cpu_.cpuState_.setZN(result);
            // Note: Overflow in decimal mode is undefined on the 6502
        }
        else {
            // Normal binary arithmetic
            const u16 sum = static_cast<u16>(cpu_.cpuState_.getA()) + static_cast<u16>(value) +
                (cpu_.cpuState_.testFlag(StatusFlag::Carry) ? 1 : 0);

            cpu_.cpuState_.setFlag(StatusFlag::Carry, sum > 0xFF);
            cpu_.cpuState_.setFlag(StatusFlag::Zero, (sum & 0xFF) == 0);
            cpu_.cpuState_.setFlag(StatusFlag::Overflow,
                ((~(cpu_.cpuState_.getA() ^ value) & (cpu_.cpuState_.getA() ^ sum) & 0x80) != 0));
            cpu_.cpuState_.setFlag(StatusFlag::Negative, (sum & 0x80) != 0);

            cpu_.cpuState_.setA(static_cast<u8>(sum & 0xFF));
        }
        break;
    }

    case Instruction::SBC: {
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);

        // SBC is ADC with inverted operand
        const u8 invertedValue = value ^ 0xFF;

        if (cpu_.cpuState_.testFlag(StatusFlag::Decimal)) {
            // BCD arithmetic in decimal mode
            u8 al = (cpu_.cpuState_.getA() & 0x0F) + (invertedValue & 0x0F) +
                (cpu_.cpuState_.testFlag(StatusFlag::Carry) ? 1 : 0);
            u8 ah = (cpu_.cpuState_.getA() >> 4) + (invertedValue >> 4);

            if (al > 9) {
                al -= 10;
                ah++;
            }

            if (ah > 9) {
                ah -= 10;
                cpu_.cpuState_.setFlag(StatusFlag::Carry, true);
            }
            else {
                cpu_.cpuState_.setFlag(StatusFlag::Carry, false);
            }

            const u8 result = (ah << 4) | (al & 0x0F);
            cpu_.cpuState_.setA(result);
            cpu_.cpuState_.setZN(result);
        }
        else {
            // Normal binary arithmetic
            const u16 diff = static_cast<u16>(cpu_.cpuState_.getA()) +
                static_cast<u16>(invertedValue) +
                (cpu_.cpuState_.testFlag(StatusFlag::Carry) ? 1 : 0);

            cpu_.cpuState_.setFlag(StatusFlag::Carry, diff > 0xFF);
            cpu_.cpuState_.setFlag(StatusFlag::Zero, (diff & 0xFF) == 0);
            cpu_.cpuState_.setFlag(StatusFlag::Overflow,
                ((~(cpu_.cpuState_.getA() ^ invertedValue) & (cpu_.cpuState_.getA() ^ diff) & 0x80) != 0));
            cpu_.cpuState_.setFlag(StatusFlag::Negative, (diff & 0x80) != 0);

            cpu_.cpuState_.setA(static_cast<u8>(diff & 0xFF));
        }
        break;
    }

    case Instruction::INC: {
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);
        value++;
        cpu_.writeMemory(addr, value);
        cpu_.cpuState_.setZN(value);
        break;
    }

    case Instruction::INX:
        cpu_.cpuState_.setX(cpu_.cpuState_.getX() + 1);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getX());
        break;

    case Instruction::INY:
        cpu_.cpuState_.setY(cpu_.cpuState_.getY() + 1);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getY());
        break;

    case Instruction::DEC: {
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);
        value--;
        cpu_.writeMemory(addr, value);
        cpu_.cpuState_.setZN(value);
        break;
    }

    case Instruction::DEX:
        cpu_.cpuState_.setX(cpu_.cpuState_.getX() - 1);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getX());
        break;

    case Instruction::DEY:
        cpu_.cpuState_.setY(cpu_.cpuState_.getY() - 1);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getY());
        break;

    default:
        break;
    }
}

/**
 * @brief Execute logical instructions (AND, ORA, EOR, BIT)
 *
 * Handles all logical operations between the accumulator and memory,
 * updating the accumulator and processor status flags.
 *
 * @param instr The logical instruction to execute
 * @param mode The addressing mode to use
 */
void InstructionExecutor::executeLogical(Instruction instr, AddressingMode mode) {
    const u16 addr = cpu_.addressingModes_.getAddress(mode);
    const u8 value = cpu_.readByAddressingMode(addr, mode);

    switch (instr) {
    case Instruction::AND:
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() & value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;

    case Instruction::ORA:
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() | value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;

    case Instruction::EOR:
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() ^ value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;

    case Instruction::BIT:
        // Set zero flag based on AND result, but don't change accumulator
        cpu_.cpuState_.setFlag(StatusFlag::Zero, (cpu_.cpuState_.getA() & value) == 0);
        // BIT also sets negative and overflow flags directly from memory byte
        cpu_.cpuState_.setFlag(StatusFlag::Negative, (value & 0x80) != 0);
        cpu_.cpuState_.setFlag(StatusFlag::Overflow, (value & 0x40) != 0);
        break;

    default:
        break;
    }
}

/**
 * @brief Execute branch instructions (BCC, BCS, BEQ, BMI, BNE, BPL, BVC, BVS)
 *
 * Handles all conditional branch instructions, testing the appropriate status flag
 * and updating the program counter if the branch is taken. Also accounts for
 * additional cycles when the branch is taken or crosses a page boundary.
 *
 * @param instr The branch instruction to execute
 * @param mode The addressing mode (always Relative for branch instructions)
 */
void InstructionExecutor::executeBranch(Instruction instr, AddressingMode mode) {
    const i8 offset = static_cast<i8>(cpu_.fetchOperand(cpu_.cpuState_.getPC()));
    cpu_.cpuState_.incrementPC();

    bool branchTaken = false;

    // Determine if branch should be taken based on instruction and flags
    switch (instr) {
    case Instruction::BCC:
        branchTaken = !cpu_.cpuState_.testFlag(StatusFlag::Carry);
        break;

    case Instruction::BCS:
        branchTaken = cpu_.cpuState_.testFlag(StatusFlag::Carry);
        break;

    case Instruction::BEQ:
        branchTaken = cpu_.cpuState_.testFlag(StatusFlag::Zero);
        break;

    case Instruction::BMI:
        branchTaken = cpu_.cpuState_.testFlag(StatusFlag::Negative);
        break;

    case Instruction::BNE:
        branchTaken = !cpu_.cpuState_.testFlag(StatusFlag::Zero);
        break;

    case Instruction::BPL:
        branchTaken = !cpu_.cpuState_.testFlag(StatusFlag::Negative);
        break;

    case Instruction::BVC:
        branchTaken = !cpu_.cpuState_.testFlag(StatusFlag::Overflow);
        break;

    case Instruction::BVS:
        branchTaken = cpu_.cpuState_.testFlag(StatusFlag::Overflow);
        break;

    default:
        break;
    }

    // If branch is taken, update PC and add cycles
    if (branchTaken) {
        const u16 oldPC = cpu_.cpuState_.getPC();
        const u16 newPC = oldPC + offset;
        cpu_.cpuState_.setPC(newPC);
        cpu_.memory_.markMemoryAccess(newPC, MemoryAccessFlag::JumpTarget);

        // Branch taken: add 1 cycle
        cpu_.cpuState_.addCycles(1);

        // Page boundary crossing: add another cycle
        if ((oldPC & 0xFF00) != (newPC & 0xFF00)) {
            cpu_.cpuState_.addCycles(1);
        }
    }
}

/**
 * @brief Execute jump instructions (JMP, JSR, RTS, RTI, BRK)
 *
 * Handles all instructions that change the program flow unconditionally,
 * including subroutine calls and returns, and interrupt handling.
 *
 * @param instr The jump instruction to execute
 * @param mode The addressing mode to use
 */
void InstructionExecutor::executeJump(Instruction instr, AddressingMode mode) {
    switch (instr) {
    case Instruction::JMP: {
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        cpu_.memory_.markMemoryAccess(addr, MemoryAccessFlag::JumpTarget);
        cpu_.cpuState_.setPC(addr);
        break;
    }

    case Instruction::JSR: {
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        cpu_.memory_.markMemoryAccess(addr, MemoryAccessFlag::JumpTarget);

        // PC is incremented during address calculation, so we need to decrement
        // to push the correct return address (last byte of JSR instruction)
        u16 returnAddr = cpu_.cpuState_.getPC() - 1;
        cpu_.push((returnAddr >> 8) & 0xFF); // Push high byte
        cpu_.push(returnAddr & 0xFF);        // Push low byte
        cpu_.cpuState_.setPC(addr);
        break;
    }

    case Instruction::RTS: {
        const u8 lo = cpu_.pop();
        const u8 hi = cpu_.pop();
        const u16 addr = (hi << 8) | lo;
        cpu_.cpuState_.setPC(addr + 1); // RTS increments PC after popping
        break;
    }

    case Instruction::RTI: {
        const u8 status = cpu_.pop();
        const u8 lo = cpu_.pop();
        const u8 hi = cpu_.pop();
        const u16 addr = (hi << 8) | lo;

        cpu_.cpuState_.setStatus(status);
        cpu_.cpuState_.setPC(addr);
        break;
    }

    case Instruction::BRK: {
        // Skip the signature byte
        cpu_.cpuState_.incrementPC();

        // Push PC and status register
        u16 returnAddr = cpu_.cpuState_.getPC();
        cpu_.push((returnAddr >> 8) & 0xFF); // Push high byte
        cpu_.push(returnAddr & 0xFF);        // Push low byte

        // Push status with Break and Unused flags set
        cpu_.push(cpu_.cpuState_.getStatus() |
            static_cast<u8>(StatusFlag::Break) |
            static_cast<u8>(StatusFlag::Unused));

        // Set interrupt disable flag
        cpu_.cpuState_.setFlag(StatusFlag::Interrupt, true);

        // Load interrupt vector
        const u16 vectorAddr = cpu_.readMemory(0xFFFE) | (cpu_.readMemory(0xFFFF) << 8);
        cpu_.cpuState_.setPC(vectorAddr);
        break;
    }

    default:
        break;
    }
}

/**
 * @brief Execute stack instructions (PHA, PHP, PLA, PLP)
 *
 * Handles all stack manipulation instructions, including pushing/popping
 * the accumulator and processor status register.
 *
 * @param instr The stack instruction to execute
 * @param mode The addressing mode (always Implied for stack instructions)
 */
void InstructionExecutor::executeStack(Instruction instr, AddressingMode mode) {
    switch (instr) {
    case Instruction::PHA:
        cpu_.push(cpu_.cpuState_.getA());
        break;

    case Instruction::PHP:
        cpu_.push(cpu_.cpuState_.getStatus() |
            static_cast<u8>(StatusFlag::Break) |
            static_cast<u8>(StatusFlag::Unused));
        break;

    case Instruction::PLA:
        cpu_.cpuState_.setA(cpu_.pop());
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;

    case Instruction::PLP:
        cpu_.cpuState_.setStatus(cpu_.pop());
        break;

    default:
        break;
    }
}

/**
 * @brief Execute register transfer instructions (TAX, TAY, TXA, TYA, TSX, TXS)
 *
 * Handles all register-to-register transfer instructions, copying values
 * between the accumulator, index registers, and stack pointer.
 *
 * @param instr The register transfer instruction to execute
 * @param mode The addressing mode (always Implied for register transfers)
 */
void InstructionExecutor::executeRegister(Instruction instr, AddressingMode mode) {
    switch (instr) {
    case Instruction::TAX:
        cpu_.cpuState_.setX(cpu_.cpuState_.getA());
        cpu_.cpuState_.setZN(cpu_.cpuState_.getX());
        break;

    case Instruction::TAY:
        cpu_.cpuState_.setY(cpu_.cpuState_.getA());
        cpu_.cpuState_.setZN(cpu_.cpuState_.getY());
        break;

    case Instruction::TXA:
        cpu_.cpuState_.setA(cpu_.cpuState_.getX());
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;

    case Instruction::TYA:
        cpu_.cpuState_.setA(cpu_.cpuState_.getY());
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;

    case Instruction::TSX:
        cpu_.cpuState_.setX(cpu_.cpuState_.getSP());
        cpu_.cpuState_.setZN(cpu_.cpuState_.getX());
        break;

    case Instruction::TXS:
        cpu_.cpuState_.setSP(cpu_.cpuState_.getX());
        break;

    default:
        break;
    }
}

/**
 * @brief Execute flag manipulation instructions (CLC, CLD, CLI, CLV, SEC, SED, SEI)
 *
 * Handles all processor status flag manipulation instructions,
 * setting or clearing specific flags.
 *
 * @param instr The flag instruction to execute
 * @param mode The addressing mode (always Implied for flag instructions)
 */
void InstructionExecutor::executeFlag(Instruction instr, AddressingMode mode) {
    switch (instr) {
    case Instruction::CLC:
        cpu_.cpuState_.setFlag(StatusFlag::Carry, false);
        break;

    case Instruction::CLD:
        cpu_.cpuState_.setFlag(StatusFlag::Decimal, false);
        break;

    case Instruction::CLI:
        cpu_.cpuState_.setFlag(StatusFlag::Interrupt, false);
        break;

    case Instruction::CLV:
        cpu_.cpuState_.setFlag(StatusFlag::Overflow, false);
        break;

    case Instruction::SEC:
        cpu_.cpuState_.setFlag(StatusFlag::Carry, true);
        break;

    case Instruction::SED:
        cpu_.cpuState_.setFlag(StatusFlag::Decimal, true);
        break;

    case Instruction::SEI:
        cpu_.cpuState_.setFlag(StatusFlag::Interrupt, true);
        break;

    default:
        break;
    }
}

/**
 * @brief Execute shift instructions (ASL, LSR, ROL, ROR)
 *
 * Handles all shift and rotate instructions, operating either on the
 * accumulator or memory depending on the addressing mode.
 *
 * @param instr The shift instruction to execute
 * @param mode The addressing mode to use
 */
void InstructionExecutor::executeShift(Instruction instr, AddressingMode mode) {
    u16 addr = 0;
    u8 value = 0;

    // Determine operand source
    if (mode == AddressingMode::Accumulator) {
        value = cpu_.cpuState_.getA();
    }
    else {
        addr = cpu_.addressingModes_.getAddress(mode);
        value = cpu_.readByAddressingMode(addr, mode);
    }

    switch (instr) {
    case Instruction::ASL: {
        // Arithmetic Shift Left
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x80) != 0);
        value <<= 1;
        break;
    }

    case Instruction::LSR: {
        // Logical Shift Right
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x01) != 0);
        value >>= 1;
        break;
    }

    case Instruction::ROL: {
        // Rotate Left
        const bool oldCarry = cpu_.cpuState_.testFlag(StatusFlag::Carry);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x80) != 0);
        value = (value << 1) | (oldCarry ? 1 : 0);
        break;
    }

    case Instruction::ROR: {
        // Rotate Right
        const bool oldCarry = cpu_.cpuState_.testFlag(StatusFlag::Carry);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x01) != 0);
        value = (value >> 1) | (oldCarry ? 0x80 : 0x00);
        break;
    }

    default:
        break;
    }

    // Update flags and store result
    cpu_.cpuState_.setZN(value);

    if (mode == AddressingMode::Accumulator) {
        cpu_.cpuState_.setA(value);
    }
    else {
        cpu_.writeMemory(addr, value);
    }
}

/**
 * @brief Execute compare instructions (CMP, CPX, CPY)
 *
 * Handles all register comparison instructions, setting flags based on
 * the comparison between the register and memory.
 *
 * @param instr The compare instruction to execute
 * @param mode The addressing mode to use
 */
void InstructionExecutor::executeCompare(Instruction instr, AddressingMode mode) {
    const u16 addr = cpu_.addressingModes_.getAddress(mode);
    const u8 value = cpu_.readByAddressingMode(addr, mode);
    u8 regValue = 0;

    // Select register to compare based on instruction
    switch (instr) {
    case Instruction::CMP:
        regValue = cpu_.cpuState_.getA();
        break;

    case Instruction::CPX:
        regValue = cpu_.cpuState_.getX();
        break;

    case Instruction::CPY:
        regValue = cpu_.cpuState_.getY();
        break;

    default:
        break;
    }

    // Perform comparison and set flags
    cpu_.cpuState_.setFlag(StatusFlag::Carry, regValue >= value);
    cpu_.cpuState_.setFlag(StatusFlag::Zero, regValue == value);
    cpu_.cpuState_.setFlag(StatusFlag::Negative, ((regValue - value) & 0x80) != 0);
}

/**
 * @brief Execute illegal/undocumented instructions
 *
 * Handles all illegal opcodes of the 6502 processor. These are undocumented
 * instructions that have side effects based on the internal workings of the CPU.
 * Many of these combine multiple operations of documented instructions.
 *
 * @param instr The illegal instruction to execute
 * @param mode The addressing mode to use
 */
void InstructionExecutor::executeIllegal(Instruction instr, AddressingMode mode) {
    // Note: These implementations are based on documented behavior of illegal opcodes

    switch (instr) {
    case Instruction::SLO: {
        // SLO = ASL + ORA
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);

        // ASL part
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x80) != 0);
        value <<= 1;
        cpu_.writeMemory(addr, value);

        // ORA part
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() | value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    }

    case Instruction::RLA: {
        // RLA = ROL + AND
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);

        // ROL part
        const bool oldCarry = cpu_.cpuState_.testFlag(StatusFlag::Carry);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x80) != 0);
        value = (value << 1) | (oldCarry ? 1 : 0);
        cpu_.writeMemory(addr, value);

        // AND part
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() & value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    }

    case Instruction::SRE: {
        // SRE = LSR + EOR
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);

        // LSR part
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x01) != 0);
        value >>= 1;
        cpu_.writeMemory(addr, value);

        // EOR part
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() ^ value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    }

    case Instruction::RRA: {
        // RRA = ROR + ADC
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);

        // ROR part
        const bool oldCarry = cpu_.cpuState_.testFlag(StatusFlag::Carry);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (value & 0x01) != 0);
        value = (value >> 1) | (oldCarry ? 0x80 : 0x00);
        cpu_.writeMemory(addr, value);

        // ADC part (simplified, not handling decimal mode here)
        const u16 sum = static_cast<u16>(cpu_.cpuState_.getA()) +
            static_cast<u16>(value) +
            (cpu_.cpuState_.testFlag(StatusFlag::Carry) ? 1 : 0);

        cpu_.cpuState_.setFlag(StatusFlag::Carry, sum > 0xFF);
        cpu_.cpuState_.setFlag(StatusFlag::Zero, (sum & 0xFF) == 0);
        cpu_.cpuState_.setFlag(StatusFlag::Overflow,
            ((~(cpu_.cpuState_.getA() ^ value) & (cpu_.cpuState_.getA() ^ sum) & 0x80) != 0));
        cpu_.cpuState_.setFlag(StatusFlag::Negative, (sum & 0x80) != 0);

        cpu_.cpuState_.setA(static_cast<u8>(sum & 0xFF));
        break;
    }

    case Instruction::DCP: {
        // DCP = DEC + CMP
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);

        // DEC part
        value--;
        cpu_.writeMemory(addr, value);

        // CMP part
        const u8 regA = cpu_.cpuState_.getA();
        cpu_.cpuState_.setFlag(StatusFlag::Carry, regA >= value);
        cpu_.cpuState_.setFlag(StatusFlag::Zero, regA == value);
        cpu_.cpuState_.setFlag(StatusFlag::Negative, ((regA - value) & 0x80) != 0);
        break;
    }

    case Instruction::ISC: {
        // ISC = INC + SBC
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        u8 value = cpu_.readByAddressingMode(addr, mode);

        // INC part
        value++;
        cpu_.writeMemory(addr, value);

        // SBC part (using inverted operand)
        const u8 invertedValue = value ^ 0xFF;
        const u16 diff = static_cast<u16>(cpu_.cpuState_.getA()) +
            static_cast<u16>(invertedValue) +
            (cpu_.cpuState_.testFlag(StatusFlag::Carry) ? 1 : 0);

        cpu_.cpuState_.setFlag(StatusFlag::Carry, diff > 0xFF);
        cpu_.cpuState_.setFlag(StatusFlag::Zero, (diff & 0xFF) == 0);
        cpu_.cpuState_.setFlag(StatusFlag::Overflow,
            ((~(cpu_.cpuState_.getA() ^ invertedValue) & (cpu_.cpuState_.getA() ^ diff) & 0x80) != 0));
        cpu_.cpuState_.setFlag(StatusFlag::Negative, (diff & 0x80) != 0);

        cpu_.cpuState_.setA(static_cast<u8>(diff & 0xFF));
        break;
    }

    case Instruction::ANC: {
        // ANC = AND + set carry from bit 7
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);

        cpu_.cpuState_.setA(cpu_.cpuState_.getA() & value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (cpu_.cpuState_.getA() & 0x80) != 0);
        break;
    }

    case Instruction::ALR: {
        // ALR = AND + LSR
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);

        // AND part
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() & value);

        // LSR part
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (cpu_.cpuState_.getA() & 0x01) != 0);
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() >> 1);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    }

    case Instruction::ARR: {
        // ARR = AND + ROR (with special flag behavior)
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);

        // AND part
        cpu_.cpuState_.setA(cpu_.cpuState_.getA() & value);

        // ROR part
        const bool oldCarry = cpu_.cpuState_.testFlag(StatusFlag::Carry);
        cpu_.cpuState_.setA((cpu_.cpuState_.getA() >> 1) | (oldCarry ? 0x80 : 0x00));

        // Special flag behavior
        cpu_.cpuState_.setFlag(StatusFlag::Zero, cpu_.cpuState_.getA() == 0);
        cpu_.cpuState_.setFlag(StatusFlag::Negative, (cpu_.cpuState_.getA() & 0x80) != 0);
        cpu_.cpuState_.setFlag(StatusFlag::Carry, (cpu_.cpuState_.getA() & 0x40) != 0);
        cpu_.cpuState_.setFlag(StatusFlag::Overflow,
            ((cpu_.cpuState_.getA() & 0x40) ^ ((cpu_.cpuState_.getA() & 0x20) << 1)) != 0);
        break;
    }

    case Instruction::AXS: {
        // AXS = A AND X, then subtract without borrow
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);

        const u8 temp = cpu_.cpuState_.getA() & cpu_.cpuState_.getX();
        const u16 result = static_cast<u16>(temp) - static_cast<u16>(value);

        cpu_.cpuState_.setFlag(StatusFlag::Carry, temp >= value);
        cpu_.cpuState_.setFlag(StatusFlag::Zero, (result & 0xFF) == 0);
        cpu_.cpuState_.setFlag(StatusFlag::Negative, (result & 0x80) != 0);

        cpu_.cpuState_.setX(static_cast<u8>(result & 0xFF));
        break;
    }

    case Instruction::LAS: {
        // LAS = Memory AND SP -> A, X, SP
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);

        const u8 result = value & cpu_.cpuState_.getSP();
        cpu_.cpuState_.setA(result);
        cpu_.cpuState_.setX(result);
        cpu_.cpuState_.setSP(result);
        cpu_.cpuState_.setZN(result);
        break;
    }

    case Instruction::KIL: {
        // KIL = Processor lock-up
        // In real hardware, this would cause the CPU to stop
        // For emulation, we just do nothing
        cpu_.cpuState_.setPC(cpu_.cpuState_.getPC() - 1); // Stay on this instruction
        break;
    }

                         // These remaining illegal instructions have more complex or unstable behavior
                         // Simplified implementations provided for emulation purposes

    case Instruction::XAA: {
        // XAA = Behavior varies by processor and conditions
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 value = cpu_.readByAddressingMode(addr, mode);

        // Simplified model: X -> A, then AND with value
        cpu_.cpuState_.setA(cpu_.cpuState_.getX() & value);
        cpu_.cpuState_.setZN(cpu_.cpuState_.getA());
        break;
    }

    case Instruction::AHX:
    case Instruction::SHA: {
        // AHX/SHA = Store A AND X AND (high byte + 1)
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 high = (addr >> 8) & 0xFF;
        const u8 result = cpu_.cpuState_.getA() & cpu_.cpuState_.getX() & (high + 1);

        cpu_.writeMemory(addr, result);
        break;
    }

    case Instruction::SHX: {
        // SHX = Store X AND (high byte + 1)
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 high = (addr >> 8) & 0xFF;
        const u8 result = cpu_.cpuState_.getX() & (high + 1);

        cpu_.writeMemory(addr, result);
        break;
    }

    case Instruction::SHY: {
        // SHY = Store Y AND (high byte + 1)
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 high = (addr >> 8) & 0xFF;
        const u8 result = cpu_.cpuState_.getY() & (high + 1);

        cpu_.writeMemory(addr, result);
        break;
    }

    case Instruction::TAS: {
        // TAS = A AND X -> SP, then store SP AND (high byte + 1)
        const u16 addr = cpu_.addressingModes_.getAddress(mode);
        const u8 high = (addr >> 8) & 0xFF;

        cpu_.cpuState_.setSP(cpu_.cpuState_.getA() & cpu_.cpuState_.getX());
        const u8 result = cpu_.cpuState_.getSP() & (high + 1);

        cpu_.writeMemory(addr, result);
        break;
    }

    default:
        break;
    }
}