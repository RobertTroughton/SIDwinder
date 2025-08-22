// prg-builder.js - PRG file builder for SIDwinder Web
// This module creates C64 PRG files combining SID music, data, and visualizer

class PRGBuilder {
    constructor() {
        this.components = [];
        this.lowestAddress = 0xFFFF;
        this.highestAddress = 0x0000;
    }

    addComponent(data, loadAddress, name) {
        if (!data || data.length === 0) {
            throw new Error(`Component ${name} has no data`);
        }

        this.components.push({
            data: data,
            loadAddress: loadAddress,
            size: data.length,
            name: name
        });

        this.lowestAddress = Math.min(this.lowestAddress, loadAddress);
        this.highestAddress = Math.max(this.highestAddress, loadAddress + data.length - 1);
    }

    build() {
        if (this.components.length === 0) {
            throw new Error('No components added to PRG');
        }

        this.components.sort((a, b) => a.loadAddress - b.loadAddress);

        const totalSize = (this.highestAddress - this.lowestAddress + 1) + 2;
        const prgData = new Uint8Array(totalSize);

        prgData[0] = this.lowestAddress & 0xFF;
        prgData[1] = (this.lowestAddress >> 8) & 0xFF;

        for (let i = 2; i < totalSize; i++) {
            prgData[i] = 0x00;
        }

        for (const component of this.components) {
            const offset = component.loadAddress - this.lowestAddress + 2;
            for (let i = 0; i < component.data.length; i++) {
                prgData[offset + i] = component.data[i];
            }
        }

        return prgData;
    }

    clear() {
        this.components = [];
        this.lowestAddress = 0xFFFF;
        this.highestAddress = 0x0000;
    }

    getInfo() {
        return {
            components: this.components.map(c => ({
                name: c.name,
                loadAddress: c.loadAddress,
                size: c.size,
                endAddress: c.loadAddress + c.size - 1
            })),
            lowestAddress: this.lowestAddress,
            highestAddress: this.highestAddress,
            totalSize: this.highestAddress - this.lowestAddress + 1
        };
    }
}

class SIDwinderPRGExporter {
    constructor(analyzer) {
        this.analyzer = analyzer;
        this.builder = new PRGBuilder();
        this.compressorManager = new CompressorManager();
        this.saveRoutineAddress = 0;
        this.restoreRoutineAddress = 0;
    }

    alignToPage(address) {
        return (address + 0xFF) & 0xFF00;
    }

    generateSaveRoutine(modifiedAddresses, targetAddress) {
        const code = [];
        let storeAddr = targetAddress;

        const filtered = modifiedAddresses
            .filter(addr => {
                if (addr >= 0x0100 && addr <= 0x01FF) return false;
                if (addr >= 0xD400 && addr <= 0xD7FF) return false;
                return true;
            })
            .sort((a, b) => a - b);

        for (const addr of filtered) {
            if (addr < 256) {
                code.push(0xA5);
                code.push(addr);
            } else {
                code.push(0xAD);
                code.push(addr & 0xFF);
                code.push((addr >> 8) & 0xFF);
            }

            code.push(0x8D);
            code.push(storeAddr & 0xFF);
            code.push((storeAddr >> 8) & 0xFF);
            storeAddr++;
        }

        code.push(0x60);
        return new Uint8Array(code);
    }

    generateRestoreRoutine(modifiedAddresses, sourceAddress) {
        const code = [];
        let loadAddr = sourceAddress;

        const filtered = modifiedAddresses
            .filter(addr => {
                if (addr >= 0x0100 && addr <= 0x01FF) return false;
                if (addr >= 0xD400 && addr <= 0xD7FF) return false;
                return true;
            })
            .sort((a, b) => a - b);

        for (const addr of filtered) {
            code.push(0xAD);
            code.push(loadAddr & 0xFF);
            code.push((loadAddr >> 8) & 0xFF);

            if (addr < 256) {
                code.push(0x85);
                code.push(addr);
            } else {
                code.push(0x8D);
                code.push(addr & 0xFF);
                code.push((addr >> 8) & 0xFF);
            }

            loadAddr++;
        }

        code.push(0x60);
        return new Uint8Array(code);
    }

    generateDataBlock(sidInfo, saveRoutineAddr, restoreRoutineAddr, name, author, numCallsPerFrame, maxCallsPerFrame, selectedSong = 0) {
        const data = new Uint8Array(0x50);

        // Apply the maximum calls per frame limit if specified
        let effectiveCallsPerFrame = numCallsPerFrame;
        if (maxCallsPerFrame !== null && numCallsPerFrame > maxCallsPerFrame) {
            console.warn(`SID requires ${numCallsPerFrame} calls per frame, but visualizer supports max ${maxCallsPerFrame}. Limiting to ${maxCallsPerFrame}.`);
            effectiveCallsPerFrame = maxCallsPerFrame;
        }

        // JMP SIDInit at $4000
        data[0] = 0x4C;
        data[1] = sidInfo.initAddress & 0xFF;
        data[2] = (sidInfo.initAddress >> 8) & 0xFF;

        // JMP SIDPlay at $4003
        data[3] = 0x4C;
        data[4] = sidInfo.playAddress & 0xFF;
        data[5] = (sidInfo.playAddress >> 8) & 0xFF;

        // JMP SaveModifiedMemory at $4006
        data[6] = 0x4C;
        data[7] = saveRoutineAddr & 0xFF;
        data[8] = (saveRoutineAddr >> 8) & 0xFF;

        // JMP RestoreModifiedMemory at $4009
        data[9] = 0x4C;
        data[10] = restoreRoutineAddr & 0xFF;
        data[11] = (restoreRoutineAddr >> 8) & 0xFF;

        data[0x0C] = effectiveCallsPerFrame & 0xFF;
        data[0x0D] = 0x00; // BorderColour
        data[0x0E] = 0x00; // BitmapScreenColour

        // Add selected song at offset 0x0F (after BitmapScreenColour)
        data[0x0F] = selectedSong & 0xFF;

        // SID Name at $4010-$402F
        const nameBytes = this.stringToPETSCII(name, 32);
        for (let i = 0; i < 32; i++) {
            data[0x10 + i] = nameBytes[i];
        }

        // Author Name at $4030-$404F
        const authorBytes = this.stringToPETSCII(author, 32);
        for (let i = 0; i < 32; i++) {
            data[0x30 + i] = authorBytes[i];
        }

        return data;
    }

    stringToPETSCII(str, length) {
        const bytes = new Uint8Array(length);
        bytes.fill(0x20);

        if (str && str.trim().length > 0) {
            str = str.trim();
            if (str.length > length) {
                str = str.substring(0, length);
            }

            const padding = Math.floor((length - str.length) / 2);

            for (let i = 0; i < str.length; i++) {
                const code = str.charCodeAt(i);
                let petscii = 0x20;

                if (code >= 65 && code <= 90) {
                    petscii = code;
                } else if (code >= 97 && code <= 122) {
                    petscii = code - 32;
                } else if (code >= 48 && code <= 57) {
                    petscii = code;
                } else if (code === 32) {
                    petscii = 0x20;
                } else {
                    petscii = code;
                }

                bytes[padding + i] = petscii & 0xFF;
            }
        }

        return bytes;
    }

    async loadBinaryFile(url) {
        try {
            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`Failed to load ${url}: ${response.statusText}`);
            }
            const arrayBuffer = await response.arrayBuffer();
            return new Uint8Array(arrayBuffer);
        } catch (error) {
            console.error(`Error loading ${url}:`, error);
            throw error;
        }
    }

    extractSIDMusicData() {
        const modifiedSID = this.analyzer.createModifiedSID();
        if (!modifiedSID) {
            throw new Error('Failed to get SID data');
        }

        const view = new DataView(modifiedSID.buffer);
        const version = view.getUint16(0x04, false);
        const headerSize = (version === 1) ? 0x76 : 0x7C;

        let loadAddress = view.getUint16(0x08, false);
        let dataStart = headerSize;

        if (loadAddress === 0) {
            loadAddress = view.getUint16(headerSize, true);
            dataStart = headerSize + 2;
        }

        const musicData = modifiedSID.slice(dataStart);

        if (musicData.length >= 2) {
            const firstTwo = (musicData[0] | (musicData[1] << 8));
            if (firstTwo === loadAddress) {
                return {
                    data: musicData.slice(2),
                    loadAddress: loadAddress
                };
            }
        }

        return {
            data: musicData,
            loadAddress: loadAddress
        };
    }

    async processVisualizerInputs(visualizerType) {

        const config = new VisualizerConfig();
        const vizConfig = await config.loadConfig(visualizerType);

        if (!vizConfig || !vizConfig.inputs) {
            return []; // No additional inputs needed
        }

        const additionalComponents = [];

        for (const inputConfig of vizConfig.inputs) {
            const inputElement = document.getElementById(inputConfig.id);
            let fileData = null;

            if (inputElement && inputElement.files.length > 0) {
                // User selected a file
                const file = inputElement.files[0];
                const arrayBuffer = await file.arrayBuffer();
                fileData = new Uint8Array(arrayBuffer);
            } else if (inputConfig.default) {
                // Use default file
                fileData = await config.loadDefaultFile(inputConfig.default);
            }

            if (fileData && inputConfig.memory) {
                // Extract memory regions
                const regions = config.extractMemoryRegions(fileData, inputConfig.memory);

                // Add each region as a component
                for (const region of regions) {
                    additionalComponents.push({
                        data: region.data,
                        loadAddress: region.targetAddress,
                        name: `${inputConfig.id}_${region.name}`
                    });
                }
            }
        }

        return additionalComponents;
    }

    async processVisualizerOptions(visualizerType) {
        const config = new VisualizerConfig();
        const vizConfig = await config.loadConfig(visualizerType);

        if (!vizConfig || !vizConfig.options) {
            return [];
        }

        const optionComponents = [];

        for (const optionConfig of vizConfig.options) {
            const element = document.getElementById(optionConfig.id);
            if (element && optionConfig.memory) {
                let value = parseInt(element.value) || optionConfig.default || 0;

                // Create a single-byte component for this option
                const data = new Uint8Array(optionConfig.memory.size || 1);
                data[0] = value & 0xFF; // Ensure it's a byte

                optionComponents.push({
                    data: data,
                    loadAddress: parseInt(optionConfig.memory.targetAddress),
                    name: `option_${optionConfig.id}`
                });
            }
        }

        return optionComponents;
    }

    async createPRG(options = {}) {
        const {
            sidLoadAddress = null,
            sidInitAddress = null,
            sidPlayAddress = null,
            dataLoadAddress = 0x4000,
            visualizerFile = 'prg/RaistlinBars.bin',
            visualizerLoadAddress = 0x4100,
            includeData = true,
            compressionType = 'tscrunch',
            maxCallsPerFrame = null,
            visualizerId = null,
            selectedSong = 0
        } = options;

        try {
            this.builder.clear();

            const sidInfo = this.extractSIDMusicData();

            const actualSidAddress = sidLoadAddress || sidInfo.loadAddress;
            const actualInitAddress = sidInitAddress || sidInfo.initAddress || actualSidAddress;
            const actualPlayAddress = sidPlayAddress || sidInfo.playAddress || (actualSidAddress + 3);

            const header = await this.analyzer.loadSID(this.analyzer.createModifiedSID());

            // Add SID music
            this.builder.addComponent(sidInfo.data, actualSidAddress, 'SID Music');

            // Add visualizer
            let nextAvailableAddress = visualizerLoadAddress;
            if (visualizerFile && visualizerFile !== 'none') {
                const visualizerBytes = await this.loadBinaryFile(visualizerFile);
                this.builder.addComponent(visualizerBytes, visualizerLoadAddress, 'Visualizer');
                nextAvailableAddress = visualizerLoadAddress + visualizerBytes.length;
            }

            // Process additional visualizer inputs
            // Use the visualizerId if provided, otherwise try to extract from filename
            const visualizerName = options.visualizerId ||
                options.visualizerFile.replace('prg/', '').replace('.bin', '').toLowerCase();

            const additionalComponents = await this.processVisualizerInputs(visualizerName);

            for (const component of additionalComponents) {
                this.builder.addComponent(component.data, component.loadAddress, component.name);
            }

            // Process visualizer options
            const optionComponents = await this.processVisualizerOptions(visualizerName);

            for (const component of optionComponents) {
                this.builder.addComponent(component.data, component.loadAddress, component.name);
            }

            // Add save/restore routines
            let saveRoutineAddr = this.alignToPage(nextAvailableAddress);
            let restoreRoutineAddr = saveRoutineAddr;

            if (this.analyzer.analysisResults && this.analyzer.analysisResults.modifiedAddresses) {
                const modifiedAddrs = Array.from(this.analyzer.analysisResults.modifiedAddresses);

                const saveRoutine = this.generateSaveRoutine(modifiedAddrs, 0);
                saveRoutineAddr = this.alignToPage(nextAvailableAddress);
                restoreRoutineAddr = this.alignToPage(saveRoutineAddr + saveRoutine.length);
                const restoreRoutine = this.generateRestoreRoutine(modifiedAddrs, 0);
                const storageAddress = this.alignToPage(restoreRoutineAddr + restoreRoutine.length);

                const finalSaveRoutine = this.generateSaveRoutine(modifiedAddrs, storageAddress);
                const finalRestoreRoutine = this.generateRestoreRoutine(modifiedAddrs, storageAddress);

                this.builder.addComponent(finalSaveRoutine, saveRoutineAddr, 'Save Routine');
                this.builder.addComponent(finalRestoreRoutine, restoreRoutineAddr, 'Restore Routine');
            } else {
                console.warn('No analysis results for save/restore routines');
                const dummyRoutine = new Uint8Array([0x60]);
                this.builder.addComponent(dummyRoutine, saveRoutineAddr, 'Dummy Save');
                restoreRoutineAddr = this.alignToPage(saveRoutineAddr + 1);
                this.builder.addComponent(dummyRoutine, restoreRoutineAddr, 'Dummy Restore');
            }

            const numCallsPerFrame = this.analyzer.analysisResults?.numCallsPerFrame || 1;

            // Make sure maxCallsPerFrame is passed from options
            // Near the end where we generate the data block:
            const dataBlock = this.generateDataBlock(
                {
                    initAddress: actualInitAddress,
                    playAddress: actualPlayAddress
                },
                saveRoutineAddr,
                restoreRoutineAddr,
                header.name || 'Unknown',
                header.author || 'Unknown',
                numCallsPerFrame,
                options.maxCallsPerFrame,
                selectedSong
            );

            this.builder.addComponent(dataBlock, dataLoadAddress, 'Data Block');

            // Build PRG
            const prgData = this.builder.build();

            const info = this.builder.getInfo();

            // Store these for later use
            this.saveRoutineAddress = saveRoutineAddr;
            this.restoreRoutineAddress = restoreRoutineAddr;

            // Apply compression if requested
            if (compressionType !== 'none') {
                try {
                    if (!this.compressorManager) {
                        this.compressorManager = new CompressorManager();
                    }

                    if (!this.compressorManager.isAvailable(compressionType)) {
                        console.warn(`${compressionType} compressor not available, returning uncompressed`);
                        return prgData;
                    }

                    const uncompressedStart = this.builder.lowestAddress;
                    const executeAddress = visualizerLoadAddress;

                    const result = await this.compressorManager.compress(
                        prgData,
                        compressionType,
                        uncompressedStart,
                        executeAddress
                    );

                    const result_ratio = result.compressedSize / result.originalSize;
                    console.log(`${compressionType.toUpperCase()} compression: ${result.originalSize} -> ${result.compressedSize} bytes (${(result_ratio * 100).toFixed(1)}%)`);

                    return result.data;

                } catch (error) {
                    console.error(`${compressionType} compression failed:`, error);
                    return prgData;
                }
            }

            return prgData;

        } catch (error) {
            console.error('Error creating PRG:', error);
            throw error;
        }
    }
}

// Export globally
window.PRGBuilder = PRGBuilder;
window.SIDwinderPRGExporter = SIDwinderPRGExporter;
