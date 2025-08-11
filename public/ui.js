// ui.js - UI Controller for SIDwinder Web with PRG Export

class UIController {
    constructor() {
        this.analyzer = new SIDAnalyzer();
        this.currentFileName = null;
        this.hasModifications = false;
        this.analysisResults = null;
        this.prgExporter = null;
        this.elements = this.cacheElements();
        this.initEventListeners();
        this.initExportSection();
    }

    cacheElements() {
        return {
            uploadSection: document.getElementById('uploadSection'),
            fileInput: document.getElementById('fileInput'),
            saveButton: document.getElementById('saveButton'),
            copyConsoleButton: document.getElementById('copyConsoleButton'),
            songTitleSection: document.getElementById('songTitleSection'),
            songTitle: document.getElementById('songTitle'),
            songAuthor: document.getElementById('songAuthor'),
            loading: document.getElementById('loading'),
            progressBar: document.getElementById('progressBar'),
            progressFill: document.getElementById('progressFill'),
            progressText: document.getElementById('progressText'),
            errorMessage: document.getElementById('errorMessage'),
            infoPanels: document.getElementById('infoPanels'),
            consoleSection: document.getElementById('consoleSection'),
            consoleContent: document.getElementById('consoleContent'),
            modalOverlay: document.getElementById('modalOverlay'),
            modalIcon: document.getElementById('modalIcon'),
            modalMessage: document.getElementById('modalMessage'),
            // Editable fields
            sidTitle: document.getElementById('sidTitle'),
            sidAuthor: document.getElementById('sidAuthor'),
            sidCopyright: document.getElementById('sidCopyright'),
            // Info fields
            sidFormat: document.getElementById('sidFormat'),
            sidVersion: document.getElementById('sidVersion'),
            sidSongs: document.getElementById('sidSongs'),
            loadAddress: document.getElementById('loadAddress'),
            initAddress: document.getElementById('initAddress'),
            playAddress: document.getElementById('playAddress'),
            memoryRange: document.getElementById('memoryRange'),
            fileSize: document.getElementById('fileSize'),
            zpUsage: document.getElementById('zpUsage'),
            clockType: document.getElementById('clockType'),
            sidModel: document.getElementById('sidModel'),
            // Export section elements
            exportSection: document.getElementById('exportSection'),
            sidAddress: document.getElementById('sidAddress'),
            visualizerType: document.getElementById('visualizerType'),
            includeData: document.getElementById('includeData'),
            exportSIDButton: document.getElementById('exportSIDButton'),
            exportPRGButton: document.getElementById('exportPRGButton'),
            exportStatus: document.getElementById('exportStatus')
        };
    }

    initEventListeners() {
        // File upload
        this.elements.uploadSection.addEventListener('click', () => {
            this.elements.fileInput.click();
        });

        this.elements.fileInput.addEventListener('change', (e) => {
            this.handleFileSelect(e);
        });

        // Save button (original)
        this.elements.saveButton.addEventListener('click', () => {
            this.saveSID();
        });

        // Copy button
        this.elements.copyConsoleButton.addEventListener('click', () => {
            this.copyConsoleContent();
        });

        // Drag and drop
        this.setupDragAndDrop();

        // Editable fields
        this.setupEditableFields();
    }

    initExportSection() {
        // Initialize PRG exporter when analyzer is ready
        if (this.analyzer) {
            this.prgExporter = new SIDwinderPRGExporter(this.analyzer);
            // Make analyzer globally accessible for debugging
            window.currentAnalyzer = this.analyzer;
        }

        // Add export button event listeners
        if (this.elements.exportSIDButton) {
            this.elements.exportSIDButton.addEventListener('click', () => {
                this.exportModifiedSID();
            });
        }

        if (this.elements.exportPRGButton) {
            this.elements.exportPRGButton.addEventListener('click', () => {
                this.exportPRGWithVisualizer();
            });
        }

        if (this.elements.exportBasicPRGButton) {
            this.elements.exportBasicPRGButton.addEventListener('click', () => {
                this.exportBasicPRG();
            });
        }
    }

    setupDragAndDrop() {
        const uploadSection = this.elements.uploadSection;

        uploadSection.addEventListener('dragover', (e) => {
            e.preventDefault();
            uploadSection.classList.add('dragover');
        });

        uploadSection.addEventListener('dragleave', () => {
            uploadSection.classList.remove('dragover');
        });

        uploadSection.addEventListener('drop', (e) => {
            e.preventDefault();
            uploadSection.classList.remove('dragover');
            const files = e.dataTransfer.files;
            if (files.length > 0) {
                this.processFile(files[0]);
            }
        });
    }

    setupEditableFields() {
        const editableFields = [this.elements.sidTitle, this.elements.sidAuthor, this.elements.sidCopyright];

        editableFields.forEach(field => {
            field.addEventListener('click', (e) => {
                if (!field.classList.contains('editing')) {
                    this.startEditing(field);
                }
            });

            field.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    this.stopEditing(field);
                } else if (e.key === 'Escape') {
                    e.preventDefault();
                    this.cancelEditing(field);
                }
            });

            field.addEventListener('blur', () => {
                if (field.classList.contains('editing')) {
                    this.stopEditing(field);
                }
            });

            field.addEventListener('input', () => {
                this.hasModifications = true;
                this.elements.saveButton.classList.add('visible');
            });
        });
    }

    startEditing(field) {
        field.classList.add('editing');

        const textSpan = field.querySelector('.text');
        textSpan.contentEditable = 'true';
        textSpan.focus();

        // Store original value
        field.dataset.originalValue = textSpan.textContent;

        // Select all text
        const range = document.createRange();
        range.selectNodeContents(textSpan);
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
    }

    stopEditing(field) {
        field.classList.remove('editing');

        const textSpan = field.querySelector('.text');
        textSpan.contentEditable = 'false';

        // Limit to 31 characters
        let text = textSpan.textContent.trim();
        if (text.length > 31) {
            text = text.substring(0, 31);
            textSpan.textContent = text;
        }

        // Update in WASM
        const fieldName = field.dataset.field;
        this.analyzer.updateMetadata(fieldName, text);
    }

    cancelEditing(field) {
        const textSpan = field.querySelector('.text');
        textSpan.textContent = field.dataset.originalValue || '';
        field.classList.remove('editing');
        textSpan.contentEditable = 'false';
    }

    async handleFileSelect(event) {
        const file = event.target.files[0];
        if (file) {
            await this.processFile(file);
        }
    }

    async processFile(file) {
        if (!file.name.toLowerCase().endsWith('.sid')) {
            this.showModal('Please select a valid SID file', false);
            return;
        }

        this.currentFileName = file.name;
        this.hasModifications = false;
        this.elements.saveButton.classList.remove('visible');

        this.showLoading(true);
        this.hideMessages();

        try {
            // Read file
            const buffer = await file.arrayBuffer();

            // Load SID file
            const header = await this.analyzer.loadSID(buffer);

            // Update UI with header info
            this.updateFileInfo(header);
            this.updateTechnicalInfo(header);
            this.updateSongTitle(header);

            // Show progress bar for analysis
            this.elements.progressBar.classList.add('active');

            // Run analysis
            const frameCount = 30000;
            let lastProgress = 0;

            this.analysisResults = await this.analyzer.analyze(frameCount, (current, total) => {
                const percent = Math.floor((current / total) * 100);
                if (percent !== lastProgress) {
                    lastProgress = percent;
                    this.elements.progressFill.style.width = percent + '%';
                    this.elements.progressText.textContent = `Analyzing: ${percent}%`;
                }
            });

            // Store analysis results in the analyzer for PRG builder to access
            this.analyzer.analysisResults = this.analysisResults;

            // Update UI with analysis results
            this.updateConsole(this.analysisResults);
            this.updateZeroPageInfo(this.analysisResults.zpAddresses);

            // Show panels
            this.elements.infoPanels.classList.add('visible');
            this.elements.songTitleSection.classList.add('visible');
            this.elements.consoleSection.classList.add('visible');

            // Show export section
            this.showExportSection();

            this.showModal(`Successfully analyzed: ${file.name}`, true);

        } catch (error) {
            this.showModal(`Error: ${error.message}`, false);
            console.error(error);
        } finally {
            this.showLoading(false);
            this.elements.progressBar.classList.remove('active');
        }
    }

    showExportSection() {
        if (this.elements.exportSection) {
            this.elements.exportSection.classList.add('visible');

            // Initialize PRG exporter if not done
            if (!this.prgExporter && this.analyzer) {
                this.prgExporter = new SIDwinderPRGExporter(this.analyzer);
                window.currentAnalyzer = this.analyzer;
            }
        }
    }

    updateFileInfo(header) {
        this.elements.sidTitle.querySelector('.text').textContent = header.name || 'Unknown';
        this.elements.sidAuthor.querySelector('.text').textContent = header.author || 'Unknown';
        this.elements.sidCopyright.querySelector('.text').textContent = header.copyright || 'Unknown';

        this.elements.sidFormat.textContent = header.format;
        this.elements.sidVersion.textContent = `v${header.version}`;
        this.elements.sidSongs.textContent = `${header.startSong}/${header.songs}`;
    }

    updateTechnicalInfo(header) {
        this.elements.loadAddress.textContent = this.formatHex(header.loadAddress, 4);
        this.elements.initAddress.textContent = this.formatHex(header.initAddress, 4);
        this.elements.playAddress.textContent = this.formatHex(header.playAddress, 4);

        const endAddr = header.loadAddress + header.fileSize - 1;
        this.elements.memoryRange.textContent =
            `${this.formatHex(header.loadAddress, 4)} - ${this.formatHex(endAddr, 4)}`;

        this.elements.fileSize.textContent = `${header.fileSize} bytes`;
        this.elements.clockType.textContent = header.clockType;
        this.elements.sidModel.textContent = header.sidModel;
    }

    updateSongTitle(header) {
        this.elements.songTitle.textContent = header.name || 'Unknown Title';
        this.elements.songAuthor.textContent = header.author || 'Unknown Author';
    }

    updateZeroPageInfo(zpAddresses) {
        if (!zpAddresses || zpAddresses.length === 0) {
            this.elements.zpUsage.textContent = 'None';
            return;
        }

        // Sort addresses
        const sorted = [...zpAddresses].sort((a, b) => a - b);

        // Group into ranges
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

        // Format ranges
        const formatted = ranges.map(r => {
            if (r.start === r.end) {
                return this.formatHex(r.start, 2);
            } else {
                return `${this.formatHex(r.start, 2)}-${this.formatHex(r.end, 2)}`;
            }
        });

        this.elements.zpUsage.textContent = formatted.join(', ');
    }

    updateConsole(results) {
        if (!results || !results.modifiedAddresses) {
            this.elements.consoleContent.innerHTML =
                '<div class="console-comment"># No modified memory found</div>';
            return;
        }

        const addresses = results.modifiedAddresses;
        const zpAddresses = addresses.filter(addr => addr < 256);
        const mainAddresses = addresses.filter(addr => addr >= 256);

        let html = '';

        if (mainAddresses.length > 0) {
            html += '<div class="console-line">';
            html += '<span class="console-comment"># Memory Range Modified:</span>';
            html += '</div>';
            html += '<div class="console-line">';
            html += '<span class="console-value">';
            html += mainAddresses.map(addr => this.formatHex(addr, 4)).join(', ');
            html += '</span>';
            html += '</div>';
        }

        if (zpAddresses.length > 0) {
            html += '<div class="console-line">&nbsp;</div>';
            html += '<div class="console-line">';
            html += '<span class="console-comment"># Zero Page Modified:</span>';
            html += '</div>';
            html += '<div class="console-line">';
            html += '<span class="console-value">';
            html += zpAddresses.map(addr => this.formatHex(addr, 2)).join(', ');
            html += '</span>';
            html += '</div>';
        }

        html += '<div class="console-line">&nbsp;</div>';
        html += '<div class="console-line">';
        html += `<span class="console-comment"># Total: ${addresses.length} addresses modified</span>`;
        html += '</div>';

        this.elements.consoleContent.innerHTML = html;
    }

    copyConsoleContent() {
        const text = this.elements.consoleContent.textContent;
        navigator.clipboard.writeText(text).then(() => {
            this.showModal('Addresses copied to clipboard!', true);
        }).catch(err => {
            // Fallback
            const textArea = document.createElement('textarea');
            textArea.value = text;
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand('copy');
            document.body.removeChild(textArea);
            this.showModal('Addresses copied to clipboard!', true);
        });
    }

    // Export functions
    exportModifiedSID() {
        const modifiedData = this.analyzer.createModifiedSID();

        if (!modifiedData) {
            this.showExportStatus('Failed to create modified SID', 'error');
            return;
        }

        const baseName = this.currentFileName ?
            this.currentFileName.replace('.sid', '') : 'modified';

        this.downloadFile(modifiedData, `${baseName}_edited.sid`);
        this.showExportStatus('SID file exported successfully!', 'success');
    }

    async exportPRGWithVisualizer() {
        if (!this.prgExporter) {
            this.showExportStatus('PRG exporter not initialized', 'error');
            return;
        }

        const visualizerType = this.elements.visualizerType.value;
        const includeData = this.elements.includeData.checked;
        const sidAddress = this.parseAddress(this.elements.sidAddress.value);

        if (visualizerType === 'none') {
            this.showExportStatus('Please select a visualizer type', 'error');
            return;
        }

        this.showExportStatus('Building PRG file...', 'info');

        try {
            const baseName = this.currentFileName ?
                this.currentFileName.replace('.sid', '') : 'output';

            const options = {
                sidLoadAddress: sidAddress,
                dataFile: includeData ? 'prg/data.bin' : null,
                dataLoadAddress: 0x4000,
                visualizerFile: `prg/${visualizerType}.bin`,
                visualizerLoadAddress: 0x4100,
                includeData: includeData
            };

            const prgData = await this.prgExporter.createPRG(options);
            this.downloadFile(prgData, `${baseName}_${visualizerType}.prg`);

            const info = this.prgExporter.builder.getInfo();
            const sizeKB = (prgData.length / 1024).toFixed(2);
            this.showExportStatus(
                `PRG exported successfully! Size: ${sizeKB}KB, ` +
                `Range: ${this.formatHex(info.lowestAddress, 4)} - ${this.formatHex(info.highestAddress, 4)}`,
                'success'
            );

        } catch (error) {
            console.error('Export error:', error);
            this.showExportStatus(`Export failed: ${error.message}`, 'error');
        }
    }

    async exportBasicPRG() {
        if (!this.prgExporter) {
            this.showExportStatus('PRG exporter not initialized', 'error');
            return;
        }

        try {
            const sidAddress = this.parseAddress(this.elements.sidAddress.value);
            const baseName = this.currentFileName ?
                this.currentFileName.replace('.sid', '') : 'output';

            // Build simple PRG with just SID
            const builder = new PRGBuilder();
            const sidInfo = this.prgExporter.extractSIDMusicData();
            builder.addComponent(sidInfo.data, sidAddress || sidInfo.loadAddress, 'SID Music');

            const prgData = builder.build();
            this.downloadFile(prgData, `${baseName}.prg`);

            this.showExportStatus('Basic PRG exported successfully!', 'success');

        } catch (error) {
            console.error('Export error:', error);
            this.showExportStatus(`Export failed: ${error.message}`, 'error');
        }
    }

    saveSID() {
        // This is the original save button functionality
        this.exportModifiedSID();
        this.hasModifications = false;
    }

    // Helper functions
    downloadFile(data, filename) {
        const blob = new Blob([data], { type: 'application/octet-stream' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    parseAddress(str) {
        str = str.trim();
        if (str.startsWith('$')) {
            return parseInt(str.substring(1), 16);
        } else if (str.startsWith('0x')) {
            return parseInt(str.substring(2), 16);
        } else {
            return parseInt(str, 10);
        }
    }

    showExportStatus(message, type) {
        const status = this.elements.exportStatus;
        if (status) {
            status.textContent = message;
            status.className = `export-status visible ${type}`;

            if (type !== 'info') {
                setTimeout(() => {
                    status.classList.remove('visible');
                }, 5000);
            }
        }
    }

    formatHex(value, digits) {
        return '$' + value.toString(16).toUpperCase().padStart(digits, '0');
    }

    showLoading(show) {
        this.elements.loading.classList.toggle('active', show);
    }

    showModal(message, isSuccess) {
        this.elements.modalIcon.textContent = isSuccess ? '✓' : '✗';
        this.elements.modalIcon.className = isSuccess ? 'modal-icon success' : 'modal-icon error';
        this.elements.modalMessage.textContent = message;

        this.elements.modalOverlay.classList.add('visible');

        setTimeout(() => {
            this.elements.modalOverlay.classList.remove('visible');
        }, 2000);
    }

    hideMessages() {
        this.elements.errorMessage.classList.remove('visible');
        this.elements.songTitleSection.classList.remove('visible');
        this.elements.consoleSection.classList.remove('visible');
        if (this.elements.exportSection) {
            this.elements.exportSection.classList.remove('visible');
        }
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    new UIController();
});