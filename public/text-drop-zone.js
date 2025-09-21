class TextDropZone {
    static create(textareaId, config = {}) {
        const textarea = document.getElementById(textareaId);
        if (!textarea) return;

        // Create drop zone wrapper
        const wrapper = document.createElement('div');
        wrapper.className = 'text-drop-zone';
        textarea.parentNode.insertBefore(wrapper, textarea);
        wrapper.appendChild(textarea);

        // Add drop indicator
        const dropIndicator = document.createElement('div');
        dropIndicator.className = 'text-drop-indicator';
        dropIndicator.innerHTML = '<i class="fas fa-file-alt"></i> Drop text file here';
        wrapper.appendChild(dropIndicator);

        // Add persistent hint about drag-drop
        const dropHint = document.createElement('div');
        dropHint.className = 'text-drop-hint';
        dropHint.innerHTML = '<i class="fas fa-upload"></i> Drag & drop .txt file or type below';
        wrapper.insertBefore(dropHint, textarea);

        // Make scrolltext boxes taller
        if (textareaId.toLowerCase().includes('scroll')) {
            textarea.rows = 6; // Double the default height
        }

        // Drag and drop handlers
        this.attachDragDrop(wrapper, textarea);
    }

    static attachDragDrop(wrapper, textarea) {
        ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
            wrapper.addEventListener(eventName, (e) => {
                e.preventDefault();
                e.stopPropagation();
            });
        });

        ['dragenter', 'dragover'].forEach(eventName => {
            wrapper.addEventListener(eventName, () => {
                wrapper.classList.add('drag-active');
            });
        });

        ['dragleave', 'drop'].forEach(eventName => {
            wrapper.addEventListener(eventName, () => {
                wrapper.classList.remove('drag-active');
            });
        });

        wrapper.addEventListener('drop', async (e) => {
            const file = e.dataTransfer.files[0];
            if (file && (file.type.startsWith('text/') || file.name.endsWith('.txt'))) {
                const text = await file.text();
                textarea.value = text;
                textarea.dispatchEvent(new Event('change'));
            }
        });
    }
}

window.TextDropZone = TextDropZone;