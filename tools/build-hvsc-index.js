#!/usr/bin/env node
/*
 * Builds public/hvsc-index.json — a flat index of every SID in HVSC with
 * title, author, and released fields parsed from the PSID/RSID header.
 *
 * Usage:
 *   node tools/build-hvsc-index.js                  # full crawl
 *   node tools/build-hvsc-index.js --root <path>    # crawl a subtree
 *   node tools/build-hvsc-index.js --concurrency N  # header-fetch parallelism
 *   node tools/build-hvsc-index.js --patch          # backfill paths listed in
 *                                                     hvsc-index.failed.json
 *   node tools/build-hvsc-index.js --patch PATH...  # backfill the given paths
 *
 * In --patch mode, the existing hvsc-index.json is loaded and any newly
 * crawled entries are merged in (replacing duplicates by path). Useful after
 * a full run where a few directories timed out.
 *
 * The crawler walks directory listings on hvsc.etv.cx and fetches the first
 * 128 bytes of each .sid via an HTTP Range request so it only pulls the
 * metadata, not the full file. Expect ~30-60 minutes for a full run.
 *
 * Output format (compact keys to keep the file small):
 *   { v: 1, generated: "2026-...", count: N, entries: [ {p, t, a, r}, ... ] }
 *     p = path (relative to hvsc root, e.g. "C64Music/MUSICIANS/H/Hubbard_Rob/Commando.sid")
 *     t = title
 *     a = author
 *     r = released
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const HVSC_ORIGIN = 'https://hvsc.etv.cx';
const OUTPUT = path.join(__dirname, '..', 'public', 'hvsc-index.json');
const FAILED_OUTPUT = path.join(__dirname, '..', 'public', 'hvsc-index.failed.json');

const { flags, positional } = parseArgs(process.argv.slice(2));
const ROOT = flags.root || 'C64Music';
const CONCURRENCY = parseInt(flags.concurrency || '8', 10);
const RETRY_ATTEMPTS = 4;
const RETRY_DELAY_BASE_MS = 1000;
const PATCH_MODE = !!flags.patch;

function parseArgs(argv) {
    const flags = {};
    const positional = [];
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a.startsWith('--')) {
            const key = a.slice(2);
            const next = argv[i + 1];
            // Only --root and --concurrency consume the following token as a
            // value; everything else is a boolean flag (so --patch path1 path2
            // leaves the paths as positional args).
            if ((key === 'root' || key === 'concurrency') && next && !next.startsWith('--')) {
                flags[key] = next; i++;
            } else {
                flags[key] = true;
            }
        } else {
            positional.push(a);
        }
    }
    return { flags, positional };
}

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

function isRetryable(err) {
    const msg = err && err.message ? err.message : '';
    if (err && (err.code === 'ECONNRESET' || err.code === 'ETIMEDOUT' ||
                err.code === 'ECONNREFUSED' || err.code === 'EAI_AGAIN')) return true;
    if (/socket hang up|Timeout|ECONN|network|EAI_AGAIN|503|502|504|429/i.test(msg)) return true;
    return false;
}

function fetchBufferOnce(url, { headers = {} } = {}) {
    return new Promise((resolve, reject) => {
        const req = https.get(url, { headers }, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                res.resume();
                resolve(fetchBufferOnce(new URL(res.headers.location, url).toString(), { headers }));
                return;
            }
            if (res.statusCode !== 200 && res.statusCode !== 206) {
                res.resume();
                const err = new Error(`HTTP ${res.statusCode} for ${url}`);
                err.statusCode = res.statusCode;
                reject(err);
                return;
            }
            const chunks = [];
            res.on('data', (c) => chunks.push(c));
            res.on('end', () => resolve(Buffer.concat(chunks)));
            res.on('error', reject);
        });
        req.on('error', reject);
        req.setTimeout(30000, () => { req.destroy(new Error('Timeout')); });
    });
}

async function fetchBuffer(url, opts) {
    let lastErr;
    for (let attempt = 0; attempt < RETRY_ATTEMPTS; attempt++) {
        try {
            return await fetchBufferOnce(url, opts);
        } catch (err) {
            lastErr = err;
            if (!isRetryable(err) || attempt === RETRY_ATTEMPTS - 1) break;
            const delay = RETRY_DELAY_BASE_MS * Math.pow(3, attempt);
            await sleep(delay);
        }
    }
    throw lastErr;
}

async function fetchText(url) {
    const buf = await fetchBuffer(url);
    return buf.toString('utf8');
}

function parseListing(html) {
    const dirs = [];
    const files = [];
    const tableMatch = html.match(/<table[^>]*>([\s\S]*?)<\/table>/i);
    const scope = tableMatch ? tableMatch[1] : html;
    const rowRegex = /<a\s+href="([^"]+)"[^>]*>(?:<img[^>]*>)?([^<]+)<\/a>/gi;
    let m;
    while ((m = rowRegex.exec(scope)) !== null) {
        const href = m[1];
        const text = m[2].trim();
        if (!text || text === '..' || text === '.' || text === 'Home' ||
            text === 'About' || text === 'HVSC' || text === 'SidSearch' ||
            text === 'Parent Directory') continue;
        if (href.startsWith('http://') || href.startsWith('https://') || href === '#') continue;

        if (href.startsWith('?path=') && !href.includes('info=')) {
            let p = decodeURIComponent(href.substring(6));
            if (p.endsWith('/')) p = p.slice(0, -1);
            dirs.push(p);
        } else if (href.includes('info=please') && href.includes('.sid')) {
            const pm = href.match(/path=([^&]+)/);
            if (pm) files.push(decodeURIComponent(pm[1]));
        } else if (href.endsWith('.sid')) {
            // Direct relative .sid link (rare on this mirror, but handle it).
            files.push(href.replace(/^\//, ''));
        }
    }
    return { dirs: unique(dirs), files: unique(files) };
}

function unique(arr) { return Array.from(new Set(arr)); }

function readNullString(buf, offset, length) {
    const end = Math.min(offset + length, buf.length);
    let s = '';
    for (let i = offset; i < end; i++) {
        const b = buf[i];
        if (b === 0) break;
        s += String.fromCharCode(b);
    }
    return s.trim();
}

function parseSidHeader(buf) {
    if (buf.length < 0x76) return null;
    const magic = buf.toString('ascii', 0, 4);
    if (magic !== 'PSID' && magic !== 'RSID') return null;
    return {
        t: readNullString(buf, 0x16, 32),
        a: readNullString(buf, 0x36, 32),
        r: readNullString(buf, 0x56, 32),
    };
}

async function fetchSidHeader(sidPath) {
    const url = `${HVSC_ORIGIN}/${sidPath}`;
    const buf = await fetchBuffer(url, { headers: { Range: 'bytes=0-127' } });
    return parseSidHeader(buf);
}

/**
 * Crawl one or more HVSC directory roots, collecting .sid paths.
 * @param {string[]} roots Directory paths to start from.
 * @returns {Promise<{sidPaths: string[], failedDirs: string[]}>}
 */
async function crawl(roots) {
    const queue = roots.slice();
    const visited = new Set();
    const sidPaths = [];
    const failedDirs = [];
    let dirCount = 0;

    while (queue.length) {
        const dir = queue.shift();
        if (visited.has(dir)) continue;
        visited.add(dir);
        dirCount++;
        try {
            const html = await fetchText(`${HVSC_ORIGIN}/?path=${encodeURIComponent(dir)}`);
            const { dirs, files } = parseListing(html);
            for (const d of dirs) {
                if (!visited.has(d) && (d === dir || d.startsWith(dir + '/') || roots.some((r) => d.startsWith(r)))) {
                    queue.push(d);
                }
            }
            for (const f of files) sidPaths.push(f);
            if (dirCount % 50 === 0) {
                process.stderr.write(`  crawled ${dirCount} dirs, ${sidPaths.length} SIDs, ${queue.length} pending\n`);
            }
        } catch (err) {
            process.stderr.write(`  ! dir failed: ${dir} (${err.message})\n`);
            failedDirs.push(dir);
        }
    }

    // Second pass for directories that failed despite in-request retries.
    if (failedDirs.length) {
        process.stderr.write(`Retrying ${failedDirs.length} failed directories...\n`);
        const stillFailed = [];
        for (const dir of failedDirs) {
            try {
                const html = await fetchText(`${HVSC_ORIGIN}/?path=${encodeURIComponent(dir)}`);
                const { dirs, files } = parseListing(html);
                for (const d of dirs) {
                    if (!visited.has(d)) queue.push(d);
                }
                for (const f of files) sidPaths.push(f);
                // Drain any subdirs newly queued by this recovered root.
                while (queue.length) {
                    const sub = queue.shift();
                    if (visited.has(sub)) continue;
                    visited.add(sub);
                    try {
                        const subHtml = await fetchText(`${HVSC_ORIGIN}/?path=${encodeURIComponent(sub)}`);
                        const subParsed = parseListing(subHtml);
                        for (const d of subParsed.dirs) if (!visited.has(d)) queue.push(d);
                        for (const f of subParsed.files) sidPaths.push(f);
                    } catch (subErr) {
                        process.stderr.write(`  ! still failing: ${sub} (${subErr.message})\n`);
                        stillFailed.push(sub);
                    }
                }
            } catch (err) {
                process.stderr.write(`  ! still failing: ${dir} (${err.message})\n`);
                stillFailed.push(dir);
            }
        }
        return { sidPaths: unique(sidPaths), failedDirs: stillFailed };
    }

    return { sidPaths: unique(sidPaths), failedDirs: [] };
}

async function buildIndex(sidPaths) {
    const entries = [];
    const failedPaths = [];
    let done = 0;
    const total = sidPaths.length;

    async function worker(slice) {
        for (const p of slice) {
            try {
                const meta = await fetchSidHeader(p);
                if (meta) entries.push({ p, ...meta });
                else failedPaths.push(p);
            } catch (err) {
                failedPaths.push(p);
            }
            done++;
            if (done % 500 === 0) {
                process.stderr.write(`  headers: ${done}/${total} (failed so far: ${failedPaths.length})\n`);
            }
        }
    }

    const slices = Array.from({ length: CONCURRENCY }, () => []);
    sidPaths.forEach((p, i) => slices[i % CONCURRENCY].push(p));
    await Promise.all(slices.map(worker));

    entries.sort((a, b) => a.p.localeCompare(b.p));
    return { entries, failedPaths };
}

function loadExistingIndex() {
    if (!fs.existsSync(OUTPUT)) return null;
    try {
        return JSON.parse(fs.readFileSync(OUTPUT, 'utf8'));
    } catch (err) {
        console.error(`Could not parse existing ${OUTPUT}: ${err.message}`);
        return null;
    }
}

function writeOutputs(entries, stillFailed, { mergeWith } = {}) {
    let finalEntries = entries;
    if (mergeWith && Array.isArray(mergeWith.entries)) {
        const byPath = new Map();
        for (const e of mergeWith.entries) byPath.set(e.p, e);
        for (const e of entries) byPath.set(e.p, e);
        finalEntries = Array.from(byPath.values()).sort((a, b) => a.p.localeCompare(b.p));
    }

    const out = {
        v: 1,
        generated: new Date().toISOString(),
        root: ROOT,
        count: finalEntries.length,
        entries: finalEntries,
    };
    fs.writeFileSync(OUTPUT, JSON.stringify(out));
    const mb = (fs.statSync(OUTPUT).size / 1024 / 1024).toFixed(2);
    console.error(`Wrote ${OUTPUT} (${mb} MB, ${finalEntries.length} entries)`);

    if (stillFailed && stillFailed.length) {
        fs.writeFileSync(FAILED_OUTPUT, JSON.stringify({
            generated: new Date().toISOString(),
            paths: stillFailed,
        }, null, 2));
        console.error(`Wrote ${FAILED_OUTPUT} (${stillFailed.length} paths). `
            + `Re-run with --patch to retry them.`);
    } else if (fs.existsSync(FAILED_OUTPUT)) {
        fs.unlinkSync(FAILED_OUTPUT);
        console.error(`Removed stale ${FAILED_OUTPUT} (nothing left to patch).`);
    }
}

async function runFullCrawl() {
    console.error(`Crawling ${HVSC_ORIGIN} starting at ${ROOT} (concurrency=${CONCURRENCY})`);
    const t0 = Date.now();
    const { sidPaths, failedDirs } = await crawl([ROOT]);
    console.error(`Found ${sidPaths.length} SID files in ${((Date.now() - t0) / 1000).toFixed(1)}s`);

    console.error('Fetching SID headers...');
    const { entries, failedPaths } = await buildIndex(sidPaths);
    console.error(`Parsed ${entries.length} headers (${failedPaths.length} failed)`);

    const stillFailed = unique([...failedDirs, ...failedPaths]);
    writeOutputs(entries, stillFailed);
}

async function runPatch() {
    const existing = loadExistingIndex();
    if (!existing) {
        console.error(`No existing ${OUTPUT} found. Run a full crawl first.`);
        process.exit(1);
    }

    let patchPaths = positional.slice();
    if (patchPaths.length === 0) {
        if (!fs.existsSync(FAILED_OUTPUT)) {
            console.error(`No paths given and no ${FAILED_OUTPUT} found. Nothing to patch.`);
            process.exit(1);
        }
        const failed = JSON.parse(fs.readFileSync(FAILED_OUTPUT, 'utf8'));
        patchPaths = failed.paths || [];
    }

    if (patchPaths.length === 0) {
        console.error('No paths to patch.');
        return;
    }

    // Normalize: strip leading and trailing slashes.
    patchPaths = patchPaths.map((p) => p.replace(/^\/+|\/+$/g, ''));

    const dirPaths = patchPaths.filter((p) => !p.endsWith('.sid'));
    const filePaths = patchPaths.filter((p) => p.endsWith('.sid'));

    console.error(`Patch mode: ${dirPaths.length} dirs + ${filePaths.length} files to backfill`);

    let sidPaths = filePaths.slice();
    let failedDirs = [];
    if (dirPaths.length) {
        const res = await crawl(dirPaths);
        sidPaths = unique([...sidPaths, ...res.sidPaths]);
        failedDirs = res.failedDirs;
    }

    console.error(`Fetching ${sidPaths.length} SID headers...`);
    const { entries, failedPaths } = await buildIndex(sidPaths);
    console.error(`Parsed ${entries.length} headers (${failedPaths.length} failed)`);

    const stillFailed = unique([...failedDirs, ...failedPaths]);
    writeOutputs(entries, stillFailed, { mergeWith: existing });
}

(async function main() {
    if (PATCH_MODE) await runPatch();
    else await runFullCrawl();
})().catch((err) => {
    console.error('Fatal:', err);
    process.exit(1);
});
