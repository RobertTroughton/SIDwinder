#!/usr/bin/env node
/*
 * Builds public/hvsc-index.json — a flat index of every SID in HVSC with
 * title, author, and released fields parsed from the PSID/RSID header.
 *
 * Usage:  node tools/build-hvsc-index.js [--root C64Music] [--concurrency 8]
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

const args = parseArgs(process.argv.slice(2));
const ROOT = args.root || 'C64Music';
const CONCURRENCY = parseInt(args.concurrency || '8', 10);

function parseArgs(argv) {
    const out = {};
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a.startsWith('--')) {
            const key = a.slice(2);
            const next = argv[i + 1];
            if (next && !next.startsWith('--')) { out[key] = next; i++; }
            else { out[key] = true; }
        }
    }
    return out;
}

function fetchBuffer(url, { headers = {} } = {}) {
    return new Promise((resolve, reject) => {
        const req = https.get(url, { headers }, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                res.resume();
                resolve(fetchBuffer(new URL(res.headers.location, url).toString(), { headers }));
                return;
            }
            if (res.statusCode !== 200 && res.statusCode !== 206) {
                res.resume();
                reject(new Error(`HTTP ${res.statusCode} for ${url}`));
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
            // Direct relative .sid link (rare on this mirror, but handle it)
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

async function crawl() {
    const queue = [ROOT];
    const visited = new Set();
    const sidPaths = [];
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
                if (!visited.has(d) && d.startsWith(ROOT)) queue.push(d);
            }
            for (const f of files) sidPaths.push(f);
            if (dirCount % 50 === 0) {
                process.stderr.write(`  crawled ${dirCount} dirs, ${sidPaths.length} SIDs, ${queue.length} pending\n`);
            }
        } catch (err) {
            process.stderr.write(`  ! dir failed: ${dir} (${err.message})\n`);
        }
    }

    return unique(sidPaths);
}

async function buildIndex(sidPaths) {
    const entries = [];
    let done = 0, failed = 0;
    const total = sidPaths.length;

    async function worker(slice) {
        for (const p of slice) {
            try {
                const meta = await fetchSidHeader(p);
                if (meta) entries.push({ p, ...meta });
                else failed++;
            } catch (err) {
                failed++;
            }
            done++;
            if (done % 500 === 0) {
                process.stderr.write(`  headers: ${done}/${total} (failed: ${failed})\n`);
            }
        }
    }

    const slices = Array.from({ length: CONCURRENCY }, () => []);
    sidPaths.forEach((p, i) => slices[i % CONCURRENCY].push(p));
    await Promise.all(slices.map(worker));

    entries.sort((a, b) => a.p.localeCompare(b.p));
    return { entries, failed };
}

(async function main() {
    console.error(`Crawling ${HVSC_ORIGIN} starting at ${ROOT} (concurrency=${CONCURRENCY})`);
    const t0 = Date.now();
    const sidPaths = await crawl();
    console.error(`Found ${sidPaths.length} SID files in ${((Date.now() - t0) / 1000).toFixed(1)}s`);

    console.error('Fetching SID headers...');
    const { entries, failed } = await buildIndex(sidPaths);
    console.error(`Parsed ${entries.length} headers (${failed} failed)`);

    const out = {
        v: 1,
        generated: new Date().toISOString(),
        root: ROOT,
        count: entries.length,
        entries,
    };
    fs.writeFileSync(OUTPUT, JSON.stringify(out));
    const mb = (fs.statSync(OUTPUT).size / 1024 / 1024).toFixed(2);
    console.error(`Wrote ${OUTPUT} (${mb} MB, ${entries.length} entries)`);
})().catch((err) => {
    console.error('Fatal:', err);
    process.exit(1);
});
