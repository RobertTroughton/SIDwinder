// sid-player.js - SID Playback Component
// Wraps jsSID (by Hermit) to provide playback UI for SIDquake
// Uses a shared jsSID instance to avoid multiple AudioContexts

var _sharedJsSID = null;
var _activeSIDPlayerInstance = null;

function getSharedJsSID() {
    if (!_sharedJsSID) {
        _sharedJsSID = new jsSID(4096, 0.0005);
    }
    return _sharedJsSID;
}

class SIDPlayer {
    constructor(containerEl) {
        this.container = containerEl;
        this.isPlaying = false;
        this.currentBlobUrl = null;
        this.currentSubtune = 0;
        this.totalSubtunes = 1;
        this.playTimeInterval = null;
        this.loaded = false;
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
                <div class="sid-player-subtune" style="display:none;">
                    <button class="sid-player-btn sid-player-prev" title="Previous subtune">
                        <i class="fas fa-step-backward"></i>
                    </button>
                    <span class="sid-player-subtune-display">1/1</span>
                    <button class="sid-player-btn sid-player-next" title="Next subtune">
                        <i class="fas fa-step-forward"></i>
                    </button>
                </div>
                <div class="sid-player-time">0:00</div>
            </div>
            <div class="sid-player-credit">Playback by <a href="https://hermit.sidrip.com" target="_blank" rel="noopener">jsSID</a> by Hermit</div>
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
        };

        this.els.playBtn.addEventListener('click', () => this.togglePlay());
        this.els.stopBtn.addEventListener('click', () => this.stop());
        this.els.restartBtn.addEventListener('click', () => this.restart());
        this.els.prevBtn.addEventListener('click', () => this.prevSubtune());
        this.els.nextBtn.addEventListener('click', () => this.nextSubtune());
    }

    takeOwnership() {
        // Stop any other SIDPlayer that's currently playing
        if (_activeSIDPlayerInstance && _activeSIDPlayerInstance !== this) {
            _activeSIDPlayerInstance.onLostOwnership();
        }
        _activeSIDPlayerInstance = this;
    }

    onLostOwnership() {
        // Another player took over the shared jsSID instance
        this.isPlaying = false;
        this.els.playBtn.innerHTML = '<i class="fas fa-play"></i>';
        this.els.playBtn.title = 'Play';
        this.stopTimeUpdate();
    }

    loadFromBinary(data, filename) {
        this.stop();
        this.takeOwnership();

        if (this.currentBlobUrl) {
            URL.revokeObjectURL(this.currentBlobUrl);
        }

        const player = getSharedJsSID();
        const blob = new Blob([data], { type: 'application/octet-stream' });
        this.currentBlobUrl = URL.createObjectURL(blob);

        player.setloadcallback(() => {
            this.onLoaded(filename);
        });

        player.loadinit(this.currentBlobUrl, 0);
    }

    loadFromUrl(url, filename) {
        this.stop();
        this.takeOwnership();

        if (this.currentBlobUrl) {
            URL.revokeObjectURL(this.currentBlobUrl);
            this.currentBlobUrl = null;
        }

        const player = getSharedJsSID();

        player.setloadcallback(() => {
            this.onLoaded(filename);
        });

        player.loadinit(url, 0);
    }

    onLoaded(filename) {
        const player = getSharedJsSID();
        this.totalSubtunes = player.getsubtunes() || 1;
        // Use the SID file's default start song (1-based in header, convert to 0-based)
        const startSong = player.getstartsong();
        this.currentSubtune = Math.max(0, Math.min(startSong - 1, this.totalSubtunes - 1));
        this.loaded = true;

        this.els.playBtn.disabled = false;
        this.els.stopBtn.disabled = false;
        this.els.restartBtn.disabled = false;

        if (this.totalSubtunes > 1) {
            this.els.subtuneContainer.style.display = 'flex';
            this.updateSubtuneDisplay();
        } else {
            this.els.subtuneContainer.style.display = 'none';
        }

        // Auto-set SID model based on file preference
        const prefModel = player.getprefmodel();
        if (prefModel) {
            player.setmodel(prefModel);
        }

    }

    togglePlay() {
        if (this.isPlaying) {
            this.pause();
        } else {
            this.play();
        }
    }

    play() {
        if (!this.loaded) return;
        this.takeOwnership();
        const player = getSharedJsSID();
        // Disconnect first so the stale ScriptProcessorNode buffer plays to nowhere.
        // Then reinit the emulation (without connecting — using initsubtune instead
        // of start, which would reconnect immediately). Wait one buffer cycle
        // (~4096 samples at 44.1kHz = 93ms) for onaudioprocess to fill a fresh
        // buffer, then connect to hear clean audio from the new tune.
        try { player.pause(); } catch(e) { /* may not be connected */ }
        player.initsubtune(this.currentSubtune);
        setTimeout(() => {
            player.playcont();
        }, 120);
        this.isPlaying = true;
        this.els.playBtn.innerHTML = '<i class="fas fa-pause"></i>';
        this.els.playBtn.title = 'Pause';
        this.startTimeUpdate();
    }

    pause() {
        const player = getSharedJsSID();
        player.pause();
        this.isPlaying = false;
        this.els.playBtn.innerHTML = '<i class="fas fa-play"></i>';
        this.els.playBtn.title = 'Play';
        this.stopTimeUpdate();
    }

    stop() {
        if (_activeSIDPlayerInstance === this && _sharedJsSID) {
            _sharedJsSID.stop();
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
                const player = getSharedJsSID();
                const seconds = player.getplaytime();
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
        if (this.currentBlobUrl) {
            URL.revokeObjectURL(this.currentBlobUrl);
            this.currentBlobUrl = null;
        }
    }

    reset() {
        this.cleanup();
        this.loaded = false;
        this.els.playBtn.disabled = true;
        this.els.stopBtn.disabled = true;
        this.els.restartBtn.disabled = true;
        this.els.subtuneContainer.style.display = 'none';
        this.els.time.textContent = '0:00';
    }
}
