window.hvscBrowser = (function () {

    // HVSC is now self-hosted: raw .sid files are served statically from
    // /HVSC/... and the whole collection tree + metadata comes from the
    // single search index (hvsc-index.json). Browsing is therefore entirely
    // client-side — no per-folder network round-trips.

    const ROOT = 'C64Music';

    let currentPath = ROOT;
    let currentSelection = null;
    let entries = [];

    let hvscPlayer = null;
    let hvscInitialized = false;

    // Index / tree state
    let searchIndex = null;          // { entries: [{p,t,a,r,s}], ... } once loaded
    let searchIndexPromise = null;   // in-flight load promise
    let dirMap = null;               // Map<dirPath, {dirs:Set, files:[{name,path,meta}]}>
    let metaByPath = null;           // Map<path, {t,a,r,s}>

    // Search state
    let searchMode = false;
    let searchDebounce = null;
    const SEARCH_RESULT_LIMIT = 500;

    /** Static URL for a SID file path (each segment URL-encoded). */
    function sidUrl(p) {
        return '/HVSC/' + p.split('/').map(encodeURIComponent).join('/');
    }

    function initializeHVSC() {
        if (hvscInitialized) return;
        hvscInitialized = true;
        wireSearch();
        loadSearchIndex()
            .then(() => fetchDirectory(ROOT))
            .catch((err) => {
                console.error('Failed to load HVSC index:', err);
                document.getElementById('fileList').innerHTML =
                    '<div class="error-message">Could not load the HVSC index. '
                    + 'Run <code>npm run build-hvsc-index</code> to generate '
                    + '<code>public/hvsc-index.json</code>.</div>';
                if (window.showError) {
                    window.showError('Failed to load HVSC index', {
                        details: err.message, duration: 0
                    });
                }
            });
    }

    async function ensurePlayerReady() {
        if (hvscPlayer) return;
        // Load all playback dependencies: WASM + playback engine + player UI
        if (window.loadScript) {
            if (typeof SIDPlayer === 'undefined') {
                await window.loadScript('sid-player.js');
            }
            if (typeof getSharedSIDPlayback === 'undefined') {
                await window.loadScript('sidwinder.js');
                await window.loadScript('sid-playback.js');
            }
        }
        const container = document.getElementById('hvscPlayerContainer');
        if (container && typeof SIDPlayer !== 'undefined') {
            hvscPlayer = new SIDPlayer(container);
        }
    }

    function loadSearchIndex() {
        if (searchIndex) return Promise.resolve(searchIndex);
        if (searchIndexPromise) return searchIndexPromise;
        searchIndexPromise = fetch('hvsc-index.json')
            .then((res) => {
                if (!res.ok) throw new Error(`HTTP ${res.status}`);
                return res.json();
            })
            .then((data) => {
                searchIndex = data;
                buildTree(data.entries || []);
                updateVersionBadge(data.hvsc);
                return data;
            })
            .catch((err) => {
                searchIndexPromise = null;
                throw err;
            });
        return searchIndexPromise;
    }

    /** Show "HVSC #NN" in the modal header when the index records a version. */
    function updateVersionBadge(version) {
        const badge = document.getElementById('hvscVersionBadge');
        if (!badge) return;
        if (version) {
            badge.textContent = `HVSC #${version}`;
            badge.title = `This mirror is current with HVSC Update #${version}`;
            badge.hidden = false;
        } else {
            badge.hidden = true;
        }
    }

    /** Build the directory tree + path->metadata map from the flat index. */
    function buildTree(all) {
        dirMap = new Map();
        metaByPath = new Map();

        const getDir = (d) => {
            let node = dirMap.get(d);
            if (!node) { node = { dirs: new Set(), files: [] }; dirMap.set(d, node); }
            return node;
        };

        for (let i = 0; i < all.length; i++) {
            const e = all[i];
            const p = e.p;
            metaByPath.set(p, e);

            const slash = p.lastIndexOf('/');
            const dir = slash === -1 ? '' : p.substring(0, slash);
            const name = slash === -1 ? p : p.substring(slash + 1);
            getDir(dir).files.push({ name, path: p, meta: e });

            // Register each directory segment under its parent.
            const segs = dir.split('/');
            for (let s = 0; s < segs.length; s++) {
                const full = segs.slice(0, s + 1).join('/');
                const parent = s === 0 ? '' : segs.slice(0, s).join('/');
                getDir(parent).dirs.add(segs[s]);
                getDir(full); // ensure node exists
            }
        }
    }

    /** List a directory from the tree as {name, path, isDirectory} entries. */
    function listDirectory(dirPath) {
        const node = dirMap && dirMap.get(dirPath);
        const out = [];
        if (!node) return out;
        node.dirs.forEach((childName) => {
            out.push({
                name: childName,
                path: dirPath ? `${dirPath}/${childName}` : childName,
                isDirectory: true,
            });
        });
        node.files.forEach((f) => {
            out.push({ name: f.name, path: f.path, isDirectory: false, meta: f.meta });
        });
        out.sort((a, b) => {
            if (a.isDirectory !== b.isDirectory) return b.isDirectory - a.isDirectory;
            return a.name.localeCompare(b.name);
        });
        return out;
    }

    async function fetchDirectory(path) {
        // Navigating into a directory clears any active search
        if (searchMode) {
            const input = document.getElementById('hvscSearchBar');
            const clearBtn = document.getElementById('hvscSearchClear');
            if (input) input.value = '';
            if (clearBtn) clearBtn.style.display = 'none';
            searchMode = false;
            const header = document.getElementById('filePanelHeader');
            if (header) header.textContent = 'Files & Directories';
        }

        if (path.endsWith('/')) path = path.slice(0, -1);

        try {
            await loadSearchIndex();
        } catch (err) {
            document.getElementById('fileList').innerHTML =
                '<div class="error-message">Failed to load HVSC index.</div>';
            return;
        }

        entries = listDirectory(path);
        currentPath = path;
        renderEntries();
        updateItemCount();
        updatePathBar();
        clearInfoPanel();
    }

    function handleItemClick(entry) {
        document.querySelectorAll('.file-item').forEach(item => {
            item.classList.remove('selected');
        });

        event.currentTarget.classList.add('selected');
        currentSelection = entry;

        if (!entry.isDirectory) {
            previewSID(entry);
        }
    }

    function updateInfoPanel(entry) {
        const content = document.getElementById('sidInfoContent');
        if (!content) return;

        const player = getSharedSIDPlayback();
        const title = player.getTitle() || '';
        const author = player.getAuthor() || '';
        const copyright = player.getCopyright() || '';
        const subtunes = player.getSubtuneCount() || 1;
        const sidCount = player.getSIDCount() || 1;
        const sidModel = player.getSIDModel();
        const isNTSC = player.isNTSC();

        const loadAddr = player.getLoadAddress();
        const initAddr = player.getInitAddress();
        const playAddr = player.getPlayAddress();
        const dataSize = player.getDataSize();

        const modelNames = { 0: 'Unknown', 1: 'MOS 6581', 2: 'MOS 8580', 3: '6581 + 8580' };
        const modelStr = modelNames[sidModel] || 'Unknown';
        const clockStr = isNTSC ? 'NTSC' : 'PAL';
        const hex = (v) => '$' + v.toString(16).toUpperCase().padStart(4, '0');
        const endAddr = loadAddr + dataSize;

        // STIL comment (from the index) if we have one for this path.
        const meta = entry.meta || (metaByPath && metaByPath.get(entry.path));
        const stil = meta && meta.s ? meta.s : '';

        let html = '';
        if (title) html += `<div class="sid-info-row"><span class="sid-info-label">Title</span><span class="sid-info-value">${escapeHtml(title)}</span></div>`;
        if (author) html += `<div class="sid-info-row"><span class="sid-info-label">Author</span><span class="sid-info-value">${escapeHtml(author)}</span></div>`;
        if (copyright) html += `<div class="sid-info-row"><span class="sid-info-label">Copyright</span><span class="sid-info-value">${escapeHtml(copyright)}</span></div>`;
        html += `<div class="sid-info-row"><span class="sid-info-label">Subtunes</span><span class="sid-info-value">${subtunes}</span></div>`;
        html += `<div class="sid-info-row"><span class="sid-info-label">SID Chip</span><span class="sid-info-value">${modelStr}</span></div>`;
        if (sidCount > 1) html += `<div class="sid-info-row"><span class="sid-info-label">SID Count</span><span class="sid-info-value">${sidCount}</span></div>`;
        html += `<div class="sid-info-row"><span class="sid-info-label">Clock</span><span class="sid-info-value">${clockStr}</span></div>`;
        html += `<div class="sid-info-row"><span class="sid-info-label">Load Address</span><span class="sid-info-value">${hex(loadAddr)}</span></div>`;
        html += `<div class="sid-info-row"><span class="sid-info-label">Init Address</span><span class="sid-info-value">${hex(initAddr)}</span></div>`;
        html += `<div class="sid-info-row"><span class="sid-info-label">Play Address</span><span class="sid-info-value">${playAddr ? hex(playAddr) : 'IRQ'}</span></div>`;
        html += `<div class="sid-info-row"><span class="sid-info-label">Memory Used</span><span class="sid-info-value">${hex(loadAddr)} - ${hex(endAddr)} (${dataSize} bytes)</span></div>`;
        html += `<div class="sid-info-row"><span class="sid-info-label">File</span><span class="sid-info-value">${escapeHtml(entry.name)}</span></div>`;
        if (stil) html += `<div class="sid-info-stil"><span class="sid-info-label">STIL</span><span class="sid-info-value">${escapeHtml(stil)}</span></div>`;
        html += `<div class="sid-info-download"><button class="btn" onclick="hvscBrowser.downloadSID()"><i class="fas fa-download"></i> Download SID</button></div>`;

        content.innerHTML = html;
    }

    function clearInfoPanel() {
        const content = document.getElementById('sidInfoContent');
        if (content) {
            content.innerHTML = '<div class="sid-info-placeholder">Select a SID file to view details</div>';
        }
    }

    function escapeHtml(str) {
        const div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    }

    function downloadSID() {
        if (!currentSelection || currentSelection.isDirectory) return;
        const a = document.createElement('a');
        a.href = sidUrl(currentSelection.path);
        a.download = currentSelection.name;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }

    async function previewSID(entry) {
        await ensurePlayerReady();
        if (hvscPlayer) {
            const wasPlaying = hvscPlayer.isPlaying;
            const player = getSharedSIDPlayback();
            player.setLoadCallback(() => {
                hvscPlayer.onLoaded(entry.name);
                updateInfoPanel(entry);
                if (wasPlaying) {
                    hvscPlayer.play();
                }
            });
            hvscPlayer.stop();
            hvscPlayer.takeOwnership();
            player.loadFromUrl(sidUrl(entry.path));
        }
    }

    function stopPreview() {
        if (hvscPlayer) {
            // Clear any pending load callback to prevent late autoplay
            const player = getSharedSIDPlayback();
            player.setLoadCallback(null);
            hvscPlayer.stop();
        }
    }

    function handleItemDoubleClick(entry) {
        if (entry.isDirectory) {
            let cleanPath = entry.path;
            if (cleanPath.endsWith('/')) {
                cleanPath = cleanPath.slice(0, -1);
            }
            fetchDirectory(cleanPath);
        } else {
            selectSID();
        }
    }

    function navigateUp() {
        if (!currentPath || currentPath === '' || currentPath === ROOT) {
            return;
        }

        let cleanPath = currentPath;
        if (cleanPath.endsWith('/')) {
            cleanPath = cleanPath.slice(0, -1);
        }

        const parts = cleanPath.split('/');
        parts.pop();

        const parentPath = parts.join('/');
        fetchDirectory(parentPath || ROOT);
    }

    function navigateHome() {
        fetchDirectory(ROOT);
    }

    function updatePathBar() {
        const pathDisplay = currentPath ? '/' + currentPath : '/';
        document.getElementById('pathBar').value = pathDisplay;
        document.getElementById('upBtn').disabled = !currentPath || currentPath === '' || currentPath === ROOT;
    }

    function selectSID() {
        if (currentSelection && !currentSelection.isDirectory) {
            stopPreview();

            const url = sidUrl(currentSelection.path);

            window.postMessage({
                type: 'sid-selected',
                name: currentSelection.name,
                path: currentSelection.path,
                url: url
            }, '*');

            const modal = document.getElementById('hvscModal');
            if (modal) {
                modal.classList.remove('visible');
            }
        }
    }

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && currentSelection) {
            if (currentSelection.isDirectory) {
                fetchDirectory(currentSelection.path);
            } else {
                selectSID();
            }
        }
    });

    function wireSearch() {
        const input = document.getElementById('hvscSearchBar');
        const clearBtn = document.getElementById('hvscSearchClear');
        if (!input || input.dataset.wired === '1') return;
        input.dataset.wired = '1';

        input.addEventListener('input', () => {
            const q = input.value.trim();
            clearBtn.style.display = q ? 'inline-flex' : 'none';
            if (searchDebounce) clearTimeout(searchDebounce);
            searchDebounce = setTimeout(() => runSearch(q), 150);
        });

        clearBtn.addEventListener('click', () => {
            input.value = '';
            clearBtn.style.display = 'none';
            if (searchDebounce) clearTimeout(searchDebounce);
            exitSearchMode();
        });
    }

    function exitSearchMode() {
        if (!searchMode) return;
        searchMode = false;
        const header = document.getElementById('filePanelHeader');
        if (header) header.textContent = 'Files & Directories';
        // Repaint the current directory so selection/state is consistent
        entries = listDirectory(currentPath);
        renderEntries();
        updateItemCount();
    }

    function renderEntries() {
        const fileList = document.getElementById('fileList');
        fileList.innerHTML = '';
        entries.forEach(entry => {
            const item = document.createElement('div');
            item.className = 'file-item' + (entry.isDirectory ? ' directory' : '');
            const icon = entry.isDirectory
                ? '<i class="fas fa-folder"></i>'
                : '<i class="fas fa-music"></i>';
            item.innerHTML = `
            <span class="file-icon">${icon}</span>
            <span class="file-name">${escapeHtml(entry.name)}</span>
        `;
            item.onclick = () => handleItemClick(entry);
            item.ondblclick = () => handleItemDoubleClick(entry);
            fileList.appendChild(item);
        });
    }

    function updateItemCount() {
        const sidCount = entries.filter(e => !e.isDirectory).length;
        const dirCount = entries.filter(e => e.isDirectory).length;
        let countText;
        if (sidCount > 0 && dirCount > 0) countText = `${sidCount} SID files, ${dirCount} folders`;
        else if (sidCount > 0) countText = `${sidCount} SID file${sidCount !== 1 ? 's' : ''}`;
        else if (dirCount > 0) countText = `${dirCount} folder${dirCount !== 1 ? 's' : ''}`;
        else countText = 'Empty folder';
        document.getElementById('itemCount').textContent = countText;
    }

    async function runSearch(query) {
        if (!query) {
            exitSearchMode();
            return;
        }

        searchMode = true;
        currentSelection = null;
        const fileList = document.getElementById('fileList');
        const header = document.getElementById('filePanelHeader');
        if (header) header.textContent = 'Search Results';

        fileList.innerHTML = '<div class="file-list-loading"><div class="file-list-spinner"></div></div>';

        let index;
        try {
            index = await loadSearchIndex();
        } catch (err) {
            fileList.innerHTML =
                '<div class="error-message">Search index not available yet. '
                + 'Browse by folder, or ask the site maintainer to run '
                + '<code>npm run build-hvsc-index</code>.</div>';
            document.getElementById('itemCount').textContent = 'Search unavailable';
            return;
        }

        // Only render the latest query's results (guards against out-of-order fetches)
        const currentInput = document.getElementById('hvscSearchBar').value.trim();
        if (currentInput !== query) return;

        const terms = query.toLowerCase().split(/\s+/).filter(Boolean);
        const matches = [];
        const all = index.entries;
        const limit = SEARCH_RESULT_LIMIT;

        for (let i = 0; i < all.length; i++) {
            const e = all[i];
            // Search across title, author, path AND folded STIL text.
            const hay = ((e.t || '') + '\x00' + (e.a || '') + '\x00'
                + (e.p || '') + '\x00' + (e.s || '')).toLowerCase();
            let ok = true;
            for (let j = 0; j < terms.length; j++) {
                if (hay.indexOf(terms[j]) === -1) { ok = false; break; }
            }
            if (ok) {
                matches.push(e);
                if (matches.length >= limit) break;
            }
        }

        renderSearchResults(matches, limit);
        const shownPlural = matches.length === 1 ? 'match' : 'matches';
        let countText = `${matches.length} ${shownPlural}`;
        if (matches.length >= limit) countText += ` (first ${limit} shown)`;
        document.getElementById('itemCount').textContent = countText;
    }

    function renderSearchResults(results, limit) {
        const fileList = document.getElementById('fileList');
        fileList.innerHTML = '';

        if (results.length === 0) {
            fileList.innerHTML = '<div class="search-empty">No matching SIDs found.</div>';
            return;
        }

        const frag = document.createDocumentFragment();
        results.forEach(r => {
            const fileName = r.p.split('/').pop();
            const folder = r.p.substring(0, r.p.length - fileName.length - 1);
            const titleLine = r.t || fileName;
            const authorLine = r.a || '';

            const item = document.createElement('div');
            item.className = 'file-item search-result';
            item.innerHTML = `
            <span class="file-icon"><i class="fas fa-music"></i></span>
            <span class="search-result-text">
                <span class="search-result-title">${escapeHtml(titleLine)}</span>
                ${authorLine ? `<span class="search-result-author">${escapeHtml(authorLine)}</span>` : ''}
                <span class="search-result-path">${escapeHtml(folder)}</span>
            </span>
        `;

            const entry = { name: fileName, path: r.p, isDirectory: false, meta: r };
            item.onclick = () => handleItemClick(entry);
            item.ondblclick = () => handleItemDoubleClick(entry);
            frag.appendChild(item);
        });
        fileList.appendChild(frag);
    }

    return {
        navigateUp: navigateUp,
        navigateHome: navigateHome,
        fetchDirectory: fetchDirectory,
        stopPreview: stopPreview,
        downloadSID: downloadSID,
        initializeHVSC: initializeHVSC
    };
})();
