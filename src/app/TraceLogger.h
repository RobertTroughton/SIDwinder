// ==================================
//             SIDwinder
//
//  Raistlin / Genesis Project (G*P)
// ==================================
#pragma once

#include "Common.h"
#include <fstream>
#include <string>
#include <vector>

namespace sidwinder {

    /**
     * @enum TraceFormat
     * @brief Format for the trace log file
     */
    enum class TraceFormat {
        Text,   ///< Text format (human-readable)
        Binary  ///< Binary format (compact)
    };

    /**
     * @class TraceLogger
     * @brief Logger for SID and CIA register writes during emulation
     *
     * The TraceLogger captures register writes to SID and CIA chips during
     * emulation for later analysis and verification.
     */
    class TraceLogger {
    public:
        /**
         * @brief Constructor
         * @param filename Filename for the trace log
         * @param format Format for the trace log (text or binary)
         */
        TraceLogger(const std::string& filename, TraceFormat format = TraceFormat::Text);

        /**
         * @brief Destructor
         */
        ~TraceLogger();

        /**
         * @brief Log a frame marker
         *
         * Marks the end of a frame in the trace log
         */
        void logFrameMarker();

        /**
         * @brief Flush the log to disk
         */
        void flushLog();

        /**
         * @brief Compare two trace logs
         * @param originalLog Path to the original trace log
         * @param relocatedLog Path to the relocated trace log
         * @param reportFile Path to write the comparison report
         * @return True if the logs are identical, false if differences found
         */
        static bool compareTraceLogs(
            const std::string& originalLog,
            const std::string& relocatedLog,
            const std::string& reportFile);

    private:
        /// Special marker for end of frame
        static constexpr u32 FRAME_MARKER = 0xFFFFFFFF;

        /**
         * @struct TraceRecord
         * @brief Binary record format for trace logs
         */
        struct TraceRecord {
            union {
                struct {
                    u16 address;  ///< Register address
                    u8 value;     ///< Value written
                    u8 unused;    ///< Set to 0 by default
                } write;

                u32 commandTag;   ///< Command tag for special records
            };

            TraceRecord() : commandTag(0) {}
            TraceRecord(u16 addr, u8 val) : write{ addr, val, 0 } {}
            TraceRecord(u32 cmd) : commandTag(cmd) {}
        };

        std::ofstream file_;     ///< Output file stream
        TraceFormat format_;     ///< File format
        bool isOpen_;            ///< File open state

        /**
         * @brief Write a record in text format
         * @param addr Register address
         * @param value Value written
         */
        void writeTextRecord(u16 addr, u8 value);

        /**
         * @brief Write a record in binary format
         * @param record Binary record to write
         */
        void writeBinaryRecord(const TraceRecord& record);
    };

} // namespace sidwinder