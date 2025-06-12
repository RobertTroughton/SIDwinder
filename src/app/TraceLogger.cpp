// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#include "TraceLogger.h"
#include "../SIDwinderUtils.h"
#include <map>

namespace sidwinder {

    TraceLogger::TraceLogger(const std::string& filename, TraceFormat format)
        : format_(format), isOpen_(false) {
        if (filename.empty()) {
            return;
        }

        file_.open(filename, format == TraceFormat::Binary ?
            (std::ios::binary | std::ios::out) : std::ios::out);
        isOpen_ = file_.is_open();

        if (!isOpen_) {
            util::Logger::error("Failed to open trace log file: " + filename);
        }
    }

    TraceLogger::~TraceLogger() {
        if (isOpen_) {
            if (format_ == TraceFormat::Binary) {
                // Write end marker
                TraceRecord record(FRAME_MARKER);
                writeBinaryRecord(record);
            }
            file_.close();
        }
    }

    void TraceLogger::logFrameMarker() {
        if (!isOpen_) return;

        if (format_ == TraceFormat::Text) {
            file_ << "\nFRAME: ";
        }
        else {
            TraceRecord record(FRAME_MARKER);
            writeBinaryRecord(record);
        }
    }

    void TraceLogger::flushLog() {
        if (isOpen_) {
            file_.flush();
        }
    }

    void TraceLogger::writeTextRecord(u16 addr, u8 value) {
        file_ << util::wordToHex(addr) << ":$" << util::byteToHex(value) << ",";
    }

    void TraceLogger::writeBinaryRecord(const TraceRecord& record) {
        file_.write(reinterpret_cast<const char*>(&record), sizeof(TraceRecord));
    }

    bool TraceLogger::compareTraceLogs(
        const std::string& originalLog,
        const std::string& relocatedLog,
        const std::string& reportFile) {

        // Read both trace files using new utilities
        auto originalData = util::readBinaryFile(originalLog);
        auto relocatedData = util::readBinaryFile(relocatedLog);

        if (!originalData || !relocatedData) {
            return false; // Error already logged by readBinaryFile
        }

        std::ofstream report(reportFile);
        if (!report) {
            util::Logger::error("Failed to create report file: " + reportFile);
            return false;
        }

        bool identical = true;
        int frameCount = 0;
        int originalFrameCount = 0;
        int relocatedFrameCount = 0;
        int differentFrameCount = 0;
        const int maxDifferenceOutput = 64;

        report << "SIDwinder Trace Log Comparison Report\n";
        report << "Original: " << originalLog << "\n";
        report << "Relocated: " << relocatedLog << "\n\n";

        std::vector<std::pair<u16, u8>> originalFrameData;
        std::vector<std::pair<u16, u8>> relocatedFrameData;

        // Parse binary data in memory instead of file streams
        size_t origPos = 0;
        size_t relocPos = 0;

        while (origPos < originalData->size() && relocPos < relocatedData->size()) {
            originalFrameData.clear();
            relocatedFrameData.clear();

            // Parse original frame
            while (origPos + sizeof(TraceRecord) <= originalData->size()) {
                TraceRecord record;
                std::memcpy(&record, originalData->data() + origPos, sizeof(TraceRecord));
                origPos += sizeof(TraceRecord);

                if (record.commandTag == FRAME_MARKER) {
                    originalFrameCount++;
                    break;
                }
                originalFrameData.emplace_back(record.write.address, record.write.value);
            }

            // Parse relocated frame
            while (relocPos + sizeof(TraceRecord) <= relocatedData->size()) {
                TraceRecord record;
                std::memcpy(&record, relocatedData->data() + relocPos, sizeof(TraceRecord));
                relocPos += sizeof(TraceRecord);

                if (record.commandTag == FRAME_MARKER) {
                    relocatedFrameCount++;
                    break;
                }
                relocatedFrameData.emplace_back(record.write.address, record.write.value);
            }

            // Check if we've reached end of either file
            if ((origPos >= originalData->size() && !originalFrameData.empty()) ||
                (relocPos >= relocatedData->size() && !relocatedFrameData.empty())) {
                break;
            }

            frameCount++;

            // Build comparison strings (same as before)
            std::string origLine = "  Orig: ";
            std::string reloLine = "  Relo: ";
            bool first = true;
            for (const auto& [addr, value] : originalFrameData) {
                if (!first) origLine += ",";
                origLine += util::wordToHex(addr) + ":" + util::byteToHex(value);
                first = false;
            }
            first = true;
            for (const auto& [addr, value] : relocatedFrameData) {
                if (!first) reloLine += ",";
                reloLine += util::wordToHex(addr) + ":" + util::byteToHex(value);
                first = false;
            }

            // Compare frames (same logic as before)
            std::map<u16, u8> origMap;
            std::map<u16, u8> reloMap;
            for (const auto& [addr, value] : originalFrameData) {
                origMap[addr] = value;
            }
            for (const auto& [addr, value] : relocatedFrameData) {
                reloMap[addr] = value;
            }

            bool frameIdentical = (originalFrameData == relocatedFrameData);
            if (!frameIdentical) {
                differentFrameCount++;
                identical = false;

                if (differentFrameCount <= maxDifferenceOutput) {
                    report << "Frame " << frameCount << ":\n";
                    report << origLine << "\n";
                    report << reloLine << "\n";

                    // Generate difference indicators (same logic as before)
                    const size_t indicatorLength = std::max(origLine.length(), reloLine.length());
                    std::string indicatorLine(indicatorLength, ' ');

                    // Mark differences in original
                    size_t origPos = 8;
                    for (const auto& [addr, value] : originalFrameData) {
                        std::string entry = util::wordToHex(addr) + ":" + util::byteToHex(value);
                        bool found = (reloMap.find(addr) != reloMap.end());
                        if (!found || reloMap[addr] != value) {
                            for (size_t i = 0; i < 7 && (origPos + i) < indicatorLength; i++) {
                                indicatorLine[origPos + i] = '*';
                            }
                        }
                        origPos += entry.length() + 1;
                    }

                    // Mark differences in relocated (same logic as before)
                    size_t reloPos = 8;
                    for (const auto& [addr, value] : relocatedFrameData) {
                        std::string entry = util::wordToHex(addr) + ":" + util::byteToHex(value);
                        bool found = (origMap.find(addr) != origMap.end());
                        if (!found || origMap[addr] != value) {
                            for (size_t i = 0; i < 7 && (reloPos + i) < indicatorLength; i++) {
                                indicatorLine[reloPos + i] = '*';
                            }
                        }
                        reloPos += entry.length() + 1;
                    }

                    report << indicatorLine << "\n\n";
                }
                else if (differentFrameCount == maxDifferenceOutput + 1) {
                    report << "Additional differences omitted...\n\n";
                }
            }
        }

        // Summary (same as before)
        if (originalFrameCount != relocatedFrameCount) {
            report << "Frame count mismatch: Original has " << originalFrameCount
                << " frames, Relocated has " << relocatedFrameCount << " frames\n\n";
            identical = false;
        }

        report << "Summary:\n";
        if (identical) {
            report << "File 1: " << originalFrameCount << " frames\n";
            report << "File 2: " << relocatedFrameCount << " frames\n";
            report << "Result: NO DIFFERENCES FOUND - " << frameCount << " frames verified\n";
        }
        else {
            report << "Result: DIFFERENCES FOUND - "
                << differentFrameCount << " frames out of "
                << frameCount << " differed\n";
        }

        return identical;
    }

} // namespace sidwinder