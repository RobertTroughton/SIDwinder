// ui.js - UI Controller for SIDwinder Web

class UIController {
    constructor() {
        this.analyzer = new SIDAnalyzer();
        this.currentFileName = null;
        this.hasModifications = false;
        this.analysisResults = null;
        this.elements = this.cacheElements();
        this.initEventListeners();
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
            sidModel: document.getElementById('sidModel')
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

        // Save button
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

            // Update UI with analysis results
            this.updateConsole(this.analysisResults);
            this.updateZeroPageInfo(this.analysisResults.zpAddresses);

            // Show panels
            this.elements.infoPanels.classList.add('visible');
            this.elements.songTitleSection.classList.add('visible');
            this.elements.consoleSection.classList.add('visible');

            this.showModal(`Successfully analyzed: ${file.name}`, true);

        } catch (error) {
            this.showModal(`Error: ${error.message}`, false);
            console.error(error);
        } finally {
            this.showLoading(false);
            this.elements.progressBar.classList.remove('active');
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

    saveSID() {
        const modifiedData = this.analyzer.createModifiedSID();

        if (!modifiedData) {
            this.showModal('Failed to create modified SID', false);
            return;
        }

        // Create blob and download
        const blob = new Blob([modifiedData], { type: 'application/octet-stream' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');

        const baseName = this.currentFileName ?
            this.currentFileName.replace('.sid', '') : 'modified';
        a.href = url;
        a.download = `${baseName}_edited.sid`;

        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

        this.showModal('SID file saved successfully!', true);
        this.hasModifications = false;
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
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    new UIController();
});