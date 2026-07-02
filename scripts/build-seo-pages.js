#!/usr/bin/env node
/*
 * Generates crawlable per-composer landing pages from public/hvsc-index.json,
 * plus a composer hub and a sitemap. The goal: searches like "c64 music by
 * Drax" find SIDquake (real, indexable text about each composer and their
 * tunes) and land on our site — never on a raw .sid download link.
 *
 * Each page lists the composer's tunes (title + year) as crawlable HTML with
 * schema.org data, and embeds the SIDquake HVSC player (iframe) so visitors
 * can browse and play right there.
 *
 * Output (all gitignored; regenerated at build — see netlify.toml):
 *   public/music/index.html        composer A–Z hub
 *   public/music/<slug>.html       one page per composer
 *   public/sitemap.xml             main pages + every composer page
 *
 * Usage:  node scripts/build-seo-pages.js [--out <publicDir>] [--base <url>]
 */

const fs = require('fs');
const path = require('path');

const { flags } = parseArgs(process.argv.slice(2));
const PUBLIC = path.resolve(flags.out || path.join(__dirname, '..', 'public'));
const INDEX = path.join(PUBLIC, 'hvsc-index.json');
const MUSIC_DIR = path.join(PUBLIC, 'music');
const BASE_URL = (flags.base || process.env.SITE_URL || 'https://sidquake.c64demo.com')
    .replace(/\/+$/, '');

function parseArgs(argv) {
    const flags = {};
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a.startsWith('--')) {
            const key = a.slice(2);
            const next = argv[i + 1];
            if (next && !next.startsWith('--')) { flags[key] = next; i++; }
            else flags[key] = true;
        }
    }
    return { flags };
}

function escapeHtml(str) {
    return String(str)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function escapeXml(str) {
    return String(str)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&apos;');
}

function slugify(name) {
    return name.toLowerCase()
        .normalize('NFKD').replace(/[̀-ͯ]/g, '') // strip accents
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .slice(0, 80) || 'unknown';
}

function yearLabel(r) {
    const tok = (r || '').trim().split(/\s+/)[0] || '';
    return /\d/.test(tok) ? tok : '';
}

function isUnknown(s) {
    const t = (s || '').trim();
    return !t || t === '<?>' || /^\?+$/.test(t);
}

/** Normalized identity token: lowercase, de-accented, alnum-collapsed. */
function norm(s) {
    return s.toLowerCase().normalize('NFKD').replace(/[̀-ͯ]/g, '')
        .replace(/[^a-z0-9]+/g, ' ').trim();
}

/** Split an AUTHOR field into individual contributors (outside parentheses). */
function splitCollaborators(a) {
    const parts = [];
    let depth = 0, cur = '';
    for (const ch of a) {
        if (ch === '(') depth++;
        else if (ch === ')') depth = Math.max(0, depth - 1);
        if (depth === 0 && (ch === '&' || ch === ',' || ch === ';' || ch === '+')) {
            parts.push(cur); cur = '';
        } else { cur += ch; }
    }
    parts.push(cur);
    return parts.map((s) => s.trim()).filter(Boolean);
}

/** Parse one contributor into {real, alias}. HVSC form: "Real Name (Handle)". */
function parsePart(p) {
    p = p.replace(/<\?>/g, ' ').replace(/\s+/g, ' ').trim(); // drop uncertainty marks
    const m = p.match(/^(.*?)\s*\(([^)]*)\)\s*$/);
    let real = '', alias = '';
    if (m) {
        real = m[1].trim();
        alias = (m[2].split('/')[0] || '').trim(); // handle before any /group
    } else if (/\s/.test(p)) {
        real = p.trim();            // multi-word, no parens -> treat as a real name
    } else {
        alias = p.trim();           // single token -> treat as a handle/alias
    }
    if (isUnknown(real)) real = '';
    if (isUnknown(alias)) alias = '';
    return { real, alias };
}

function parseCredits(a) {
    if (isUnknown(a)) return [];
    return splitCollaborators(a).map(parsePart).filter((x) => x.real || x.alias);
}

function bump(map, key) { map.set(key, (map.get(key) || 0) + 1); }
function bump2(map, k1, k2) {
    if (!map.has(k1)) map.set(k1, new Map());
    bump(map.get(k1), k2);
}
function topKey(map) {
    let best = null, bestN = -1;
    if (!map) return null;
    for (const [k, n] of map) if (n > bestN) { bestN = n; best = k; }
    return best;
}

/**
 * Canonicalize composers so every credit for an artist — solo, in a
 * collaboration, by real name, or by handle — collapses to one entity.
 *
 * Strategy: prefer the REAL NAME as the identity. This naturally unifies people
 * who use several handles (e.g. JCH / Chordian both -> Jens-Christian Huus).
 * Credits that are handle-only fold into that handle's dominant real name; a
 * handle never seen with a real name keys by itself. The handle is added to the
 * display title only when it's actually dominant, so a one-off stray credit
 * (e.g. "Rob Hubbard (Ample Hamble)") never mislabels a page.
 */
function buildComposers(entries) {
    const realDisp = new Map();       // realNorm  -> Map(realOrig  -> count)
    const aliasDisp = new Map();      // aliasNorm -> Map(aliasOrig -> count)
    const realAliasCount = new Map(); // realNorm  -> Map(aliasNorm -> count)  (both present)
    const aliasRealCount = new Map(); // aliasNorm -> Map(realNorm  -> count)  (both present)

    for (const e of entries) {
        for (const { real, alias } of parseCredits(e.a)) {
            if (real) bump2(realDisp, norm(real), real);
            if (alias) bump2(aliasDisp, norm(alias), alias);
            if (real && alias) {
                bump2(realAliasCount, norm(real), norm(alias));
                bump2(aliasRealCount, norm(alias), norm(real));
            }
        }
    }

    // A handle's dominant real name, so handle-only credits fold into the real
    // person (e.g. a bare "DRAX" -> Thomas Mogensen).
    const aliasToReal = new Map();
    for (const [an, reals] of aliasRealCount) aliasToReal.set(an, topKey(reals));

    const keyFor = (real, alias) => {
        if (real) return 'r:' + norm(real);
        if (alias) {
            const an = norm(alias);
            return aliasToReal.has(an) ? 'r:' + aliasToReal.get(an) : 'a:' + an;
        }
        return null;
    };

    const entities = new Map(); // key -> Map(path -> entry)
    for (const e of entries) {
        const keys = new Set();
        for (const { real, alias } of parseCredits(e.a)) {
            const k = keyFor(real, alias);
            if (k) keys.add(k);
        }
        for (const k of keys) {
            if (!entities.has(k)) entities.set(k, new Map());
            entities.get(k).set(e.p, e);
        }
    }

    const handleOf = (an) => topKey(aliasDisp.get(an)) || an;

    const usedSlugs = new Set();
    const composers = [];
    for (const [key, tuneMap] of entities) {
        let name, aka = [];
        if (key.startsWith('r:')) {
            const rn = key.slice(2);
            const realName = topKey(realDisp.get(rn)) || rn;
            const aliasCounts = realAliasCount.get(rn);
            name = realName;
            if (aliasCounts) {
                const bestAn = topKey(aliasCounts);
                const bestCount = aliasCounts.get(bestAn);
                // Only title a handle that's genuinely representative.
                if (bestCount >= 8 && bestCount >= 0.15 * tuneMap.size) {
                    name = `${realName} (${handleOf(bestAn)})`;
                }
                aka = [...aliasCounts.keys()]
                    .sort((a, b) => aliasCounts.get(b) - aliasCounts.get(a))
                    .map(handleOf)
                    .filter((h) => !name.includes(`(${h})`));
            }
        } else {
            name = handleOf(key.slice(2)); // handle never seen with a real name
        }

        let slug = slugify(name);
        if (usedSlugs.has(slug)) {
            let n = 2;
            while (usedSlugs.has(`${slug}-${n}`)) n++;
            slug = `${slug}-${n}`;
        }
        usedSlugs.add(slug);

        const tunes = [...tuneMap.values()]
            .sort((a, b) => (a.t || a.p).localeCompare(b.t || b.p));
        composers.push({ name, slug, tunes, aka });
    }

    composers.sort((a, b) => a.name.localeCompare(b.name));
    return composers;
}

/** Folder of a SID path, e.g. C64Music/MUSICIANS/H/Hubbard_Rob. */
function folderOf(p) {
    const i = p.lastIndexOf('/');
    return i === -1 ? '' : p.substring(0, i);
}

function mostCommon(arr) {
    const counts = new Map();
    let best = arr[0], bestN = 0;
    for (const v of arr) {
        const n = (counts.get(v) || 0) + 1;
        counts.set(v, n);
        if (n > bestN) { bestN = n; best = v; }
    }
    return best;
}

function pageHtml(composer) {
    const { name, slug, tunes, aka = [] } = composer;
    const akaLine = aka.length
        ? `<p class="seo-aka">Also credited as: ${escapeHtml(aka.slice(0, 8).join(', '))}</p>`
        : '';
    const canonical = `${BASE_URL}/music/${slug}.html`;
    const count = tunes.length;
    const primaryFolder = mostCommon(tunes.map((t) => folderOf(t.p)));
    const embedSrc = `/hvsc-embed.html?mode=play&start=${encodeURIComponent(primaryFolder)}`;
    const desc = `Listen to ${count} C64 SID tune${count === 1 ? '' : 's'} by ${name} `
        + `from the High Voltage SID Collection, hosted on SIDquake.`;

    // schema.org: the composer as a MusicGroup with their recordings.
    const jsonld = {
        '@context': 'https://schema.org',
        '@type': 'MusicGroup',
        name,
        url: canonical,
        genre: 'Commodore 64 SID music',
        track: tunes.slice(0, 200).map((t) => ({
            '@type': 'MusicRecording',
            name: t.t || t.p.split('/').pop(),
            ...(yearLabel(t.r) ? { datePublished: yearLabel(t.r) } : {}),
        })),
    };

    const rows = tunes.map((t) => {
        const title = t.t || t.p.split('/').pop();
        const yr = yearLabel(t.r);
        const folder = folderOf(t.p);
        return `      <li class="tune" data-start="${escapeHtml(folder)}">`
            + `<span class="tune-title">${escapeHtml(title)}</span>`
            + `<span class="tune-year">${escapeHtml(yr)}</span></li>`;
    }).join('\n');

    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>C64 SID music by ${escapeHtml(name)} | SIDquake</title>
<meta name="description" content="${escapeHtml(desc)}">
<link rel="canonical" href="${escapeHtml(canonical)}">
<meta property="og:title" content="C64 SID music by ${escapeHtml(name)}">
<meta property="og:description" content="${escapeHtml(desc)}">
<meta property="og:url" content="${escapeHtml(canonical)}">
<link rel="stylesheet" href="/styles.css">
<link rel="stylesheet" href="/styles-deferred.css">
<style>
  .seo-wrap { max-width: 1000px; margin: 0 auto; padding: 32px 20px 64px; }
  .seo-wrap h1 { margin: 0 0 6px; }
  .seo-sub { color: var(--text-muted); margin: 0 0 24px; }
  .seo-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
  @media (max-width: 800px) { .seo-grid { grid-template-columns: 1fr; } }
  .tune-list { list-style: none; margin: 0; padding: 0; max-height: 520px; overflow: auto;
    border: 1px solid var(--border); border-radius: 8px; }
  .tune { display: flex; align-items: center; gap: 10px; padding: 6px 12px;
    border-bottom: 1px solid var(--border); cursor: pointer; }
  .tune:hover { background: var(--bg-elevated); }
  .tune-title { flex: 1; }
  .tune-year { color: var(--text-muted); font-size: 12px; font-variant-numeric: tabular-nums; }
  .seo-embed { width: 100%; height: 560px; border: 1px solid var(--border); border-radius: 8px; }
  .seo-cta { display: inline-block; margin: 4px 0 20px; }
  .seo-foot { color: var(--text-muted); font-size: 0.85em; margin-top: 32px; }
  .seo-foot a, .seo-wrap a { color: var(--accent); }
</style>
<script type="application/ld+json">${JSON.stringify(jsonld)}</script>
</head>
<body>
<div class="seo-wrap">
  <p><a href="/music/">&larr; All composers</a> &middot; <a href="/">SIDquake</a></p>
  <h1>C64 SID music by ${escapeHtml(name)}</h1>
  <p class="seo-sub">${count} tune${count === 1 ? '' : 's'} in the High Voltage SID Collection, playable on SIDquake.</p>
  ${akaLine}
  <p><a class="seo-cta btn" href="/?hvsc=${encodeURIComponent(primaryFolder)}">Open ${escapeHtml(name)} in the SIDquake player &rarr;</a></p>
  <div class="seo-grid">
    <ul class="tune-list" id="tuneList">
${rows}
    </ul>
    <iframe class="seo-embed" id="seoEmbed" src="${escapeHtml(embedSrc)}" title="SIDquake HVSC player" loading="lazy"></iframe>
  </div>
  <p class="seo-foot">
    Tunes &copy; their respective composers, for private listening. Music from the
    <a href="https://hvsc.c64.org/" target="_blank" rel="noopener">High Voltage SID Collection</a>,
    curated by the HVSC Crew. Hosted by <a href="/">SIDquake</a>.
  </p>
</div>
<script>
  // Clicking a tune points the embedded player at that tune's folder.
  var list = document.getElementById('tuneList');
  var frame = document.getElementById('seoEmbed');
  if (list && frame) list.addEventListener('click', function (e) {
    var li = e.target.closest('.tune');
    if (!li) return;
    var start = li.getAttribute('data-start') || '';
    frame.src = '/hvsc-embed.html?mode=play&start=' + encodeURIComponent(start);
  });
</script>
</body>
</html>
`;
}

function hubHtml(composers) {
    const canonical = `${BASE_URL}/music/`;
    const links = composers.map((c) =>
        `<li><a href="/music/${c.slug}.html">${escapeHtml(c.name)}</a> `
        + `<span class="hub-count">(${c.tunes.length})</span></li>`).join('\n');
    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>C64 SID composers — ${composers.length} artists | SIDquake</title>
<meta name="description" content="Browse ${composers.length} Commodore 64 SID composers and their music from the High Voltage SID Collection, playable on SIDquake.">
<link rel="canonical" href="${escapeHtml(canonical)}">
<link rel="stylesheet" href="/styles.css">
<link rel="stylesheet" href="/styles-deferred.css">
<style>
  .seo-wrap { max-width: 1000px; margin: 0 auto; padding: 32px 20px 64px; }
  .hub-list { columns: 3; column-gap: 28px; list-style: none; padding: 0; }
  @media (max-width: 800px) { .hub-list { columns: 1; } }
  .hub-list li { break-inside: avoid; margin: 3px 0; }
  .hub-count { color: var(--text-muted); font-size: 12px; }
  .seo-wrap a { color: var(--accent); }
</style>
</head>
<body>
<div class="seo-wrap">
  <p><a href="/">&larr; SIDquake</a></p>
  <h1>C64 SID composers</h1>
  <p>${composers.length} composers from the High Voltage SID Collection, hosted and playable on SIDquake.</p>
  <ul class="hub-list">
${links}
  </ul>
</div>
</body>
</html>
`;
}

function sitemapXml(composers) {
    const urls = [`${BASE_URL}/`, `${BASE_URL}/music/`]
        .concat(composers.map((c) => `${BASE_URL}/music/${c.slug}.html`));
    const body = urls.map((u) => `  <url><loc>${escapeXml(u)}</loc></url>`).join('\n');
    return `<?xml version="1.0" encoding="UTF-8"?>\n`
        + `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${body}\n</urlset>\n`;
}

function main() {
    if (!fs.existsSync(INDEX)) {
        console.error(`No ${INDEX}. Build the HVSC index first (npm run build-hvsc-index).`);
        process.exit(0); // non-fatal for the Netlify build
    }
    const index = JSON.parse(fs.readFileSync(INDEX, 'utf8'));
    const entries = index.entries || [];

    const composers = buildComposers(entries);

    // Write pages.
    fs.mkdirSync(MUSIC_DIR, { recursive: true });
    for (const c of composers) {
        fs.writeFileSync(path.join(MUSIC_DIR, `${c.slug}.html`), pageHtml(c));
    }
    fs.writeFileSync(path.join(MUSIC_DIR, 'index.html'), hubHtml(composers));
    fs.writeFileSync(path.join(PUBLIC, 'sitemap.xml'), sitemapXml(composers));

    const tuneTotal = composers.reduce((n, c) => n + c.tunes.length, 0);
    console.error(`Generated ${composers.length} composer pages (${tuneTotal} tunes) `
        + `+ hub + sitemap.xml at base ${BASE_URL}`);
}

main();
