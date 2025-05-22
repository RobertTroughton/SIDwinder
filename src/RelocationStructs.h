#pragma once

#include "Common.h"
#include "SIDwinderUtils.h"
#include <string>
#include <map>

namespace sidwinder {

    /**
     * @struct RelocationEntry
     * @brief Information about a memory location that needs relocation
     */
    struct RelocationEntry {
        u16 targetAddress;          // The address being pointed to
        enum class Type {
            Low,                    // Low byte of address
            High                    // High byte of address
        } type;

        std::string toString() const {
            return std::string(type == Type::Low ? "LOW" : "HIGH") +
                " byte of $" + util::wordToHex(targetAddress);
        }
    };

    /**
     * @class RelocationTable
     * @brief Central registry of all memory locations that need relocation
     */
    class RelocationTable {
    public:
        /**
         * @brief Add a relocation entry
         * @param addr Memory address to mark for relocation
         * @param targetAddr The target address it points to
         * @param type Whether this is a low or high byte
         */
        void addEntry(u16 addr, u16 targetAddr, RelocationEntry::Type type) {
            entries_[addr] = { targetAddr, type };
        }

        /**
         * @brief Check if an address needs relocation
         * @param addr Memory address to check
         * @return True if address is marked for relocation
         */
        bool hasEntry(u16 addr) const {
            return entries_.find(addr) != entries_.end();
        }

        /**
         * @brief Get the relocation entry for an address
         * @param addr Memory address
         * @return The relocation entry or nullptr if not found
         */
        const RelocationEntry* getEntry(u16 addr) const {
            auto it = entries_.find(addr);
            if (it != entries_.end()) {
                return &it->second;
            }
            return nullptr;
        }

        /**
         * @brief Get all relocation entries
         * @return The map of addresses to relocation entries
         */
        const std::map<u16, RelocationEntry>& getAllEntries() const {
            return entries_;
        }

        /**
         * @brief Clear all entries
         */
        void clear() {
            entries_.clear();
        }

    private:
        std::map<u16, RelocationEntry> entries_;
    };

} // namespace sidwinder