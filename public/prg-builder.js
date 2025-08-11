// prg-builder.js - PRG file builder for SIDwinder Web
// This module creates C64 PRG files combining SID music, data, and visualizer

class PRGBuilder {
    constructor() {
        this.components = [];
        this.lowestAddress = 0xFFFF;
        this.highestAddress = 0x0000;
    }

    /**
     * Add a component to the PRG
     * @param {Uint8Array} data - The binary data
     * @param {number} loadAddress - C64 memory address where this should load
     * @param {string} name - Component name for debugging
     */
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

        // Track memory range
        this.lowestAddress = Math.min(this.lowestAddress, loadAddress);
        this.highestAddress = Math.max(this.highestAddress, loadAddress + data.length - 1);

        console.log(`Added component: ${name} at $${loadAddress.toString(16).toUpperCase().padStart(4, '0')}, size: ${data.length} bytes`);
    }

    /**
     * Build the final PRG file
     * @returns {Uint8Array} The complete PRG file
     */
    build() {
        if (this.components.length === 0) {
            throw new Error('No components added to PRG');
        }

        // Sort components by load address
        this.components.sort((a, b) => a.loadAddress - b.loadAddress);

        // Calculate total size needed
        const totalSize = (this.highestAddress - this.lowestAddress + 1) + 2; // +2 for load address
        const prgData = new Uint8Array(totalSize);

        // Set load address (little-endian)
        prgData[0] = this.lowestAddress & 0xFF;
        prgData[1] = (this.lowestAddress >> 8) & 0xFF;

        console.log(`PRG load address: $${this.lowestAddress.toString(16).toUpperCase().padStart(4, '0')}`);
        console.log(`PRG memory range: $${this.lowestAddress.toString(16).toUpperCase().padStart(4, '0')} - $${this.highestAddress.toString(16).toUpperCase().padStart(4, '0')}`);

        // Fill with zeros initially (this represents uninitialized memory)
        for (let i = 2; i < totalSize; i++) {
            prgData[i] = 0x00;
        }

        // Copy each component to its position
        for (const component of this.components) {
            const offset = component.loadAddress - this.lowestAddress + 2;

            console.log(`Placing ${component.name} at PRG offset ${offset} (C64: $${component.loadAddress.toString(16).toUpperCase().padStart(4, '0')})`);

            // Copy the data
            for (let i = 0; i < component.data.length; i++) {
                prgData[offset + i] = component.data[i];
            }
        }

        console.log(`Total PRG size: ${totalSize} bytes`);
        return prgData;
    }

    /**
     * Check if all components are contiguous in memory
     */
    isContiguous() {
        if (this.components.length <= 1) return true;

        const sorted = [...this.components].sort((a, b) => a.loadAddress - b.loadAddress);

        for (let i = 1; i < sorted.length; i++) {
            const prevEnd = sorted[i - 1].loadAddress + sorted[i - 1].size;
            if (prevEnd !== sorted[i].loadAddress) {
                return false;
            }
        }
        return true;
    }

    /**
     * Clear all components
     */
    clear() {
        this.components = [];
        this.lowestAddress = 0xFFFF;
        this.highestAddress = 0x0000;
    }

    /**
     * Get information about the PRG structure
     */
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
            totalSize: this.highestAddress - this.lowestAddress + 1,
            hasGaps: !this.isContiguous()
        };
    }
}

// Integration with SIDwinder Web
class SIDwinderPRGExporter {
    constructor(analyzer) {
        this.analyzer = analyzer;
        this.builder = new PRGBuilder();
        this.saveRoutineAddress = 0;
        this.restoreRoutineAddress = 0;
    }

    /**
     * Align address to next page boundary (256-byte aligned)
     * @param {number} address - Address to align
     * @returns {number} Aligned address
     */
    alignToPage(address) {
        return (address + 0xFF) & 0xFF00;
    }

    /**
     * Generate 6502 code to save modified memory addresses
     * @param {Array} modifiedAddresses - Array of addresses that were modified
     * @param {number} targetAddress - Where to store the values
     * @returns {Uint8Array} The 6502 machine code
     */
    generateSaveRoutine(modifiedAddresses, targetAddress) {
        const code = [];
        let storeAddr = targetAddress;

        // Filter out:
        // - Stack memory ($0100-$01FF)
        // - SID registers ($D400-$D7FF)
        const filtered = modifiedAddresses
            .filter(addr => {
                // Skip stack
                if (addr >= 0x0100 && addr <= 0x01FF) return false;
                // Skip SID
                if (addr >= 0xD400 && addr <= 0xD7FF) return false;
                return true;
            })
            .sort((a, b) => a - b);

        console.log(`Save routine: ${filtered.length} addresses to save (filtered from ${modifiedAddresses.length})`);

        for (const addr of filtered) {
            if (addr < 256) {
                // Zero page - use LDA zp
                code.push(0xA5);  // LDA zp
                code.push(addr);
            } else {
                // Absolute - use LDA abs
                code.push(0xAD);  // LDA abs
                code.push(addr & 0xFF);
                code.push((addr >> 8) & 0xFF);
            }

            // STA to storage area
            code.push(0x8D);  // STA abs
            code.push(storeAddr & 0xFF);
            code.push((storeAddr >> 8) & 0xFF);

            storeAddr++;
        }

        // RTS
        code.push(0x60);

        return new Uint8Array(code);
    }

    /**
     * Generate 6502 code to restore modified memory addresses
     * @param {Array} modifiedAddresses - Array of addresses that were modified
     * @param {number} sourceAddress - Where the values were stored
     * @returns {Uint8Array} The 6502 machine code
     */
    generateRestoreRoutine(modifiedAddresses, sourceAddress) {
        const code = [];
        let loadAddr = sourceAddress;

        // Filter out:
        // - Stack memory ($0100-$01FF)
        // - SID registers ($D400-$D7FF)
        const filtered = modifiedAddresses
            .filter(addr => {
                // Skip stack
                if (addr >= 0x0100 && addr <= 0x01FF) return false;
                // Skip SID
                if (addr >= 0xD400 && addr <= 0xD7FF) return false;
                return true;
            })
            .sort((a, b) => a - b);

        console.log(`Restore routine: ${filtered.length} addresses to restore`);

        for (const addr of filtered) {
            // LDA from storage area
            code.push(0xAD);  // LDA abs
            code.push(loadAddr & 0xFF);
            code.push((loadAddr >> 8) & 0xFF);

            if (addr < 256) {
                // Zero page - use STA zp
                code.push(0x85);  // STA zp
                code.push(addr);
            } else {
                // Absolute - use STA abs
                code.push(0x8D);  // STA abs
                code.push(addr & 0xFF);
                code.push((addr >> 8) & 0xFF);
            }

            loadAddr++;
        }

        // RTS
        code.push(0x60);

        return new Uint8Array(code);
    }

    /**
     * Generate the data block at $5000
     * @param {Object} sidInfo - SID information including addresses
     * @param {number} saveRoutineAddr - Address of save routine
     * @param {number} restoreRoutineAddr - Address of restore routine
     * @param {string} name - SID name
     * @param {string} author - SID author
     * @returns {Uint8Array} The data block
     */
    generateDataBlock(sidInfo, saveRoutineAddr, restoreRoutineAddr, name, author) {
        const data = new Uint8Array(0x50);  // 80 bytes total

        // JMP SIDInit (at $5000)
        data[0] = 0x4C;  // JMP opcode
        data[1] = sidInfo.initAddress & 0xFF;
        data[2] = (sidInfo.initAddress >> 8) & 0xFF;

        // JMP SIDPlay (at $5003)
        data[3] = 0x4C;  // JMP opcode
        data[4] = sidInfo.playAddress & 0xFF;
        data[5] = (sidInfo.playAddress >> 8) & 0xFF;

        // JMP SaveModifiedMemory (at $5006)
        data[6] = 0x4C;  // JMP opcode
        data[7] = saveRoutineAddr & 0xFF;
        data[8] = (saveRoutineAddr >> 8) & 0xFF;

        // JMP RestoreModifiedMemory (at $5009)
        data[9] = 0x4C;  // JMP opcode
        data[10] = restoreRoutineAddr & 0xFF;
        data[11] = (restoreRoutineAddr >> 8) & 0xFF;

        // Unused bytes $500C-$500F (could be used for flags/version)
        // Fill with zeros for now

        // SID Name at $5010-$502F (32 bytes, centered)
        const nameBytes = this.stringToPETSCIICentered(name, 32);
        for (let i = 0; i < 32; i++) {
            data[0x10 + i] = nameBytes[i];
        }

        // Author Name at $5030-$504F (32 bytes, centered)
        const authorBytes = this.stringToPETSCIICentered(author, 32);
        for (let i = 0; i < 32; i++) {
            data[0x30 + i] = authorBytes[i];
        }

        return data;
    }

    /**
     * Convert string to PETSCII bytes with padding/truncation
     * Uses correct PETSCII encoding:
     * - Uppercase: $41-$5A (A-Z)
     * - Lowercase: $01-$1A (a-z)
     * - Numbers: $30-$39 (0-9)
     * - Space: $20
     * @param {string} str - Input string
     * @param {number} length - Target length
     * @returns {Uint8Array} Byte array
     */
    stringToPETSCII(str, length) {
        const bytes = new Uint8Array(length);
        bytes.fill(0);  // Fill with zeros

        if (str) {
            for (let i = 0; i < Math.min(str.length, length); i++) {
                const char = str.charAt(i);
                const code = str.charCodeAt(i);

                let petscii = 0;

                if (code >= 65 && code <= 90) {
                    // Uppercase A-Z -> $41-$5A
                    petscii = 0x41 + (code - 65);
                } else if (code >= 97 && code <= 122) {
                    // Lowercase a-z -> $01-$1A
                    petscii = 0x01 + (code - 97);
                } else if (code >= 48 && code <= 57) {
                    // Numbers 0-9 -> $30-$39
                    petscii = 0x30 + (code - 48);
                } else if (code === 32) {
                    // Space -> $20
                    petscii = 0x20;
                } else if (code === 45) {
                    // Hyphen -> $2D
                    petscii = 0x2D;
                } else if (code === 46) {
                    // Period -> $2E
                    petscii = 0x2E;
                } else if (code === 33) {
                    // Exclamation -> $21
                    petscii = 0x21;
                } else if (code === 39) {
                    // Apostrophe -> $27
                    petscii = 0x27;
                } else {
                    // Default to space for unknown characters
                    petscii = 0x20;
                }

                // Sanity check: ensure value is in range $00-$7F
                bytes[i] = petscii & 0x7F;
            }
        }

        return bytes;
    }

    /**
     * Convert string to PETSCII bytes, centered within the field
     * @param {string} str - Input string
     * @param {number} length - Target length (32 bytes)
     * @returns {Uint8Array} Byte array with centered text
     */
    stringToPETSCIICentered(str, length) {
        const bytes = new Uint8Array(length);
        bytes.fill(0x20);  // Fill with spaces ($20)

        if (str && str.trim().length > 0) {
            // Trim the string
            str = str.trim();

            // Truncate if too long
            if (str.length > length) {
                str = str.substring(0, length);
            }

            // Calculate padding for centering
            const padding = Math.floor((length - str.length) / 2);

            // Convert each character to PETSCII
            for (let i = 0; i < str.length; i++) {
                const code = str.charCodeAt(i);
                let petscii = 0x20; // Default to space

                if (code >= 65 && code <= 90) {
                    // Uppercase A-Z -> $41-$5A
                    petscii = 0x41 + (code - 65);
                } else if (code >= 97 && code <= 122) {
                    // Lowercase a-z -> $01-$1A
                    petscii = 0x01 + (code - 97);
                } else if (code >= 48 && code <= 57) {
                    // Numbers 0-9 -> $30-$39
                    petscii = 0x30 + (code - 48);
                } else if (code === 32) {
                    // Space -> $20
                    petscii = 0x20;
                } else if (code === 45) {
                    // Hyphen -> $2D
                    petscii = 0x2D;
                } else if (code === 46) {
                    // Period -> $2E
                    petscii = 0x2E;
                } else if (code === 33) {
                    // Exclamation -> $21
                    petscii = 0x21;
                } else if (code === 39) {
                    // Apostrophe -> $27
                    petscii = 0x27;
                } else if (code === 38) {
                    // Ampersand -> $26
                    petscii = 0x26;
                } else if (code === 40) {
                    // Left parenthesis -> $28
                    petscii = 0x28;
                } else if (code === 41) {
                    // Right parenthesis -> $29
                    petscii = 0x29;
                } else if (code === 44) {
                    // Comma -> $2C
                    petscii = 0x2C;
                } else if (code === 58) {
                    // Colon -> $3A
                    petscii = 0x3A;
                } else if (code === 59) {
                    // Semicolon -> $3B
                    petscii = 0x3B;
                } else if (code === 47) {
                    // Slash -> $2F
                    petscii = 0x2F;
                } else {
                    // Default to space for unknown characters
                    petscii = 0x20;
                }

                // Sanity check: ensure value is in range $00-$7F
                bytes[padding + i] = petscii & 0x7F;
            }
        }

        return bytes;
    }

    /**
     * Load a binary file from URL
     * @param {string} url - URL to the binary file
     * @returns {Promise<Uint8Array>} The file data
     */
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

    /**
     * Extract music data from the current SID file
     * @returns {Object} The SID music data and load address
     */
    extractSIDMusicData() {
        // Get the modified SID from the analyzer
        const modifiedSID = this.analyzer.createModifiedSID();
        if (!modifiedSID) {
            throw new Error('Failed to get SID data');
        }

        // Parse the SID to extract just the music data
        // SID header is 0x7C bytes for v2+ or 0x76 for v1
        const view = new DataView(modifiedSID.buffer);

        // Check version (at offset 0x04, big-endian)
        const version = view.getUint16(0x04, false);
        const headerSize = (version === 1) ? 0x76 : 0x7C;

        // Get load address (at offset 0x08, big-endian)
        let loadAddress = view.getUint16(0x08, false);
        let dataStart = headerSize;

        // If load address is 0, it's in the data
        if (loadAddress === 0) {
            // Load address is embedded in the data (little-endian)
            loadAddress = view.getUint16(headerSize, true);
            dataStart = headerSize + 2;
        }

        // Extract just the music data (without the embedded load address)
        const musicData = modifiedSID.slice(dataStart);

        // IMPORTANT: Check if the music data starts with the load address bytes
        // This happens when the SID data includes its own load address
        if (musicData.length >= 2) {
            const firstTwo = (musicData[0] | (musicData[1] << 8));
            if (firstTwo === loadAddress) {
                console.log('Detected embedded load address in music data, skipping first 2 bytes');
                // Skip the embedded load address
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

    /**
     * Create a complete PRG with SID, data, and visualizer
     * @param {Object} options - Build options
     * @returns {Promise<Uint8Array>} The complete PRG file
     */
    async createPRG(options = {}) {
        const {
            sidLoadAddress = null,  // null = use original from SID
            dataLoadAddress = 0x5000,  // Fixed at $5000
            visualizerFile = 'prg/RaistlinBars.bin',
            visualizerLoadAddress = 0x4100,
            includeData = true
        } = options;

        try {
            this.builder.clear();

            // 1. Extract SID music data
            console.log('Extracting SID music data...');
            const sidInfo = this.extractSIDMusicData();
            const actualSidAddress = sidLoadAddress || sidInfo.loadAddress;

            // Get SID metadata from analyzer
            const header = await this.analyzer.loadSID(this.analyzer.createModifiedSID());

            // Add SID addresses to info
            sidInfo.initAddress = header.initAddress;
            sidInfo.playAddress = header.playAddress;

            this.builder.addComponent(sidInfo.data, actualSidAddress, 'SID Music');

            // 2. Load visualizer first to know where to place save/restore routines
            let nextAvailableAddress = visualizerLoadAddress;
            if (visualizerFile && visualizerFile !== 'none') {
                console.log(`Loading ${visualizerFile}...`);
                const visualizerBytes = await this.loadBinaryFile(visualizerFile);
                this.builder.addComponent(visualizerBytes, visualizerLoadAddress, 'Visualizer');
                nextAvailableAddress = visualizerLoadAddress + visualizerBytes.length;
            }

            // 3. Align to next page boundary for save routine
            let saveRoutineAddr = this.alignToPage(nextAvailableAddress);
            let restoreRoutineAddr = saveRoutineAddr;
            let storageAddress = saveRoutineAddr; // Will be updated after routines are placed

            if (this.analyzer.analysisResults && this.analyzer.analysisResults.modifiedAddresses) {
                const modifiedAddrs = Array.from(this.analyzer.analysisResults.modifiedAddresses);

                // Generate save routine at page boundary
                const saveRoutine = this.generateSaveRoutine(modifiedAddrs, 0); // Temp address
                this.builder.addComponent(saveRoutine, saveRoutineAddr, 'Save Routine');

                // Calculate next page boundary for restore routine
                const saveEndAddr = saveRoutineAddr + saveRoutine.length;
                restoreRoutineAddr = this.alignToPage(saveEndAddr);

                // Generate restore routine at its page boundary
                const restoreRoutine = this.generateRestoreRoutine(modifiedAddrs, 0); // Temp address
                this.builder.addComponent(restoreRoutine, restoreRoutineAddr, 'Restore Routine');

                // Now calculate storage address (next page after restore routine)
                const restoreEndAddr = restoreRoutineAddr + restoreRoutine.length;
                storageAddress = this.alignToPage(restoreEndAddr);

                // Regenerate routines with correct storage address
                this.builder.clear();
                this.builder.addComponent(sidInfo.data, actualSidAddress, 'SID Music');
                if (visualizerFile && visualizerFile !== 'none') {
                    const visualizerBytes = await this.loadBinaryFile(visualizerFile);
                    this.builder.addComponent(visualizerBytes, visualizerLoadAddress, 'Visualizer');
                }

                // Final save routine with correct storage address
                const finalSaveRoutine = this.generateSaveRoutine(modifiedAddrs, storageAddress);
                this.builder.addComponent(finalSaveRoutine, saveRoutineAddr, 'Save Routine');

                // Final restore routine with correct storage address
                const finalRestoreRoutine = this.generateRestoreRoutine(modifiedAddrs, storageAddress);
                this.builder.addComponent(finalRestoreRoutine, restoreRoutineAddr, 'Restore Routine');

                console.log(`Save routine at: $${saveRoutineAddr.toString(16).toUpperCase().padStart(4, '0')}`);
                console.log(`Restore routine at: $${restoreRoutineAddr.toString(16).toUpperCase().padStart(4, '0')}`);
                console.log(`Storage area at: $${storageAddress.toString(16).toUpperCase().padStart(4, '0')}`);
            } else {
                console.warn('No analysis results available for save/restore routines');
                // Create dummy routines that just RTS
                const dummyRoutine = new Uint8Array([0x60]); // RTS
                this.builder.addComponent(dummyRoutine, saveRoutineAddr, 'Dummy Save');
                restoreRoutineAddr = this.alignToPage(saveRoutineAddr + 1);
                this.builder.addComponent(dummyRoutine, restoreRoutineAddr, 'Dummy Restore');
            }

            // 4. Generate data block at $5000
            if (includeData) {
                console.log('Generating data block...');
                const dataBlock = this.generateDataBlock(
                    {
                        initAddress: sidInfo.initAddress || actualSidAddress,
                        playAddress: sidInfo.playAddress || (actualSidAddress + 3)
                    },
                    saveRoutineAddr,
                    restoreRoutineAddr,
                    header.name || 'Unknown',
                    header.author || 'Unknown'
                );
                this.builder.addComponent(dataBlock, dataLoadAddress, 'Data Block');
            }

            // Build the PRG
            console.log('Building PRG file...');
            const prgData = this.builder.build();

            // Log the structure
            const info = this.builder.getInfo();
            console.log('PRG Structure:', info);

            // Store addresses for reference
            this.saveRoutineAddress = saveRoutineAddr;
            this.restoreRoutineAddress = restoreRoutineAddr;

            return prgData;

        } catch (error) {
            console.error('Error creating PRG:', error);
            throw error;
        }
    }

    /**
     * Create and download a PRG file
     * @param {string} filename - Output filename
     * @param {Object} options - Build options
     */
    async downloadPRG(filename = 'output.prg', options = {}) {
        try {
            const prgData = await this.createPRG(options);

            // Create blob and download
            const blob = new Blob([prgData], { type: 'application/octet-stream' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = filename;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);

            console.log(`Downloaded ${filename} (${prgData.length} bytes)`);
            return true;

        } catch (error) {
            console.error('Failed to download PRG:', error);
            return false;
        }
    }
}

// Export for use in other modules
window.PRGBuilder = PRGBuilder;
window.SIDwinderPRGExporter = SIDwinderPRGExporter;