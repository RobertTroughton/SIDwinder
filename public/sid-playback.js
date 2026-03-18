// sid-playback.js - reSID-based SID playback engine for SIDwinder
// Wraps reSID (via WASM) with AudioWorkletNode for glitch-free output.

class SIDPlayback {
    constructor(bufferSize = 4096) {
        this.bufferSize = bufferSize;
        this.audioCtx = null;
        this.workletNode = null;
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

        this._loadAddress = 0;
        this._initAddress = 0;
        this._playAddress = 0;
        this._dataSize = 0;

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

        // Register AudioWorklet processor and create node
        await this.audioCtx.audioWorklet.addModule('sid-worklet-processor.js');
        this.workletNode = new AudioWorkletNode(this.audioCtx, 'sid-worklet-processor');

        // Generate samples when the worklet needs more
        this.workletNode.port.onmessage = (e) => {
            if (e.data.type === 'need-samples' && this.playing && this.loaded) {
                this._generateAndPost();
            }
        };

        // Gain node for volume control
        this.gainNode = this.audioCtx.createGain();
        this.gainNode.gain.value = this.volume;
        this.workletNode.connect(this.gainNode);
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
            audio_cleanup:           cwrap('audio_cleanup', null, []),
        };
    }

    _generateAndPost() {
        const generated = this.api.audio_generate(this.wasmBufferPtr, this.bufferSize);
        if (generated <= 0) return;

        // Read samples from WASM heap (use HEAPU8.buffer fresh after WASM call
        // to handle ALLOW_MEMORY_GROWTH buffer detachment)
        const heap = this.module.HEAPU8.buffer;
        const int16View = new Int16Array(heap, this.wasmBufferPtr, generated);

        // Convert int16 to float32 for the worklet
        const floatSamples = new Float32Array(generated);
        for (let i = 0; i < generated; i++) {
            floatSamples[i] = int16View[i] / 32768.0;
        }

        // Transfer the buffer to the worklet (zero-copy)
        this.workletNode.port.postMessage(
            { type: 'samples', samples: floatSamples },
            [floatSamples.buffer]
        );
    }

    async loadFromArrayBuffer(arrayBuffer) {
        await this.init();

        // Stop playback and flush worklet queue before loading new SID
        this.playing = false;
        if (this.workletNode) {
            this.workletNode.port.postMessage({ type: 'stop' });
        }

        // Reset WASM SID state if a tune was already loaded
        if (this.loaded) {
            this.api.audio_cleanup();
            this.loaded = false;
        }

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

        // Parse addresses from SID header (big-endian)
        this._parseSIDHeader(data);

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
    }

    play() {
        if (!this.loaded) return;

        // Resume audio context if suspended (browser autoplay policy)
        if (this.audioCtx.state === 'suspended') {
            this.audioCtx.resume();
        }

        this.playing = true;

        // Flush any stale samples and tell worklet to start accepting new ones
        this.workletNode.port.postMessage({ type: 'stop' });
        this.workletNode.port.postMessage({ type: 'start' });

        // Pre-fill the worklet queue so playback starts immediately
        for (let i = 0; i < 3; i++) {
            this._generateAndPost();
        }

        // Fade in from silence to mask any transition click (~85ms)
        const now = this.audioCtx.currentTime;
        this.gainNode.gain.cancelScheduledValues(now);
        this.gainNode.gain.setValueAtTime(0, now);
        this.gainNode.gain.linearRampToValueAtTime(this.volume, now + 0.085);

        this.gainNode.connect(this.audioCtx.destination);
    }

    pause() {
        this.playing = false;
        if (this.workletNode) {
            this.workletNode.port.postMessage({ type: 'stop' });
        }
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
            this.gainNode.gain.cancelScheduledValues(this.audioCtx.currentTime);
            this.gainNode.gain.setValueAtTime(vol, this.audioCtx.currentTime);
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

    _parseSIDHeader(data) {
        if (data.length < 0x76) return;
        const be16 = (hi, lo) => (data[hi] << 8) | data[lo];
        const dataOffset = be16(0x06, 0x07);
        let loadAddr = be16(0x08, 0x09);
        this._initAddress = be16(0x0A, 0x0B);
        this._playAddress = be16(0x0C, 0x0D);
        const musicData = data.subarray(dataOffset);
        let musicLen = data.length - dataOffset;
        if (loadAddr === 0 && musicLen >= 2) {
            loadAddr = musicData[0] | (musicData[1] << 8);
            musicLen -= 2;
        }
        this._loadAddress = loadAddr;
        if (this._initAddress === 0) this._initAddress = loadAddr;
        this._dataSize = musicLen;
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
    getLoadAddress()  { return this._loadAddress; }
    getInitAddress()  { return this._initAddress; }
    getPlayAddress()  { return this._playAddress; }
    getDataSize()     { return this._dataSize; }

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
