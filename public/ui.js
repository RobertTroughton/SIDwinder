// ui.js - UI Controller for SIDwinder Web with Visual Visualizer Selection

class UIController {
    constructor() {
        this.analyzer = new SIDAnalyzer();
        this.currentFileName = null;
        this.hasModifications = false;
        this.analysisResults = null;
        this.prgExporter = null;
        this.sidHeader = null;
        this.originalMetadata = {}; // Store original metadata for comparison
        this.selectedVisualizer = null;
        this.visualizerConfig = null;
        this.elements = this.cacheElements();
        this.initEventListeners();
    }

    cacheElements() {
        return {
            uploadSection: document.getElementById('uploadSection'),
            fileInput: document.getElementById('fileInput'),
            songTitleSection: document.getElementById('songTitleSection'),
            songTitle: document.getElementById('songTitle'),
            songAuthor: document.getElementById('songAuthor'),
            loading: document.getElementById('loading'),
            progressBar: document.getElementById('progressBar'),
            progressFill: document.getElementById('progressFill'),
            progressText: document.getElementById('progressText'),
            errorMessage: document.getElementById('errorMessage'),
            infoSection: document.getElementById('infoSection'),
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
            visualizerGrid: document.getElementById('visualizerGrid'),
            visualizerOptions: document.getElementById('visualizerOptions'),
            useCompression: document.getElementById('useCompression'),
            exportModifiedSIDButton: document.getElementById('exportModifiedSIDButton'),
            exportPRGButton: document.getElementById('exportPRGButton'),
            exportStatus: document.getElementById('exportStatus'),
            exportHint: document.getElementById('exportHint')
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

        // Export modified SID button
        this.elements.exportModifiedSIDButton.addEventListener('click', () => {
            this.exportModifiedSID();
        });

        // Export PRG button
        this.elements.exportPRGButton.addEventListener('click', () => {
            this.exportPRGWithVisualizer();
        });

        // Drag and drop
        this.setupDragAndDrop();

        // Editable fields
        this.setupEditableFields();
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

        // Convert field name to match what the analyzer expects
        let analyzerFieldName = fieldName;
        if (fieldName === 'title') analyzerFieldName = 'name';

        this.analyzer.updateMetadata(analyzerFieldName, text);

        // Check if modifications were made
        this.checkForModifications();
    }

    cancelEditing(field) {
        const textSpan = field.querySelector('.text');
        textSpan.textContent = field.dataset.originalValue || '';
        field.classList.remove('editing');
        textSpan.contentEditable = 'false';
    }

    checkForModifications() {
        // Compare current values with original
        const currentTitle = this.elements.sidTitle.querySelector('.text').textContent.trim();
        const currentAuthor = this.elements.sidAuthor.querySelector('.text').textContent.trim();
        const currentCopyright = this.elements.sidCopyright.querySelector('.text').textContent.trim();

        const hasChanges =
            currentTitle !== this.originalMetadata.title ||
            currentAuthor !== this.originalMetadata.author ||
            currentCopyright !== this.originalMetadata.copyright;

        this.hasModifications = hasChanges;

        // Enable/disable export button
        this.elements.exportModifiedSIDButton.disabled = !hasChanges;

        // Show/hide hint
        if (this.elements.exportHint) {
            this.elements.exportHint.style.display = hasChanges ? 'none' : 'block';
        }
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
        this.elements.exportModifiedSIDButton.disabled = true;

        this.showLoading(true);
        this.hideMessages();

        try {
            // Read file
            const buffer = await file.arrayBuffer();

            // Load SID file
            const header = await this.analyzer.loadSID(buffer);
            this.sidHeader = header;

            // Store original metadata
            this.originalMetadata = {
                title: header.name || '',
                author: header.author || '',
                copyright: header.copyright || ''
            };

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
            this.elements.infoSection.classList.add('visible');
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

            // Initialize visualizer selection
            this.initVisualizerSelection();

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

    initVisualizerSelection() {
        this.selectedVisualizer = null;
        this.visualizerConfig = new VisualizerConfig();
        this.buildVisualizerGrid();
    }

    buildVisualizerGrid() {
        const grid = document.getElementById('visualizerGrid');
        if (!grid) return;

        grid.innerHTML = '';

        for (const viz of VISUALIZERS) {
            const card = this.createVisualizerCard(viz);
            grid.appendChild(card);
        }
    }

    createVisualizerCard(visualizer) {
        const card = document.createElement('div');
        card.className = 'visualizer-card';
        card.dataset.id = visualizer.id;

        card.innerHTML = `
            <div class="visualizer-preview">
                <img src="${visualizer.preview}" alt="${visualizer.name}" 
                     onerror="this.src='previews/default.png'">
            </div>
            <div class="visualizer-info">
                <h3>${visualizer.name}</h3>
                <p>${visualizer.description}</p>
            </div>
            <div class="visualizer-selected-badge">✓ Selected</div>
        `;

        card.addEventListener('click', () => {
            this.selectVisualizer(visualizer);
        });

        return card;
    }

    selectVisualizer(visualizer) {
        // Update visual selection
        const cards = document.querySelectorAll('.visualizer-card');
        cards.forEach(card => {
            card.classList.toggle('selected', card.dataset.id === visualizer.id);
        });

        this.selectedVisualizer = visualizer;

        // Enable export button
        this.elements.exportPRGButton.disabled = false;

        // Load and show options for this visualizer
        this.loadVisualizerOptions(visualizer);
    }

    async loadVisualizerOptions(visualizer) {
        const optionsContainer = document.getElementById('visualizerOptions');

        // Clear any existing options
        optionsContainer.innerHTML = '';

        if (!visualizer.config) {
            // No config means no extra options
            optionsContainer.style.display = 'none';
            return;
        }

        // Load config
        const config = await this.visualizerConfig.loadConfig(visualizer.id);
        if (!config || (!config.inputs && !config.options)) {
            optionsContainer.style.display = 'none';
            return;
        }

        // Show container
        optionsContainer.style.display = 'block';

        // Create options title
        const title = document.createElement('h3');
        title.textContent = `${visualizer.name} Options`;
        optionsContainer.appendChild(title);

        // Add file inputs
        if (config.inputs) {
            for (const input of config.inputs) {
                const inputEl = this.createFileInput(input);
                optionsContainer.appendChild(inputEl);
            }
        }

        // Add other options
        if (config.options) {
            for (const option of config.options) {
                const optionEl = this.createOption(option);
                optionsContainer.appendChild(optionEl);
            }
        }
    }

    createFileInput(config) {
        const div = document.createElement('div');
        div.className = 'file-input-option';
        div.innerHTML = `
        <label for="${config.id}">${config.label}:</label>
        <div class="file-input-controls">
            <div class="file-input-wrapper">
                <input type="file" id="${config.id}" accept="${config.accept}" 
                       data-config='${JSON.stringify(config)}' style="display: none;">
                <button type="button" class="file-select-button" id="${config.id}-button">
                    Choose
                </button>
                <span class="file-name" id="${config.id}-name">
                    ${config.default ? 'Using default' : 'No file selected'}
                </span>
                ${config.default ?
                `<button type="button" class="file-clear-button" id="${config.id}-clear" style="display: none;">
                        ✕
                    </button>` : ''}
            </div>
            ${config.description ? `<div class="input-hint">${config.description}</div>` : ''}
        </div>
        `;

        const fileInput = div.querySelector('input[type="file"]');
        const fileName = div.querySelector('.file-name');
        const selectButton = div.querySelector('.file-select-button');
        const clearButton = div.querySelector('.file-clear-button');

        // Click button to open file dialog
        selectButton.addEventListener('click', () => {
            fileInput.click();
        });

        // Handle file selection
        fileInput.addEventListener('change', (e) => {
            if (e.target.files.length > 0) {
                fileName.textContent = e.target.files[0].name;
                if (clearButton) {
                    clearButton.style.display = 'inline-block';
                }
            } else {
                fileName.textContent = config.default ? 'Using default' : 'No file selected';
                if (clearButton) {
                    clearButton.style.display = 'none';
                }
            }
        });

        // Clear button to revert to default
        if (clearButton) {
            clearButton.addEventListener('click', () => {
                fileInput.value = '';
                fileName.textContent = 'Using default';
                clearButton.style.display = 'none';
            });
        }

        return div;
    }

    createOption(config) {
        const div = document.createElement('div');
        div.className = 'export-option';

        if (config.type === 'select') {
            div.innerHTML = `
            <label for="${config.id}">${config.label}:</label>
            <select id="${config.id}">
                ${config.values.map(v =>
                `<option value="${v.value}" ${v.value === config.default ? 'selected' : ''}>
                        ${v.label}
                    </option>`
            ).join('')}
            </select>
        `;
        } else if (config.type === 'number') {
            // Create the number input HTML
            const html = `
            <label for="${config.id}">${config.label}:</label>
            <div class="number-input-wrapper">
                <input type="number" 
                       id="${config.id}" 
                       value="${config.default || 0}" 
                       min="${config.min || 0}" 
                       max="${config.max || 255}"
                       data-config='${JSON.stringify(config)}'>
                ${config.description ? `<span class="input-description">${config.description}</span>` : ''}
            </div>
        `;
            div.innerHTML = html;
        }

        return div;
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

        // Update the original metadata to reflect the saved state
        this.originalMetadata = {
            title: this.elements.sidTitle.querySelector('.text').textContent.trim(),
            author: this.elements.sidAuthor.querySelector('.text').textContent.trim(),
            copyright: this.elements.sidCopyright.querySelector('.text').textContent.trim()
        };

        // Reset modification state
        this.hasModifications = false;
        this.elements.exportModifiedSIDButton.disabled = true;
        if (this.elements.exportHint) {
            this.elements.exportHint.style.display = 'block';
        }
    }

    async exportPRGWithVisualizer() {
        if (!this.selectedVisualizer) {
            this.showExportStatus('Please select a visualizer', 'error');
            return;
        }

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

        const useCompression = this.elements.useCompression ? this.elements.useCompression.checked : false;

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
                visualizerFile: this.selectedVisualizer.binary,
                visualizerLoadAddress: 0x4100,
                includeData: true,
                useCompression: useCompression
            };

            const prgData = await this.prgExporter.createPRG(options);

            const suffix = useCompression ? '_compressed' : '';
            this.downloadFile(prgData, `${baseName}_${this.selectedVisualizer.id}${suffix}.prg`);

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
        if (this.elements.infoSection) {
            this.elements.infoSection.classList.remove('visible');
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