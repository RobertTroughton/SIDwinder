// visualizer-configs.js - Visualizer configuration loader

class VisualizerConfig {
    constructor() {
        this.configs = new Map();
    }

    async loadConfig(visualizerId) {
        const visualizer = VISUALIZERS.find(v => v.id === visualizerId);
        if (!visualizer || !visualizer.config) {
            return null;
        }

        try {
            const response = await fetch(visualizer.config);
            if (!response.ok) {
                console.warn(`Could not load config for ${visualizerId}`);
                return null;
            }

            const config = await response.json();

            // No longer modify the visualizer object - just return the config
            return config;
        } catch (error) {
            console.error(`Error loading config for ${visualizerId}:`, error);
            return null;
        }
    }

    async loadDefaultFile(filename) {
        try {
            const response = await fetch(filename);
            if (!response.ok) {
                console.warn(`Could not load default file: ${filename}`);
                return null;
            }
            const arrayBuffer = await response.arrayBuffer();
            return new Uint8Array(arrayBuffer);
        } catch (error) {
            console.error(`Error loading default file ${filename}:`, error);
            return null;
        }
    }

    extractMemoryRegions(fileData, memoryConfig) {
        const regions = [];

        for (const region of memoryConfig) {
            const offset = parseInt(region.sourceOffset, 16);
            const size = parseInt(region.size, 16);
            const targetAddr = parseInt(region.targetAddress, 16);

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