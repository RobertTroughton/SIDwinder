// image-preview-manager.js - Enhanced image preview system for SIDwinder
// Replaces file buttons with clickable image previews

class ImagePreviewManager {
    constructor() {
        this.previewCache = new Map();
        this.defaultImages = new Map();
        this.loadingPromises = new Map();
    }

    // Create a preview element for an image input
    createImagePreview(config) {
        const container = document.createElement('div');
        container.className = 'image-preview-container';
        container.innerHTML = `
            <div class="image-preview-wrapper" data-input-id="${config.id}">
                <div class="image-preview-frame">
                    <img class="image-preview-img" 
                         src="" 
                         alt="${config.label} preview"
                         width="320" 
                         height="200">
                    <div class="image-preview-overlay">
                        <div class="preview-click-hint">Click to change image</div>
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
            <input type="file" 
                   id="${config.id}" 
                   accept="${config.accept}" 
                   style="display: none;">
        `;

        // Set up click handler
        const wrapper = container.querySelector('.image-preview-wrapper');
        const fileInput = container.querySelector('input[type="file"]');

        wrapper.addEventListener('click', () => {
            fileInput.click();
        });

        // Set up file change handler
        fileInput.addEventListener('change', (e) => {
            this.handleFileChange(e, config);
        });

        return container;
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
            // Show loading state
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

                // Check if we're already loading this image
                if (this.loadingPromises.has(config.default)) {
                    await this.loadingPromises.get(config.default);
                    return;
                }

                // Load the default file
                const loadPromise = this.loadDefaultFile(config.default);
                this.loadingPromises.set(config.default, loadPromise);

                const fileData = await loadPromise;
                const preview = await this.createPreviewFromData(fileData, config.default);

                // Cache the preview
                this.previewCache.set(config.default, preview);

                img.src = preview.dataUrl;
                info.textContent = `Default: ${config.default.split('/').pop()}`;
                sizeInfo.textContent = preview.sizeText;

                // Clean up loading promise
                this.loadingPromises.delete(config.default);
            }
        } catch (error) {
            console.error('Error loading default image:', error);
            info.textContent = 'Error loading default';
            sizeInfo.textContent = '';

            // Show a placeholder error image
            this.showErrorPlaceholder(img);
        } finally {
            loadingDiv.style.display = 'none';
        }
    }

    // Load default file using VisualizerConfig
    async loadDefaultFile(defaultPath) {
        if (!window.currentVisualizerConfig) {
            window.currentVisualizerConfig = new VisualizerConfig();
        }
        return await window.currentVisualizerConfig.loadDefaultFile(defaultPath);
    }

    // Handle file selection
    async handleFileChange(event, config) {
        const file = event.target.files[0];
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
                // Handle PNG files
                previewData = await this.createPreviewFromPNG(file);
            } else {
                // Handle binary files (like .koa)
                const arrayBuffer = await file.arrayBuffer();
                const fileData = new Uint8Array(arrayBuffer);
                previewData = await this.createPreviewFromData(fileData, file.name);
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

    // Create preview from PNG file
    async createPreviewFromPNG(file) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');

            img.onload = () => {
                // Set canvas to C64 resolution
                canvas.width = 320;
                canvas.height = 200;

                // Draw and scale the image
                ctx.imageSmoothingEnabled = false;
                ctx.drawImage(img, 0, 0, 320, 200);

                // Get the data URL for preview
                const dataUrl = canvas.toDataURL();

                resolve({
                    dataUrl: dataUrl,
                    sizeText: `${(file.size / 1024).toFixed(1)}KB (PNG)`
                });
            };

            img.onerror = () => {
                reject(new Error('Invalid PNG file'));
            };

            // Create object URL for the image
            const objectUrl = URL.createObjectURL(file);
            img.src = objectUrl;

            // Clean up object URL after loading
            const originalOnLoad = img.onload;
            img.onload = () => {
                URL.revokeObjectURL(objectUrl);
                originalOnLoad();
            };
        });
    }

    // Create preview from binary data (like .koa files)
    async createPreviewFromData(fileData, filename) {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = 320;
        canvas.height = 200;

        try {
            // Check if this looks like a Koala file
            if (this.isKoalaFile(fileData)) {
                await this.renderKoalaPreview(ctx, fileData);
            } else {
                // Show a generic binary file placeholder
                this.renderBinaryPlaceholder(ctx, filename);
            }
        } catch (error) {
            console.error('Error rendering preview:', error);
            this.renderBinaryPlaceholder(ctx, filename);
        }

        return {
            dataUrl: canvas.toDataURL(),
            sizeText: `${(fileData.length / 1024).toFixed(1)}KB (${this.getFileType(fileData)})`
        };
    }

    // Check if binary data is a Koala file
    isKoalaFile(data) {
        return data.length === 10003 && data[0] === 0x00 && data[1] === 0x60;
    }

    // Render Koala file as preview image
    async renderKoalaPreview(ctx, koalaData) {
        // C64 color palette (same as in png_converter.cpp)
        const palette = [
            [0x00, 0x00, 0x00], // Black
            [0xFF, 0xFF, 0xFF], // White  
            [0x75, 0x3D, 0x3D], // Red
            [0x7B, 0xB4, 0xB4], // Cyan
            [0x7D, 0x44, 0x88], // Purple
            [0x5C, 0x98, 0x5C], // Green
            [0x34, 0x33, 0x83], // Blue
            [0xCB, 0xCC, 0x7C], // Yellow
            [0x7C, 0x55, 0x2F], // Orange
            [0x52, 0x3E, 0x00], // Brown
            [0xA7, 0x6F, 0x6F], // Light Red
            [0x4E, 0x4E, 0x4E], // Dark Grey
            [0x76, 0x76, 0x76], // Grey
            [0x9F, 0xDB, 0x9F], // Light Green
            [0x6D, 0x6C, 0xBC], // Light Blue
            [0xA3, 0xA3, 0xA3]  // Light Grey
        ];

        // Extract data sections
        const mapData = koalaData.slice(2, 8002);      // Bitmap data
        const scrData = koalaData.slice(8002, 9002);   // Screen memory  
        const colData = koalaData.slice(9002, 10002);  // Color memory
        const bgColor = koalaData[10002];              // Background color

        // Render the bitmap
        const imageData = ctx.createImageData(320, 200);
        const pixels = imageData.data;

        for (let charY = 0; charY < 25; charY++) {
            for (let charX = 0; charX < 40; charX++) {
                const screenIndex = charY * 40 + charX;
                const scrByte = scrData[screenIndex];
                const colByte = colData[screenIndex];

                // Extract colors for this character cell
                const color1 = (scrByte >> 4) & 0x0F;
                const color2 = scrByte & 0x0F;
                const color3 = colByte & 0x0F;
                const colors = [bgColor, color1, color2, color3];

                // Render 8x8 character cell
                for (let y = 0; y < 8; y++) {
                    const bitmapIndex = screenIndex * 8 + y;
                    const bitmapByte = mapData[bitmapIndex];

                    for (let x = 0; x < 8; x += 2) {
                        const pixelX = charX * 8 + x;
                        const pixelY = charY * 8 + y;

                        // Extract 2-bit color index
                        const colorIndex = (bitmapByte >> (6 - x)) & 0x03;
                        const colorValue = colors[colorIndex] & 0x0F;
                        const rgb = palette[colorValue];

                        // Set both pixels in the pair (multicolor mode)
                        for (let px = 0; px < 2; px++) {
                            const finalX = pixelX + px;
                            if (finalX < 320 && pixelY < 200) {
                                const pixelIndex = (pixelY * 320 + finalX) * 4;
                                pixels[pixelIndex] = rgb[0];     // R
                                pixels[pixelIndex + 1] = rgb[1]; // G
                                pixels[pixelIndex + 2] = rgb[2]; // B
                                pixels[pixelIndex + 3] = 255;    // A
                            }
                        }
                    }
                }
            }
        }

        ctx.putImageData(imageData, 0, 0);
    }

    // Render placeholder for binary files
    renderBinaryPlaceholder(ctx, filename) {
        // Fill with a dark pattern
        ctx.fillStyle = '#222';
        ctx.fillRect(0, 0, 320, 200);

        // Add some pattern
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

        // Add text
        ctx.fillStyle = '#888';
        ctx.font = '16px monospace';
        ctx.textAlign = 'center';
        ctx.fillText('BINARY FILE', 160, 90);

        ctx.font = '12px monospace';
        const shortName = filename.length > 25 ? filename.substring(0, 22) + '...' : filename;
        ctx.fillText(shortName, 160, 110);
    }

    // Determine file type from data
    getFileType(data) {
        if (this.isKoalaFile(data)) {
            return 'Koala';
        }
        return 'Binary';
    }

    // Show error placeholder
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

// Note: CSS styles for image previews are included in styles.css

// Export the manager
window.ImagePreviewManager = ImagePreviewManager;