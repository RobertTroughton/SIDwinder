// sid-player.js - SID Playback Component
// Wraps reSID (via WASM) to provide playback UI for SIDwinder
// Uses a shared SIDPlayback instance to avoid multiple AudioContexts

var _activeSIDPlayerInstance = null;

class SIDPlayer {
    constructor(containerEl) {
        this.container = containerEl;
        this.isPlaying = false;
        this.currentSubtune = 0;
        this.totalSubtunes = 1;
        this.playTimeInterval = null;
        this.loaded = false;
        this._pendingData = null;
        this._pendingUrl = null;
        this._lastLoadedData = null;
        this._lastLoadedFilename = null;
        this._ownershipLost = false;
        this.buildUI();
    }

    buildUI() {
        this.container.innerHTML = `
            <div class="sid-player">
                <button class="sid-player-btn sid-player-play" title="Play" disabled>
                    <i class="fas fa-play"></i>
                </button>
                <button class="sid-player-btn sid-player-stop" title="Stop" disabled>
                    <i class="fas fa-stop"></i>
                </button>
                <button class="sid-player-btn sid-player-restart" title="Restart" disabled>
                    <i class="fas fa-undo"></i>
                </button>
                <div class="sid-player-subtune">
                    <button class="sid-player-btn sid-player-prev" title="Previous subtune" disabled>
                        <i class="fas fa-step-backward"></i>
                    </button>
                    <span class="sid-player-subtune-display">1/1</span>
                    <button class="sid-player-btn sid-player-next" title="Next subtune" disabled>
                        <i class="fas fa-step-forward"></i>
                    </button>
                </div>
                <div class="sid-player-time">0:00</div>
                <div class="sid-player-quality">
                    <select class="sid-player-quality-select" title="Sampling quality">
                        <option value="0">Fast</option>
                        <option value="1">Interpolate</option>
                        <option value="2">Resample</option>
                    </select>
                </div>
            </div>
            <div class="sid-player-credit">Playback by <a href="https://github.com/libsidplayfp/resid" target="_blank" rel="noopener">reSID</a></div>
        `;

        this.els = {
            playBtn: this.container.querySelector('.sid-player-play'),
            stopBtn: this.container.querySelector('.sid-player-stop'),
            restartBtn: this.container.querySelector('.sid-player-restart'),
            prevBtn: this.container.querySelector('.sid-player-prev'),
            nextBtn: this.container.querySelector('.sid-player-next'),
            subtuneContainer: this.container.querySelector('.sid-player-subtune'),
            subtuneDisplay: this.container.querySelector('.sid-player-subtune-display'),
            time: this.container.querySelector('.sid-player-time'),
            qualitySelect: this.container.querySelector('.sid-player-quality-select'),
        };

        this.els.playBtn.addEventListener('click', () => this.togglePlay());
        this.els.stopBtn.addEventListener('click', () => this.stop());
        this.els.restartBtn.addEventListener('click', () => this.restart());
        this.els.prevBtn.addEventListener('click', () => this.prevSubtune());
        this.els.nextBtn.addEventListener('click', () => this.nextSubtune());

        // Restore sampling quality from session
        const savedQuality = sessionStorage.getItem('sidSamplingMethod');
        this.els.qualitySelect.value = savedQuality !== null ? savedQuality : '1';

        this.els.qualitySelect.addEventListener('change', () => {
            const method = parseInt(this.els.qualitySelect.value, 10);
            sessionStorage.setItem('sidSamplingMethod', method);
            const player = getSharedSIDPlayback();
            player.setSamplingMethod(method);
            // Sync all other quality selects on the page
            document.querySelectorAll('.sid-player-quality-select').forEach(sel => {
                if (sel !== this.els.qualitySelect) sel.value = method;
            });
        });
    }

    takeOwnership() {
        // Stop any other SIDPlayer that's currently playing
        if (_activeSIDPlayerInstance && _activeSIDPlayerInstance !== this) {
            _activeSIDPlayerInstance.onLostOwnership();
        }
        _activeSIDPlayerInstance = this;
    }

    onLostOwnership() {
        // Another player took over the shared playback instance
        this.isPlaying = false;
        this._ownershipLost = true;
        this.els.playBtn.innerHTML = '<i class="fas fa-play"></i>';
        this.els.playBtn.title = 'Play';
        this.stopTimeUpdate();
    }

    async loadFromBinary(data, filename) {
        this.stop();
        this.takeOwnership();
        this._ownershipLost = false;

        // Store a copy so we can reload if another player takes over
        this._lastLoadedData = new Uint8Array(data.buffer || data).slice();
        this._lastLoadedFilename = filename;

        const player = getSharedSIDPlayback();

        player.setLoadCallback(() => {
            this.onLoaded(filename);
        });

        try {
            await player.loadFromArrayBuffer(data.buffer || data);
        } catch (e) {
            console.error('SIDPlayer: Failed to load SID data:', e);
        }
    }

    async loadFromUrl(url, filename) {
        this.stop();
        this.takeOwnership();

        const player = getSharedSIDPlayback();

        player.setLoadCallback(() => {
            this.onLoaded(filename);
        });

        try {
            await player.loadFromUrl(url);
        } catch (e) {
            console.error('SIDPlayer: Failed to load SID URL:', e);
        }
    }

    onLoaded(filename) {
        const player = getSharedSIDPlayback();
        this.totalSubtunes = player.getSubtuneCount() || 1;
        const startSong = player.getStartSong();
        this.currentSubtune = Math.max(0, Math.min(startSong - 1, this.totalSubtunes - 1));
        this.loaded = true;

        this.els.playBtn.disabled = false;
        this.els.stopBtn.disabled = false;
        this.els.restartBtn.disabled = false;

        this.updateSubtuneDisplay();

        // Auto-set SID model based on file preference
        const prefModel = player.getSIDModel();
        if (prefModel) {
            player.setModel(prefModel);
        }

        // Apply saved sampling quality
        const savedQuality = sessionStorage.getItem('sidSamplingMethod');
        if (savedQuality !== null) {
            player.setSamplingMethod(parseInt(savedQuality, 10));
        }
    }

    togglePlay() {
        if (this.isPlaying) {
            this.pause();
        } else {
            this.play();
        }
    }

    async play() {
        if (!this.loaded) return;
        this.takeOwnership();
        const player = getSharedSIDPlayback();

        // If another player loaded different data while we lost ownership,
        // reload our SID data before playing
        if (this._ownershipLost && this._lastLoadedData) {
            this._ownershipLost = false;
            player.setLoadCallback(() => {
                this.onLoaded(this._lastLoadedFilename);
                player.setSubtune(this.currentSubtune);
                player.play();
                this.isPlaying = true;
                this.els.playBtn.innerHTML = '<i class="fas fa-pause"></i>';
                this.els.playBtn.title = 'Pause';
                this.startTimeUpdate();
            });
            await player.loadFromArrayBuffer(this._lastLoadedData.buffer);
            return;
        }

        player.pause();
        player.setSubtune(this.currentSubtune);
        player.play();
        this.isPlaying = true;
        this.els.playBtn.innerHTML = '<i class="fas fa-pause"></i>';
        this.els.playBtn.title = 'Pause';
        this.startTimeUpdate();
    }

    pause() {
        const player = getSharedSIDPlayback();
        player.pause();
        this.isPlaying = false;
        this.els.playBtn.innerHTML = '<i class="fas fa-play"></i>';
        this.els.playBtn.title = 'Play';
        this.stopTimeUpdate();
    }

    stop() {
        if (_activeSIDPlayerInstance === this && _sharedSIDPlayback) {
            _sharedSIDPlayback.stop();
        }
        this.isPlaying = false;
        this.els.playBtn.innerHTML = '<i class="fas fa-play"></i>';
        this.els.playBtn.title = 'Play';
        this.els.time.textContent = '0:00';
        this.stopTimeUpdate();
    }

    restart() {
        if (!this.loaded) return;
        this.play();
    }

    prevSubtune() {
        if (this.currentSubtune > 0) {
            this.currentSubtune--;
            this.updateSubtuneDisplay();
            if (this.isPlaying) this.play();
        }
    }

    nextSubtune() {
        if (this.currentSubtune < this.totalSubtunes - 1) {
            this.currentSubtune++;
            this.updateSubtuneDisplay();
            if (this.isPlaying) this.play();
        }
    }

    updateSubtuneDisplay() {
        this.els.subtuneDisplay.textContent = `${this.currentSubtune + 1}/${this.totalSubtunes}`;
        this.els.prevBtn.disabled = this.currentSubtune <= 0;
        this.els.nextBtn.disabled = this.currentSubtune >= this.totalSubtunes - 1;
    }

    startTimeUpdate() {
        this.stopTimeUpdate();
        this.playTimeInterval = setInterval(() => {
            if (this.isPlaying) {
                const player = getSharedSIDPlayback();
                const seconds = player.getPlayTime();
                const mins = Math.floor(seconds / 60);
                const secs = seconds % 60;
                this.els.time.textContent = `${mins}:${secs.toString().padStart(2, '0')}`;
            }
        }, 500);
    }

    stopTimeUpdate() {
        if (this.playTimeInterval) {
            clearInterval(this.playTimeInterval);
            this.playTimeInterval = null;
        }
    }

    cleanup() {
        this.stop();
    }

    reset() {
        this.cleanup();
        this.loaded = false;
        this.totalSubtunes = 1;
        this.currentSubtune = 0;
        this.els.playBtn.disabled = true;
        this.els.stopBtn.disabled = true;
        this.els.restartBtn.disabled = true;
        this.els.prevBtn.disabled = true;
        this.els.nextBtn.disabled = true;
        this.els.subtuneDisplay.textContent = '1/1';
        this.els.time.textContent = '0:00';
    }
}
