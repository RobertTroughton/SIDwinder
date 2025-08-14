// visualizer-configs.js - Visualizer configuration loader

class VisualizerConfig {
    constructor() {
        this.configs = new Map();
        this.loadedFiles = new Map(); // Cache loaded config files
    }

    async loadConfig(visualizerName) {
        // Check cache first
        if (this.configs.has(visualizerName)) {
            return this.configs.get(visualizerName);
        }

        try {
            const response = await fetch(`prg/${visualizerName}.json`);
            if (!response.ok) {
                // No config file means simple visualizer with no extra inputs
                return null;
            }

            const config = await response.json();
            this.configs.set(visualizerName, config);
            return config;

        } catch (error) {
            console.log(`No config for ${visualizerName}, using defaults`);
            return null;
        }
    }

    async loadDefaultFile(url) {
        try {
            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`Failed to load default file: ${url}`);
            }
            const arrayBuffer = await response.arrayBuffer();
            return new Uint8Array(arrayBuffer);
        } catch (error) {
            console.warn(`Could not load default file ${url}:`, error);
            return null;
        }
    }

    validateFileSize(file, expectedSizes) {
        // Koala files are typically 10001 or 10003 bytes
        const validSizes = expectedSizes || [10001, 10003];
        return validSizes.includes(file.length);
    }

    extractMemoryRegions(fileData, memoryConfig) {
        const regions = [];

        for (const region of memoryConfig) {
            const offset = parseInt(region.sourceOffset);
            const size = parseInt(region.size);
            const targetAddr = parseInt(region.targetAddress);

            if (offset + size > fileData.length) {
                throw new Error(`Invalid region ${region.name}: exceeds file size`);
            }

            regions.push({
                name: region.name,
                data: fileData.slice(offset, offset + size),
                targetAddress: targetAddr,
                size: size
            });
        }

        return regions;
    }
}

// Export globally
window.VisualizerConfig = VisualizerConfig;