// error-modal.js - Unified error handling system for SIDquake
// Provides consistent error, warning, success, and info modals throughout the application

class ErrorModal {
    constructor() {
        this.modalElement = null;
        this.timeoutId = null;
        this.initialized = false;
    }

    /**
     * Initialize the modal DOM elements
     */
    init() {
        if (this.initialized) return;

        // Check if modal already exists in DOM (from index.html)
        this.modalElement = document.getElementById('modalOverlay');

        if (!this.modalElement) {
            // Create modal if it doesn't exist
            this.createModalHTML();
        }

        this.initialized = true;
    }

    /**
     * Create modal HTML if not present in DOM
     */
    createModalHTML() {
        const modalHTML = `
            <div class="modal-overlay" id="modalOverlay">
                <div class="modal-content">
                    <div class="modal-icon" id="modalIcon"></div>
                    <div class="modal-title" id="modalTitle"></div>
                    <div class="modal-message" id="modalMessage"></div>
                    <div class="modal-details" id="modalDetails"></div>
                    <div class="modal-actions" id="modalActions"></div>
                </div>
            </div>
        `;

        const tempDiv = document.createElement('div');
        tempDiv.innerHTML = modalHTML;
        document.body.appendChild(tempDiv.firstElementChild);
        this.modalElement = document.getElementById('modalOverlay');
    }

    /**
     * Show an error message
     * @param {string} message - Primary error message
     * @param {Object} options - Optional configuration
     * @param {string} options.title - Error title
     * @param {string} options.details - Technical details (collapsible)
     * @param {number} options.duration - Auto-dismiss duration in ms (0 for manual)
     * @param {Array} options.actions - Array of {label, callback} for action buttons
     * @param {boolean} options.log - Whether to log to console (default: true)
     */
    error(message, options = {}) {
        const defaultOptions = {
            title: 'Error',
            icon: '\u2717', // X mark
            iconClass: 'error',
            duration: 0, // Errors require manual dismiss by default
            log: true,
            ...options
        };

        if (defaultOptions.log) {
            console.error(`[SIDquake Error] ${message}`, options.details || '');
        }

        this._show(message, defaultOptions);
    }

    /**
     * Show a warning message
     * @param {string} message - Warning message
     * @param {Object} options - Optional configuration
     */
    warning(message, options = {}) {
        const defaultOptions = {
            title: 'Warning',
            icon: '\u26A0', // Warning triangle
            iconClass: 'warning',
            duration: 4000,
            log: true,
            ...options
        };

        if (defaultOptions.log) {
            console.warn(`[SIDquake Warning] ${message}`);
        }

        this._show(message, defaultOptions);
    }

    /**
     * Show a success message
     * @param {string} message - Success message
     * @param {Object} options - Optional configuration
     */
    success(message, options = {}) {
        const defaultOptions = {
            title: '',
            icon: '\u2713', // Checkmark
            iconClass: 'success',
            duration: 2000,
            log: false,
            ...options
        };

        this._show(message, defaultOptions);
    }

    /**
     * Show an info message
     * @param {string} message - Info message
     * @param {Object} options - Optional configuration
     */
    info(message, options = {}) {
        const defaultOptions = {
            title: '',
            icon: '\u2139', // Info symbol
            iconClass: 'info',
            duration: 3000,
            log: false,
            ...options
        };

        this._show(message, defaultOptions);
    }

    /**
     * Show a confirmation dialog
     * @param {string} message - Confirmation message
     * @param {Object} options - Optional configuration
     * @returns {Promise<boolean>} - Resolves to true if confirmed, false if cancelled
     */
    confirm(message, options = {}) {
        return new Promise((resolve) => {
            const defaultOptions = {
                title: 'Confirm',
                icon: '?',
                iconClass: 'confirm',
                duration: 0,
                actions: [
                    { label: 'Cancel', callback: () => resolve(false), secondary: true },
                    { label: 'Confirm', callback: () => resolve(true) }
                ],
                ...options
            };

            this._show(message, defaultOptions);
        });
    }

    /**
     * Internal method to display the modal
     */
    _show(message, options) {
        if (!this.initialized) this.init();

        // Clear any existing timeout
        if (this.timeoutId) {
            clearTimeout(this.timeoutId);
            this.timeoutId = null;
        }

        const iconEl = document.getElementById('modalIcon');
        const titleEl = document.getElementById('modalTitle');
        const messageEl = document.getElementById('modalMessage');
        const detailsEl = document.getElementById('modalDetails');
        const actionsEl = document.getElementById('modalActions');

        // Set icon
        if (iconEl) {
            iconEl.textContent = options.icon || '';
            iconEl.className = `modal-icon ${options.iconClass || ''}`;
        }

        // Set title (optional)
        if (titleEl) {
            titleEl.textContent = options.title || '';
            titleEl.style.display = options.title ? 'block' : 'none';
        }

        // Set message
        if (messageEl) {
            messageEl.textContent = message;
        }

        // Set details (optional, collapsible for technical info)
        if (detailsEl) {
            if (options.details) {
                detailsEl.innerHTML = `
                    <details class="error-details">
                        <summary>Technical Details</summary>
                        <pre>${this._escapeHtml(options.details)}</pre>
                    </details>
                `;
                detailsEl.style.display = 'block';
            } else {
                detailsEl.innerHTML = '';
                detailsEl.style.display = 'none';
            }
        }

        // Set action buttons
        if (actionsEl) {
            actionsEl.innerHTML = '';

            if (options.actions && options.actions.length > 0) {
                options.actions.forEach(action => {
                    const btn = document.createElement('button');
                    btn.className = `modal-action-btn ${action.secondary ? 'secondary' : 'primary'}`;
                    btn.textContent = action.label;
                    btn.addEventListener('click', () => {
                        this.hide();
                        if (action.callback) action.callback();
                    });
                    actionsEl.appendChild(btn);
                });
                actionsEl.style.display = 'flex';
            } else if (options.duration === 0) {
                // Add dismiss button for manual-dismiss modals without actions
                const btn = document.createElement('button');
                btn.className = 'modal-action-btn primary';
                btn.textContent = 'OK';
                btn.addEventListener('click', () => this.hide());
                actionsEl.appendChild(btn);
                actionsEl.style.display = 'flex';
            } else {
                actionsEl.style.display = 'none';
            }
        }

        // Show modal
        this.modalElement.classList.add('visible');

        // Auto-dismiss if duration is set
        if (options.duration > 0) {
            this.timeoutId = setTimeout(() => {
                this.hide();
            }, options.duration);
        }

        // Add click-outside to dismiss (only for success/info messages)
        if (options.duration > 0) {
            const clickHandler = (e) => {
                if (e.target === this.modalElement) {
                    this.hide();
                    this.modalElement.removeEventListener('click', clickHandler);
                }
            };
            this.modalElement.addEventListener('click', clickHandler);
        }
    }

    /**
     * Hide the modal
     */
    hide() {
        if (this.timeoutId) {
            clearTimeout(this.timeoutId);
            this.timeoutId = null;
        }

        if (this.modalElement) {
            this.modalElement.classList.remove('visible');
        }
    }

    /**
     * Escape HTML to prevent XSS
     */
    _escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Create global instance
window.errorModal = new ErrorModal();

// Convenience functions for global access
window.showError = (message, options) => window.errorModal.error(message, options);
window.showWarning = (message, options) => window.errorModal.warning(message, options);
window.showSuccess = (message, options) => window.errorModal.success(message, options);
window.showInfo = (message, options) => window.errorModal.info(message, options);
window.showConfirm = (message, options) => window.errorModal.confirm(message, options);

// Export class for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ErrorModal;
}
