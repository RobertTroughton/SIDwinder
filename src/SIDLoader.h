#pragma once

#include "Common.h"
#include "SIDFileFormat.h"
#include <cstring>
#include <memory>
#include <string>
#include <string_view>
#include <vector>
#include <filesystem>

namespace fs = std::filesystem;

class CPU6510;

class SIDLoader {
public:
    SIDLoader();

    void setCPU(CPU6510* cpu);

    void setInitAddress(u16 address);
    void setPlayAddress(u16 address);
    void setLoadAddress(u16 address);

    void setTitle(const std::string& title) {
        strncpy(header_.name, title.c_str(), sizeof(header_.name) - 1);
        header_.name[sizeof(header_.name) - 1] = '\0';
    }

    void setAuthor(const std::string& author) {
        strncpy(header_.author, author.c_str(), sizeof(header_.author) - 1);
        header_.author[sizeof(header_.author) - 1] = '\0';
    }

    void setCopyright(const std::string& copyright) {
        strncpy(header_.copyright, copyright.c_str(), sizeof(header_.copyright) - 1);
        header_.copyright[sizeof(header_.copyright) - 1] = '\0';
    }

    bool loadSID(const std::string& filename);

    static bool extractPrgFromSid(const fs::path& sidFile, const fs::path& outputPrg);

    u16 getInitAddress() const { return header_.initAddress; }
    u16 getPlayAddress() const { return header_.playAddress; }
    u16 getLoadAddress() const { return header_.loadAddress; }
    u16 getDataSize() const { return dataSize_; }
    const SIDHeader& getHeader() const { return header_; }

    const std::vector<u8>& getOriginalMemory() const { return originalMemory_; }
    u16 getOriginalMemoryBase() const { return originalMemoryBase_; }

    int getNumPlayCallsPerFrame() const { return numPlayCallsPerFrame_; }
    void setNumPlayCallsPerFrame(int num) { numPlayCallsPerFrame_ = num; }

    bool backupMemory();
    bool restoreMemory();

private:
    bool copyMusicToMemory(const u8* data, u16 size, u16 loadAddr);

    SIDHeader header_;
    u16 dataSize_ = 0;
    CPU6510* cpu_ = nullptr;
    std::vector<u8> originalMemory_;
    u16 originalMemoryBase_ = 0;
    u8 numPlayCallsPerFrame_ = 1;
    std::vector<u8> memoryBackup_;
};