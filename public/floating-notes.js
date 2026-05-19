// Decorative animated music notes that drift across the background.
class FreshFloatingNotes {
    constructor() {
        this.container = null;
        this.musicNotes = ['♪', '♫', '♬', '♩', '♭', '♯', '𝄞', '𝄢'];
        this.isActive = false;

        this.init();
    }

    init() {
        this.createContainer();
        this.startFloating();
    }

    createContainer() {
        if (!this.container) {
            this.container = document.createElement('div');
            this.container.className = 'floating-notes-container';
            document.body.appendChild(this.container);
        }
    }

    createNote() {
        const note = document.createElement('div');
        note.className = 'floating-note';

        const symbol = this.musicNotes[Math.floor(Math.random() * this.musicNotes.length)];
        note.textContent = symbol;

        const colors = [
            'rgba(0, 212, 255, 0.4)',   // Cyan
            'rgba(118, 75, 162, 0.35)', // Purple
            'rgba(102, 126, 234, 0.45)', // Blue
            'rgba(255, 107, 107, 0.3)',  // Red
            'rgba(52, 211, 153, 0.4)',   // Green
            'rgba(251, 191, 36, 0.35)',  // Yellow
            'rgba(244, 114, 182, 0.4)',  // Pink
            'rgba(156, 163, 175, 0.4)',  // Gray
            'rgba(245, 101, 101, 0.35)', // Orange-red
            'rgba(139, 92, 246, 0.4)'    // Violet
        ];

        const randomColor = colors[Math.floor(Math.random() * colors.length)];
        note.style.color = randomColor;

        const x = Math.random() * (window.innerWidth - 200);
        const y = Math.random() * (window.innerHeight - 200);
        note.style.left = x + 'px';
        note.style.top = y + 'px';

        // Pick one of eight directions so motion is balanced over time.
        const animations = [
            'float-up', 'float-down',
            'diagonal-up-right', 'diagonal-down-left',
            'diagonal-up-left', 'diagonal-down-right',
            'float-left', 'float-right'
        ];
        const anim = animations[Math.floor(Math.random() * animations.length)];

        note.style.animation = anim + ' 7s ease-in-out forwards';

        this.container.appendChild(note);

        // Remove a little after the 7s animation completes to avoid DOM buildup.
        setTimeout(() => {
            if (note.parentNode) {
                note.parentNode.removeChild(note);
            }
        }, 8000);

        return note;
    }

    startFloating() {
        this.isActive = true;

        // Spawn an initial burst, staggered so they don't all start in lockstep.
        for (let i = 0; i < 24; i++) {
            setTimeout(() => {
                if (this.isActive) {
                    this.createNote();
                }
            }, i * 100);
        }

        setInterval(() => {
            if (this.isActive) {
                this.createNote();
            }
        }, 167);
    }
}

// Initialise when the browser is idle so the decorative effect never delays
// first paint or audio bring-up. This script is loaded dynamically after DOMContentLoaded.
if ('requestIdleCallback' in window) {
    requestIdleCallback(() => {
        window.freshFloatingNotes = new FreshFloatingNotes();
    });
} else {
    setTimeout(() => {
        window.freshFloatingNotes = new FreshFloatingNotes();
    }, 3000);
}