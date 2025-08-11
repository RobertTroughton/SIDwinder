// prg-builder.js - PRG file builder for SIDwinder Web
// This module creates C64 PRG files combining SID music, data, and visualizer

console.log('PRG Builder script loading...');

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

        console.log(`Added component: ${name} at $${loadAddress.toString(16).toUpperCase().padStart(4, '0')}, size: ${data.length} bytes`);
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

        console.log(`Total PRG size: ${totalSize} bytes`);
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

        console.log(`Save routine: ${filtered.length} addresses to save`);

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

        console.log(`Restore routine: ${filtered.length} addresses to restore`);

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

    generateDataBlock(sidInfo, saveRoutineAddr, restoreRoutineAddr, name, author) {
        const data = new Uint8Array(0x50);

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

        console.log('Data block created at $4000');
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
                console.log('Skipping embedded load address in music data');
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

    generateBASICStub(sysAddress) {
        const addrStr = sysAddress.toString();
        const basic = [];

        const lineLength = 2 + 2 + 1 + addrStr.length + 1;
        const nextLine = 0x0801 + lineLength;

        basic.push(nextLine & 0xFF);
        basic.push((nextLine >> 8) & 0xFF);
        basic.push(0x0A);
        basic.push(0x00);
        basic.push(0x9E);

        for (let i = 0; i < addrStr.length; i++) {
            basic.push(addrStr.charCodeAt(i));
        }

        basic.push(0x00);
        basic.push(0x00);
        basic.push(0x00);

        console.log(`BASIC stub: SYS ${sysAddress}`);
        return new Uint8Array(basic);
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
            addBASICStub = true
        } = options;

        try {
            this.builder.clear();

            console.log('Extracting SID music data...');
            const sidInfo = this.extractSIDMusicData();

            const actualSidAddress = sidLoadAddress || sidInfo.loadAddress;
            const actualInitAddress = sidInitAddress || sidInfo.initAddress || actualSidAddress;
            const actualPlayAddress = sidPlayAddress || sidInfo.playAddress || (actualSidAddress + 3);

            console.log(`SID addresses - Load: $${actualSidAddress.toString(16)}, Init: $${actualInitAddress.toString(16)}, Play: $${actualPlayAddress.toString(16)}`);

            const header = await this.analyzer.loadSID(this.analyzer.createModifiedSID());

            if (addBASICStub) {
                console.log('Adding BASIC stub...');
                const basicStub = this.generateBASICStub(visualizerLoadAddress);
                this.builder.addComponent(basicStub, 0x0801, 'BASIC Stub');
            }

            this.builder.addComponent(sidInfo.data, actualSidAddress, 'SID Music');

            let nextAvailableAddress = visualizerLoadAddress;
            if (visualizerFile && visualizerFile !== 'none') {
                console.log(`Loading ${visualizerFile}...`);
                const visualizerBytes = await this.loadBinaryFile(visualizerFile);
                this.builder.addComponent(visualizerBytes, visualizerLoadAddress, 'Visualizer');
                nextAvailableAddress = visualizerLoadAddress + visualizerBytes.length;
            }

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

            console.log('Generating data block at $4000...');
            const dataBlock = this.generateDataBlock(
                {
                    initAddress: actualInitAddress,
                    playAddress: actualPlayAddress
                },
                saveRoutineAddr,
                restoreRoutineAddr,
                header.name || 'Unknown',
                header.author || 'Unknown'
            );
            this.builder.addComponent(dataBlock, dataLoadAddress, 'Data Block');

            console.log('Building PRG file...');
            const prgData = this.builder.build();

            const info = this.builder.getInfo();
            console.log('PRG Structure:', info);

            this.saveRoutineAddress = saveRoutineAddr;
            this.restoreRoutineAddress = restoreRoutineAddr;

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
console.log('PRG Builder loaded successfully!');