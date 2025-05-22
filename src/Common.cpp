#include "Common.h"
#include <algorithm>

std::string getFileExtension(const fs::path& filePath) {
    std::string ext = filePath.extension().string();
    std::transform(ext.begin(), ext.end(), ext.begin(),
        [](unsigned char c) { return std::tolower(c); });
    return ext;
}

