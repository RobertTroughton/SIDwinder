// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#include "Disassembler.h"
#include "CodeFormatter.h"
#include "DisassemblyWriter.h"
#include "LabelGenerator.h"
#include "MemoryAnalyzer.h"
#include "SIDLoader.h"
#include "cpu6510.h"

namespace sidwinder {

    /**
     * @brief Constructor for Disassembler
     *
     * Initializes the disassembler with references to the CPU and SID loader,
     * then calls initialize() to set up the internal components.
     *
     * @param cpu Reference to the CPU with execution state
     * @param sid Reference to the SID file loader
     */
    Disassembler::Disassembler(const CPU6510& cpu, const SIDLoader& sid)
        : cpu_(cpu),
        sid_(sid) {
        initialize();
    }

    /**
     * @brief Destructor for Disassembler
     *
     * Default destructor - unique_ptr members will be automatically cleaned up.
     */
    Disassembler::~Disassembler() {
        // Clear all callbacks before destroying members
        const_cast<CPU6510&>(cpu_).setOnMemoryFlowCallback(nullptr);
        const_cast<CPU6510&>(cpu_).setOnWriteMemoryCallback(nullptr);
        const_cast<CPU6510&>(cpu_).setOnIndirectReadCallback(nullptr);
        const_cast<CPU6510&>(cpu_).setOnComparisonCallback(nullptr);
    }

    /**
     * @brief Initialize the disassembler components
     *
     * Sets up the memory analyzer, label generator, code formatter, and disassembly writer.
     * Also configures the indirect read callback to track memory access patterns.
     */
    void Disassembler::initialize() {

        // Create memory analyzer but don't analyze yet
        analyzer_ = std::make_unique<MemoryAnalyzer>(
            cpu_.getMemory(),
            cpu_.getMemoryAccess(),
            sid_.getLoadAddress(),
            sid_.getLoadAddress() + sid_.getDataSize()
        );

        // Create label generator
        labelGenerator_ = std::make_unique<LabelGenerator>(
            *analyzer_,
            sid_.getLoadAddress(),
            sid_.getLoadAddress() + sid_.getDataSize(),
            cpu_.getMemory()
        );

        // Create code formatter
        formatter_ = std::make_unique<CodeFormatter>(
            cpu_,
            *labelGenerator_,
            cpu_.getMemory()
        );

        // Create disassembly writer
        writer_ = std::make_unique<DisassemblyWriter>(
            cpu_,
            sid_,
            *analyzer_,
            *labelGenerator_,
            *formatter_
        );

        // Set up indirect read callback (existing)
        const_cast<CPU6510&>(cpu_).setOnIndirectReadCallback([this](u16 pc, u8 zpAddr, u16 targetAddr) {
            if (writer_) {
                writer_->addIndirectAccess(pc, zpAddr, targetAddr);
            }
            });

        const_cast<CPU6510&>(cpu_).setOnMemoryFlowCallback(
            [this](u16 pc, char reg, u16 sourceAddr, u8 value, bool isIndexed) {
                if (writer_) {
                    writer_->onMemoryFlow(pc, reg, sourceAddr, value, isIndexed);
                }
            }
        );

        // Set up memory write callback to detect self-modifying code
        const_cast<CPU6510&>(cpu_).setOnWriteMemoryCallback([this](u16 addr, u8 value) {
            if (writer_) {
                // Just record the write for later analysis
                RegisterSourceInfo sourceInfo = cpu_.getWriteSourceInfo(addr);
                DisassemblyWriter::WriteRecord record = { addr, value, sourceInfo };
                writer_->allWrites_.push_back(record);
            }
            });

        // Set up comparison callback for pointer-based pattern detection
        const_cast<CPU6510&>(cpu_).setOnComparisonCallback(
            [this](u16 pc, char reg, u8 compareValue, u16 sourceAddr, bool isMemorySource) {
                if (writer_) {
                    writer_->onComparison(pc, reg, compareValue, sourceAddr, isMemorySource);
                }
            }
        );
    }

    /**
     * @brief Generate an assembly file from the loaded SID
     *
     * Performs analysis on the CPU memory, generates labels, processes
     * memory access patterns, and produces an assembly language output file.
     *
     * @param outputPath Path to write the assembly file
     * @param sidLoad New SID load address (for relocation)
     * @param sidInit New SID init address
     * @param sidPlay New SID play address
     */
    void Disassembler::generateAsmFile(
        const std::string& outputPath,
        u16 sidLoad,
        u16 sidInit,
        u16 sidPlay,
        bool removeCIAWrites) {
    
        if (!analyzer_ || !labelGenerator_ || !formatter_ || !writer_) {
            util::Logger::error("Disassembler not properly initialized");
            return;
        }

        // Perform memory analysis
        analyzer_->analyzeExecution();
        analyzer_->analyzeAccesses();
        analyzer_->analyzeData();

        // Analyze recorded writes for self-modification
        writer_->analyzeWritesForSelfModification();

        // Process indirect accesses and self-modifying code patterns
        writer_->processIndirectAccesses();

        // Generate labels based on the analysis
        labelGenerator_->generateLabels();

        // Apply any pending subdivisions to data blocks
        labelGenerator_->applySubdivisions();

        // Generate the assembly file
        writer_->generateAsmFile(outputPath, sidLoad, sidInit, sidPlay, removeCIAWrites);
    }

} // namespace sidwinder