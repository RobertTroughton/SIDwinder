// ui.js - UI Controller for SIDwinder Web with PRG Export

class UIController {
    constructor() {
        this.analyzer = new SIDAnalyzer();
        this.currentFileName = null;
        this.hasModifications = false;
        this.analysisResults = null;
        this.prgExporter = null;
        this.sidHeader = null; // Store the SID header info
        this.elements = this.cacheElements();
        this.initEventListeners();
        this.initExportSection();
    }

    cacheElements() {
        return {
            uploadSection: document.getElementById('uploadSection'),
            fileInput: document.getElementById('fileInput'),
            saveButton: document.getElementById('saveButton'),
            songTitleSection: document.getElementById('songTitleSection'),
            songTitle: document.getElementById('songTitle'),
            songAuthor: document.getElementById('songAuthor'),
            loading: document.getElementById('loading'),
            progressBar: document.getElementById('progressBar'),
            progressFill: document.getElementById('progressFill'),
            progressText: document.getElementById('progressText'),
            errorMessage: document.getElementById('errorMessage'),
            infoPanels: document.getElementById('infoPanels'),
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
            visualizerType: document.getElementById('visualizerType'),
            autoRun: document.getElementById('autoRun'),
            useCompression: document.getElementById('useCompression'),
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

        // Drag and drop
        this.setupDragAndDrop();

        // Editable fields
        this.setupEditableFields();
    }

    initExportSection() {
        // Wait for PRG builder to be available
        // The PRG exporter will be initialized when a file is loaded

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
            this.sidHeader = header; // Store the header for later use

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
            this.updateZeroPageInfo(this.analysisResults.zpAddresses);

            // Show panels
            this.elements.infoPanels.classList.add('visible');
            this.elements.songTitleSection.classList.add('visible');

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

            // Initialize PRG exporter now that we have analyzer ready
            if (!this.prgExporter && this.analyzer) {
                // Check if SIDwinderPRGExporter is available
                if (typeof SIDwinderPRGExporter !== 'undefined') {
                    this.prgExporter = new SIDwinderPRGExporter(this.analyzer);
                    window.currentAnalyzer = this.analyzer;
                } else {
                    console.error('SIDwinderPRGExporter not loaded yet');
                    // Try again after a short delay
                    setTimeout(() => {
                        if (typeof SIDwinderPRGExporter !== 'undefined' && !this.prgExporter) {
                            this.prgExporter = new SIDwinderPRGExporter(this.analyzer);
                            window.currentAnalyzer = this.analyzer;
                        }
                    }, 500);
                }
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

    // In ui.js, update exportPRGWithVisualizer

    async exportPRGWithVisualizer() {
        // Check if PRG exporter is available
        if (!this.prgExporter) {
            if (typeof SIDwinderPRGExporter === 'undefined') {
                this.showExportStatus('PRG builder not loaded. Please refresh the page.', 'error');
                return;
            }
            // Try to initialize it now
            if (this.analyzer) {
                this.prgExporter = new SIDwinderPRGExporter(this.analyzer);
            } else {
                this.showExportStatus('Analyzer not ready. Please reload the SID file.', 'error');
                return;
            }
        }

        if (!this.sidHeader) {
            this.showExportStatus('No SID file loaded', 'error');
            return;
        }

        const visualizerType = this.elements.visualizerType.value;
        const autoRun = this.elements.autoRun.checked;
        const useCompression = this.elements.useCompression ? this.elements.useCompression.checked : false;

        if (visualizerType === 'none') {
            this.showExportStatus('Please select a visualizer type', 'error');
            return;
        }

        this.showExportStatus('Building PRG file...', 'info');

        try {
            const baseName = this.currentFileName ?
                this.currentFileName.replace('.sid', '') : 'output';

            // Use the actual SID addresses from the loaded file
            const options = {
                sidLoadAddress: this.sidHeader.loadAddress,
                sidInitAddress: this.sidHeader.initAddress,
                sidPlayAddress: this.sidHeader.playAddress,
                dataLoadAddress: 0x4000,
                visualizerFile: `prg/${visualizerType}.bin`,
                visualizerLoadAddress: 0x4100,
                includeData: true,
                addBASICStub: autoRun && !useCompression,  // No BASIC stub for compressed
                useCompression: useCompression
            };

            const prgData = await this.prgExporter.createPRG(options);

            const suffix = useCompression ? '_compressed' : '';
            this.downloadFile(prgData, `${baseName}_${visualizerType}${suffix}.prg`);

            const sizeKB = (prgData.length / 1024).toFixed(2);
            let statusMsg = `PRG exported successfully! Size: ${sizeKB}KB`;

            if (useCompression) {
                statusMsg += ' (RLE compressed)';
            }

            this.showExportStatus(statusMsg, 'success');

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
        if (this.elements.exportSection) {
            this.elements.exportSection.classList.remove('visible');
        }
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {

    // Wait a moment for all scripts to load
    setTimeout(() => {
        // Check if required classes are available
        if (typeof SIDAnalyzer === 'undefined') {
            console.error('SIDAnalyzer not loaded');
            alert('Error: Core components not loaded. Please refresh the page.');
            return;
        }

        if (typeof SIDwinderPRGExporter === 'undefined') {
            console.error('WARNING: SIDwinderPRGExporter not loaded yet');
            // Try to wait a bit longer
            setTimeout(() => {
                if (typeof SIDwinderPRGExporter === 'undefined') {
                    console.error('ERROR: SIDwinderPRGExporter still not available after waiting');
                }
            }, 1000);
        }

        // Initialize the UI controller anyway
        window.uiController = new UIController();
    }, 100);
});