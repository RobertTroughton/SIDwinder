// sid-worklet-processor.js - AudioWorklet processor for SID playback
// Receives Float32 audio samples from the main thread via MessagePort
// and outputs them in the audio thread's process() callback.

class SIDWorkletProcessor extends AudioWorkletProcessor {
    constructor() {
        super();
        this._queue = [];
        this._offset = 0;
        this._active = false;
        this._totalSamples = 0;
        this._requested = false;

        this.port.onmessage = (e) => {
            const msg = e.data;
            if (msg.type === 'samples') {
                this._queue.push(msg.samples);
                this._totalSamples += msg.samples.length;
                this._requested = false;
            } else if (msg.type === 'start') {
                this._active = true;
                this._requested = false;
            } else if (msg.type === 'stop') {
                this._active = false;
                this._queue.length = 0;
                this._offset = 0;
                this._totalSamples = 0;
                this._requested = false;
            }
        };
    }

    process(inputs, outputs) {
        const output = outputs[0][0];

        if (!this._active) {
            output.fill(0);
            return true;
        }

        let written = 0;
        while (written < output.length && this._queue.length > 0) {
            const buf = this._queue[0];
            const avail = buf.length - this._offset;
            const need = output.length - written;
            const n = Math.min(avail, need);

            for (let i = 0; i < n; i++) {
                output[written + i] = buf[this._offset + i];
            }

            written += n;
            this._offset += n;
            this._totalSamples -= n;

            if (this._offset >= buf.length) {
                this._queue.shift();
                this._offset = 0;
            }
        }

        for (let i = written; i < output.length; i++) {
            output[i] = 0;
        }

        // Request more samples when buffer is running low
        if (this._totalSamples < 8192 && !this._requested) {
            this._requested = true;
            this.port.postMessage({ type: 'need-samples' });
        }

        return true;
    }
}

registerProcessor('sid-worklet-processor', SIDWorkletProcessor);
