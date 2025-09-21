// image-preview-manager.js - Enhanced image preview system with modal gallery
// Replaces file buttons with clickable image previews and modal gallery selection

class GalleryModal {
    constructor() {
        this.modal = null;
        this.currentConfig = null;
        this.currentContainer = null;
        this.selectedItem = null;
        this.initialized = false;
    }

    init() {
        if (this.initialized) return;

        this.modal = document.getElementById('galleryModal');
        if (!this.modal) {
            console.warn('Gallery modal element not found in DOM');
            return;
        }

        const closeBtn = document.getElementById('galleryModalClose');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => this.close());
        }

        // Close on escape key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.modal && this.modal.classList.contains('visible')) {
                this.close();
            }
        });

        // Close on click outside
        this.modal.addEventListener('click', (e) => {
            if (e.target === this.modal) {
                this.close();
            }
        });

        this.initialized = true;
    }

    open(config, container) {
        if (!this.initialized) this.init();
        if (!this.modal) return;

        this.currentConfig = config;
        this.currentContainer = container;
        this.selectedItem = null;

        // Set subtitle
        const subtitle = document.getElementById('gallerySubtitle');
        if (subtitle) {
            subtitle.textContent = `Select ${config.label || 'an image'}`;
        }

        // Build gallery grid
        this.buildGallery(config.gallery);

        // Show modal
        this.modal.classList.add('visible');
    }

    buildGallery(galleryItems) {
        const gridContainer = document.getElementById('galleryGridContainer');
        if (!gridContainer) return;

        gridContainer.innerHTML = '';

        if (!galleryItems || galleryItems.length === 0) {
            gridContainer.innerHTML = '<div class="gallery-loading">No images available</div>';
            this.updateItemCount(0);
            return;
        }

        galleryItems.forEach((item, index) => {
            const card = document.createElement('div');
            card.className = 'gallery-item-card';
            card.dataset.file = item.file;
            card.dataset.name = item.name;
            card.dataset.index = index;

            card.innerHTML = `
                <div class="gallery-item-preview">
                    <img src="${item.file}" alt="${item.name}" />
                </div>
                <div class="gallery-item-info">
                    <div class="gallery-item-name">${item.name}</div>
                </div>
                <div class="gallery-item-selected-badge">✓ Selected</div>
            `;

            card.addEventListener('click', () => this.selectItem(card, item));
            gridContainer.appendChild(card);
        });

        this.updateItemCount(galleryItems.length);
    }

    selectItem(card, item) {
        // Clear previous selection
        document.querySelectorAll('.gallery-item-card').forEach(c => {
            c.classList.remove('selected');
        });

        // Mark as selected
        card.classList.add('selected');
        this.selectedItem = item;

        // Apply selection after a brief delay for visual feedback
        setTimeout(() => {
            this.applySelection(item);
            this.close();
        }, 200);
    }

    async applySelection(item) {
        if (!this.currentContainer || !this.currentConfig) return;

        // This calls the existing loadGalleryImage method from ImagePreviewManager
        if (window.imagePreviewManager) {
            await window.imagePreviewManager.loadGalleryImage(
                this.currentContainer,
                this.currentConfig,
                item.file,
                item.name
            );
        }
    }

    updateItemCount(count) {
        const countElement = document.getElementById('galleryItemCount');
        if (countElement) {
            countElement.textContent = `${count} image${count !== 1 ? 's' : ''}`;
        }
    }

    close() {
        if (this.modal) {
            this.modal.classList.remove('visible');
        }
        this.currentConfig = null;
        this.currentContainer = null;
        this.selectedItem = null;
    }
}

class ImagePreviewManager {
    constructor() {
        this.previewCache = new Map();
        this.defaultImages = new Map();
        this.loadingPromises = new Map();
        this.galleryModal = null;
    }

    // Initialize gallery modal on first use
    initGalleryModal() {
        if (!this.galleryModal) {
            this.galleryModal = new GalleryModal();
            this.galleryModal.init();
        }
        return this.galleryModal;
    }

    // Create a preview element for an image input
    createImagePreview(config) {
        const container = document.createElement('div');
        container.className = 'image-preview-container';

        const hasGallery = config.gallery && config.gallery.length > 0;

        container.innerHTML = `
            <div class="image-preview-wrapper ${hasGallery ? 'with-gallery' : ''}" data-input-id="${config.id}">
                <div class="image-preview-drop-zone">
                    <div class="image-preview-frame">
                        <img class="image-preview-img" 
                             src="" 
                             alt="${config.label} preview"
                             width="320" 
                             height="200">
                        <div class="image-preview-overlay">
                            <div class="preview-overlay-content">
                                <i class="fas fa-upload"></i>
                                <div class="preview-click-hint">Click to browse or drag image here</div>
                            </div>
                        </div>
                        <div class="image-preview-loading">
                            <div class="preview-spinner"></div>
                            <div>Loading...</div>
                        </div>
                    </div>
                    <div class="image-preview-info">
                        <span class="preview-filename">Loading default...</span>
                        <span class="preview-size"></span>
                    </div>
                </div>
                ${hasGallery ? `
                    <div class="image-gallery-toggle">
                        <button type="button" class="gallery-btn">
                            <i class="fas fa-images"></i>
                            Choose from Gallery
                        </button>
                    </div>
                ` : ''}
            </div>
            <input type="file" 
                   id="${config.id}" 
                   accept="${config.accept}" 
                   style="display: none;">
        `;

        this.attachDragDropHandlers(container, config);
        this.attachGalleryHandlers(container, config);

        // Set up click handler
        const wrapper = container.querySelector('.image-preview-wrapper');
        const fileInput = container.querySelector('input[type="file"]');

        const previewFrame = wrapper.querySelector('.image-preview-frame');
        previewFrame.addEventListener('click', () => {
            fileInput.click();
        });

        // Set up file change handler
        fileInput.addEventListener('change', (e) => {
            this.handleFileChange(e, config);
        });

        return container;
    }

    attachDragDropHandlers(container, config) {
        const dropZone = container.querySelector('.image-preview-drop-zone');

        ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
            dropZone.addEventListener(eventName, (e) => {
                e.preventDefault();
                e.stopPropagation();
            });
        });

        ['dragenter', 'dragover'].forEach(eventName => {
            dropZone.addEventListener(eventName, () => {
                dropZone.classList.add('drag-active');
            });
        });

        ['dragleave', 'drop'].forEach(eventName => {
            dropZone.addEventListener(eventName, () => {
                dropZone.classList.remove('drag-active');
            });
        });

        dropZone.addEventListener('drop', (e) => {
            const files = e.dataTransfer.files;
            if (files.length > 0) {
                const file = files[0];
                if (this.isValidImageFile(file, config)) {
                    const fileInput = container.querySelector(`#${config.id}`);
                    if (fileInput) {
                        delete fileInput.dataset.gallerySelected;
                        delete fileInput.dataset.galleryFile;
                    }
                    this.handleFileChange({ target: { files: [file] } }, config);
                } else {
                    this.showError(container, 'Please drop a valid image file');
                }
            }
        });
    }

    attachGalleryHandlers(container, config) {
        const toggleBtn = container.querySelector('.gallery-btn');

        if (toggleBtn && config.gallery && config.gallery.length > 0) {
            toggleBtn.addEventListener('click', () => {
                const modal = this.initGalleryModal();
                modal.open(config, container);
            });
        }
    }

    // Check if file is valid based on config
    isValidImageFile(file, config) {
        if (!config.accept) return true;

        const acceptTypes = config.accept.split(',').map(t => t.trim());

        // Check MIME type
        for (const acceptType of acceptTypes) {
            if (acceptType.startsWith('.')) {
                // Extension check
                if (file.name.toLowerCase().endsWith(acceptType.toLowerCase())) {
                    return true;
                }
            } else if (acceptType.includes('*')) {
                // Wildcard MIME type (e.g., image/*)
                const [type, subtype] = acceptType.split('/');
                if (file.type.startsWith(type + '/')) {
                    return true;
                }
            } else if (file.type === acceptType) {
                // Exact MIME type match
                return true;
            }
        }

        return false;
    }

    // Show error message (implement as needed)
    showError(container, message) {
        console.error(message);
        // Could add visual error feedback here
    }

    // Load and display default image
    async loadDefaultImage(config) {
        const wrapper = document.querySelector(`[data-input-id="${config.id}"]`);
        if (!wrapper) return;

        const img = wrapper.querySelector('.image-preview-img');
        const info = wrapper.querySelector('.preview-filename');
        const sizeInfo = wrapper.querySelector('.preview-size');
        const loadingDiv = wrapper.querySelector('.image-preview-loading');

        try {
            loadingDiv.style.display = 'flex';

            if (config.default) {
                // Check cache first
                if (this.previewCache.has(config.default)) {
                    const cached = this.previewCache.get(config.default);
                    img.src = cached.dataUrl;
                    info.textContent = `Default: ${config.default.split('/').pop()}`;
                    sizeInfo.textContent = cached.sizeText;
                    loadingDiv.style.display = 'none';
                    return;
                }

                // Load the default file
                const fileData = await this.loadDefaultFile(config.default);

                // Check if it's a PNG file
                if (config.default.toLowerCase().endsWith('.png') && this.isPNGFile(fileData)) {
                    // Create preview from PNG data directly
                    const preview = await this.createPreviewFromPNGData(fileData);
                    this.previewCache.set(config.default, preview);

                    img.src = preview.dataUrl;
                    info.textContent = `Default: ${config.default.split('/').pop()}`;
                    sizeInfo.textContent = preview.sizeText;
                } else {
                    // Handle other file types
                    const preview = await this.createPreviewFromData(fileData, config.default);
                    this.previewCache.set(config.default, preview);

                    img.src = preview.dataUrl;
                    info.textContent = `Default: ${config.default.split('/').pop()}`;
                    sizeInfo.textContent = preview.sizeText;
                }
            }
        } catch (error) {
            console.error('Error loading default image:', error);
            info.textContent = 'Error loading default';
            sizeInfo.textContent = '';
            this.showErrorPlaceholder(img);
        } finally {
            loadingDiv.style.display = 'none';
        }
    }

    async loadGalleryImage(container, config, filename, name) {
        const wrapper = container.querySelector(`[data-input-id="${config.id}"]`);
        if (!wrapper) return;

        const img = wrapper.querySelector('.image-preview-img');
        const info = wrapper.querySelector('.preview-filename');
        const sizeInfo = wrapper.querySelector('.preview-size');
        const loadingDiv = wrapper.querySelector('.image-preview-loading');

        try {
            loadingDiv.style.display = 'flex';

            // Load the gallery file
            const response = await fetch(filename);
            if (!response.ok) {
                throw new Error(`Failed to load gallery image: ${filename}`);
            }

            const arrayBuffer = await response.arrayBuffer();
            const fileData = new Uint8Array(arrayBuffer);

            // Check if it's a PNG file
            if (filename.toLowerCase().endsWith('.png') && this.isPNGFile(fileData)) {
                const preview = await this.createPreviewFromPNGData(fileData);

                img.src = preview.dataUrl;
                info.textContent = name;
                sizeInfo.textContent = preview.sizeText;

                // Store this selection in the file input for later processing
                const blob = new Blob([fileData], { type: 'image/png' });
                const file = new File([blob], name + '.png', { type: 'image/png' });

                // Store the file in the input element using DataTransfer
                const dataTransfer = new DataTransfer();
                dataTransfer.items.add(file);
                const fileInput = container.querySelector(`#${config.id}`);
                if (fileInput) {
                    fileInput.files = dataTransfer.files;
                    fileInput.dataset.gallerySelected = 'true';
                    fileInput.dataset.galleryFile = filename;
                }
            } else {
                const preview = await this.createPreviewFromData(fileData, name);

                img.src = preview.dataUrl;
                info.textContent = name;
                sizeInfo.textContent = preview.sizeText;

                // Store the file data for non-PNG files too
                const blob = new Blob([fileData], { type: 'application/octet-stream' });
                const file = new File([blob], name, { type: 'application/octet-stream' });

                const dataTransfer = new DataTransfer();
                dataTransfer.items.add(file);
                const fileInput = container.querySelector(`#${config.id}`);
                if (fileInput) {
                    fileInput.files = dataTransfer.files;
                }
            }

        } catch (error) {
            console.error('Error loading gallery image:', error);
            info.textContent = `Error: ${name}`;
            sizeInfo.textContent = error.message;
            this.showErrorPlaceholder(img);
        } finally {
            loadingDiv.style.display = 'none';
        }
    }

    // Rest of the existing methods remain the same...
    async loadDefaultFile(defaultPath) {
        if (!window.currentVisualizerConfig) {
            window.currentVisualizerConfig = new VisualizerConfig();
        }
        return await window.currentVisualizerConfig.loadDefaultFile(defaultPath);
    }

    async handleFileChange(event, config) {
        const file = event.target.files[0];

        const fileInput = event.target;
        if (fileInput) {
            delete fileInput.dataset.gallerySelected;
            delete fileInput.dataset.galleryFile;
        }

        const wrapper = document.querySelector(`[data-input-id="${config.id}"]`);
        if (!wrapper) return;

        const img = wrapper.querySelector('.image-preview-img');
        const info = wrapper.querySelector('.preview-filename');
        const sizeInfo = wrapper.querySelector('.preview-size');
        const loadingDiv = wrapper.querySelector('.image-preview-loading');

        if (!file) return;

        try {
            loadingDiv.style.display = 'flex';

            let previewData;

            if (file.type === 'image/png') {
                previewData = await this.createPreviewFromPNG(file);
            }

            img.src = previewData.dataUrl;
            info.textContent = file.name;
            sizeInfo.textContent = previewData.sizeText;

        } catch (error) {
            console.error('Error processing file:', error);
            info.textContent = `Error: ${file.name}`;
            sizeInfo.textContent = error.message;
            this.showErrorPlaceholder(img);
        } finally {
            loadingDiv.style.display = 'none';
        }
    }

    async createPreviewFromPNG(file) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');

            img.onload = () => {
                canvas.width = 320;
                canvas.height = 200;

                ctx.imageSmoothingEnabled = false;
                ctx.drawImage(img, 0, 0, 320, 200);

                const dataUrl = canvas.toDataURL();

                resolve({
                    dataUrl: dataUrl,
                    sizeText: `${(file.size / 1024).toFixed(1)}KB (PNG)`
                });
            };

            img.onerror = () => {
                reject(new Error('Invalid PNG file'));
            };

            const objectUrl = URL.createObjectURL(file);
            img.src = objectUrl;

            img.addEventListener('load', () => {
                URL.revokeObjectURL(objectUrl);
            }, { once: true });
        });
    }

    async createPreviewFromPNGData(pngData) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');

            img.onload = () => {
                canvas.width = 320;
                canvas.height = 200;

                ctx.imageSmoothingEnabled = false;
                ctx.drawImage(img, 0, 0, 320, 200);

                const dataUrl = canvas.toDataURL();

                URL.revokeObjectURL(img.src);

                resolve({
                    dataUrl: dataUrl,
                    sizeText: `${(pngData.length / 1024).toFixed(1)}KB (PNG)`
                });
            };

            img.onerror = () => {
                URL.revokeObjectURL(img.src);
                reject(new Error('Invalid PNG data'));
            };

            const blob = new Blob([pngData], { type: 'image/png' });
            const blobUrl = URL.createObjectURL(blob);
            img.src = blobUrl;
        });
    }

    // Create preview from binary data
    async createPreviewFromData(data, filename) {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = 320;
        canvas.height = 200;

        this.renderBinaryPlaceholder(ctx, filename);

        return {
            dataUrl: canvas.toDataURL(),
            sizeText: `${(data.length / 1024).toFixed(1)}KB (Binary)`
        };
    }

    isPNGFile(data) {
        if (data.length < 8) return false;
        return data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4E && data[3] === 0x47 &&
            data[4] === 0x0D && data[5] === 0x0A && data[6] === 0x1A && data[7] === 0x0A;
    }

    renderBinaryPlaceholder(ctx, filename) {
        ctx.fillStyle = '#222';
        ctx.fillRect(0, 0, 320, 200);

        ctx.strokeStyle = '#444';
        ctx.lineWidth = 1;
        for (let i = 0; i < 320; i += 16) {
            ctx.beginPath();
            ctx.moveTo(i, 0);
            ctx.lineTo(i, 200);
            ctx.stroke();
        }
        for (let i = 0; i < 200; i += 16) {
            ctx.beginPath();
            ctx.moveTo(0, i);
            ctx.lineTo(320, i);
            ctx.stroke();
        }

        ctx.fillStyle = '#888';
        ctx.font = '16px monospace';
        ctx.textAlign = 'center';
        ctx.fillText('BINARY FILE', 160, 90);

        ctx.font = '12px monospace';
        const shortName = filename.length > 25 ? filename.substring(0, 22) + '...' : filename;
        ctx.fillText(shortName, 160, 110);
    }

    getFileType(data) {
        if (this.isPNGFile(data)) {
            return 'PNG';
        }
        return 'Binary';
    }

    showErrorPlaceholder(img) {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = 320;
        canvas.height = 200;

        ctx.fillStyle = '#400';
        ctx.fillRect(0, 0, 320, 200);

        ctx.fillStyle = '#fff';
        ctx.font = '16px monospace';
        ctx.textAlign = 'center';
        ctx.fillText('ERROR', 160, 90);
        ctx.font = '12px monospace';
        ctx.fillText('Unable to load image', 160, 110);

        img.src = canvas.toDataURL();
    }
}

// Export the manager and make it available globally
window.ImagePreviewManager = ImagePreviewManager;
// Create a global instance for convenience
window.imagePreviewManager = new ImagePreviewManager();