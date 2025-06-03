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

    void TraceLogger::logSIDWrite(u16 addr, u8 value) {
        if (!isOpen_) return;

        if (format_ == TraceFormat::Text) {
            writeTextRecord(addr, value);
        }
        else {
            TraceRecord record(addr, value);
            writeBinaryRecord(record);
        }
    }

    void TraceLogger::logCIAWrite(u16 addr, u8 value) {
        return; // TODO: we need a way to enable/disable each sort of trace

        if (!isOpen_) return;

        if (format_ == TraceFormat::Text) {
            writeTextRecord(addr, value);
        }
        else {
            TraceRecord record(addr, value);
            writeBinaryRecord(record);
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

        std::ifstream original(originalLog, std::ios::binary);
        std::ifstream relocated(relocatedLog, std::ios::binary);
        std::ofstream report(reportFile);

        if (!original || !relocated || !report) {
            util::Logger::error("Failed to open trace log files for comparison");
            return false;
        }

        bool identical = true;
        int frameCount = 0;
        int originalFrameCount = 0;
        int relocatedFrameCount = 0;
        int differentFrameCount = 0;
        const int maxDifferenceOutput = 64; // Maximum number of frame differences to output

        report << "SIDwinder Trace Log Comparison Report\n";
        report << "Original: " << originalLog << "\n";
        report << "Relocated: " << relocatedLog << "\n\n";

        // Storage for current frame data
        std::vector<std::pair<u16, u8>> originalFrameData;
        std::vector<std::pair<u16, u8>> relocatedFrameData;

        TraceRecord origRecord, relocRecord;
        bool origEof = false;
        bool relocEof = false;

        // Process both files frame by frame
        while (!origEof && !relocEof) {
            // Read original frame
            originalFrameData.clear();
            while (original.read(reinterpret_cast<char*>(&origRecord), sizeof(TraceRecord))) {
                if (origRecord.commandTag == FRAME_MARKER) {
                    originalFrameCount++;
                    break;
                }
                originalFrameData.emplace_back(origRecord.write.address, origRecord.write.value);
            }

            if (original.eof()) {
                origEof = true;
            }

            // Read relocated frame
            relocatedFrameData.clear();
            while (relocated.read(reinterpret_cast<char*>(&relocRecord), sizeof(TraceRecord))) {
                if (relocRecord.commandTag == FRAME_MARKER) {
                    relocatedFrameCount++;
                    break;
                }
                relocatedFrameData.emplace_back(relocRecord.write.address, relocRecord.write.value);
            }

            if (relocated.eof()) {
                relocEof = true;
            }

            // Stop comparison if either file ends
            if (origEof || relocEof) {
                break;
            }

            // Compare the frames
            frameCount++;

            // Format frame data as strings for easier comparison and indicator placement
            std::string origLine = "  Orig: ";
            std::string reloLine = "  Relo: ";

            // Format the original frame data
            bool first = true;
            for (const auto& [addr, value] : originalFrameData) {
                if (!first) origLine += ",";
                origLine += util::wordToHex(addr) + ":" + util::byteToHex(value);
                first = false;
            }

            // Format the relocated frame data
            first = true;
            for (const auto& [addr, value] : relocatedFrameData) {
                if (!first) reloLine += ",";
                reloLine += util::wordToHex(addr) + ":" + util::byteToHex(value);
                first = false;
            }

            // Create a map for easier lookup
            std::map<u16, u8> origMap;
            std::map<u16, u8> reloMap;

            for (const auto& [addr, value] : originalFrameData) {
                origMap[addr] = value;
            }

            for (const auto& [addr, value] : relocatedFrameData) {
                reloMap[addr] = value;
            }

            // Compare the data and mark differences
            bool frameIdentical = (originalFrameData == relocatedFrameData);

            // If frame is different, output details
            if (!frameIdentical) {
                differentFrameCount++;
                identical = false;

                // Only output details for up to maxDifferenceOutput frames
                if (differentFrameCount <= maxDifferenceOutput) {
                    report << "Frame " << frameCount << ":\n";
                    report << origLine << "\n";
                    report << reloLine << "\n";

                    // Create a combined indicator that shows all differences
                    // Start with a blank line matching the length of the shorter of the two lines
                    const size_t indicatorLength = std::max(origLine.length(), reloLine.length());
                    std::string indicatorLine(indicatorLength, ' ');

                    // Compare each entry in original to relocated
                    size_t origPos = 8; // Starting position (after "  Orig: ")
                    for (const auto& [addr, value] : originalFrameData) {
                        std::string entry = util::wordToHex(addr) + ":" + util::byteToHex(value);
                        bool found = (reloMap.find(addr) != reloMap.end());

                        if (!found || reloMap[addr] != value) {
                            // Mark this entry as different or missing from relocated
                            for (size_t i = 0; i < 7 && (origPos + i) < indicatorLength; i++) {
                                indicatorLine[origPos + i] = '*';
                            }
                        }

                        // Move to next position (entry length + comma)
                        origPos += entry.length() + 1;
                    }

                    // Compare each entry in relocated to original
                    size_t reloPos = 8; // Starting position (after "  Relo: ")
                    for (const auto& [addr, value] : relocatedFrameData) {
                        std::string entry = util::wordToHex(addr) + ":" + util::byteToHex(value);
                        bool found = (origMap.find(addr) != origMap.end());

                        if (!found || origMap[addr] != value) {
                            // Mark this entry as different or missing from original
                            for (size_t i = 0; i < 7 && (reloPos + i) < indicatorLength; i++) {
                                indicatorLine[reloPos + i] = '*';
                            }
                        }

                        // Move to next position (entry length + comma)
                        reloPos += entry.length() + 1;
                    }

                    // For significant structural differences (many registers present in one but not the other)
                    // Mark the spots after the end of the shorter list
                    if (originalFrameData.size() > relocatedFrameData.size() && !relocatedFrameData.empty()) {
                        // Mark spots where original has entries but relocated doesn't
                        size_t markPos = reloPos;
                        while (markPos < indicatorLength) {
                            for (int i = 0; i < 7 && markPos + i < indicatorLength; i++) {
                                indicatorLine[markPos + i] = '*';
                            }
                            markPos += 8; // Approximate spacing for missing entries
                        }
                    }
                    else if (relocatedFrameData.size() > originalFrameData.size() && !originalFrameData.empty()) {
                        // Mark spots where relocated has entries but original doesn't
                        size_t markPos = origPos;
                        while (markPos < indicatorLength) {
                            for (int i = 0; i < 7 && markPos + i < indicatorLength; i++) {
                                indicatorLine[markPos + i] = '*';
                            }
                            markPos += 8; // Approximate spacing for missing entries
                        }
                    }

                    report << indicatorLine << "\n\n";
                }
                else if (differentFrameCount == maxDifferenceOutput + 1) {
                    report << "Additional differences omitted...\n\n";
                }
            }
        }

        // Check for frame count mismatch
        if (originalFrameCount != relocatedFrameCount) {
            report << "Frame count mismatch: Original has " << originalFrameCount
                << " frames, Relocated has " << relocatedFrameCount << " frames\n\n";
            identical = false;
        }

        // Output summary
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