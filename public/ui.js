﻿// ui.js - UI Controller for SIDwinder Web with Visual Visualizer Selection and Image Previews

// Global C64 color palette
const C64_COLORS = [
    { value: 0, name: 'Black', hex: '#000000' },
    { value: 1, name: 'White', hex: '#FFFFFF' },
    { value: 2, name: 'Red', hex: '#753d3d' },
    { value: 3, name: 'Cyan', hex: '#7bb4b4' },
    { value: 4, name: 'Purple', hex: '#7d4488' },
    { value: 5, name: 'Green', hex: '#5c985c' },
    { value: 6, name: 'Blue', hex: '#343383' },
    { value: 7, name: 'Yellow', hex: '#cbcc7c' },
    { value: 8, name: 'Orange', hex: '#7c552f' },
    { value: 9, name: 'Brown', hex: '#523e00' },
    { value: 10, name: 'Light Red', hex: '#a76f6f' },
    { value: 11, name: 'Dark Grey', hex: '#4e4e4e' },
    { value: 12, name: 'Grey', hex: '#767676' },
    { value: 13, name: 'Light Green', hex: '#9fdb9f' },
    { value: 14, name: 'Light Blue', hex: '#6d6cbc' },
    { value: 15, name: 'Light Grey', hex: '#a3a3a3' }
];

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
        this.hvscBrowserWindow = null;
        this.elements = this.cacheElements();
        this.initEventListeners();
    }

    cacheElements() {
        return {
            // Upload container elements
            uploadContainer: document.querySelector('.upload-container'),
            uploadMethods: document.querySelectorAll('.upload-method'),
            uploadPanels: document.querySelectorAll('.upload-panel'),

            // Individual panels
            dragDropPanel: document.getElementById('dragDropPanel'),
            browsePanel: document.getElementById('browsePanel'),
            hvscPanel: document.getElementById('hvscPanel'),

            // Upload elements
            uploadSection: document.getElementById('uploadSection'),
            browseButton: document.getElementById('browseButton'),
            hvscButton: document.getElementById('hvscButton'),
            hvscSelected: document.getElementById('hvscSelected'),
            selectedFile: document.getElementById('selectedFile'),

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
            compressionType: document.getElementById('compressionType'),
            exportModifiedSIDButton: document.getElementById('exportModifiedSIDButton'),
            exportPRGButton: document.getElementById('exportPRGButton'),
            exportStatus: document.getElementById('exportStatus'),
            exportHint: document.getElementById('exportHint')
        };
    }

    initEventListeners() {
        // Upload method selector
        this.elements.uploadMethods.forEach(method => {
            method.addEventListener('click', (e) => {
                const selectedMethod = e.currentTarget.dataset.method;
                this.switchUploadMethod(selectedMethod);
            });
        });

        // Browse button
        this.elements.browseButton.addEventListener('click', () => {
            this.elements.fileInput.click();
        });

        // HVSC button
        this.elements.hvscButton.addEventListener('click', () => {
            this.openHVSCBrowser();
        });

        // File upload (old drag & drop section click)
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

        // Listen for messages from HVSC browser window
        window.addEventListener('message', (e) => {
            if (e.data && e.data.type === 'sid-selected') {
                this.handleHVSCSelection(e.data);
            }
        });

        // Initialize the UI in "attract mode"
        this.initializeAttractMode();
    }

    switchUploadMethod(method) {
        // Update method tabs
        this.elements.uploadMethods.forEach(m => {
            m.classList.toggle('active', m.dataset.method === method);
        });

        // Update panels
        this.elements.uploadPanels.forEach(panel => {
            panel.classList.remove('active');
        });

        // Show the selected panel
        switch (method) {
            case 'drag-drop':
                this.elements.dragDropPanel.classList.add('active');
                break;
            case 'browse':
                this.elements.browsePanel.classList.add('active');
                break;
            case 'hvsc':
                this.elements.hvscPanel.classList.add('active');
                break;
        }
    }

    openHVSCBrowser() {
        // Calculate center position
        const width = 950;
        const height = 650;
        const left = (window.screen.width - width) / 2;
        const top = (window.screen.height - height) / 2;

        // Open the HVSC browser in a popup window
        this.hvscBrowserWindow = window.open(
            'hvsc-browser.html',
            'hvscBrowser',
            `width=${width},height=${height},left=${left},top=${top},resizable=yes,scrollbars=yes`
        );

        // Focus the window if it was already open
        if (this.hvscBrowserWindow) {
            this.hvscBrowserWindow.focus();
        }
    }

    async handleHVSCSelection(data) {
        console.log('HVSC selection received:', data);

        // Update UI to show selected file
        this.elements.hvscSelected.style.display = 'block';
        this.elements.selectedFile.textContent = data.name;

        // Close the browser window
        if (this.hvscBrowserWindow) {
            this.hvscBrowserWindow.close();
            this.hvscBrowserWindow = null;
        }

        // Download the SID file from HVSC
        this.showLoading(true);
        this.showModal('Downloading SID from HVSC...', true);

        try {
            // Fetch the SID file
            const response = await fetch(data.url);
            if (!response.ok) {
                throw new Error('Failed to download SID file');
            }

            const blob = await response.blob();

            // Create a File object from the blob
            const file = new File([blob], data.name, { type: 'application/octet-stream' });

            // Process the file as if it was uploaded
            await this.processFile(file);

        } catch (error) {
            console.error('Error downloading HVSC file:', error);
            this.showModal('Failed to download SID from HVSC', false);
            this.showLoading(false);
        }
    }

    initializeAttractMode() {
        // Set all info fields to placeholder values
        this.elements.sidTitle.querySelector('.text').textContent = 'Song Title';
        this.elements.sidAuthor.querySelector('.text').textContent = 'Artist Name';
        this.elements.sidCopyright.querySelector('.text').textContent = 'Copyright Info';

        this.elements.sidFormat.textContent = 'PSID';
        this.elements.sidVersion.textContent = 'v2';
        this.elements.sidSongs.textContent = '1/1';

        this.elements.loadAddress.textContent = '$1000';
        this.elements.initAddress.textContent = '$1000';
        this.elements.playAddress.textContent = '$1003';
        this.elements.memoryRange.textContent = '$1000 - $2FFF';
        this.elements.fileSize.textContent = '8192 bytes';
        this.elements.zpUsage.textContent = '$02-$FF';
        this.elements.clockType.textContent = 'PAL';
        this.elements.sidModel.textContent = 'MOS 6581';

        const numCallsElement = document.getElementById('numCallsPerFrame');
        if (numCallsElement) {
            numCallsElement.textContent = '1';
        }

        const modifiedMemoryElement = document.getElementById('modifiedMemoryCount');
        if (!modifiedMemoryElement) {
            // Create the row in attract mode too
            const infoPanels = document.getElementById('infoPanels');
            const technicalPanel = infoPanels.querySelector('.panel:nth-child(2)');

            const modifiedRow = document.createElement('div');
            modifiedRow.id = 'modifiedMemoryRow';
            modifiedRow.className = 'info-row';
            modifiedRow.innerHTML = `
        <span class="info-label">Modified Memory:</span>
        <span class="info-value" id="modifiedMemoryCount">0 locations</span>
    `;

            // Find the Clock Type row to insert before it
            const clockTypeRow = technicalPanel.querySelector('.info-row:nth-last-child(3)');
            if (clockTypeRow) {
                technicalPanel.insertBefore(modifiedRow, clockTypeRow);
            } else {
                technicalPanel.appendChild(modifiedRow);
            }
        } else {
            modifiedMemoryElement.textContent = '0 locations';
        }

        // Initialize visualizer grid with disabled state
        this.buildAttractModeVisualizerGrid();
    }

    buildAttractModeVisualizerGrid() {
        const grid = document.getElementById('visualizerGrid');
        if (!grid) return;

        grid.innerHTML = '';

        // Show all visualizers in disabled state
        for (let i = 0; i < VISUALIZERS.length; i++) {
            const viz = VISUALIZERS[i];
            const card = this.createVisualizerCard(viz);
            card.classList.add('disabled');
            card.style.pointerEvents = 'none';

            // Show the first one as selected for visual consistency
            if (i === 0) {
                card.classList.add('selected');
            }

            grid.appendChild(card);
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
            const textSpan = field.querySelector('.text');

            field.addEventListener('click', (e) => {
                if (!field.classList.contains('editing') && !field.classList.contains('disabled')) {
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

            // Use blur on the text span instead of the field
            textSpan.addEventListener('blur', () => {
                if (field.classList.contains('editing')) {
                    // Use setTimeout to allow click events on other elements to fire first
                    setTimeout(() => {
                        if (field.classList.contains('editing')) {
                            this.stopEditing(field);
                        }
                    }, 200);
                }
            });

            // Add paste handler to strip formatting
            textSpan.addEventListener('paste', (e) => {
                e.preventDefault();

                // Get plain text from clipboard
                let text = '';
                if (e.clipboardData || e.originalEvent.clipboardData) {
                    text = (e.clipboardData || e.originalEvent.clipboardData).getData('text/plain');
                } else if (window.clipboardData) {
                    text = window.clipboardData.getData('Text');
                }

                // Clean up the text
                text = text.replace(/[\r\n\t]/g, ' '); // Replace newlines and tabs with spaces
                text = text.replace(/\s+/g, ' '); // Replace multiple spaces with single space
                text = text.trim();

                // Insert the plain text at cursor position
                if (window.getSelection) {
                    const selection = window.getSelection();
                    if (!selection.rangeCount) return;
                    selection.deleteFromDocument();
                    selection.getRangeAt(0).insertNode(document.createTextNode(text));

                    // Move cursor to end of inserted text
                    selection.collapseToEnd();
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

        // Clean and limit text
        let text = textSpan.textContent || '';

        // Remove any HTML that might have been pasted
        text = text.replace(/<[^>]*>/g, '');

        // Clean whitespace
        text = text.replace(/[\r\n\t]/g, ' ');
        text = text.replace(/\s+/g, ' ');
        text = text.trim();

        // Limit to 31 characters
        if (text.length > 31) {
            text = text.substring(0, 31);
        }

        textSpan.textContent = text;

        // Update in WASM
        const fieldName = field.dataset.field;
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
            this.analyzer.sidHeader = header;

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

            this.analyzer.analysisResults = this.analysisResults;

            // Update UI with analysis results
            this.updateZeroPageInfo(this.analysisResults.zpAddresses);
            this.updateModifiedMemoryCount();
            this.updateNumCallsPerFrame(this.analysisResults.numCallsPerFrame);

            // Show panels - remove disabled state and add visible
            this.elements.infoSection.classList.remove('disabled');
            this.elements.infoSection.classList.add('visible');
            this.elements.songTitleSection.classList.remove('disabled');
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
            // Remove disabled state and add visible
            this.elements.exportSection.classList.remove('disabled');
            this.elements.exportSection.classList.add('visible');

            // Update the header to show calls per frame info
            const header = this.elements.exportSection.querySelector('h2');
            if (header && this.analysisResults) {
                const calls = this.analysisResults.numCallsPerFrame || 1;
                header.innerHTML = `🎮 Choose Your Visualizer <span style="font-size: 0.8em; color: #666;"></span>`;
            }

            // Add song selector if multiple songs
            this.addSongSelector();

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

    addSongSelector() {
        // Remove any existing song selector
        const existingSelector = document.getElementById('songSelectorContainer');
        if (existingSelector) {
            existingSelector.remove();
        }

        // Only add if there are multiple songs
        if (this.sidHeader && this.sidHeader.songs > 1) {
            const visualizerGrid = document.getElementById('visualizerGrid');
            const selectorContainer = document.createElement('div');
            selectorContainer.id = 'songSelectorContainer';
            selectorContainer.className = 'export-option song-selector-container';
            selectorContainer.innerHTML = `
            <label for="songSelector">Select Song:</label>
            <select id="songSelector">
                ${Array.from({ length: Math.min(this.sidHeader.songs, 256) }, (_, i) => i + 1)
                    .map(num => `<option value="${num}" ${num === this.sidHeader.startSong ? 'selected' : ''}>
                        Song ${num} of ${this.sidHeader.songs}${num === this.sidHeader.startSong ? ' (default)' : ''}
                    </option>`).join('')}
            </select>
        `;

            // Insert before visualizer grid
            visualizerGrid.parentNode.insertBefore(selectorContainer, visualizerGrid);
        }
    }

    async initVisualizerSelection() {
        this.selectedVisualizer = null;
        this.visualizerConfig = new VisualizerConfig();
        await this.loadAllVisualizerConfigs();
        this.buildVisualizerGrid();
    }

    async loadAllVisualizerConfigs() {
        // Load configs for all visualizers to get their maxCallsPerFrame values
        for (const viz of VISUALIZERS) {
            if (viz.config) {
                try {
                    const config = await this.visualizerConfig.loadConfig(viz.id);
                    if (config && config.maxCallsPerFrame !== undefined) {
                        viz.maxCallsPerFrame = config.maxCallsPerFrame;
                    }
                    // Make sure we're not overwriting the config
                    viz.configData = config; // Store the full config
                } catch (error) {
                    console.warn(`Could not load config for ${viz.id}:`, error);
                }
            }
        }
    }

    buildVisualizerGrid() {
        const grid = document.getElementById('visualizerGrid');
        if (!grid) return;

        grid.innerHTML = '';

        const requiredCalls = this.analysisResults?.numCallsPerFrame || 1;

        // Separate visualizers into compatible and incompatible
        const compatible = [];
        const incompatible = [];

        // Get the actual modified addresses array
        const modifiedAddresses = this.analysisResults?.modifiedAddresses || [];

        for (const viz of VISUALIZERS) {
            // Check if visualizer can handle this SID
            if (viz.configData) {
                const validLayouts = this.prgExporter.selectValidLayouts(
                    viz.configData,
                    this.sidHeader.loadAddress,
                    this.analysisResults?.dataBytes || 0x2000,
                    modifiedAddresses  // Pass actual addresses array, not count
                );

                // Mark visualizer as incompatible if no valid layouts
                if (validLayouts.filter(l => l.valid).length === 0) {
                    incompatible.push(viz);
                } else {
                    compatible.push(viz);
                }
            } else {
                compatible.push(viz);
            }
        }

        // Sort each group by name
        compatible.sort((a, b) => a.name.localeCompare(b.name));
        incompatible.sort((a, b) => a.name.localeCompare(b.name));

        // Add compatible visualizers
        for (let i = 0; i < compatible.length; i++) {
            const viz = compatible[i];
            const card = this.createVisualizerCard(viz);
            grid.appendChild(card);

            // Auto-select the first compatible visualizer
            if (i === 0) {
                this.selectVisualizer(viz);
                card.classList.add('selected');
            }
        }

        // Add separator if there are both compatible and incompatible visualizers
        if (compatible.length > 0 && incompatible.length > 0) {
            const separator = document.createElement('div');
            separator.className = 'visualizer-separator';
            separator.innerHTML = '<span>Incompatible with this SID (requires fewer calls/frame)</span>';
            separator.style.cssText = `
            grid-column: 1 / -1;
            text-align: center;
            padding: 20px;
            color: #666;
            font-style: italic;
            border-top: 1px dashed #333;
            margin: 10px 0;
        `;
            grid.appendChild(separator);
        }

        // Add incompatible visualizers
        for (const viz of incompatible) {
            const card = this.createVisualizerCard(viz);
            grid.appendChild(card);
        }
    }

    createVisualizerCard(visualizer) {
        const card = document.createElement('div');
        card.className = 'visualizer-card';
        card.dataset.id = visualizer.id;

        // Check if this visualizer can handle the required calls per frame
        const requiredCalls = this.analysisResults?.numCallsPerFrame || 1;
        const maxCalls = visualizer.configData?.maxCallsPerFrame || Infinity;
        const isDisabled = requiredCalls > maxCalls;

        if (isDisabled) {
            card.classList.add('disabled');
        }

        const disabledMessage = isDisabled ?
            `Requires max ${maxCalls} call${maxCalls > 1 ? 's' : ''}/frame` : '';

        card.innerHTML = `
        <div class="visualizer-preview">
            <img src="${visualizer.preview}" alt="${visualizer.name}" 
                 onerror="this.src='previews/default.png'">
        </div>
        <div class="visualizer-info" ${isDisabled ? `data-reason="${disabledMessage}"` : ''}>
            <h3>${visualizer.name}</h3>
            <p>${visualizer.description}</p>
        </div>
        <div class="visualizer-selected-badge">✓ Selected</div>
    `;

        if (!isDisabled) {
            card.addEventListener('click', () => {
                this.selectVisualizer(visualizer);
            });
        }

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
        optionsContainer.innerHTML = '';

        if (!visualizer.config) {
            optionsContainer.style.display = 'none';
            return;
        }

        const config = await this.visualizerConfig.loadConfig(visualizer.id);

        // Check if we have any options to display
        const hasLayouts = config?.layouts && Object.keys(config.layouts).length > 1;
        const hasInputs = config?.inputs && config.inputs.length > 0;
        const hasOptions = config?.options && config.options.length > 0;

        // Always show if we have any options or if we need compression
        if (!hasLayouts && !hasInputs && !hasOptions) {
            // Still show for compression option
            optionsContainer.style.display = 'block';
            optionsContainer.className = 'visualizer-options-panel';
            optionsContainer.innerHTML = `
            <div class="options-header">
                <h3>📎 Export Configuration</h3>
            </div>
            <div class="options-content">
                ${this.createCompressionOptionsHTML()}
            </div>
        `;
            return;
        }

        optionsContainer.style.display = 'block';
        optionsContainer.className = 'visualizer-options-panel';

        // Create the structured HTML
        let html = `
        <div class="options-header">
            <h3>📎 ${visualizer.name} Configuration</h3>
        </div>
        <div class="options-content">
    `;

        // Memory Layout Section (if applicable)
        if (hasLayouts) {
            const layoutHTML = this.createLayoutSelectorHTML(visualizer, config);
            if (layoutHTML) {
                html += `
                <div class="option-group">
                    <div class="option-group-title">Memory Location</div>
                    ${layoutHTML}
                </div>
            `;
            }
        }

        // File Inputs Section (if applicable)
        if (hasInputs) {
            html += '<div class="option-group"><div class="option-group-title">Resources</div>';
            for (const input of config.inputs) {
                html += this.createFileInputHTML(input);
            }
            html += '</div>';
        }

        // Other Options Section (if applicable)
        if (hasOptions) {
            html += '<div class="option-group"><div class="option-group-title">Settings</div>';
            for (const option of config.options) {
                html += this.createOptionHTML(option);
            }
            html += '</div>';
        }

        // Always add Compression Section
        html += this.createCompressionOptionsHTML();

        html += '</div>'; // close options-content

        optionsContainer.innerHTML = html;

        // Attach event listeners after HTML is inserted
        this.attachOptionEventListeners(config);
    }

    createCompressionOptionsHTML() {
        return `
        <div class="option-group">
            <div class="option-group-title">Compression</div>
            <div class="compression-options">
                <label class="compression-radio-option">
                    <input type="radio" 
                           name="compression-type" 
                           value="none">
                    <div class="compression-details">
                        <span class="compression-name">None</span>
                        <span class="compression-desc">Uncompressed PRG</span>
                    </div>
                </label>
                <label class="compression-radio-option">
                    <input type="radio" 
                           name="compression-type" 
                           value="tscrunch"
                           checked>
                    <div class="compression-details">
                        <span class="compression-name">TSCrunch</span>
                        <span class="compression-desc">Best compression ratio</span>
                    </div>
                </label>
            </div>
        </div>
    `;
    }

    createLayoutSelectorHTML(visualizer, config) {
        const sidLoadAddress = this.sidHeader?.loadAddress || 0x1000;
        const sidSize = this.analysisResults?.dataBytes || 0x2000;
        const modifiedAddresses = this.analysisResults?.modifiedAddresses || 0;
        const modifiedCount = this.analysisResults?.modifiedAddresses?.length || 0;

        if (!this.prgExporter) {
            this.prgExporter = new SIDwinderPRGExporter(this.analyzer);
        }

        const layouts = this.prgExporter.selectValidLayouts(config, sidLoadAddress, sidSize, modifiedAddresses);

        // Sort all layouts by address
        layouts.sort((a, b) => a.vizStart - b.vizStart);

        const validLayouts = layouts.filter(l => l.valid);

        if (validLayouts.length === 0) {
            return '<div class="option-warning">⚠️ No compatible memory layouts available</div>';
        }

        let html = '<div class="layout-options">';

        // All layouts in one list
        let firstValidIndex = -1;
        layouts.forEach((layoutInfo, index) => {
            const layout = layoutInfo.layout;

            // Calculate the full memory range including save/restore
            let rangeStart, rangeEnd;
            if (modifiedCount > 0 && layoutInfo.saveRestoreStart < layoutInfo.vizStart) {
                // Save/restore is before visualizer
                rangeStart = this.formatHex(layoutInfo.saveRestoreStart, 4);
                rangeEnd = this.formatHex(layoutInfo.vizEnd - 1, 4);
            } else if (modifiedCount > 0 && layoutInfo.saveRestoreEnd > layoutInfo.vizEnd) {
                // Save/restore is after visualizer
                rangeStart = this.formatHex(layoutInfo.vizStart, 4);
                rangeEnd = this.formatHex(layoutInfo.saveRestoreEnd - 1, 4);
            } else {
                // No save/restore or it fits within visualizer range
                rangeStart = this.formatHex(layoutInfo.vizStart, 4);
                rangeEnd = this.formatHex(layoutInfo.vizEnd - 1, 4);
            }

            const isValid = layoutInfo.valid;

            // Track first valid layout for auto-selection
            if (isValid && firstValidIndex === -1) {
                firstValidIndex = index;
            }

            // Generate a more descriptive name based on the address
            const bankName = `bank${(layoutInfo.vizStart >> 12).toString(16).toUpperCase()}000`;

            html += `
        <label class="layout-radio-option ${!isValid ? 'disabled' : ''}" 
               ${!isValid ? `title="${layoutInfo.overlapReason}"` : ''}>
            <input type="radio" 
                   name="memory-layout" 
                   value="${layoutInfo.key}" 
                   ${isValid && index === firstValidIndex ? 'checked' : ''}
                   ${!isValid ? 'disabled' : ''}>
            <div class="layout-details">
                <span class="layout-name">${layout.name || bankName}</span>
                <span class="layout-range">${rangeStart}-${rangeEnd}</span>
            </div>
        </label>
    `;
        });

        html += '</div>';
        return html;
    }

    createFileInputHTML(config) {
        // Check if this is an image input that should use preview
        const isImageInput = config.accept && (
            config.accept.includes('image/') ||
            config.accept.includes('.png') ||
            config.accept.includes('.koa')
        );

        if (isImageInput) {
            // Create a container for the image preview
            return `
            <div class="option-row option-row-full">
                <label class="option-label">${config.label}</label>
                <div class="option-control">
                    <div id="${config.id}-preview-container" class="image-input-container">
                        <!-- Preview will be inserted here -->
                    </div>
                </div>
            </div>
        `;
        } else {
            // Use traditional file input for non-image files
            return `
            <div class="option-row">
                <label class="option-label">${config.label}</label>
                <div class="option-control">
                    <input type="file" 
                           id="${config.id}" 
                           accept="${config.accept}" 
                           style="display: none;">
                    <button type="button" 
                            class="file-button" 
                            data-file-input="${config.id}">
                        Choose File
                    </button>
                    <span class="file-status" id="${config.id}-status">
                        ${config.default ? 'Using default' : 'No file selected'}
                    </span>
                </div>
            </div>
        `;
        }
    }

    createOptionHTML(config) {
        let html = `<div class="option-row">`;

        if (config.type === 'number') {
            // Check if this is a color option (0-15 range)
            if (config.id && config.id.toLowerCase().includes('color') &&
                config.min === 0 && config.max === 15) {
                // Color slider option
                html += this.createColorSliderHTML(config);
            } else {
                // Regular number input
                html += `
                <label class="option-label">${config.label}</label>
                <div class="option-control">
                    <input type="number" 
                           id="${config.id}" 
                           class="number-input"
                           value="${config.default || 0}" 
                           min="${config.min || 0}" 
                           max="${config.max || 255}">
                    ${config.description ? `<span class="option-hint">${config.description}</span>` : ''}
                </div>
            `;
            }
        } else if (config.type === 'select') {
            html += `
            <label class="option-label">${config.label}</label>
            <div class="option-control">
                <select id="${config.id}" class="select-input">
                    ${config.values.map(v =>
                `<option value="${v.value}" ${v.value === config.default ? 'selected' : ''}>
                            ${v.label}
                        </option>`
            ).join('')}
                </select>
            </div>
        `;
        } else if (config.type === 'date') {
            html += `
            <label class="option-label">${config.label}</label>
            <div class="option-control">
                <input type="date" id="${config.id}" class="date-input">
                <span class="date-preview" id="${config.id}-preview">Not set</span>
            </div>
        `;
        } else if (config.type === 'textarea') {
            // New textarea handling
            html += `
            <label class="option-label">${config.label}</label>
            <div class="option-control">
                <div class="textarea-container">
                    <textarea 
                        id="${config.id}" 
                        maxlength="${config.maxLength || 255}"
                        rows="3"
                        placeholder="${config.description || ''}"
                    >${config.default || ''}</textarea>
                    ${config.loadSave ? `
                        <div class="textarea-controls">
                            <button type="button" class="load-text-btn" data-target="${config.id}">Load</button>
                            <button type="button" class="save-text-btn" data-target="${config.id}">Save</button>
                        </div>
                    ` : ''}
                </div>
            </div>
        `;
        }

        html += '</div>';
        return html;
    }

    createColorSliderHTML(config) {
        const defaultValue = config.default || 0;
        const defaultColor = C64_COLORS[defaultValue];

        return `
        <label class="option-label">${config.label}</label>
        <div class="option-control color-slider-control">
            <div class="slider-wrapper">
                <input type="range" 
                       id="${config.id}" 
                       class="color-slider"
                       min="0" 
                       max="15" 
                       value="${defaultValue}"
                       data-config-id="${config.id}">
                <div class="color-slider-track">
                    ${C64_COLORS.map(c => `
                        <div class="color-segment" 
                             style="background: ${c.hex}"
                             data-value="${c.value}"
                             data-name="${c.name}"
                             title="${c.value}: ${c.name}">
                        </div>
                    `).join('')}
                </div>
            </div>
            <div class="color-value" id="${config.id}-display">
                <span class="color-swatch" style="background: ${defaultColor.hex}"></span>
                <span class="color-text">
                    <span class="color-number">${defaultValue}</span>: 
                    <span class="color-name">${defaultColor.name}</span>
                </span>
            </div>
        </div>
    `;
    }

    attachOptionEventListeners(config) {
        // Initialize image preview manager if not already created
        if (!window.imagePreviewManager) {
            window.imagePreviewManager = new ImagePreviewManager();
        }

        // Set up image previews for image inputs
        if (config && config.inputs) {
            config.inputs.forEach(inputConfig => {
                const isImageInput = inputConfig.accept && (
                    inputConfig.accept.includes('image/') ||
                    inputConfig.accept.includes('.png') ||
                    inputConfig.accept.includes('.koa')
                );

                if (isImageInput) {
                    const container = document.getElementById(`${inputConfig.id}-preview-container`);
                    if (container) {
                        // Create and insert the preview element
                        const previewElement = window.imagePreviewManager.createImagePreview(inputConfig);
                        container.appendChild(previewElement);

                        // Load the default image
                        window.imagePreviewManager.loadDefaultImage(inputConfig);
                    }
                }
            });
        }

        // Traditional file input handlers (for non-image files)
        document.querySelectorAll('.file-button').forEach(button => {
            button.addEventListener('click', (e) => {
                const inputId = e.target.dataset.fileInput;
                document.getElementById(inputId).click();
            });
        });

        document.querySelectorAll('input[type="file"]:not([accept*="image"]):not([accept*=".png"]):not([accept*=".koa"])').forEach(input => {
            input.addEventListener('change', (e) => {
                const statusEl = document.getElementById(`${e.target.id}-status`);
                if (e.target.files.length > 0) {
                    statusEl.textContent = e.target.files[0].name;
                    statusEl.classList.add('has-file');
                }
            });
        });

        // Date input handlers
        document.querySelectorAll('input[type="date"]').forEach(input => {
            input.addEventListener('change', (e) => {
                const previewEl = document.getElementById(`${e.target.id}-preview`);
                if (previewEl) {
                    previewEl.textContent = this.formatDateForDisplay(e.target.value);
                }
            });
        });

        // Color slider handlers
        document.querySelectorAll('.color-slider').forEach(slider => {
            // Handle slider input changes (for programmatic changes)
            slider.addEventListener('input', (e) => {
                this.updateColorDisplay(e.target);
            });
        });

        // Handle direct clicks on color segments
        document.querySelectorAll('.color-segment').forEach(segment => {
            segment.addEventListener('click', (e) => {
                e.stopPropagation(); // Prevent event bubbling
                const value = parseInt(e.target.dataset.value);
                const slider = e.target.closest('.slider-wrapper').querySelector('.color-slider');
                if (slider) {
                    slider.value = value;
                    // Trigger the input event manually
                    const event = new Event('input', { bubbles: true });
                    slider.dispatchEvent(event);
                }
            });
        });

        // Textarea load/save handlers
        document.querySelectorAll('.load-text-btn').forEach(button => {
            button.addEventListener('click', (e) => {
                this.loadScrollText(e.target.getAttribute('data-target'));
            });
        });

        document.querySelectorAll('.save-text-btn').forEach(button => {
            button.addEventListener('click', (e) => {
                this.saveScrollText(e.target.getAttribute('data-target'));
            });
        });
    }

    updateColorDisplay(slider) {
        const value = parseInt(slider.value);
        const color = C64_COLORS[value];
        const displayEl = document.getElementById(`${slider.id}-display`);

        if (displayEl) {
            displayEl.innerHTML = `
            <span class="color-swatch" style="background: ${color.hex}"></span>
            <span class="color-text">
                <span class="color-number">${value}</span>: 
                <span class="color-name">${color.name}</span>
            </span>
        `;
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

        // Always show modified memory count - add this here
        this.updateModifiedMemoryCount();
    }

    // Add this new method after updateTechnicalInfo:
    updateModifiedMemoryCount() {
        const allModified = this.analysisResults?.modifiedAddresses || [];

        // Apply the same filtering as save/restore routines
        const filtered = allModified.filter(addr => {
            if (addr >= 0x0100 && addr <= 0x01FF) return false; // Stack
            if (addr >= 0xD400 && addr <= 0xD7FF) return false; // SID I/O
            return true;
        });

        const modifiedCount = filtered.length;

        // Check if the row already exists
        let modifiedRow = document.getElementById('modifiedMemoryRow');
        if (!modifiedRow) {
            // Create the row if it doesn't exist
            const infoPanels = document.getElementById('infoPanels');
            const technicalPanel = infoPanels.querySelector('.panel:nth-child(2)'); // Technical Details panel

            modifiedRow = document.createElement('div');
            modifiedRow.id = 'modifiedMemoryRow';
            modifiedRow.className = 'info-row';
            modifiedRow.innerHTML = `
            <span class="info-label">Modified Memory:</span>
            <span class="info-value" id="modifiedMemoryCount">-</span>
        `;

            // Insert before Clock Type row (which is third from last)
            const clockRow = technicalPanel.querySelector('#clockType').closest('.info-row');
            technicalPanel.insertBefore(modifiedRow, clockRow);
        }

        // Update the value
        const countElement = document.getElementById('modifiedMemoryCount');
        if (modifiedCount === 0) {
            countElement.textContent = 'None';
        } else if (modifiedCount === 1) {
            countElement.textContent = '1 location';
        } else {
            countElement.textContent = `${modifiedCount} locations`;
        }
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

    updateNumCallsPerFrame(numCalls) {
        const element = document.getElementById('numCallsPerFrame');
        if (element) {
            element.textContent = numCalls || '1';
        }
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

        // Get the selected memory layout
        const layoutRadio = document.querySelector('input[name="memory-layout"]:checked');
        const selectedLayoutKey = layoutRadio ? layoutRadio.value : null;

        if (!selectedLayoutKey && this.selectedVisualizer.config) {
            // If visualizer has layouts but none selected
            this.showExportStatus('Please select a memory layout', 'error');
            return;
        }

        // Get the selected compression type from radio buttons
        const compressionRadio = document.querySelector('input[name="compression-type"]:checked');
        const compressionType = compressionRadio ? compressionRadio.value : 'tscrunch';

        this.showExportStatus('Building PRG file...', 'info');

        // Get the selected song (default to startSong if selector doesn't exist)
        const songSelector = document.getElementById('songSelector');
        const selectedSong = songSelector ? parseInt(songSelector.value) : this.sidHeader.startSong;

        try {
            const baseName = this.currentFileName ?
                this.currentFileName.replace('.sid', '') : 'output';

            // Load the visualizer config to get the SYS address
            const vizConfig = await this.visualizerConfig.loadConfig(this.selectedVisualizer.id);
            let visualizerSysAddress = 0x4100; // default fallback

            if (selectedLayoutKey && vizConfig && vizConfig.layouts[selectedLayoutKey]) {
                const layout = vizConfig.layouts[selectedLayoutKey];
                // Use sysAddress if available, otherwise fall back to baseAddress + 0x100
                if (layout.sysAddress) {
                    visualizerSysAddress = parseInt(layout.sysAddress);
                } else if (layout.baseAddress) {
                    visualizerSysAddress = parseInt(layout.baseAddress) + 0x100;
                }
            }

            const options = {
                sidLoadAddress: this.sidHeader.loadAddress,
                sidInitAddress: this.sidHeader.initAddress,
                sidPlayAddress: this.sidHeader.playAddress,
                visualizerFile: this.selectedVisualizer.binary,
                visualizerLoadAddress: visualizerSysAddress,  // Use the actual address
                compressionType: compressionType,
                visualizerId: this.selectedVisualizer.id,
                selectedSong: selectedSong - 1,
                layoutKey: selectedLayoutKey
            };

            const prgData = await this.prgExporter.createPRG(options);

            // Generate filename based on compression
            const isCompressed = compressionType !== 'none';
            let filename;

            if (isCompressed) {
                // Compressed: just songname.prg
                filename = `${baseName}.prg`;
            } else {
                // Uncompressed: songname-sys{decimal_address}.prg
                filename = `${baseName}-sys${visualizerSysAddress}.prg`;
            }

            this.downloadFile(prgData, filename);

            const sizeKB = (prgData.length / 1024).toFixed(2);
            let statusMsg = `PRG exported successfully! Size: ${sizeKB}KB`;

            if (compressionType !== 'none') {
                statusMsg += ` (${compressionType.toUpperCase()} compressed)`;
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

    formatDateForDisplay(dateString) {
        if (!dateString) return 'Not Set';

        const date = new Date(dateString);
        const months = ['January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'];

        const day = date.getDate();
        const month = months[date.getMonth()];
        const year = date.getFullYear();

        // Add ordinal suffix
        const suffix = this.getOrdinalSuffix(day);

        return `${day}${suffix} ${month} ${year}`;
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

        // Don't hide sections, just disable them
        this.elements.songTitleSection.classList.remove('visible');
        this.elements.songTitleSection.classList.add('disabled');

        if (this.elements.exportSection) {
            this.elements.exportSection.classList.remove('visible');
            this.elements.exportSection.classList.add('disabled');
        }

        if (this.elements.infoSection) {
            this.elements.infoSection.classList.remove('visible');
            this.elements.infoSection.classList.add('disabled');
        }

        // Reset to attract mode
        this.initializeAttractMode();
    }

    loadScrollText(textareaId) {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = '.txt';

        input.onchange = (e) => {
            const file = e.target.files[0];
            if (file) {
                const reader = new FileReader();
                reader.onload = (e) => {
                    const textarea = document.getElementById(textareaId);
                    if (textarea) {
                        textarea.value = e.target.result;
                    }
                };
                reader.readAsText(file);
            }
        };

        input.click();
    }

    saveScrollText(textareaId) {
        const textarea = document.getElementById(textareaId);
        if (!textarea) return;

        const text = textarea.value;
        const blob = new Blob([text], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);

        const a = document.createElement('a');
        a.href = url;
        a.download = 'scrolltext.txt';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
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