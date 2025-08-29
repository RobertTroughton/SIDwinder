// png_converter.cpp - PNG to C64 Bitmap Converter for SIDwinder
// Converts 320x200 PNG images to C64 multicolor bitmap format

#include <cstdint>
#include <vector>
#include <string>
#include <cmath>
#include <set>
#include <map>

// C64 color palette (RGB values) - Using VICE3_6_Pepto_PAL
struct C64Color {
    uint8_t r, g, b;
    const char* name;
};

static const C64Color C64_PALETTE[16] = {
    {0x00, 0x00, 0x00, "Black"},      // 0
    {0xFF, 0xFF, 0xFF, "White"},      // 1  
    {0x68, 0x37, 0x2B, "Red"},        // 2
    {0x70, 0xA4, 0xB2, "Cyan"},       // 3
    {0x6F, 0x3D, 0x86, "Purple"},     // 4
    {0x58, 0x8D, 0x43, "Green"},      // 5
    {0x35, 0x28, 0x79, "Blue"},       // 6
    {0xB8, 0xC7, 0x6F, "Yellow"},     // 7
    {0x6F, 0x4F, 0x25, "Orange"},     // 8
    {0x43, 0x39, 0x00, "Brown"},      // 9
    {0x9A, 0x67, 0x59, "Light Red"},  // 10
    {0x44, 0x44, 0x44, "Dark Grey"},  // 11
    {0x6C, 0x6C, 0x6C, "Grey"},       // 12
    {0x9A, 0xD2, 0x84, "Light Green"}, // 13
    {0x6C, 0x5E, 0xB5, "Light Blue"}, // 14
    {0x95, 0x95, 0x95, "Light Grey"}  // 15
};

// Additional palette variations for exact matching
struct PaletteEntry {
    uint8_t r, g, b;
    uint8_t colorIndex;
};

// Common palette variations - add more as needed
static const PaletteEntry PALETTE_VARIATIONS[] = {
    // VICE variants for cyan (color 3)
    {0x70, 0xA4, 0xB2, 3}, // Pepto PAL
    {0x7A, 0xBF, 0xC7, 3}, // Pixcen
    {0xAA, 0xFF, 0xEE, 3}, // Old estimate
    {0x99, 0xE6, 0xF9, 3}, // VICE Internal

    // Light grey variants (color 15)
    {0x95, 0x95, 0x95, 15}, // Pepto PAL  
    {0xAB, 0xAB, 0xAB, 15}, // Pixcen
    {0xBB, 0xBB, 0xBB, 15}, // Old estimate
    {0xD2, 0xD2, 0xD2, 15}, // VICE Internal
};

class PNGToC64Converter {
private:
    uint8_t* imageData;
    int width, height;
    std::vector<uint8_t> mapData;
    std::vector<uint8_t> scrData;
    std::vector<uint8_t> colData;
    uint8_t backgroundColor;

    // Color matching statistics
    int exactMatches;
    int distanceMatches;
    std::map<uint8_t, int> colorUsage;

    // Calculate color distance using Euclidean distance in RGB space
    double colorDistance(const C64Color& c1, uint8_t r, uint8_t g, uint8_t b) {
        double dr = c1.r - r;
        double dg = c1.g - g;
        double db = c1.b - b;
        return sqrt(dr * dr + dg * dg + db * db);
    }

    // Find closest C64 color to RGB value - try exact match first, then distance
    uint8_t findClosestC64Color(uint8_t r, uint8_t g, uint8_t b) {
        // First try exact matches from palette variations
        const int numVariations = sizeof(PALETTE_VARIATIONS) / sizeof(PaletteEntry);
        for (int i = 0; i < numVariations; i++) {
            if (PALETTE_VARIATIONS[i].r == r &&
                PALETTE_VARIATIONS[i].g == g &&
                PALETTE_VARIATIONS[i].b == b) {
                exactMatches++;
                return PALETTE_VARIATIONS[i].colorIndex;
            }
        }

        // Then try exact matches from main palette
        for (int i = 0; i < 16; i++) {
            if (C64_PALETTE[i].r == r &&
                C64_PALETTE[i].g == g &&
                C64_PALETTE[i].b == b) {
                exactMatches++;
                return i;
            }
        }

        // Finally fall back to distance matching
        uint8_t closest = 0;
        double minDistance = colorDistance(C64_PALETTE[0], r, g, b);

        for (int i = 1; i < 16; i++) {
            double distance = colorDistance(C64_PALETTE[i], r, g, b);
            if (distance < minDistance) {
                minDistance = distance;
                closest = i;
            }
        }
        distanceMatches++;
        return closest;
    }

    // Get pixel color index from image data
    uint8_t getPixelColor(int x, int y) {
        if (x >= width || y >= height) return 0;

        int index = (y * width + x) * 4; // Assuming RGBA
        uint8_t r = imageData[index];
        uint8_t g = imageData[index + 1];
        uint8_t b = imageData[index + 2];

        return findClosestC64Color(r, g, b);
    }

    // Analyze 8x8 character cell for colors
    bool analyzeCharCell(int charX, int charY, std::set<uint8_t>& colors) {
        colors.clear();

        // Scan 8x8 pixel area (4x8 in multicolor mode - double-wide pixels)
        for (int y = 0; y < 8; y++) {
            for (int x = 0; x < 8; x += 2) { // Step by 2 for multicolor double pixels
                int pixelX = charX * 8 + x;
                int pixelY = charY * 8 + y;

                uint8_t color1 = getPixelColor(pixelX, pixelY);
                uint8_t color2 = getPixelColor(pixelX + 1, pixelY);

                // In multicolor mode, both pixels in a pair should be the same
                if (color1 != color2) {
                    // For now, use the first pixel's color
                    colors.insert(color1);
                }
                else {
                    colors.insert(color1);
                }
            }
        }

        // C64 multicolor mode allows max 4 colors per 8x8 char
        return colors.size() <= 4;
    }

    // Find best background color by testing each possibility
    uint8_t findBestBackgroundColor() {
        std::map<uint8_t, int> colorUsage;

        // Count usage of each color across all character cells
        for (int charY = 0; charY < 25; charY++) {
            for (int charX = 0; charX < 40; charX++) {
                std::set<uint8_t> cellColors;
                if (!analyzeCharCell(charX, charY, cellColors)) {
                    continue; // Skip invalid cells for now
                }

                for (uint8_t color : cellColors) {
                    colorUsage[color]++;
                }
            }
        }

        // Create a list of valid background colors with their scores
        std::vector<std::pair<uint8_t, int>> validBackgrounds;

        // Try each color as background and see if it works for all cells
        for (const auto& candidate : colorUsage) {
            uint8_t bgColor = candidate.first;
            bool canUseAsBg = true;
            int score = candidate.second; // Higher usage = higher score

            // Test if this background color works for all cells
            for (int charY = 0; charY < 25 && canUseAsBg; charY++) {
                for (int charX = 0; charX < 40 && canUseAsBg; charX++) {
                    std::set<uint8_t> cellColors;
                    if (!analyzeCharCell(charX, charY, cellColors)) {
                        canUseAsBg = false;
                        break;
                    }

                    // If this cell doesn't use the background color, 
                    // it can only have 3 other colors
                    if (cellColors.find(bgColor) == cellColors.end()) {
                        if (cellColors.size() > 3) {
                            canUseAsBg = false;
                            break;
                        }
                    }
                    else {
                        // Cell uses background color, can have 3 others
                        if (cellColors.size() > 4) {
                            canUseAsBg = false;
                            break;
                        }
                    }
                }
            }

            if (canUseAsBg) {
                validBackgrounds.push_back({ bgColor, score });
            }
        }

        if (validBackgrounds.empty()) {
            return 0; // Fallback to black
        }

        // Sort by score (usage count) - highest first
        std::sort(validBackgrounds.begin(), validBackgrounds.end(),
            [](const auto& a, const auto& b) { return a.second > b.second; });

        // Return the most used valid background color
        return validBackgrounds[0].first;
    }

    // Convert 8x8 character cell to bitmap data
    void convertCharCell(int charX, int charY, uint8_t bgColor) {
        std::set<uint8_t> cellColors;
        analyzeCharCell(charX, charY, cellColors);

        // Remove background color from set to get remaining colors
        cellColors.erase(bgColor);

        // Convert set to vector for indexing
        std::vector<uint8_t> colors(cellColors.begin(), cellColors.end());

        // Ensure we have at most 3 non-background colors
        if (colors.size() > 3) {
            colors.resize(3);
        }

        // Pad with background color if needed
        while (colors.size() < 3) {
            colors.push_back(bgColor);
        }

        // Set screen memory (colors for this character)
        int screenIndex = charY * 40 + charX;
        scrData[screenIndex] = (colors[0] << 4) | colors[1]; // Upper nibble: color1, lower: color2
        colData[screenIndex] = colors[2]; // Color memory holds the third color

        // Convert pixel data to bitmap
        for (int y = 0; y < 8; y++) {
            uint8_t bitmapByte = 0;

            for (int x = 0; x < 8; x += 2) {
                int pixelX = charX * 8 + x;
                int pixelY = charY * 8 + y;

                uint8_t pixelColor = getPixelColor(pixelX, pixelY);
                uint8_t colorIndex;

                // Map pixel color to 2-bit value
                if (pixelColor == bgColor) {
                    colorIndex = 0; // Background
                }
                else {
                    // Find in our color list
                    colorIndex = 1; // Default
                    for (size_t i = 0; i < colors.size(); i++) {
                        if (colors[i] == pixelColor) {
                            colorIndex = i + 1;
                            break;
                        }
                    }
                }

                // Each pixel pair uses 2 bits
                bitmapByte |= (colorIndex << (6 - x));
            }

            // Store in map data (bitmap memory)
            int bitmapIndex = (charY * 40 + charX) * 8 + y;
            mapData[bitmapIndex] = bitmapByte;
        }
    }

public:
    PNGToC64Converter() : imageData(nullptr), width(0), height(0), backgroundColor(0), exactMatches(0), distanceMatches(0) {
        mapData.resize(8000);  // 40x25 chars * 8 bytes each
        scrData.resize(1000);  // 40x25 screen memory
        colData.resize(1000);  // 40x25 color memory
    }

    ~PNGToC64Converter() {
        if (imageData) {
            delete[] imageData;
        }
    }

    // Set image data (should be 320x200 RGBA)
    bool setImageData(uint8_t* data, int w, int h) {
        if (w != 320 || h != 200) {
            return false; // Only support 320x200 for now
        }

        if (imageData) {
            delete[] imageData;
        }

        width = w;
        height = h;
        int dataSize = width * height * 4; // RGBA
        imageData = new uint8_t[dataSize];

        // Copy the data
        for (int i = 0; i < dataSize; i++) {
            imageData[i] = data[i];
        }

        return true;
    }

    // Convert PNG to C64 format
    bool convert() {
        if (!imageData) return false;

        // First pass: find optimal background color
        backgroundColor = findBestBackgroundColor();

        // Second pass: verify all character cells are valid
        for (int charY = 0; charY < 25; charY++) {
            for (int charX = 0; charX < 40; charX++) {
                std::set<uint8_t> cellColors;
                if (!analyzeCharCell(charX, charY, cellColors)) {
                    return false; // Image has too many colors in a character cell
                }

                // Check if colors work with selected background
                if (cellColors.find(backgroundColor) == cellColors.end()) {
                    if (cellColors.size() > 3) {
                        return false;
                    }
                }
                else {
                    if (cellColors.size() > 4) {
                        return false;
                    }
                }
            }
        }

        // Third pass: convert all character cells
        for (int charY = 0; charY < 25; charY++) {
            for (int charX = 0; charX < 40; charX++) {
                convertCharCell(charX, charY, backgroundColor);
            }
        }

        return true;
    }

    // Create KOA-compatible file data
    std::vector<uint8_t> createKoalaFile() {
        std::vector<uint8_t> koalaData;
        koalaData.reserve(10003); // Standard Koala file size

        // Load address (0x6000) - little endian
        koalaData.push_back(0x00);
        koalaData.push_back(0x60);

        // Bitmap data (8000 bytes) - starts at offset 2
        koalaData.insert(koalaData.end(), mapData.begin(), mapData.end());

        // Screen memory (1000 bytes) - starts at offset 8002  
        koalaData.insert(koalaData.end(), scrData.begin(), scrData.end());

        // Color memory (1000 bytes) - starts at offset 9002
        koalaData.insert(koalaData.end(), colData.begin(), colData.end());

        // Background color (1 byte) - at offset 10002
        koalaData.push_back(backgroundColor);

        return koalaData;
    }

    // Get individual components
    const std::vector<uint8_t>& getMapData() const { return mapData; }
    const std::vector<uint8_t>& getScrData() const { return scrData; }
    const std::vector<uint8_t>& getColData() const { return colData; }
    uint8_t getBackgroundColor() const { return backgroundColor; }

    // Get color matching statistics
    void getColorMatchingStats(int& exact, int& distance) {
        exact = exactMatches;
        distance = distanceMatches;
    }
};

// WASM interface functions
extern "C" {
    static PNGToC64Converter* converter = nullptr;

    // Initialize converter
    int png_converter_init() {
        if (converter) {
            delete converter;
        }
        converter = new PNGToC64Converter();
        return 1;
    }

    // Set image data
    int png_converter_set_image(uint8_t* data, int width, int height) {
        if (!converter) return 0;
        return converter->setImageData(data, width, height) ? 1 : 0;
    }

    // Convert image
    int png_converter_convert() {
        if (!converter) return 0;
        return converter->convert() ? 1 : 0;
    }

    // Create Koala file
    int png_converter_create_koala(uint8_t* output) {
        if (!converter) return 0;

        auto koalaData = converter->createKoalaFile();
        for (size_t i = 0; i < koalaData.size(); i++) {
            output[i] = koalaData[i];
        }
        return koalaData.size();
    }

    // Get background color that was selected
    int png_converter_get_background_color() {
        if (!converter) return 0;
        return converter->getBackgroundColor();
    }

    // Get component data
    int png_converter_get_map_data(uint8_t* output) {
        if (!converter) return 0;
        const auto& data = converter->getMapData();
        for (size_t i = 0; i < data.size(); i++) {
            output[i] = data[i];
        }
        return data.size();
    }

    int png_converter_get_scr_data(uint8_t* output) {
        if (!converter) return 0;
        const auto& data = converter->getScrData();
        for (size_t i = 0; i < data.size(); i++) {
            output[i] = data[i];
        }
        return data.size();
    }

    int png_converter_get_col_data(uint8_t* output) {
        if (!converter) return 0;
        const auto& data = converter->getColData();
        for (size_t i = 0; i < data.size(); i++) {
            output[i] = data[i];
        }
        return data.size();
    }

    // Get color matching statistics
    int png_converter_get_color_stats(int* exactMatches, int* distanceMatches) {
        if (!converter) {
            *exactMatches = 0;
            *distanceMatches = 0;
            return 0;
        }
        converter->getColorMatchingStats(*exactMatches, *distanceMatches);
        return 1;
    }

    // Cleanup
    void png_converter_cleanup() {
        if (converter) {
            delete converter;
            converter = nullptr;
        }
    }
}