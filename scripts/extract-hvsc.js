#!/usr/bin/env node
/*
 * Extracts the committed HVSC archive into public/HVSC/ so the site can serve
 * the raw .sid files statically. Run locally once after cloning, and by the
 * Netlify build (see netlify.toml) on every deploy.
 *
 * The archive lives in hvsc-data/ (committed) as a single .7z or .zip whose
 * top-level entry is "C64Music/...". After extraction the tree is:
 *   public/HVSC/C64Music/...
 *
 * If public/HVSC/C64Music already exists and --force is not passed, extraction
 * is skipped (so local dev doesn't re-extract 61k files every time).
 *
 * Usage:
 *   node scripts/extract-hvsc.js            # extract if not already present
 *   node scripts/extract-hvsc.js --force    # always re-extract
 */

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const sevenBin = require('7zip-bin');

const ROOT = path.join(__dirname, '..');
const ARCHIVE_DIR = path.join(ROOT, 'hvsc-data');
const DEST = path.join(ROOT, 'public', 'HVSC');
const MARKER = path.join(DEST, 'C64Music');
const FORCE = process.argv.includes('--force');

function findArchive() {
    if (!fs.existsSync(ARCHIVE_DIR)) return null;
    const candidates = fs.readdirSync(ARCHIVE_DIR)
        .filter((f) => /\.(7z|zip)$/i.test(f))
        .sort();
    return candidates.length ? path.join(ARCHIVE_DIR, candidates[0]) : null;
}

function main() {
    if (fs.existsSync(MARKER) && !FORCE) {
        console.error(`public/HVSC/C64Music already present — skipping extract `
            + `(use --force to re-extract).`);
        return;
    }

    const archive = findArchive();
    if (!archive) {
        console.error(`No HVSC archive found in ${ARCHIVE_DIR} (expected a .7z or .zip).`);
        console.error(`Drop the HVSC archive there (its top folder should be C64Music/).`);
        // Non-fatal so a Netlify build without the archive still publishes the
        // rest of the site; HVSC browsing just won't have files to serve.
        process.exit(0);
    }

    console.error(`Extracting ${path.basename(archive)} -> public/HVSC/ ...`);
    fs.mkdirSync(DEST, { recursive: true });

    // The bundled 7za can lose its exec bit through npm install; restore it.
    try { fs.chmodSync(sevenBin.path7za, 0o755); } catch (_) { /* best effort */ }

    // 7za x <archive> -o<dest> -y  (handles both .7z and .zip)
    const res = spawnSync(sevenBin.path7za, ['x', archive, `-o${DEST}`, '-y'], {
        stdio: ['ignore', 'ignore', 'inherit'],
    });
    if (res.status !== 0) {
        console.error(`Extraction failed (7za exit ${res.status}).`);
        process.exit(1);
    }

    if (!fs.existsSync(MARKER)) {
        console.error(`Warning: extracted archive but public/HVSC/C64Music not found. `
            + `Check the archive's top-level folder is named C64Music.`);
    }
    console.error('HVSC extraction complete.');
}

main();
