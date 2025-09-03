// Fresh Floating Notes - 8x notes, no logging, faster movement
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

        // Apply random color directly in JavaScript
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

        // Random position
        const x = Math.random() * (window.innerWidth - 200);
        const y = Math.random() * (window.innerHeight - 200);
        note.style.left = x + 'px';
        note.style.top = y + 'px';

        // Pick animation - balanced movement in all directions
        const animations = [
            'float-up', 'float-down',                    // Vertical balance
            'diagonal-up-right', 'diagonal-down-left',   // Diagonal balance
            'diagonal-up-left', 'diagonal-down-right',   // Diagonal balance
            'float-left', 'float-right'                  // Horizontal balance
        ];
        const anim = animations[Math.floor(Math.random() * animations.length)];

        // Apply animation directly - 7s instead of 10s (30% faster)
        note.style.animation = anim + ' 7s ease-in-out forwards';

        this.container.appendChild(note);

        setTimeout(() => {
            if (note.parentNode) {
                note.parentNode.removeChild(note);
            }
        }, 8000); // Reduced cleanup time too

        return note;
    }

    startFloating() {
        this.isActive = true;

        // Create 24 notes immediately (3x the current 8)
        for (let i = 0; i < 24; i++) {
            setTimeout(() => {
                if (this.isActive) {
                    this.createNote();
                }
            }, i * 100); // Stagger them slightly with faster timing
        }

        // Then create new notes more frequently - every 167ms instead of 500ms (3x faster)
        setInterval(() => {
            if (this.isActive) {
                this.createNote();
            }
        }, 167);
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    setTimeout(() => {
        window.freshFloatingNotes = new FreshFloatingNotes();
    }, 1000);
});