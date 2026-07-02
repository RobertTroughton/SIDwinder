// hvsc-random.js - Random SID selector for the self-hosted HVSC collection.
// Picks a random tune straight from the search index (hvsc-index.json). If a
// curated list of path prefixes (hvsc-random.json) is present, the pick is
// restricted to tunes under those paths; otherwise the whole collection is used.

window.hvscRandom = (function () {

    let indexEntries = null;     // array of {p,t,a,r,s}
    let curatedPrefixes = [];    // optional path prefixes to bias toward
    let loadPromise = null;

    function sidUrl(p) {
        return '/HVSC/' + p.split('/').map(encodeURIComponent).join('/');
    }

    async function loadPaths() {
        if (indexEntries) return true;
        if (loadPromise) return loadPromise;
        loadPromise = (async () => {
            // Curated prefixes are optional — ignore if missing.
            try {
                const cur = await fetch('hvsc-random.json');
                if (cur.ok) {
                    const data = await cur.json();
                    curatedPrefixes = (data.paths || []).map((p) =>
                        p.endsWith('/') ? p : p + '/');
                }
            } catch (_) { /* optional */ }

            const res = await fetch('hvsc-index.json');
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            const index = await res.json();
            indexEntries = index.entries || [];
            console.log(`HVSC random: ${indexEntries.length} tunes available`);
            return true;
        })().catch((err) => {
            loadPromise = null;
            console.error('Error loading HVSC index for random:', err);
            return false;
        });
        return loadPromise;
    }

    /** Pick a random SID from the index (optionally within curated prefixes). */
    async function selectRandomSID(maxDepth = 5, onProgress = null) {
        if (!await loadPaths()) {
            throw new Error('Could not load HVSC index');
        }
        if (!indexEntries.length) {
            throw new Error('No HVSC tunes available');
        }

        let pool = indexEntries;
        if (curatedPrefixes.length) {
            const filtered = indexEntries.filter((e) =>
                curatedPrefixes.some((pre) => e.p.startsWith(pre)));
            if (filtered.length) pool = filtered;
        }

        if (onProgress) onProgress('Picking a random tune...');

        const pick = pool[Math.floor(Math.random() * pool.length)];
        const name = pick.p.split('/').pop();
        const slash = pick.p.lastIndexOf('/');
        const browsePath = slash === -1 ? '' : pick.p.substring(0, slash);

        return {
            name: name,
            path: pick.p,
            url: sidUrl(pick.p),
            browsePath: browsePath
        };
    }

    return {
        loadPaths: loadPaths,
        selectRandomSID: selectRandomSID
    };
})();
