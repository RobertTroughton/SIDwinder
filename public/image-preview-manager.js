class ImageSelectorModal {
    constructor() {
        this.modal = null;
        this.currentConfig = null;
        this.currentContainer = null;
        this.dropZone = null;
        this.initialized = false;
    }

    init() {
        if (this.initialized) return;

        this.createModalHTML();
        this.attachEventListeners();
        this.initialized = true;
    }

    createModalHTML() {
        const modalHTML = `
            <div class="image-selector-modal" id="imageSelectorModal">
                <div class="image-selector-modal-content">
                    <button class="image-selector-modal-close" id="imageSelectorModalClose">✕</button>
                    <div class="image-selector-modal-body">
                        <h3 class="image-selector-title" id="imageSelectorTitle">Select Image</h3>
                        
                        <div class="image-selector-drop-zone" id="imageSelectorDropZone">
                            <i class="fas fa-cloud-upload-alt" style="font-size: 48px; color: #667eea; margin-bottom: 15px;"></i>
                            <div class="drop-zone-text">Drag and drop an image here</div>
                            <div class="drop-zone-subtext">or use the options below</div>
                        </div>

                        <div class="image-selector-options">
                            <button class="selector-option-btn" id="selectorBrowseBtn">
                                <i class="fas fa-folder-open"></i>
                                <span>Browse Files</span>
                            </button>
                            <button class="selector-option-btn" id="selectorGalleryBtn">
                                <i class="fas fa-images"></i>
                                <span>Choose from Gallery</span>
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        `;

        const tempDiv = document.createElement('div');
        tempDiv.innerHTML = modalHTML;
        document.body.appendChild(tempDiv.firstElementChild);

        this.modal = document.getElementById('imageSelectorModal');
        this.dropZone = document.getElementById('imageSelectorDropZone');
    }

    attachEventListeners() {
        const closeBtn = document.getElementById('imageSelectorModalClose');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => this.close());
        }

        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.modal && this.modal.classList.contains('visible')) {
                this.close();
            }
        });

        this.modal.addEventListener('click', (e) => {
            if (e.target === this.modal) {
                this.close();
            }
        });

        const browseBtn = document.getElementById('selectorBrowseBtn');
        if (browseBtn) {
            browseBtn.addEventListener('click', () => {
                this.handleBrowse();
            });
        }

        const galleryBtn = document.getElementById('selectorGalleryBtn');
        if (galleryBtn) {
            galleryBtn.addEventListener('click', () => {
                this.handleGallery();
            });
        }

        this.attachDropZoneHandlers();
    }

    attachDropZoneHandlers() {
        ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
            this.dropZone.addEventListener(eventName, (e) => {
                e.preventDefault();
                e.stopPropagation();
            });
        });

        ['dragenter', 'dragover'].forEach(eventName => {
            this.dropZone.addEventListener(eventName, () => {
                this.dropZone.classList.add('drag-active');
            });
        });

        ['dragleave', 'drop'].forEach(eventName => {
            this.dropZone.addEventListener(eventName, () => {
                this.dropZone.classList.remove('drag-active');
            });
        });

        this.dropZone.addEventListener('drop', (e) => {
            const files = e.dataTransfer.files;
            if (files.length > 0) {
                const file = files[0];
                if (this.isValidImageFile(file)) {
                    const fileInput = this.currentContainer.querySelector(`#${this.currentConfig.id}`);
                    if (fileInput) {
                        delete fileInput.dataset.gallerySelected;
                        delete fileInput.dataset.galleryFile;
                    }
                    window.imagePreviewManager.handleFileChange({ target: { files: [file] } }, this.currentConfig);
                    this.close();
                } else {
                    alert('Please drop a valid image file');
                }
            }
        });
    }

    isValidImageFile(file) {
        if (!this.currentConfig || !this.currentConfig.accept) return true;

        const acceptTypes = this.currentConfig.accept.split(',').map(t => t.trim());

        for (const acceptType of acceptTypes) {
            if (acceptType.startsWith('.')) {
                if (file.name.toLowerCase().endsWith(acceptType.toLowerCase())) {
                    return true;
                }
            } else if (acceptType.includes('*')) {
                const [type] = acceptType.split('/');
                if (file.type.startsWith(type + '/')) {
                    return true;
                }
            } else if (file.type === acceptType) {
                return true;
            }
        }

        return false;
    }

    open(config, container) {
        if (!this.initialized) this.init();
        if (!this.modal) return;

        this.currentConfig = config;
        this.currentContainer = container;

        const title = document.getElementById('imageSelectorTitle');
        if (title) {
            title.textContent = config.label || 'Select Image';
        }

        const galleryBtn = document.getElementById('selectorGalleryBtn');
        if (galleryBtn) {
            if (config.gallery && config.gallery.length > 0) {
                galleryBtn.style.display = 'flex';
            } else {
                galleryBtn.style.display = 'none';
            }
        }

        this.modal.classList.add('visible');
        document.body.style.overflow = 'hidden';
    }

    close() {
        if (this.modal) {
            this.modal.classList.remove('visible');
            document.body.style.overflow = '';
        }
    }

    handleBrowse() {
        const fileInput = this.currentContainer.querySelector(`#${this.currentConfig.id}`);
        if (fileInput) {
            fileInput.click();
            this.close();
        }
    }

    handleGallery() {
        this.close();
        const galleryModal = window.imagePreviewManager.initGalleryModal();
        galleryModal.open(this.currentConfig, this.currentContainer);
    }
}

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

        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.modal && this.modal.classList.contains('visible')) {
                this.close();
            }
        });

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

        const subtitle = document.getElementById('gallerySubtitle');
        if (subtitle) {
            subtitle.textContent = `Select ${config.label || 'an image'}`;
        }

        this.populateGallery(config.gallery);

        this.modal.classList.add('visible');
        document.body.style.overflow = 'hidden';
    }

    close() {
        if (this.modal) {
            this.modal.classList.remove('visible');
            document.body.style.overflow = '';
        }
    }

    populateGallery(gallery) {
        const gridContainer = document.getElementById('galleryGridContainer');
        const itemCount = document.getElementById('galleryItemCount');

        if (!gridContainer) return;

        gridContainer.innerHTML = '';

        if (!gallery || gallery.length === 0) {
            gridContainer.innerHTML = '<div class="gallery-loading">No images available</div>';
            if (itemCount) {
                itemCount.textContent = '0 items';
            }
            return;
        }

        gallery.forEach((item, index) => {
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

            card.addEventListener('click', () => {
                document.querySelectorAll('.gallery-item-card').forEach(c => {
                    c.classList.remove('selected');
                });
                card.classList.add('selected');
                this.selectedItem = item;

                setTimeout(() => {
                    this.selectImage();
                }, 200);
            });

            gridContainer.appendChild(card);
        });

        if (itemCount) {
            itemCount.textContent = `${gallery.length} ${gallery.length === 1 ? 'item' : 'items'}`;
        }
    }

    async selectImage() {
        if (!this.selectedItem) return;

        await window.imagePreviewManager.loadGalleryImage(
            this.currentContainer,
            this.currentConfig,
            this.selectedItem.file,
            this.selectedItem.name
        );

        this.close();
    }
}

class ImagePreviewManager {
    constructor() {
        this.previewCache = new Map();
        this.galleryModal = null;
        this.selectorModal = null;
    }

    initGalleryModal() {
        if (!this.galleryModal) {
            this.galleryModal = new GalleryModal();
            this.galleryModal.init();
        }
        return this.galleryModal;
    }

    initSelectorModal() {
        if (!this.selectorModal) {
            this.selectorModal = new ImageSelectorModal();
            this.selectorModal.init();
        }
        return this.selectorModal;
    }

    createImagePreview(config) {
        const container = document.createElement('div');
        container.className = 'image-preview-container';

        container.innerHTML = `
            <div class="image-preview-wrapper" data-input-id="${config.id}">
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
                                <div class="preview-click-hint">Click to select image</div>
                            </div>
                        </div>
                        <div class="image-preview-loading">
                            <div class="preview-spinner"></div>
                            <div>Loading...</div>
                        </div>
                    </div>
                </div>
            </div>
            <input type="file" 
                   id="${config.id}" 
                   accept="${config.accept}" 
                   style="display: none;">
        `;

        const wrapper = container.querySelector('.image-preview-wrapper');
        const fileInput = container.querySelector('input[type="file"]');
        const previewFrame = wrapper.querySelector('.image-preview-frame');

        previewFrame.addEventListener('click', () => {
            const modal = this.initSelectorModal();
            modal.open(config, container);
        });

        fileInput.addEventListener('change', (e) => {
            this.handleFileChange(e, config);
        });

        return container;
    }

    showError(container, message) {
        console.error(message);
    }

    async loadDefaultImage(config) {
        const wrapper = document.querySelector(`[data-input-id="${config.id}"]`);
        if (!wrapper) return;

        const img = wrapper.querySelector('.image-preview-img');
        const loadingDiv = wrapper.querySelector('.image-preview-loading');

        try {
            loadingDiv.style.display = 'flex';

            if (config.default) {
                if (this.previewCache.has(config.default)) {
                    const cached = this.previewCache.get(config.default);
                    img.src = cached.dataUrl;
                    loadingDiv.style.display = 'none';
                    return;
                }

                const fileData = await this.loadDefaultFile(config.default);

                if (config.default.toLowerCase().endsWith('.png') && this.isPNGFile(fileData)) {
                    const preview = await this.createPreviewFromPNGData(fileData);
                    this.previewCache.set(config.default, preview);
                    img.src = preview.dataUrl;
                } else {
                    const preview = await this.createPreviewFromData(fileData, config.default);
                    this.previewCache.set(config.default, preview);
                    img.src = preview.dataUrl;
                }
            }
        } catch (error) {
            console.error('Error loading default image:', error);
            this.showErrorPlaceholder(img);
        } finally {
            loadingDiv.style.display = 'none';
        }
    }

    async loadGalleryImage(container, config, filepath, name) {
        const wrapper = container.querySelector(`[data-input-id="${config.id}"]`);
        if (!wrapper) return;

        const img = wrapper.querySelector('.image-preview-img');
        const loadingDiv = wrapper.querySelector('.image-preview-loading');

        try {
            loadingDiv.style.display = 'flex';

            const response = await fetch(filepath);
            if (!response.ok) {
                throw new Error(`Failed to load gallery image: ${filepath}`);
            }

            const arrayBuffer = await response.arrayBuffer();
            const fileData = new Uint8Array(arrayBuffer);

            if (filepath.toLowerCase().endsWith('.png') && this.isPNGFile(fileData)) {
                const preview = await this.createPreviewFromPNGData(fileData);
                img.src = preview.dataUrl;

                const blob = new Blob([fileData], { type: 'image/png' });
                const file = new File([blob], name + '.png', { type: 'image/png' });

                const dataTransfer = new DataTransfer();
                dataTransfer.items.add(file);
                const fileInput = container.querySelector(`#${config.id}`);
                if (fileInput) {
                    fileInput.files = dataTransfer.files;
                    fileInput.dataset.gallerySelected = 'true';
                    fileInput.dataset.galleryFile = filepath;
                }
            } else {
                const preview = await this.createPreviewFromData(fileData, name);
                img.src = preview.dataUrl;

                const blob = new Blob([fileData], { type: 'image/png' });
                const file = new File([blob], name, { type: 'image/png' });

                const dataTransfer = new DataTransfer();
                dataTransfer.items.add(file);
                const fileInput = container.querySelector(`#${config.id}`);
                if (fileInput) {
                    fileInput.files = dataTransfer.files;
                    fileInput.dataset.gallerySelected = 'true';
                    fileInput.dataset.galleryFile = filepath;
                }
            }
        } catch (error) {
            console.error('Error loading gallery image:', error);
            this.showErrorPlaceholder(img);
        } finally {
            loadingDiv.style.display = 'none';
        }
    }

    async handleFileChange(e, config) {
        const files = e.target.files;
        if (!files || files.length === 0) return;

        const file = files[0];
        const wrapper = document.querySelector(`[data-input-id="${config.id}"]`);
        if (!wrapper) return;

        const img = wrapper.querySelector('.image-preview-img');
        const loadingDiv = wrapper.querySelector('.image-preview-loading');

        try {
            loadingDiv.style.display = 'flex';

            const fileData = await this.readFileAsArrayBuffer(file);

            if (file.name.toLowerCase().endsWith('.png') && this.isPNGFile(fileData)) {
                const preview = await this.createPreviewFromPNGData(fileData);
                img.src = preview.dataUrl;
            } else {
                const preview = await this.createPreviewFromData(fileData, file.name);
                img.src = preview.dataUrl;
            }

            if (config.onChange) {
                config.onChange(file);
            }
        } catch (error) {
            console.error('Error loading file:', error);
            this.showErrorPlaceholder(img);
        } finally {
            loadingDiv.style.display = 'none';
        }
    }

    readFileAsArrayBuffer(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = (e) => resolve(new Uint8Array(e.target.result));
            reader.onerror = reject;
            reader.readAsArrayBuffer(file);
        });
    }

    async loadDefaultFile(path) {
        const response = await fetch(path);
        if (!response.ok) {
            throw new Error(`Failed to load default file: ${path}`);
        }
        const arrayBuffer = await response.arrayBuffer();
        return new Uint8Array(arrayBuffer);
    }

    isPNGFile(data) {
        return data.length >= 8 &&
               data[0] === 0x89 && data[1] === 0x50 &&
               data[2] === 0x4E && data[3] === 0x47 &&
               data[4] === 0x0D && data[5] === 0x0A &&
               data[6] === 0x1A && data[7] === 0x0A;
    }

    async createPreviewFromPNGData(pngData) {
        return new Promise((resolve, reject) => {
            const blob = new Blob([pngData], { type: 'image/png' });
            const reader = new FileReader();
            
            reader.onload = (e) => {
                const dataUrl = e.target.result;
                resolve({
                    dataUrl: dataUrl,
                    sizeText: `${Math.round(pngData.length / 1024)}KB`
                });
            };
            
            reader.onerror = () => {
                reject(new Error('Failed to load PNG'));
            };
            
            reader.readAsDataURL(blob);
        });
    }

    async createPreviewFromData(data, filename) {
        return new Promise((resolve, reject) => {
            const blob = new Blob([data], { type: 'application/octet-stream' });
            const reader = new FileReader();
            
            reader.onload = (e) => {
                const dataUrl = e.target.result;
                resolve({
                    dataUrl: dataUrl,
                    sizeText: `${Math.round(data.length / 1024)}KB`
                });
            };
            
            reader.onerror = () => {
                reject(new Error('Failed to load image'));
            };
            
            reader.readAsDataURL(blob);
        });
    }

    showErrorPlaceholder(img) {
        img.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzIwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMzIwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iIzMzMyIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmaWxsPSIjNjY2IiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiIgZm9udC1zaXplPSIxNCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkVycm9yIGxvYWRpbmcgaW1hZ2U8L3RleHQ+PC9zdmc+';
    }
}
