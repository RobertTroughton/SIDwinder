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
    Disassembler::~Disassembler() = default;

    /**
     * @brief Initialize the disassembler components
     *
     * Sets up the memory analyzer, label generator, code formatter, and disassembly writer.
     * Also configures the indirect read callback to track memory access patterns.
     */
    void Disassembler::initialize() {
        util::Logger::debug("Initializing disassembler...");

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
            sid_.getLoadAddress() + sid_.getDataSize()
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

        // Set up indirect read callback
        const_cast<CPU6510&>(cpu_).setOnIndirectReadCallback([this](u16 pc, u8 zpAddr, u16 targetAddr) {
            if (writer_) {
                writer_->addIndirectAccess(pc, zpAddr, targetAddr);
            }
            });

        util::Logger::debug("Disassembler initialization complete");
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
     * @return Number of unused bytes removed, or -1 on error
     */
    int Disassembler::generateAsmFile(
        const std::string& outputPath,
        u16 sidLoad,
        u16 sidInit,
        u16 sidPlay) {

        if (!analyzer_ || !labelGenerator_ || !formatter_ || !writer_) {
            util::Logger::error("Disassembler not properly initialized");
            return -1;
        }

        // NOW perform the analysis AFTER all CPU execution is complete
        util::Logger::debug("Performing memory analysis...");
        analyzer_->analyzeExecution();
        analyzer_->analyzeAccesses();
        analyzer_->analyzeData();

        // Process any detected indirect accesses to identify relocation entries
        util::Logger::debug("Processing indirect memory accesses...");
        writer_->processIndirectAccesses();

        // Generate labels based on the analysis
        util::Logger::debug("Generating labels...");
        labelGenerator_->generateLabels();

        // Apply any pending subdivisions to data blocks
        labelGenerator_->applySubdivisions();

        // Generate the assembly file
        return writer_->generateAsmFile(outputPath, sidLoad, sidInit, sidPlay);
    }

} // namespace sidwinder