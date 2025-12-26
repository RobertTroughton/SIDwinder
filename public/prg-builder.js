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

        // Sort by loadAddress, with larger components first at the same address
        // This ensures smaller patches (like option values) override larger binaries
        this.components.sort((a, b) => {
            if (a.loadAddress !== b.loadAddress) {
                return a.loadAddress - b.loadAddress;
            }
            // Same load address: larger components first (so smaller ones can override)
            return b.size - a.size;
        });

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

    /**
     * Find safe memory location for save/restore routines
     * Searches for gaps between existing components that can fit the routines
     * @param {number} routineSize - Total size of save+restore routines
     * @param {number} sidLoadAddress - SID load address
     * @param {number} sidDataLength - SID data length
     * @returns {number} Safe address for routines
     */
    findSafeMemoryForRoutines(routineSize, sidLoadAddress, sidDataLength) {
        // Build list of used memory ranges from components
        const usedRanges = [];

        for (const comp of this.builder.components) {
            usedRanges.push({
                start: comp.loadAddress,
                end: comp.loadAddress + comp.size
            });
        }

        // Add I/O area as always used ($D000-$DFFF)
        usedRanges.push({ start: 0xD000, end: 0xE000 });

        // Sort by start address
        usedRanges.sort((a, b) => a.start - b.start);

        // Look for gaps that can fit the routines
        // Start searching from $0900 (after zero page, stack, system areas, and screen)
        let prevEnd = 0x0900;

        for (const range of usedRanges) {
            // Skip if this range starts before our search point
            if (range.end <= prevEnd) continue;

            const gapStart = prevEnd;
            const gapEnd = range.start;

            // Skip gaps in I/O area
            if (gapStart >= 0xD000 && gapStart < 0xE000) {
                prevEnd = Math.max(prevEnd, range.end);
                continue;
            }

            // Check if gap is before I/O area
            const effectiveGapEnd = Math.min(gapEnd, 0xD000);
            const gapSize = effectiveGapEnd - gapStart;

            if (gapSize >= routineSize) {
                // Found a suitable gap
                return this.alignToPage(gapStart);
            }

            prevEnd = Math.max(prevEnd, range.end);
        }

        // Check gap after all components but before I/O
        if (prevEnd < 0xD000) {
            const gapSize = 0xD000 - prevEnd;
            if (gapSize >= routineSize) {
                return this.alignToPage(prevEnd);
            }
        }

        // Check after I/O area ($E000+) but only if it won't overflow
        const afterIO = Math.max(prevEnd, 0xE000);
        if (afterIO + routineSize <= 0xFFFF) {
            return this.alignToPage(afterIO);
        }

        // Last resort: use $0900 and hope for the best
        console.warn(`Could not find ${routineSize} bytes for save/restore routines, using $0900`);
        return 0x0900;
    }

    calculateSaveRestoreSize(modifiedAddresses) {
        const filtered = modifiedAddresses.filter(addr => {
            if (addr >= 0x0100 && addr <= 0x01FF) return false;
            if (addr >= 0xD400 && addr <= 0xD7FF) return false;
            return true;
        });

        let saveSize = 1; // RTS
        let restoreSize = 1; // RTS
        for (const addr of filtered) {
            if (addr < 256) {
                saveSize += 5; // Save: LDA zp (2) + STA abs (3) = 5
                restoreSize += 4; // Restore: LDA # (2) + STA zp (2) = 4
            } else {
                saveSize += 6; // Save: LDA abs (3) + STA abs (3) = 6
                restoreSize += 5; // Restore: LDA # (2) + STA abs (3) = 5
            }
        }

        return {
            saveSize,
            restoreSize,
            totalSize: saveSize + restoreSize,
            addressCount: filtered.length
        };
    }

    selectValidLayouts(vizConfig, sidLoadAddress, sidSize, modifiedAddresses = null) {
        const validLayouts = [];

        // The SID data range - save/restore routines are placed separately in free memory
        let effectiveSidStart = sidLoadAddress;
        let effectiveSidEnd = sidLoadAddress + sidSize;

        // Cap at 0xFFFF to handle high-memory SIDs correctly
        if (effectiveSidEnd > 0xFFFF) effectiveSidEnd = 0xFFFF;

        // Note: Save/restore routines are placed AFTER all components (including visualizer)
        // by the PRG builder, not immediately after the SID. So we don't add routine size
        // to the SID range for overlap detection.

        for (const [key, layout] of Object.entries(vizConfig.layouts)) {
            const vizStart = parseInt(layout.baseAddress);
            const vizEnd = vizStart + parseInt(layout.size || '0x4000');

            // Check for overlaps - visualizer vs SID data range (without save/restore)
            const hasOverlap = !(vizEnd <= effectiveSidStart || vizStart >= effectiveSidEnd);

            // Format hex inline
            const sidStartHex = '$' + effectiveSidStart.toString(16).toUpperCase().padStart(4, '0');
            const sidEndHex = '$' + effectiveSidEnd.toString(16).toUpperCase().padStart(4, '0');

            // Calculate where save/restore would actually go (after visualizer if needed)
            let saveRestoreStart = effectiveSidEnd;
            if (!hasOverlap && vizEnd > saveRestoreStart) {
                // If visualizer is after SID, save/restore goes after visualizer
                saveRestoreStart = this.alignToPage(vizEnd);
            }

            validLayouts.push({
                key: key,
                layout: layout,
                valid: !hasOverlap,
                vizStart: vizStart,
                vizEnd: vizEnd,
                saveRestoreStart: saveRestoreStart,
                saveRestoreEnd: saveRestoreStart + (modifiedAddresses ? this.calculateSaveRestoreSize(modifiedAddresses).totalSize : 0),
                overlapReason: hasOverlap ?
                    `Overlaps with SID (${sidStartHex}-${sidEndHex})` :
                    null
            });
        }

        return validLayouts;
    }

    generateOptimizedSaveRoutine(modifiedAddresses, restoreRoutineAddr) {
        const code = [];
        let restoreOffset = 0;

        const filtered = modifiedAddresses
            .filter(addr => {
                if (addr >= 0x0100 && addr <= 0x01FF) return false;
                if (addr >= 0xD400 && addr <= 0xD7FF) return false;
                return true;
            })
            .sort((a, b) => a - b);

        for (const addr of filtered) {
            // Load from memory address
            if (addr < 256) {
                code.push(0xA5); // LDA zp
                code.push(addr);
            } else {
                code.push(0xAD); // LDA abs
                code.push(addr & 0xFF);
                code.push((addr >> 8) & 0xFF);
            }

            // Store into restore routine (self-modifying code)
            // Skip the LDA # opcode (1 byte) to get to the value byte
            const targetAddr = restoreRoutineAddr + restoreOffset + 1;
            code.push(0x8D); // STA abs
            code.push(targetAddr & 0xFF);
            code.push((targetAddr >> 8) & 0xFF);

            // Calculate next offset based on what the restore routine will use
            if (addr < 256) {
                restoreOffset += 4; // LDA # (2) + STA zp (2)
            } else {
                restoreOffset += 5; // LDA # (2) + STA abs (3)
            }
        }

        code.push(0x60); // RTS
        return new Uint8Array(code);
    }

    generateOptimizedRestoreRoutine(modifiedAddresses) {
        const code = [];

        const filtered = modifiedAddresses
            .filter(addr => {
                if (addr >= 0x0100 && addr <= 0x01FF) return false;
                if (addr >= 0xD400 && addr <= 0xD7FF) return false;
                return true;
            })
            .sort((a, b) => a - b);

        for (const addr of filtered) {
            // LDA immediate (value will be filled by save routine)
            code.push(0xA9); // LDA #
            code.push(0x00); // Placeholder value

            // Store to memory address
            if (addr < 256) {
                code.push(0x85); // STA zp (2 bytes)
                code.push(addr);
            } else {
                code.push(0x8D); // STA abs (3 bytes)
                code.push(addr & 0xFF);
                code.push((addr >> 8) & 0xFF);
            }
        }

        code.push(0x60); // RTS
        return new Uint8Array(code);
    }

    generateDataBlock(sidInfo, analysisResults, header, saveRoutineAddr, restoreRoutineAddr, numCallsPerFrame, maxCallsPerFrame, selectedSong = 0, modifiedCount = 0, sidChipCount = 1) {
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

        // Apply font case conversion if needed
        let nameStr = header.name || '';
        let authorStr = header.author || '';
        let copyrightStr = header.copyright || '';

        if (typeof FONT_DATA !== 'undefined' && this.currentFontCaseType !== undefined) {
            nameStr = FONT_DATA.convertTextForFont(nameStr, this.currentFontCaseType);
            authorStr = FONT_DATA.convertTextForFont(authorStr, this.currentFontCaseType);
            copyrightStr = FONT_DATA.convertTextForFont(copyrightStr, this.currentFontCaseType);
        }

        // SID Name at $xx10-$xx2F
        const nameBytes = this.stringToPETSCII(this.centerString(nameStr, 32), 32);
        for (let i = 0; i < 32; i++) {
            data[0x10 + i] = nameBytes[i];
        }

        // Author Name at $xx30-$xx4F
        const authorBytes = this.stringToPETSCII(this.centerString(authorStr, 32), 32);
        for (let i = 0; i < 32; i++) {
            data[0x30 + i] = authorBytes[i];
        }

        // Copyright at $xx50-$xx6F
        const copyrightBytes = this.stringToPETSCII(this.centerString(copyrightStr, 32), 32);
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

        // Store modified address count at $xxCB-$xxCC
        data[0xCB] = modifiedCount & 0xFF;
        data[0xCC] = (modifiedCount >> 8) & 0xFF;

        // Store number of SID chips at $xxCD (1-4, clamped)
        data[0xCD] = Math.min(Math.max(sidChipCount, 1), 4) & 0xFF;

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

        // Build the string progressively, ensuring we don't break in the middle of a range
        let result = '';
        const maxLength = 20;
        const ellipsis = '...';
        const ellipsisLength = ellipsis.length;

        for (let i = 0; i < parts.length; i++) {
            const part = parts[i];
            const separator = i === 0 ? '' : ', ';
            const testString = result + separator + part;

            // Check if adding this part would exceed our limit
            if (testString.length > maxLength) {
                // If we haven't added anything yet, truncate the first part
                if (result === '') {
                    // This handles the edge case where even the first range is too long
                    if (part.length > maxLength - ellipsisLength) {
                        result = part.substring(0, maxLength - ellipsisLength) + ellipsis;
                    } else {
                        result = part;
                    }
                } else {
                    // We have content, check if we can fit the ellipsis
                    if (result.length <= maxLength - ellipsisLength) {
                        result = result + ellipsis;
                    } else {
                        // Remove the last complete range and add ellipsis
                        const lastComma = result.lastIndexOf(',');
                        if (lastComma > 0 && lastComma <= maxLength - ellipsisLength) {
                            result = result.substring(0, lastComma) + ellipsis;
                        } else {
                            // If we can't cleanly remove the last range, just truncate
                            result = result.substring(0, maxLength - ellipsisLength) + ellipsis;
                        }
                    }
                }
                break;
            }

            result = testString;
        }

        return result;
    }

    stringToPETSCII(str, length) {
        const bytes = new Uint8Array(length);
        bytes.fill(0);  // Screen code 0 = space (ASCII 32)

        if (str && str.length > 0) {
            const maxLen = Math.min(str.length, length);

            for (let i = 0; i < maxLen; i++) {
                const code = str.charCodeAt(i);
                let screenCode = 0;  // Default to space (screen code 0 = ASCII 32)

                // Convert ASCII to screen code by subtracting 32
                // ASCII 32-127 maps to screen codes 0-95
                // This aligns with our charset where glyph N = ASCII (N+32)
                if (code >= 32 && code <= 127) {
                    screenCode = code - 32;
                } else {
                    // Out of range - use space
                    screenCode = 0;
                }

                bytes[i] = screenCode & 0xFF;
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

    async processVisualizerInputs(visualizerType, layoutKey = 'bank4000') {
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
                    if (typeof PNGConverter === 'undefined') {
                        console.error('PNGConverter not available');
                        throw new Error('PNG converter not loaded. Please refresh the page and try again.');
                    }

                    if (!window.SIDwinderModule) {
                        console.error('SIDwinderModule not available');
                        throw new Error('WASM module not ready. Please wait a moment and try again.');
                    }

                    try {
                        const converter = new PNGConverter(window.SIDwinderModule);
                        converter.init();
                        const result = await converter.convertPNGToC64(file);
                        fileData = result.data;

                        // Verify standard C64 bitmap structure
                        if (fileData.length === 10003 && fileData[0] === 0x00 && fileData[1] === 0x60) {
                            // Valid format detected
                        } else {
                            console.warn('Unexpected C64 image format - this may cause issues');
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
                    } catch (loadError) {
                        console.error('File loading failed:', loadError);
                        throw new Error(`Failed to load file ${file.name}: ${loadError.message}`);
                    }
                }
            } else if (inputConfig.default) {
                try {
                    const rawFileData = await config.loadDefaultFile(inputConfig.default);

                    // Check if the default file is a PNG that needs conversion
                    if (inputConfig.default.toLowerCase().endsWith('.png') && this.isPNGFile(rawFileData)) {
                        // Check for PNG converter availability
                        if (typeof PNGConverter === 'undefined') {
                            console.error('PNGConverter not available');
                            throw new Error('PNG converter not loaded. Please refresh the page and try again.');
                        }

                        if (!window.SIDwinderModule) {
                            console.error('SIDwinderModule not available');
                            throw new Error('WASM module not ready. Please wait a moment and try again.');
                        }

                        try {
                            // Create a blob from the PNG data and convert it to a File-like object
                            const blob = new Blob([rawFileData], { type: 'image/png' });
                            const file = new File([blob], inputConfig.default.split('/').pop(), { type: 'image/png' });

                            const converter = new PNGConverter(window.SIDwinderModule);
                            converter.init();
                            const result = await converter.convertPNGToC64(file);
                            fileData = result.data;

                            if (fileData.length === 10003 && fileData[0] === 0x00 && fileData[1] === 0x60) {
                                console.log('Default PNG converted to valid C64 image format');
                            } else {
                                console.warn('Default PNG conversion resulted in unexpected C64 image format');
                            }
                        } catch (pngError) {
                            console.error('Default PNG conversion failed:', pngError);
                            throw new Error(`Default PNG conversion failed: ${pngError.message}`);
                        }
                    } else {
                        // Use the raw file data for other binary files
                        fileData = rawFileData;
                    }
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

                    // Bounds checking
                    if (sourceOffset >= fileData.length) {
                        console.warn(`Offset ${sourceOffset} exceeds file size ${fileData.length} for component ${memConfig.name}`);
                        continue;
                    }

                    const endOffset = Math.min(sourceOffset + size, fileData.length);
                    const data = fileData.slice(sourceOffset, endOffset);

                    if (data.length === 0) {
                        console.warn(`No data extracted for component ${memConfig.name}`);
                        continue;
                    }

                    additionalComponents.push({
                        data: data,
                        loadAddress: targetAddress,
                        name: `${inputConfig.id}_${memConfig.name}`
                    });
                }
            }
        }

        return additionalComponents;
    }

    // Helper method to detect PNG files by magic number
    isPNGFile(data) {
        if (data.length < 8) return false;
        return data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4E && data[3] === 0x47 &&
            data[4] === 0x0D && data[5] === 0x0A && data[6] === 0x1A && data[7] === 0x0A;
    }

    // Add this to your prg-builder.js file, updating the existing processVisualizerOptions method

    async processVisualizerOptions(visualizerType, layoutKey = 'bank4000') {
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

        // Reset font case type for this export
        this.currentFontCaseType = undefined;

        // Initialize sanitizer if not already done
        if (!this.sanitizer) {
            this.sanitizer = new PETSCIISanitizer();
        }

        const optionComponents = [];

        for (const optionConfig of vizConfig.options) {
            const element = document.getElementById(optionConfig.id);
            if (!element) continue;

            // Special handling for font when charset data should be injected
            if (optionConfig.id === 'font' && layout.charsetAddress && vizConfig.fontType) {
                const fontIndex = parseInt(element.value);
                const validIndex = !isNaN(fontIndex) ? fontIndex : (optionConfig.default ?? 0);

                // Get font data from the global FONT_DATA
                if (typeof FONT_DATA !== 'undefined') {
                    try {
                        // Prepare fallback config using the binary
                        const fallbackConfig = {
                            binarySource: layout.binary,
                            binaryOffset: parseInt(layout.charsetAddress) - parseInt(layout.baseAddress)
                        };

                        const fontData = await FONT_DATA.getFontData(vizConfig.fontType, validIndex, fallbackConfig);
                        if (fontData) {
                            const targetAddress = parseInt(layout.charsetAddress);
                            optionComponents.push({
                                data: fontData,
                                loadAddress: targetAddress,
                                name: `font_charset`
                            });

                            // Store the font case type for text conversion
                            this.currentFontCaseType = await FONT_DATA.getFontCaseType(vizConfig.fontType, validIndex);
                        }
                    } catch (fontError) {
                        console.warn('Failed to load font, using default:', fontError);
                        // Continue without custom font - binary will have default
                    }
                }
                continue; // Skip normal processing for this option
            }

            // Special handling for barStyle when character data should be injected
            if (optionConfig.id === 'barStyle' && vizConfig.barStyleType && layout.barCharsAddress) {
                const styleIndex = parseInt(element.value);
                const validIndex = !isNaN(styleIndex) ? styleIndex : (optionConfig.default ?? 0);

                // Get bar style character data from the global BAR_STYLES_DATA
                if (typeof BAR_STYLES_DATA !== 'undefined') {
                    const charData = BAR_STYLES_DATA.getBarStyleData(vizConfig.barStyleType, validIndex);
                    if (charData) {
                        const targetAddress = parseInt(layout.barCharsAddress);
                        optionComponents.push({
                            data: charData,
                            loadAddress: targetAddress,
                            name: `barStyle_chars`
                        });
                    }
                }
                continue; // Skip normal processing for this option
            }

            // Special handling for colorPalette when color table data should be injected
            if (optionConfig.id === 'colorPalette' && vizConfig.colorPaletteType && layout.colorTableAddress) {
                const paletteIndex = parseInt(element.value);
                const validIndex = !isNaN(paletteIndex) ? paletteIndex : (optionConfig.default ?? 0);

                // Check if there's a colorEffect selected (default to 0 = Height-based)
                const colorEffectElement = document.getElementById('colorEffect');
                const colorEffectIndex = colorEffectElement ? parseInt(colorEffectElement.value) : 0;
                const validEffectIndex = !isNaN(colorEffectIndex) ? colorEffectIndex : 0;

                // Get color palette data from the global COLOR_PALETTES_DATA
                if (typeof COLOR_PALETTES_DATA !== 'undefined') {
                    // Only inject height-based color table for effect mode 0
                    if (validEffectIndex === 0) {
                        const colorData = COLOR_PALETTES_DATA.getColorPaletteData(vizConfig.colorPaletteType, validIndex);
                        if (colorData) {
                            const targetAddress = parseInt(layout.colorTableAddress);
                            optionComponents.push({
                                data: colorData,
                                loadAddress: targetAddress,
                                name: `colorPalette_table`
                            });
                        }
                    }

                    // Also inject border and background colors if the layout has addresses for them
                    const paletteDetails = COLOR_PALETTES_DATA.getColorPaletteDetails(validIndex);
                    if (paletteDetails) {
                        // Inject border color if layout specifies address
                        if (layout.borderColor) {
                            const borderData = new Uint8Array(1);
                            borderData[0] = paletteDetails.borderColor & 0xFF;
                            optionComponents.push({
                                data: borderData,
                                loadAddress: parseInt(layout.borderColor),
                                name: `colorPalette_border`
                            });
                        }
                        // Inject background color if layout specifies address
                        if (layout.backgroundColor) {
                            const bgData = new Uint8Array(1);
                            bgData[0] = paletteDetails.backgroundColor & 0xFF;
                            optionComponents.push({
                                data: bgData,
                                loadAddress: parseInt(layout.backgroundColor),
                                name: `colorPalette_background`
                            });
                        }
                    }
                }
                continue; // Skip normal processing for this option
            }

            // Special handling for colorEffect when colorEffectMode and lineGradientColors should be injected
            if (optionConfig.id === 'colorEffect' && vizConfig.colorEffectType && layout.colorEffectModeAddress) {
                const effectIndex = parseInt(element.value);
                const validEffectIndex = !isNaN(effectIndex) ? effectIndex : (optionConfig.default ?? 0);

                // Get the selected palette index
                const colorPaletteElement = document.getElementById('colorPalette');
                const paletteIndex = colorPaletteElement ? parseInt(colorPaletteElement.value) : 0;
                const validPaletteIndex = !isNaN(paletteIndex) ? paletteIndex : 0;

                if (typeof COLOR_PALETTES_DATA !== 'undefined') {
                    // Inject colorEffectMode byte
                    const effectModeData = new Uint8Array(1);
                    effectModeData[0] = validEffectIndex & 0xFF;
                    optionComponents.push({
                        data: effectModeData,
                        loadAddress: parseInt(layout.colorEffectModeAddress),
                        name: `colorEffect_mode`
                    });

                    // For non-height modes (1 = Line Gradient, 2 = Solid), inject line gradient colors
                    if (validEffectIndex !== 0 && layout.lineGradientColorsAddress) {
                        let lineColors;
                        const effectType = vizConfig.colorEffectType;

                        if (validEffectIndex === 1) {
                            // Line Gradient mode
                            if (effectType === 'water') {
                                lineColors = COLOR_PALETTES_DATA.generateLineGradientWater(validPaletteIndex, 14, 3);
                            } else if (effectType === 'waterlogo') {
                                lineColors = COLOR_PALETTES_DATA.generateLineGradientWater(validPaletteIndex, 8, 3);
                            } else if (effectType === 'mirror') {
                                lineColors = COLOR_PALETTES_DATA.generateLineGradientMirror(validPaletteIndex, 9);
                            } else if (effectType === 'mirrorlogo') {
                                lineColors = COLOR_PALETTES_DATA.generateLineGradientMirror(validPaletteIndex, 5);
                            }
                        } else if (validEffectIndex === 2) {
                            // Solid mode - use barColor instead of palette
                            let lineCount;
                            if (effectType === 'water') lineCount = 17;
                            else if (effectType === 'waterlogo') lineCount = 11;
                            else if (effectType === 'mirror') lineCount = 18;
                            else if (effectType === 'mirrorlogo') lineCount = 10;
                            else lineCount = 17;

                            // Get barColor from the UI element
                            const barColorElement = document.getElementById('barColor');
                            const barColor = barColorElement ? (parseInt(barColorElement.value) & 0x0F) : 1;

                            // Create solid color array with the selected bar color
                            lineColors = new Uint8Array(lineCount);
                            lineColors.fill(barColor);
                        }

                        if (lineColors) {
                            optionComponents.push({
                                data: lineColors,
                                loadAddress: parseInt(layout.lineGradientColorsAddress),
                                name: `colorEffect_lineColors`
                            });
                        }
                    }
                }
                continue; // Skip normal processing for this option
            }

            // Handle color picker options (songNameColor, artistNameColor, bgColor)
            if (optionConfig.type === 'colorPicker') {
                const colorValue = parseInt(element.value);
                const validColor = !isNaN(colorValue) ? (colorValue & 0x0F) : (optionConfig.default ?? 0);

                if (optionConfig.id === 'songNameColor' && layout.songNameColorAddress) {
                    const colorData = new Uint8Array(1);
                    colorData[0] = validColor;
                    optionComponents.push({
                        data: colorData,
                        loadAddress: parseInt(layout.songNameColorAddress),
                        name: 'songNameColor'
                    });
                } else if (optionConfig.id === 'artistNameColor' && layout.artistNameColorAddress) {
                    const colorData = new Uint8Array(1);
                    colorData[0] = validColor;
                    optionComponents.push({
                        data: colorData,
                        loadAddress: parseInt(layout.artistNameColorAddress),
                        name: 'artistNameColor'
                    });
                } else if (optionConfig.id === 'bgColor') {
                    // Background color affects both border and background
                    if (layout.borderColor) {
                        const borderData = new Uint8Array(1);
                        borderData[0] = validColor;
                        optionComponents.push({
                            data: borderData,
                            loadAddress: parseInt(layout.borderColor),
                            name: 'bgColor_border'
                        });
                    }
                    if (layout.backgroundColor) {
                        const bgData = new Uint8Array(1);
                        bgData[0] = validColor;
                        optionComponents.push({
                            data: bgData,
                            loadAddress: parseInt(layout.backgroundColor),
                            name: 'bgColor_background'
                        });
                    }
                }
                continue; // Skip normal processing for this option
            }

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

                    // Sanitize the date string
                    const sanitized = this.sanitizer.sanitize(formattedDate, {
                        maxLength: 32,
                        padToLength: 32,
                        center: true,
                        reportUnknown: false
                    });

                    const data = this.sanitizer.toPETSCIIBytes(sanitized.text, true);

                    optionComponents.push({
                        data: data,
                        loadAddress: targetAddress,
                        name: `option_${optionConfig.id}`
                    });

                } else if (optionConfig.type === 'number' || optionConfig.type === 'select') {
                    // Use proper null check to handle 0 values correctly
                    // (0 is falsy in JS but is a valid color value)
                    const parsedValue = parseInt(element.value);
                    const value = !isNaN(parsedValue) ? parsedValue : (optionConfig.default ?? 0);
                    const data = new Uint8Array(1);
                    data[0] = value & 0xFF;

                    optionComponents.push({
                        data: data,
                        loadAddress: targetAddress,
                        name: `option_${optionConfig.id}`
                    });

                } else if (optionConfig.type === 'textarea') {
                    const textValue = element.value || optionConfig.default || '';

                    // Sanitize the textarea content
                    const sanitized = this.sanitizer.sanitize(textValue, {
                        maxLength: optionConfig.maxLength || 255,
                        preserveNewlines: false,  // Convert newlines to spaces for scrolltext
                        reportUnknown: true
                    });

                    // Show warnings if any problematic characters were found
                    if (sanitized.hasWarnings) {
                        this.sanitizer.showWarningDialog(sanitized.warnings);
                    }

                    // Convert to PETSCII bytes
                    const petsciiData = this.sanitizer.toPETSCIIBytes(sanitized.text, true);

                    // Add null terminator
                    const data = new Uint8Array(petsciiData.length + 1);
                    data.set(petsciiData);
                    data[data.length - 1] = 0x00; // Null terminator

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

    // Update the existing stringToPETSCII function to use the sanitizer
    stringToPETSCII(str, length) {
        // Initialize sanitizer if not already done
        if (!this.sanitizer) {
            this.sanitizer = new PETSCIISanitizer();
        }

        // Sanitize the string
        const sanitized = this.sanitizer.sanitize(str || '', {
            maxLength: length,
            padToLength: length,
            center: false,
            reportUnknown: false  // Don't report for metadata fields
        });

        // Convert to PETSCII bytes
        return this.sanitizer.toPETSCIIBytes(sanitized.text, true);
    }

    // Update the centerString method to use sanitizer
    centerString(str, length) {
        if (!this.sanitizer) {
            this.sanitizer = new PETSCIISanitizer();
        }

        const sanitized = this.sanitizer.sanitize(str || '', {
            maxLength: length,
            padToLength: length,
            center: true,
            reportUnknown: false
        });

        return sanitized.text;
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

            // Get modified addresses count for layout validation
            const modifiedCount = this.analyzer.analysisResults?.modifiedAddresses?.length || 0;

            // Get the layout key from options (passed from UI) or select first valid one
            let layoutKey = options.layoutKey;
            if (!layoutKey) {
                const validLayouts = this.selectValidLayouts(vizConfig, sidInfo.loadAddress, sidInfo.dataSize, modifiedAddresses);
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

            // Process visualizer options BEFORE calculating save/restore addresses
            // This ensures we know where all visualizer data is placed
            const optionComponents = await this.processVisualizerOptions(visualizerName, layoutKey);
            for (const component of optionComponents) {
                this.builder.addComponent(component.data, component.loadAddress, component.name);
            }

            // NEW ARCHITECTURE: Place save/restore routines in safe memory
            // The data block contains JMPs that point directly to these routines
            let saveRoutineAddr = 0;
            let restoreRoutineAddr = 0;

            if (this.analyzer.analysisResults && this.analyzer.analysisResults.modifiedAddresses) {
                const modifiedAddrs = Array.from(this.analyzer.analysisResults.modifiedAddresses);

                // Calculate the routine size FIRST to know how much space we need
                const routineSizes = this.calculateSaveRestoreSize(modifiedAddrs);
                const totalRoutineSize = routineSizes.totalSize;

                // Find a safe address that can fit the routines without overflowing
                let safeAddress = this.findSafeMemoryForRoutines(totalRoutineSize, actualSidAddress, sidInfo.data.length);

                // Generate routines to get their actual sizes
                const restoreRoutine = this.generateOptimizedRestoreRoutine(modifiedAddrs);

                // Place restore routine first, at safe address
                restoreRoutineAddr = safeAddress;

                // Place save routine after restore routine
                saveRoutineAddr = restoreRoutineAddr + restoreRoutine.length;

                // Regenerate save routine with correct restore address
                const finalSaveRoutine = this.generateOptimizedSaveRoutine(modifiedAddrs, restoreRoutineAddr);

                // Add the actual routines - data block JMPs point directly to these
                this.builder.addComponent(restoreRoutine, restoreRoutineAddr, 'Restore Routine');
                this.builder.addComponent(finalSaveRoutine, saveRoutineAddr, 'Save Routine');

            } else {
                console.warn('No analysis results for save/restore routines');
                // Create dummy RTS routines at a safe location
                const dummyRoutine = new Uint8Array([0x60]); // RTS

                // Place after data block
                const safeAddress = this.alignToPage(dataLoadAddress + 0x100);
                restoreRoutineAddr = safeAddress;
                saveRoutineAddr = safeAddress + 1;

                this.builder.addComponent(dummyRoutine, restoreRoutineAddr, 'Dummy Restore');
                this.builder.addComponent(new Uint8Array([0x60]), saveRoutineAddr, 'Dummy Save');
            }

            const numCallsPerFrame = this.analyzer.analysisResults?.numCallsPerFrame || 1;
            const sidChipCount = this.analyzer.analysisResults?.sidChipCount || 1;

            // The data block JMPs point directly to the save/restore routines
            const dataBlock = this.generateDataBlock(
                {
                    initAddress: actualInitAddress,
                    playAddress: actualPlayAddress,
                    loadAddress: actualSidAddress,
                    dataSize: sidInfo.dataSize
                },
                this.analyzer.analysisResults,
                header,
                saveRoutineAddr,      // Point directly to save routine
                restoreRoutineAddr,   // Point directly to restore routine
                numCallsPerFrame,
                configMaxCallsPerFrame,
                selectedSong,
                modifiedCount,
                sidChipCount
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