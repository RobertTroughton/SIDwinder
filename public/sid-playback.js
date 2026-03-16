// sid-playback.js - reSID-based SID playback engine for SIDwinder
// Replaces jsSID with cycle-accurate reSID emulation via WASM.
// Uses ScriptProcessorNode for audio output (AudioWorklet upgrade possible later).

class SIDPlayback {
    constructor(bufferSize = 4096) {
        this.bufferSize = bufferSize;
        this.audioCtx = null;
        this.scriptNode = null;
        this.gainNode = null;
        this.module = null;
        this.api = null;
        this.loaded = false;
        this.playing = false;
        this.volume = 1.0;
        this.wasmBuffer = null;
        this.wasmBufferPtr = 0;

        // Metadata cache (avoid crossing WASM boundary every frame)
        this._title = '';
        this._author = '';
        this._copyright = '';
        this._subtunes = 0;
        this._startSong = 0;
        this._sidModel = 6581;
        this._sidCount = 1;
        this._isNTSC = false;

        this._loadCallback = null;
    }

    async init() {
        if (this.module) return;

        // Reuse the SIDwinder WASM module if already loaded by SIDAnalyzer
        if (window.SIDwinderModule && typeof window.SIDwinderModule.cwrap === 'function') {
            // Module already instantiated by sidwinder-core.js
            this.module = window.SIDwinderModule;
        } else if (typeof SIDwinderModule === 'function') {
            // Module factory not yet called - instantiate it
            this.module = await SIDwinderModule();
        } else {
            throw new Error('SIDwinderModule not loaded. Include sidwinder.js first.');
        }

        this._bindAPI();

        // Create audio context
        const AC = window.AudioContext || window.webkitAudioContext;
        this.audioCtx = new AC();

        // Init the WASM audio engine with the browser's sample rate
        this.api.audio_init(this.audioCtx.sampleRate);

        // Allocate a persistent WASM buffer for audio samples (int16)
        this.wasmBufferPtr = this.module._malloc(this.bufferSize * 2);

        // Create ScriptProcessorNode for audio output
        this.scriptNode = this.audioCtx.createScriptProcessor(this.bufferSize, 0, 1);
        this.scriptNode.onaudioprocess = (e) => this._onAudioProcess(e);

        // Gain node for volume control
        this.gainNode = this.audioCtx.createGain();
        this.gainNode.gain.value = this.volume;
        this.scriptNode.connect(this.gainNode);
    }

    _bindAPI() {
        const cwrap = this.module.cwrap;
        this.api = {
            audio_init:              cwrap('audio_init', null, ['number']),
            audio_load_sid:          cwrap('audio_load_sid', 'number', ['number', 'number']),
            audio_set_subtune:       cwrap('audio_set_subtune', null, ['number']),
            audio_generate:          cwrap('audio_generate', 'number', ['number', 'number']),
            audio_set_model:         cwrap('audio_set_model', null, ['number']),
            audio_set_sampling_method: cwrap('audio_set_sampling_method', null, ['number']),
            audio_get_title:         cwrap('audio_get_title', 'string', []),
            audio_get_author:        cwrap('audio_get_author', 'string', []),
            audio_get_copyright:     cwrap('audio_get_copyright', 'string', []),
            audio_get_subtune_count: cwrap('audio_get_subtune_count', 'number', []),
            audio_get_default_subtune: cwrap('audio_get_default_subtune', 'number', []),
            audio_get_sid_model:     cwrap('audio_get_sid_model', 'number', []),
            audio_get_sid_count:     cwrap('audio_get_sid_count', 'number', []),
            audio_get_play_time:     cwrap('audio_get_play_time', 'number', []),
            audio_get_is_ntsc:       cwrap('audio_get_is_ntsc', 'number', []),
            audio_get_play_address:  cwrap('audio_get_play_address', 'number', []),
            audio_get_volume:        cwrap('audio_get_volume', 'number', []),
            audio_read_memory:       cwrap('audio_read_memory', 'number', ['number']),
            audio_get_dbg_sid_writes: cwrap('audio_get_dbg_sid_writes', 'number', []),
            audio_get_dbg_play_pc:   cwrap('audio_get_dbg_play_pc', 'number', []),
            audio_get_dbg_play_sp:   cwrap('audio_get_dbg_play_sp', 'number', []),
            audio_cleanup:           cwrap('audio_cleanup', null, []),
        };
    }

    _onAudioProcess(event) {
        const output = event.outputBuffer.getChannelData(0);

        if (!this.playing || !this.loaded) {
            output.fill(0);
            return;
        }

        // Generate int16 samples from WASM
        const numSamples = output.length;
        const generated = this.api.audio_generate(this.wasmBufferPtr, numSamples);

        if (generated <= 0) {
            output.fill(0);
            return;
        }

        // Read samples from WASM heap (use HEAPU8.buffer fresh after WASM call
        // to handle ALLOW_MEMORY_GROWTH buffer detachment)
        const heap = this.module.HEAPU8.buffer;
        const int16View = new Int16Array(heap, this.wasmBufferPtr, generated);

        for (let i = 0; i < numSamples; i++) {
            if (i < generated) {
                output[i] = int16View[i] / 32768.0;
            } else {
                output[i] = 0;
            }
        }

        // Debug: log first few callbacks and then periodically
        if (!this._debugCount) this._debugCount = 0;
        this._debugCount++;
        if (this._debugCount <= 5 || this._debugCount % 100 === 0) {
            let maxAbs = 0;
            for (let i = 0; i < generated; i++) {
                const v = Math.abs(int16View[i]);
                if (v > maxAbs) maxAbs = v;
            }
            const sidWrites = this.api.audio_get_dbg_sid_writes();
            const pc = this.api.audio_get_dbg_play_pc();
            const sp = this.api.audio_get_dbg_play_sp();
            const vol = this.api.audio_get_volume();
            console.log(`[SIDPlayback] cb#${this._debugCount}: maxSample=${maxAbs}, sidWrites=${sidWrites}, vol=${vol}, PC=$${pc.toString(16).padStart(4,'0')}, SP=$${sp.toString(16).padStart(2,'0')}`);
        }
    }

    async loadFromArrayBuffer(arrayBuffer) {
        await this.init();

        const data = new Uint8Array(arrayBuffer);

        // Allocate WASM memory and copy SID file data
        const ptr = this.module._malloc(data.length);
        this.module.HEAPU8.set(data, ptr);

        // Load the SID file
        const result = this.api.audio_load_sid(ptr, data.length);
        this.module._free(ptr);

        if (result !== 0) {
            throw new Error(`Failed to load SID file (error ${result})`);
        }

        // Cache metadata
        this._title = this.api.audio_get_title();
        this._author = this.api.audio_get_author();
        this._copyright = this.api.audio_get_copyright();
        this._subtunes = this.api.audio_get_subtune_count();
        this._startSong = this.api.audio_get_default_subtune();
        this._sidModel = this.api.audio_get_sid_model();
        this._sidCount = this.api.audio_get_sid_count();
        this._isNTSC = this.api.audio_get_is_ntsc() !== 0;

        this.loaded = true;
        this._debugCount = 0;  // Reset debug for new SID

        console.log(`[SIDPlayback] SID loaded: "${this._title}" by ${this._author}, subtunes=${this._subtunes}, startSong=${this._startSong}, model=${this._sidModel}, chips=${this._sidCount}`);

        if (this._loadCallback) {
            this._loadCallback();
        }
    }

    async loadFromUrl(url) {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`Failed to fetch ${url}: ${response.status}`);
        const buffer = await response.arrayBuffer();
        return this.loadFromArrayBuffer(buffer);
    }

    setSubtune(subtune) {
        if (!this.loaded) return;
        this.api.audio_set_subtune(subtune);
        const playAddr = this.api.audio_get_play_address();
        const vol = this.api.audio_get_volume();
        console.log(`[SIDPlayback] setSubtune(${subtune}): playAddr=$${playAddr.toString(16).padStart(4,'0')}, volume=${vol}`);
        this._debugCount = 0;  // Re-log callbacks after subtune change
    }

    play() {
        if (!this.loaded) {
            console.warn('[SIDPlayback] play() called but not loaded');
            return;
        }

        // Resume audio context if suspended (browser autoplay policy)
        if (this.audioCtx.state === 'suspended') {
            this.audioCtx.resume();
        }

        this.playing = true;
        this.gainNode.connect(this.audioCtx.destination);
        console.log(`[SIDPlayback] play() - audioCtx.state=${this.audioCtx.state}, playing=${this.playing}`);
    }

    pause() {
        this.playing = false;
        try {
            this.gainNode.disconnect(this.audioCtx.destination);
        } catch (e) {
            // Already disconnected
        }
    }

    stop() {
        this.pause();
        if (this.loaded) {
            // Reset to start of current subtune
            this.api.audio_set_subtune(this._startSong > 0 ? this._startSong - 1 : 0);
        }
    }

    setVolume(vol) {
        this.volume = vol;
        if (this.gainNode) {
            this.gainNode.gain.value = vol;
        }
    }

    setModel(model) {
        if (this.api) {
            this.api.audio_set_model(model);
            this._sidModel = model;
        }
    }

    setSamplingMethod(method) {
        // 0 = fast, 1 = interpolate, 2 = resample
        if (this.api) {
            this.api.audio_set_sampling_method(method);
        }
    }

    setLoadCallback(fn) {
        this._loadCallback = fn;
    }

    // ---- Metadata getters ----
    getTitle()        { return this._title; }
    getAuthor()       { return this._author; }
    getCopyright()    { return this._copyright; }
    getSubtuneCount() { return this._subtunes; }
    getStartSong()    { return this._startSong; }
    getSIDModel()     { return this._sidModel; }
    getSIDCount()     { return this._sidCount; }
    isNTSC()          { return this._isNTSC; }

    getPlayTime() {
        if (!this.api || !this.loaded) return 0;
        return Math.floor(this.api.audio_get_play_time());
    }

    cleanup() {
        this.pause();
        if (this.api) {
            this.api.audio_cleanup();
        }
        if (this.wasmBufferPtr && this.module) {
            this.module._free(this.wasmBufferPtr);
            this.wasmBufferPtr = 0;
        }
        this.loaded = false;
    }
}

// Shared singleton instance (matches jsSID's pattern)
var _sharedSIDPlayback = null;

function getSharedSIDPlayback() {
    if (!_sharedSIDPlayback) {
        _sharedSIDPlayback = new SIDPlayback(4096);
    }
    return _sharedSIDPlayback;
}
