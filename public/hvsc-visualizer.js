// hvsc-visualizer.js - spectrum-bar visualizer for the HVSC browser.
//
// Reads the live playback signal from an AnalyserNode (see sid-playback.js) and
// renders 64 log-spaced frequency bars on a canvas. Designed to look good on
// SIDquake's dark theme: an amber->cyan gradient (low freq = warm/on-brand,
// high freq = cool), fast-attack/slow-release bar motion, slowly-falling peak
// caps, and a white flash on strong bass beats.
//
// Decoupled from the audio engine: it just needs an AnalyserNode, so it keeps
// working regardless of what generates the sound.

window.hvscVisualizer = (function () {
    const BARS = 64;
    const F_MIN = 40;       // Hz, low edge of the lowest bar
    const F_MAX = 11000;    // Hz, high edge of the top bar
    const FLOOR = 0.05;     // 0..1 noise-floor gate; higher = more gaps between bars
    const SLOPE = 1.0;      // treble tilt compensation; higher = more high-freq boost
    // Loudness window mapped to bar height. SID is loud, so the default
    // (-100..-30 dB) pegs everything at max — give headroom by raising MAX_DB.
    // If bars still peg, raise MAX_DB toward 0; if they're too short, lower it.
    const MIN_DB = -90;
    const MAX_DB = -10;

    let canvas = null, ctx = null, analyser = null, freq = null;
    let levels = null, peaks = null, bandLo = null, bandHi = null;
    let W = 0, H = 0, dpr = 1;
    let rafId = null, running = false;
    let bassAvg = 0, flash = 0;

    function init(canvasEl, analyserNode) {
        canvas = canvasEl;
        analyser = analyserNode;
        // Finer FFT sharpens the low end (each low bar was ~1 coarse bin, so a
        // bass note's leakage smeared across neighbours). Own these here.
        try {
            analyser.fftSize = 4096;
            analyser.smoothingTimeConstant = 0.55;
            // Headroom so loud SID doesn't clamp every bin to 255.
            analyser.minDecibels = MIN_DB;
            analyser.maxDecibels = MAX_DB;
        } catch (_) { /* keep defaults if the node rejects it */ }
        ctx = canvas.getContext('2d');
        freq = new Uint8Array(analyser.frequencyBinCount);
        levels = new Float32Array(BARS);
        peaks = new Float32Array(BARS);
        computeBands();
        resize();
        if (!init._resizeWired) {
            window.addEventListener('resize', resize);
            init._resizeWired = true;
        }
    }

    // Precompute the FFT-bin range each bar covers (log-spaced across F_MIN..F_MAX).
    function computeBands() {
        const nyquist = analyser.context.sampleRate / 2;
        const binHz = nyquist / analyser.frequencyBinCount;
        const fMax = Math.min(F_MAX, nyquist);
        bandLo = new Int32Array(BARS);
        bandHi = new Int32Array(BARS);
        for (let b = 0; b < BARS; b++) {
            const f0 = F_MIN * Math.pow(fMax / F_MIN, b / BARS);
            const f1 = F_MIN * Math.pow(fMax / F_MIN, (b + 1) / BARS);
            let lo = Math.floor(f0 / binHz);
            let hi = Math.ceil(f1 / binHz);
            lo = Math.max(0, Math.min(freq.length - 1, lo));
            hi = Math.max(lo + 1, Math.min(freq.length, hi));
            bandLo[b] = lo; bandHi[b] = hi;
        }
    }

    function resize() {
        if (!canvas || !ctx) return;
        dpr = window.devicePixelRatio || 1;
        const rect = canvas.getBoundingClientRect();
        W = Math.max(1, Math.floor(rect.width));
        H = Math.max(1, Math.floor(rect.height));
        canvas.width = Math.floor(W * dpr);
        canvas.height = Math.floor(H * dpr);
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }

    function start() {
        if (running || !analyser) return;
        resize();          // re-measure in case the canvas was 0-sized at init
        running = true;
        loop();
    }

    function stop() {
        running = false;
        if (rafId) cancelAnimationFrame(rafId);
        rafId = null;
    }

    // Zero all bar state and wipe the canvas, so nothing is left "frozen" from a
    // previous tune (used on tune/song switch and when the browser closes/opens).
    function reset() {
        if (levels) levels.fill(0);
        if (peaks) peaks.fill(0);
        flash = 0;
        bassAvg = 0;
        if (ctx) ctx.clearRect(0, 0, W, H);
    }

    function loop() {
        if (!running) return;
        rafId = requestAnimationFrame(loop);
        step();
    }

    function step() {
        if (!ctx) return;
        if (W === 0 || H === 0) resize(); // canvas became visible/sized after init
        analyser.getByteFrequencyData(freq);

        let bass = 0;
        for (let b = 0; b < BARS; b++) {
            // Bar target = loudest bin in its band (feels punchier than average).
            let m = 0;
            for (let i = bandLo[b]; i < bandHi[b]; i++) if (freq[i] > m) m = freq[i];
            let t = m / 255;
            // Noise-floor gate: drop low-level "fill" to zero so valleys open up
            // between real peaks.
            t = (t - FLOOR) / (1 - FLOOR);
            if (t < 0) t = 0;
            // Tilt compensation: music rolls off toward high frequencies, which
            // makes the bass bars always taller. Boost bars with frequency (bar
            // index) so the display reads balanced left-to-right.
            t *= 1 + SLOPE * (b / (BARS - 1));
            if (t > 1) t = 1;

            // Fast attack, slow release for smooth, musical motion.
            const k = t > levels[b] ? 0.55 : 0.14;
            levels[b] += (t - levels[b]) * k;

            // Peak cap that slowly falls back down.
            if (levels[b] > peaks[b]) peaks[b] = levels[b];
            else peaks[b] = Math.max(0, peaks[b] - 0.006);

            if (b < 6) bass += levels[b];
        }
        bass /= 6;

        // Beat detection: flash when bass jumps above its running average.
        bassAvg = bassAvg * 0.92 + bass * 0.08;
        if (bass > bassAvg * 1.35 && bass > 0.45) flash = Math.min(1, flash + 0.9);
        flash *= 0.86;

        render();
    }

    function render() {
        ctx.clearRect(0, 0, W, H);

        const gap = Math.max(1, (W / BARS) * 0.18);
        const bw = (W - gap * (BARS + 1)) / BARS;
        const baseY = H;
        const usableH = H - 3;

        for (let b = 0; b < BARS; b++) {
            const x = gap + b * (bw + gap);
            const lvl = levels[b];
            const bh = Math.max(1, lvl * usableH);
            const top = baseY - bh;

            // Amber (low freq, on-brand) -> cyan (high freq); brighten with level + beat.
            const hue = 35 + (b / BARS) * 160;
            const light = 44 + lvl * 26 + flash * 22;

            const grad = ctx.createLinearGradient(0, baseY, 0, top);
            grad.addColorStop(0, `hsla(${hue}, 90%, ${light * 0.55}%, 0.95)`);
            grad.addColorStop(1, `hsla(${hue}, 95%, ${Math.min(88, light + 16)}%, 1)`);
            ctx.fillStyle = grad;
            barPath(x, top, bw, bh);
            ctx.fill();

            // White-hot tip on strong bars / beats.
            const hot = Math.max(0, lvl - 0.72) * 1.8 + flash * 0.5;
            if (hot > 0.02) {
                ctx.fillStyle = `rgba(255,255,255,${Math.min(0.9, hot)})`;
                barPath(x, top, bw, Math.min(bh, 3));
                ctx.fill();
            }

            // Peak cap.
            const py = baseY - Math.max(peaks[b] * usableH, 1);
            ctx.fillStyle = `hsla(${hue}, 100%, ${72 + flash * 20}%, 0.85)`;
            ctx.fillRect(x, py - 1.5, bw, 1.5);
        }

        // Subtle full-width flash on the beat.
        if (flash > 0.04) {
            ctx.fillStyle = `rgba(255,255,255,${flash * 0.07})`;
            ctx.fillRect(0, 0, W, H);
        }
    }

    // Bar with a slightly rounded top.
    function barPath(x, y, w, h) {
        const r = Math.min(w / 2, 3, h);
        ctx.beginPath();
        ctx.moveTo(x, y + h);
        ctx.lineTo(x, y + r);
        ctx.quadraticCurveTo(x, y, x + r, y);
        ctx.lineTo(x + w - r, y);
        ctx.quadraticCurveTo(x + w, y, x + w, y + r);
        ctx.lineTo(x + w, y + h);
        ctx.closePath();
    }

    return { init, start, stop, reset };
})();
