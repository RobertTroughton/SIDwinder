#!/usr/bin/env node
/*
 * Builds public/hvsc-index.json — a flat index of every SID in the locally
 * hosted HVSC mirror (public/HVSC/) with title, author and released parsed
 * from the PSID/RSID header, plus a folded-in STIL text field for full-text
 * search.
 *
 * SIDwinder now self-hosts HVSC as static files under public/HVSC/, so this
 * script reads the collection straight off disk — no network crawl. A full
 * run takes seconds, not the 30-60 minutes the old proxy-based crawler needed.
 *
 * Usage:
 *   node tools/build-hvsc-index.js                 # index public/HVSC
 *   node tools/build-hvsc-index.js --root <dir>    # index a different tree
 *   node tools/build-hvsc-index.js --out <file>    # write somewhere else
 *   node tools/build-hvsc-index.js --version 85    # record the HVSC update #
 *
 * The HVSC update number is stored in the index as "hvsc" and shown in the
 * browser UI. If --version is omitted, the builder tries to detect it from
 * DOCUMENTS/HVSC.txt; pass --version to be certain.
 *
 * The --root directory is the HVSC content root: the folder that CONTAINS
 * C64Music (so index paths look like "C64Music/MUSICIANS/...", matching the
 * URLs the site serves from /HVSC/...). STIL is read from
 * <root>/C64Music/DOCUMENTS/STIL.txt when present.
 *
 * Output format (compact keys to keep the file small):
 *   { v: 2, generated, root, count, entries: [ {p, t, a, r, s?}, ... ] }
 *     p = path relative to the HVSC content root
 *         (e.g. "C64Music/MUSICIANS/H/Hubbard_Rob/Commando.sid")
 *     t = title       (from SID header)
 *     a = author      (from SID header)
 *     r = released    (from SID header)
 *     s = STIL text   (comments/trivia, folded for search; omitted if none)
 */

const fs = require('fs');
const path = require('path');

const { flags } = parseArgs(process.argv.slice(2));
const ROOT = path.resolve(flags.root || path.join(__dirname, '..', 'public', 'HVSC'));
const OUTPUT = path.resolve(flags.out || path.join(__dirname, '..', 'public', 'hvsc-index.json'));

// Cap folded STIL text per entry so a handful of essay-length comments can't
// balloon the index. Search still matches within this window.
const MAX_STIL_CHARS = 2000;

function parseArgs(argv) {
    const flags = {};
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a.startsWith('--')) {
            const key = a.slice(2);
            const next = argv[i + 1];
            if ((key === 'root' || key === 'out' || key === 'version') && next && !next.startsWith('--')) {
                flags[key] = next; i++;
            } else {
                flags[key] = true;
            }
        }
    }
    return { flags };
}

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

/** Read just the 0x76-byte header of a SID file. */
function readSidHeader(absPath) {
    const fd = fs.openSync(absPath, 'r');
    try {
        const buf = Buffer.alloc(0x80);
        const n = fs.readSync(fd, buf, 0, 0x80, 0);
        return parseSidHeader(buf.subarray(0, n));
    } finally {
        fs.closeSync(fd);
    }
}

/** Recursively collect every .sid path (relative to ROOT, forward slashes). */
function walkSids(dir, relBase, out) {
    let dirents;
    try {
        dirents = fs.readdirSync(dir, { withFileTypes: true });
    } catch (err) {
        process.stderr.write(`  ! cannot read ${dir}: ${err.message}\n`);
        return;
    }
    for (const de of dirents) {
        const abs = path.join(dir, de.name);
        const rel = relBase ? `${relBase}/${de.name}` : de.name;
        if (de.isDirectory()) {
            walkSids(abs, rel, out);
        } else if (de.isFile() && de.name.toLowerCase().endsWith('.sid')) {
            out.push(rel);
        }
    }
}

/**
 * Parse DOCUMENTS/STIL.txt into two maps of folded, search-friendly text:
 *   fileText: "C64Music/<path>.sid" -> text
 *   dirText:  "C64Music/<dir>/"      -> text (applies to every SID in that dir)
 *
 * STIL entries are keyed by a path line starting with "/" (relative to the
 * C64Music root). File entries end in ".sid"; directory-wide entries end in
 * "/". Everything between one path line and the next is that entry's block;
 * we strip "FIELD:" labels and "(#n)" subtune markers and keep the prose.
 */
function parseStil(stilPath) {
    const fileText = new Map();
    const dirText = new Map();
    let raw;
    try {
        raw = fs.readFileSync(stilPath, 'latin1');
    } catch (err) {
        return { fileText, dirText };
    }

    const lines = raw.split(/\r?\n/);
    let curKey = null;
    let buf = [];

    const flush = () => {
        if (!curKey) return;
        const text = cleanStilBlock(buf);
        if (text) {
            const full = 'C64Music' + curKey;
            if (curKey.endsWith('/')) dirText.set(full, text);
            else fileText.set(full, text);
        }
        buf = [];
    };

    for (const line of lines) {
        // A path line is an unindented "/..." that names a .sid or a directory.
        if (/^\/.*\.sid$/i.test(line) || /^\/.*\/$/.test(line)) {
            flush();
            curKey = line.trim();
        } else if (curKey) {
            buf.push(line);
        }
    }
    flush();

    return { fileText, dirText };
}

function cleanStilBlock(lines) {
    const parts = [];
    for (let line of lines) {
        line = line.replace(/^\s+/, '');
        if (!line) continue;
        line = line.replace(/^\(#\d+\)\s*/, '');          // subtune marker
        line = line.replace(/^[A-Z][A-Z ]{1,20}:\s*/, ''); // FIELD: label
        line = line.trim();
        if (line) parts.push(line);
    }
    let text = parts.join(' ').replace(/\s+/g, ' ').trim();
    if (text.length > MAX_STIL_CHARS) text = text.slice(0, MAX_STIL_CHARS);
    return text;
}

/** STIL text for a SID path = its own entry plus any parent-dir entries. */
function stilFor(relPath, fileText, dirText) {
    const pieces = [];
    if (fileText.has(relPath)) pieces.push(fileText.get(relPath));
    // Walk up the directory chain accumulating dir-wide comments.
    let dir = relPath.slice(0, relPath.lastIndexOf('/') + 1);
    while (dir.length > 'C64Music/'.length) {
        if (dirText.has(dir)) pieces.push(dirText.get(dir));
        const parent = dir.slice(0, dir.lastIndexOf('/', dir.length - 2) + 1);
        if (parent === dir) break;
        dir = parent;
    }
    if (!pieces.length) return '';
    let text = pieces.join(' ').replace(/\s+/g, ' ').trim();
    if (text.length > MAX_STIL_CHARS) text = text.slice(0, MAX_STIL_CHARS);
    return text;
}

/**
 * Best-effort HVSC update number, from DOCUMENTS/HVSC.txt. The file header
 * names the release (e.g. "Update #85" / "Release 85"); pass --version to
 * override if the format ever changes.
 */
function detectVersion(root) {
    try {
        const txt = fs.readFileSync(
            path.join(root, 'C64Music', 'DOCUMENTS', 'HVSC.txt'), 'latin1'
        ).slice(0, 4000);
        const m = txt.match(/(?:Update|Release|Version)\s*#?\s*(\d{2,3})\b/i);
        if (m) return m[1];
    } catch (_) { /* no HVSC.txt */ }
    return null;
}

function main() {
    if (!fs.existsSync(ROOT)) {
        console.error(`HVSC root not found: ${ROOT}`);
        console.error(`Extract HVSC into public/HVSC/ (so public/HVSC/C64Music exists) `
            + `or pass --root <dir>.`);
        process.exit(1);
    }

    const t0 = Date.now();
    console.error(`Indexing ${ROOT}`);

    const sidRel = [];
    walkSids(ROOT, '', sidRel);
    sidRel.sort((a, b) => a.localeCompare(b));
    console.error(`Found ${sidRel.length} SID files`);

    const stilPath = path.join(ROOT, 'C64Music', 'DOCUMENTS', 'STIL.txt');
    const { fileText, dirText } = parseStil(stilPath);
    console.error(fs.existsSync(stilPath)
        ? `Parsed STIL: ${fileText.size} file entries, ${dirText.size} dir entries`
        : `No STIL.txt at ${stilPath} (continuing without comments)`);

    const entries = [];
    let headerFails = 0;
    for (const rel of sidRel) {
        let meta;
        try {
            meta = readSidHeader(path.join(ROOT, rel));
        } catch (err) {
            meta = null;
        }
        if (!meta) { headerFails++; continue; }
        const entry = { p: rel, t: meta.t, a: meta.a, r: meta.r };
        const s = stilFor(rel, fileText, dirText);
        if (s) entry.s = s;
        entries.push(entry);
    }

    if (headerFails) console.error(`  (${headerFails} files had unreadable headers)`);

    const version = (typeof flags.version === 'string' ? flags.version : null)
        || detectVersion(ROOT);
    console.error(version
        ? `HVSC version: #${version}`
        : `HVSC version: unknown (pass --version <N> to record it)`);

    const out = {
        v: 2,
        generated: new Date().toISOString(),
        root: 'C64Music',
        hvsc: version || null,
        count: entries.length,
        entries,
    };
    fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
    fs.writeFileSync(OUTPUT, JSON.stringify(out));
    const mb = (fs.statSync(OUTPUT).size / 1024 / 1024).toFixed(2);
    console.error(`Wrote ${OUTPUT} (${mb} MB, ${entries.length} entries) `
        + `in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
}

main();
