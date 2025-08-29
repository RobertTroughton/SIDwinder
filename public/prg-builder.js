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

    selectValidLayouts(vizConfig, sidLoadAddress, sidSize) {
        const validLayouts = [];
        const sidEnd = sidLoadAddress + sidSize;

        for (const [key, layout] of Object.entries(vizConfig.layouts)) {
            const vizStart = parseInt(layout.baseAddress);
            const vizEnd = vizStart + parseInt(layout.size || '0x4000');

            const hasOverlap = !(vizEnd <= sidLoadAddress || vizStart >= sidEnd);

            // Format hex inline
            const sidStartHex = '$' + sidLoadAddress.toString(16).toUpperCase().padStart(4, '0');
            const sidEndHex = '$' + sidEnd.toString(16).toUpperCase().padStart(4, '0');

            validLayouts.push({
                key: key,
                layout: layout,
                valid: !hasOverlap,
                vizStart: vizStart,
                vizEnd: vizEnd,
                overlapReason: hasOverlap ?
                    `Overlaps with SID (${sidStartHex}-${sidEndHex})` :
                    null
            });
        }

        return validLayouts;
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

    generateDataBlock(sidInfo, analysisResults, header, saveRoutineAddr, restoreRoutineAddr, numCallsPerFrame, maxCallsPerFrame, selectedSong = 0) {
        const data = new Uint8Array(0x100);

        let effectiveCallsPerFrame = numCallsPerFrame;
        if (maxCallsPerFrame !== null && numCallsPerFrame > maxCallsPerFrame) {
            console.warn(`SID requires ${numCallsPerFrame} calls per frame, but visualizer supports max ${maxCallsPerFrame}. Limiting to ${maxCallsPerFrame}.`);
            effectiveCallsPerFrame = maxCallsPerFrame;
        }

        // JMP SIDInit at $xx00
        data[0] = 0x4C;
        data[1] = sidInfo.initAddress & 0xFF;
        data[2] = (sidInfo.initAddress >> 8) & 0xFF;

        // JMP SIDPlay at $xx03
        data[3] = 0x4C;
        data[4] = sidInfo.playAddress & 0xFF;
        data[5] = (sidInfo.playAddress >> 8) & 0xFF;

        // JMP SaveModifiedMemory at $xx06
        data[6] = 0x4C;
        data[7] = saveRoutineAddr & 0xFF;
        data[8] = (saveRoutineAddr >> 8) & 0xFF;

        // JMP RestoreModifiedMemory at $xx09
        data[9] = 0x4C;
        data[10] = restoreRoutineAddr & 0xFF;
        data[11] = (restoreRoutineAddr >> 8) & 0xFF;

        data[0x0C] = effectiveCallsPerFrame & 0xFF;
        data[0x0D] = 0x00; // BorderColour (will be overwritten by options if present)
        data[0x0E] = 0x00; // BackgroundColour (will be overwritten by options if present)
        data[0x0F] = selectedSong & 0xFF;

        // SID Name at $xx10-$xx2F
        const nameBytes = this.stringToPETSCII(this.centerString(header.name || '', 32), 32);
        for (let i = 0; i < 32; i++) {
            data[0x10 + i] = nameBytes[i];
        }

        // Author Name at $xx30-$xx4F
        const authorBytes = this.stringToPETSCII(this.centerString(header.author || '', 32), 32);
        for (let i = 0; i < 32; i++) {
            data[0x30 + i] = authorBytes[i];
        }

        // Copyright at $xx50-$xx6F
        const copyrightBytes = this.stringToPETSCII(this.centerString(header.copyright || '', 32), 32);
        for (let i = 0; i < 32; i++) {
            data[0x50 + i] = copyrightBytes[i];
        }

        // Technical metadata at $xxC0+
        data[0xC0] = sidInfo.loadAddress & 0xFF;
        data[0xC1] = (sidInfo.loadAddress >> 8) & 0xFF;

        data[0xC2] = sidInfo.initAddress & 0xFF;
        data[0xC3] = (sidInfo.initAddress >> 8) & 0xFF;

        data[0xC4] = sidInfo.playAddress & 0xFF;
        data[0xC5] = (sidInfo.playAddress >> 8) & 0xFF;

        const endAddress = sidInfo.loadAddress + (sidInfo.dataSize || 0x1000) - 1;
        data[0xC6] = endAddress & 0xFF;
        data[0xC7] = (endAddress >> 8) & 0xFF;

        data[0xC8] = (header.songs || 1) & 0xFF;

        const clockType = (header.clockType === 'NTSC') ? 1 : 0;
        data[0xC9] = clockType;

        const sidModel = (header.sidModel && header.sidModel.includes('8580')) ? 1 : 0;
        data[0xCA] = sidModel;

        // ZP usage data
        let zpString = 'NONE';
        if (analysisResults) {
            zpString = this.formatZPUsage(analysisResults.zpAddresses);
        }
        const zpBytes = this.stringToPETSCII(zpString, 32);
        for (let i = 0; i < 32; i++) {
            data[0xE0 + i] = zpBytes[i];
        }

        return data;
    }

    formatZPUsage(zpAddresses) {
        if (!zpAddresses || zpAddresses.length === 0) {
            return 'NONE';
        }

        const sorted = [...zpAddresses].sort((a, b) => a - b);
        const ranges = [];
        let currentRange = { start: sorted[0], end: sorted[0] };

        for (let i = 1; i < sorted.length; i++) {
            if (sorted[i] === currentRange.end + 1) {
                currentRange.end = sorted[i];
            } else {
                ranges.push(currentRange);
                currentRange = { start: sorted[i], end: sorted[i] };
            }
        }
        ranges.push(currentRange);

        const parts = ranges.map(r => {
            if (r.start === r.end) {
                return `$${r.start.toString(16).toUpperCase().padStart(2, '0')}`;
            } else {
                return `$${r.start.toString(16).toUpperCase().padStart(2, '0')}-$${r.end.toString(16).toUpperCase().padStart(2, '0')}`;
            }
        });

        let result = parts.join(', ');
        if (result.length > 255) {
            result = result.substring(0, 252) + '...';
        }

        return result;
    }

    stringToPETSCII(str, length) {
        const bytes = new Uint8Array(length);
        bytes.fill(0x20);

        if (str && str.length > 0) {
            const maxLen = Math.min(str.length, length);

            for (let i = 0; i < maxLen; i++) {
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

                bytes[i] = petscii & 0xFF;
            }
        }

        return bytes;
    }

    centerString(str, length) {
        if (!str || str.length === 0) {
            return str;
        }

        str = str.trim();
        if (str.length >= length) {
            return str.substring(0, length);
        }

        const padding = Math.floor((length - str.length) / 2);
        const paddingStr = ' '.repeat(padding);
        const result = paddingStr + str;

        return result.padEnd(length, ' ');
    }

    getOrdinalSuffix(day) {
        if (day > 3 && day < 21) return 'th';
        switch (day % 10) {
            case 1: return 'st';
            case 2: return 'nd';
            case 3: return 'rd';
            default: return 'th';
        }
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
                    loadAddress: loadAddress,
                    dataSize: musicData.slice(2).length
                };
            }
        }

        return {
            data: musicData,
            loadAddress: loadAddress,
            dataSize: musicData.length
        };
    }

    async processVisualizerInputs(visualizerType, layoutKey = 'addr4000') {
        const config = new VisualizerConfig();
        const vizConfig = await config.loadConfig(visualizerType);

        if (!vizConfig || !vizConfig.inputs) {
            return [];
        }

        const additionalComponents = [];

        for (const inputConfig of vizConfig.inputs) {
            const inputElement = document.getElementById(inputConfig.id);
            let fileData = null;

            if (inputElement && inputElement.files.length > 0) {
                const file = inputElement.files[0];

                // Check if this is a PNG file that needs conversion
                if (file.type === 'image/png' && file.name.toLowerCase().endsWith('.png')) {
                    // Check for PNG converter availability
                    if (typeof EnhancedImageLoader === 'undefined') {
                        console.error('EnhancedImageLoader not available');
                        throw new Error('PNG converter not loaded. Please refresh the page and try again.');
                    }

                    if (!window.SIDwinderModule) {
                        console.error('SIDwinderModule not available');
                        throw new Error('WASM module not ready. Please wait a moment and try again.');
                    }

                    try {
                        console.log(`Converting PNG file: ${file.name}`);
                        const enhancedLoader = new EnhancedImageLoader(window.SIDwinderModule);
                        const result = await enhancedLoader.loadImageFile(file);
                        fileData = result.data;

                        // Debug the generated KOA structure
                        console.log(`PNG converted successfully:`);
                        console.log(`- File size: ${fileData.length} bytes (expected: 10003)`);
                        console.log(`- Load address: ${fileData[1].toString(16).padStart(2, '0')}${fileData[0].toString(16).padStart(2, '0')}`);
                        console.log(`- Background color: ${result.backgroundColor} (${result.backgroundColorName})`);
                        console.log(`- BG at offset ${fileData.length - 1}: ${fileData[fileData.length - 1]}`);

                        // Verify standard KOA structure
                        if (fileData.length === 10003 && fileData[0] === 0x00 && fileData[1] === 0x60) {
                            console.log('✓ Valid KOA format detected');
                        } else {
                            console.warn('⚠ Unexpected KOA format - this may cause issues');
                        }
                    } catch (pngError) {
                        console.error('PNG conversion failed:', pngError);
                        throw new Error(`PNG conversion failed: ${pngError.message}`);
                    }
                } else {
                    // Handle regular binary files
                    try {
                        const arrayBuffer = await file.arrayBuffer();
                        fileData = new Uint8Array(arrayBuffer);
                        console.log(`Loaded binary file: ${file.name}, size: ${fileData.length} bytes`);
                    } catch (loadError) {
                        console.error('File loading failed:', loadError);
                        throw new Error(`Failed to load file ${file.name}: ${loadError.message}`);
                    }
                }
            } else if (inputConfig.default) {
                try {
                    fileData = await config.loadDefaultFile(inputConfig.default);
                    console.log(`Loaded default file: ${inputConfig.default}`);
                } catch (defaultError) {
                    console.error('Default file loading failed:', defaultError);
                    throw new Error(`Failed to load default file ${inputConfig.default}: ${defaultError.message}`);
                }
            }

            if (fileData && inputConfig.memory && inputConfig.memory[layoutKey]) {
                const memoryRegions = inputConfig.memory[layoutKey];

                for (const memConfig of memoryRegions) {
                    const sourceOffset = parseInt(memConfig.sourceOffset);
                    const targetAddress = parseInt(memConfig.targetAddress);
                    const size = parseInt(memConfig.size);

                    // Handle Koala file structure - skip load address if present
                    let adjustedOffset = sourceOffset;

                    // Bounds checking
                    if (adjustedOffset >= fileData.length) {
                        console.warn(`Offset ${adjustedOffset} exceeds file size ${fileData.length} for component ${memConfig.name}`);
                        continue;
                    }

                    const endOffset = Math.min(adjustedOffset + size, fileData.length);
                    const data = fileData.slice(adjustedOffset, endOffset);

                    if (data.length === 0) {
                        console.warn(`No data extracted for component ${memConfig.name}`);
                        continue;
                    }

                    console.log(`Adding component: ${inputConfig.id}_${memConfig.name}, size: ${data.length}, address: $${targetAddress.toString(16).toUpperCase()}`);

                    additionalComponents.push({
                        data: data,
                        loadAddress: targetAddress,
                        name: `${inputConfig.id}_${memConfig.name}`
                    });
                }
            }
        }

        console.log(`Processed ${additionalComponents.length} visualizer input components`);
        return additionalComponents;
    }

    async processVisualizerOptions(visualizerType, layoutKey = 'addr4000') {
        const config = new VisualizerConfig();
        const vizConfig = await config.loadConfig(visualizerType);

        if (!vizConfig || !vizConfig.options) {
            return [];
        }

        const layout = vizConfig.layouts[layoutKey];
        if (!layout) {
            console.warn(`Layout ${layoutKey} not found`);
            return [];
        }

        const optionComponents = [];

        for (const optionConfig of vizConfig.options) {
            const element = document.getElementById(optionConfig.id);
            if (!element) continue;

            // Check if this option maps to a layout field
            if (optionConfig.dataField && layout[optionConfig.dataField]) {
                const targetAddress = parseInt(layout[optionConfig.dataField]);

                if (optionConfig.type === 'date') {
                    const dateValue = element.value;
                    let formattedDate = '';

                    if (dateValue) {
                        const date = new Date(dateValue);
                        const day = date.getDate();
                        const months = ['January', 'February', 'March', 'April', 'May', 'June',
                            'July', 'August', 'September', 'October', 'November', 'December'];
                        const month = months[date.getMonth()];
                        const year = date.getFullYear();

                        const suffix = this.getOrdinalSuffix(day);
                        formattedDate = `${day}${suffix} ${month} ${year}`;
                    }

                    const data = this.stringToPETSCII(
                        this.centerString(formattedDate, 32),
                        32
                    );

                    optionComponents.push({
                        data: data,
                        loadAddress: targetAddress,
                        name: `option_${optionConfig.id}`
                    });

                } else if (optionConfig.type === 'number') {
                    let value = parseInt(element.value) || optionConfig.default || 0;
                    const data = new Uint8Array(1);
                    data[0] = value & 0xFF;

                    optionComponents.push({
                        data: data,
                        loadAddress: targetAddress,
                        name: `option_${optionConfig.id}`
                    });
                } else if (optionConfig.type === 'textarea') {
                    const textValue = element.value || optionConfig.default || '';

                    // Convert to PETSCII and null-terminate
                    const data = new Uint8Array(Math.min(textValue.length + 1, 255));

                    for (let i = 0; i < textValue.length && i < data.length - 1; i++) {
                        let petscii = textValue.charCodeAt(i);
                        if (petscii >= 97 && petscii <= 122) petscii -= 96; // Convert to uppercase
                        data[i] = petscii & 0xFF;
                    }
                    data[Math.min(textValue.length, data.length - 1)] = 0x00; // Null terminator

                    optionComponents.push({
                        data: data,
                        loadAddress: targetAddress,
                        name: `option_${optionConfig.id}`
                    });
                }
            }
        }

        return optionComponents;
    }

    async createPRG(options = {}) {
        const {
            sidLoadAddress = null,
            sidInitAddress = null,
            sidPlayAddress = null,
            preferredAddress = null,
            visualizerFile = 'prg/TextInput.bin',
            compressionType = 'tscrunch',
            maxCallsPerFrame = null,
            visualizerId = null,
            selectedSong = 0
        } = options;

        try {
            this.builder.clear();

            const sidInfo = this.extractSIDMusicData();

            let header = null;
            if (this.analyzer.sidHeader) {
                header = this.analyzer.sidHeader;
            } else {
                const modifiedSID = this.analyzer.createModifiedSID();
                if (modifiedSID) {
                    header = await this.analyzer.loadSID(modifiedSID);
                    this.analyzer.sidHeader = header;
                }
            }

            if (!header) {
                header = {
                    name: 'Unknown',
                    author: 'Unknown',
                    copyright: '',
                    songs: 1,
                    clockType: 'PAL',
                    sidModel: '6581',
                    fileSize: sidInfo.data.length
                };
            }

            // Load visualizer config and select layout
            const config = new VisualizerConfig();
            const visualizerName = options.visualizerId || options.visualizerFile.replace('prg/', '').replace('.bin', '');
            const vizConfig = await config.loadConfig(visualizerName);
            const configMaxCallsPerFrame = vizConfig?.maxCallsPerFrame || null;

            // Get the layout key from options (passed from UI) or select first valid one
            let layoutKey = options.layoutKey;
            if (!layoutKey) {
                const validLayouts = this.selectValidLayouts(vizConfig, sidInfo.loadAddress, sidInfo.dataSize);
                const firstValid = validLayouts.find(l => l.valid);
                if (!firstValid) {
                    throw new Error(`No valid layout found for visualizer ${visualizerName}`);
                }
                layoutKey = firstValid.key;
            }

            const layout = vizConfig?.layouts?.[layoutKey];

            if (!layout) {
                throw new Error(`No valid layout found for visualizer ${visualizerName}`);
            }

            const dataLoadAddress = parseInt(layout.dataAddress);
            const visualizerLoadAddress = parseInt(layout.sysAddress);

            const actualSidAddress = sidLoadAddress || sidInfo.loadAddress;
            const actualInitAddress = sidInitAddress || sidInfo.initAddress || actualSidAddress;
            const actualPlayAddress = sidPlayAddress || sidInfo.playAddress || (actualSidAddress + 3);

            // Add SID music
            this.builder.addComponent(sidInfo.data, actualSidAddress, 'SID Music');

            // Add visualizer
            let nextAvailableAddress = visualizerLoadAddress;

            if (layout.binary) {
                const visualizerBytes = await this.loadBinaryFile(layout.binary);
                const binaryLoadAddress = parseInt(layout.binaryDataStart || layout.baseAddress);
                this.builder.addComponent(visualizerBytes, binaryLoadAddress, 'Visualizer Binary');
                const binaryEndAddress = parseInt(layout.binaryDataEnd || (binaryLoadAddress + visualizerBytes.length));
                nextAvailableAddress = binaryEndAddress + 1;
            }

            // Process additional visualizer inputs
            const additionalComponents = await this.processVisualizerInputs(visualizerName, layoutKey);
            for (const component of additionalComponents) {
                this.builder.addComponent(component.data, component.loadAddress, component.name);
            }

            // Process visualizer options
            const optionComponents = await this.processVisualizerOptions(visualizerName, layoutKey);
            for (const component of optionComponents) {
                this.builder.addComponent(component.data, component.loadAddress, component.name);
            }

            // Add save/restore routines
            let saveRoutineAddr = this.alignToPage(nextAvailableAddress);
            let restoreRoutineAddr = saveRoutineAddr;

            let storageAddress;

            if (this.analyzer.analysisResults && this.analyzer.analysisResults.modifiedAddresses) {
                const modifiedAddrs = Array.from(this.analyzer.analysisResults.modifiedAddresses);

                // Calculate sizes
                const tempSaveRoutine = this.generateSaveRoutine(modifiedAddrs, 0x8000);
                const tempRestoreRoutine = this.generateRestoreRoutine(modifiedAddrs, 0x8000);
                const storageSpaceNeeded = modifiedAddrs.length;

                // Always place before visualizer base address
                const baseAddress = parseInt(layout.baseAddress);
                storageAddress = baseAddress - storageSpaceNeeded;
                restoreRoutineAddr = storageAddress - tempRestoreRoutine.length;
                saveRoutineAddr = restoreRoutineAddr - tempSaveRoutine.length;

                // Generate final routines with correct storage address
                const finalSaveRoutine = this.generateSaveRoutine(modifiedAddrs, storageAddress);
                const finalRestoreRoutine = this.generateRestoreRoutine(modifiedAddrs, storageAddress);

                this.builder.addComponent(finalSaveRoutine, saveRoutineAddr, 'Save Routine');
                this.builder.addComponent(finalRestoreRoutine, restoreRoutineAddr, 'Restore Routine');
            } else {
                console.warn('No analysis results for save/restore routines');
                const dummyRoutine = new Uint8Array([0x60]);
                saveRoutineAddr = 0x3F00;
                restoreRoutineAddr = 0x3F80;
                this.builder.addComponent(dummyRoutine, saveRoutineAddr, 'Dummy Save');
                this.builder.addComponent(dummyRoutine, restoreRoutineAddr, 'Dummy Restore');
            }

            const numCallsPerFrame = this.analyzer.analysisResults?.numCallsPerFrame || 1;

            const dataBlock = this.generateDataBlock(
                {
                    initAddress: actualInitAddress,
                    playAddress: actualPlayAddress,
                    loadAddress: actualSidAddress,
                    dataSize: sidInfo.dataSize
                },
                this.analyzer.analysisResults,
                header,
                saveRoutineAddr,
                restoreRoutineAddr,
                numCallsPerFrame,
                configMaxCallsPerFrame,
                selectedSong
            );

            this.builder.addComponent(dataBlock, dataLoadAddress, 'Data Block');

            // Build PRG
            const prgData = this.builder.build();

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