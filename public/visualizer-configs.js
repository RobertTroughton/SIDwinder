class VisualizerConfig {
    constructor() {
        this.configs = new Map();
        this.galleryCache = new Map(); // Cache loaded galleries
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

            // Process inputs to merge galleries
            if (config.inputs) {
                for (const input of config.inputs) {
                    if (input.galleryFiles || input.gallery) {
                        input.gallery = await this.loadAndMergeGalleries(
                            input.galleryFiles || [],
                            input.gallery || []
                        );
                    }
                }
            }

            return config;
        } catch (error) {
            console.error(`Error loading config for ${visualizerId}:`, error);
            return null;
        }
    }

    async loadAndMergeGalleries(galleryFiles, inlineGallery) {
        const mergedGallery = [];
        const seenFiles = new Set();

        // Load external gallery files
        for (const galleryFile of galleryFiles) {
            try {
                const items = await this.loadGalleryFile(galleryFile);
                for (const item of items) {
                    if (!seenFiles.has(item.file)) {
                        mergedGallery.push(item);
                        seenFiles.add(item.file);
                    }
                }
            } catch (error) {
                console.warn(`Failed to load gallery file ${galleryFile}:`, error);
            }
        }

        // Add inline gallery items
        for (const item of inlineGallery) {
            if (!seenFiles.has(item.file)) {
                mergedGallery.push(item);
                seenFiles.add(item.file);
            }
        }

        return mergedGallery;
    }

    async loadGalleryFile(galleryFile) {
        // Check cache first
        if (this.galleryCache.has(galleryFile)) {
            return this.galleryCache.get(galleryFile);
        }

        try {
            const response = await fetch(galleryFile);
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const items = await response.json();

            // Validate format
            if (!Array.isArray(items)) {
                throw new Error('Gallery file must contain an array');
            }

            // Validate each item
            for (const item of items) {
                if (!item.name || !item.file) {
                    throw new Error('Gallery items must have "name" and "file" properties');
                }
            }

            // Cache the result
            this.galleryCache.set(galleryFile, items);
            return items;
        } catch (error) {
            console.error(`Error loading gallery file ${galleryFile}:`, error);
            return [];
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

    // Clear the gallery cache if needed
    clearGalleryCache() {
        this.galleryCache.clear();
    }
}

window.VisualizerConfig = VisualizerConfig;