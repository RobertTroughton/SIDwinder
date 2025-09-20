window.hvscBrowser = (function () {

    const HVSC_BASE = '/.netlify/functions/hvsc';

    let currentPath = 'C64Music';
    let currentSelection = null;
    let entries = [];

    // Add an initialization flag
    let hvscInitialized = false;

    // Add an init function
    function initializeHVSC() {
        if (!hvscInitialized) {
            fetchDirectory('C64Music');
            hvscInitialized = true;
        }
    }

    async function fetchDirectory(path) {
        // Clean the path
        if (path.endsWith('/')) {
            path = path.slice(0, -1);
        }

        // Try URL encoding the path parameter
        const encodedPath = encodeURIComponent(path);
        const url = `${HVSC_BASE}?path=${encodedPath}`;

        document.getElementById('fileList').innerHTML = '<div class="loading">Loading directory</div>';

        try {
            const response = await fetch(url);

            if (!response.ok) {
                throw new Error('Failed to fetch directory');
            }

            const html = await response.text();

            parseDirectory(html, path);
            currentPath = path;
            updatePathBar();
        } catch (error) {
            console.error('Fetch error:', error);
            document.getElementById('fileList').innerHTML =
                '<div class="error-message">Failed to load directory. Check your connection and try again.</div>';
        }
    }

    function parseDirectory(html, path) {
        entries = [];
        const fileList = document.getElementById('fileList');
        fileList.innerHTML = '';

        // Look for ANY table, not just width="99%"
        const tableRegex = /<table[^>]*>([\s\S]*?)<\/table>/i;
        const tableMatch = html.match(tableRegex);

        if (tableMatch) {
            const tableContent = tableMatch[1];

            // Parse each row for links
            const rowRegex = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
            let rowMatch;

            while ((rowMatch = rowRegex.exec(tableContent)) !== null) {
                const row = rowMatch[1];
                const linkMatch = row.match(/<a\s+href="([^"]+)"[^>]*>(?:<img[^>]*>)?([^<]+)<\/a>/i);

                if (linkMatch) {
                    const href = linkMatch[1];
                    let name = linkMatch[2].trim();

                    // Process directory links
                    if (href.startsWith('?path=') && !href.includes('info=')) {
                        let pathValue = decodeURIComponent(href.substring(6));
                        if (pathValue.endsWith('/')) {
                            pathValue = pathValue.slice(0, -1);
                        }
                        name = name.replace(/\/$/, '');

                        entries.push({
                            name: name,
                            path: pathValue,
                            isDirectory: true
                        });
                    }
                    // Process SID file links
                    else if (href.includes('.sid') && !href.includes('info=')) {
                        let fileName = href.split('/').pop();
                        entries.push({
                            name: fileName,
                            path: href,
                            isDirectory: false
                        });
                    }
                    else if (href.includes('info=please') && href.includes('.sid')) {
                        const pathMatch = href.match(/path=([^&]+)/);
                        if (pathMatch) {
                            const filePath = decodeURIComponent(pathMatch[1]);
                            const fileName = filePath.split('/').pop();

                            if (!entries.find(e => e.name === fileName)) {
                                entries.push({
                                    name: fileName,
                                    path: filePath,
                                    isDirectory: false
                                });
                            }
                        }
                    }
                }
            }
        } else {
            // Alternative: Look for ALL links with ?path= or .sid
            const linkRegex = /<a\s+href="([^"]+)"[^>]*>([^<]+)<\/a>/gi;
            let match;

            while ((match = linkRegex.exec(html)) !== null) {
                const href = match[1];
                const linkText = match[2].trim();

                // Skip navigation and external links
                if (linkText === 'Home' || linkText === 'About' || linkText === 'HVSC' ||
                    linkText === 'SidSearch' || linkText === '..' || linkText === '.' ||
                    linkText === 'Parent Directory' || href.startsWith('http://') ||
                    href.startsWith('https://') || href === '#') {
                    continue;
                }

                // Directory links
                if (href.includes('?path=') && !href.includes('info=')) {
                    const pathMatch = href.match(/\?path=([^&]*)/);
                    if (pathMatch) {
                        let pathValue = decodeURIComponent(pathMatch[1]);
                        if (pathValue.endsWith('/')) {
                            pathValue = pathValue.slice(0, -1);
                        }
                        entries.push({
                            name: linkText.replace(/\/$/, ''),
                            path: pathValue,
                            isDirectory: true
                        });
                    }
                }
                // SID files
                else if (href.includes('info=please') || linkText.endsWith('.sid')) {
                    if (href.includes('path=')) {
                        const pathMatch = href.match(/path=([^&]+)/);
                        if (pathMatch) {
                            const filePath = decodeURIComponent(pathMatch[1]);
                            const fileName = filePath.split('/').pop();
                            entries.push({
                                name: fileName,
                                path: filePath,
                                isDirectory: false
                            });
                        }
                    }
                }
            }
        }

        // Sort and render entries
        entries.sort((a, b) => {
            if (a.isDirectory !== b.isDirectory) {
                return b.isDirectory - a.isDirectory;
            }
            return a.name.localeCompare(b.name);
        });

        entries.forEach(entry => {
            const item = document.createElement('div');
            item.className = 'file-item' + (entry.isDirectory ? ' directory' : '');

            const icon = entry.isDirectory ? '📁' : '🎵';

            item.innerHTML = `
            <span class="file-icon">${icon}</span>
            <span class="file-name">${entry.name}</span>
        `;

            item.onclick = () => handleItemClick(entry);
            item.ondblclick = () => handleItemDoubleClick(entry);

            fileList.appendChild(item);
        });

        const sidCount = entries.filter(e => !e.isDirectory).length;
        const dirCount = entries.filter(e => e.isDirectory).length;

        let countText = '';
        if (sidCount > 0 && dirCount > 0) {
            countText = `${sidCount} SID files, ${dirCount} folders`;
        } else if (sidCount > 0) {
            countText = `${sidCount} SID file${sidCount !== 1 ? 's' : ''}`;
        } else if (dirCount > 0) {
            countText = `${dirCount} folder${dirCount !== 1 ? 's' : ''}`;
        } else {
            countText = 'Empty folder';
        }

        document.getElementById('itemCount').textContent = countText;
    }

    function handleItemClick(entry) {
        document.querySelectorAll('.file-item').forEach(item => {
            item.classList.remove('selected');
        });
        
        event.currentTarget.classList.add('selected');
        currentSelection = entry;
    }

    function handleItemDoubleClick(entry) {
        if (entry.isDirectory) {
            // Remove any trailing slashes from the path before fetching
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
        if (!currentPath || currentPath === '' || currentPath === 'C64Music') {
            return;
        }

        let cleanPath = currentPath;
        if (cleanPath.endsWith('/')) {
            cleanPath = cleanPath.slice(0, -1);
        }

        const parts = cleanPath.split('/');
        parts.pop();

        const parentPath = parts.join('/');
        fetchDirectory(parentPath || 'C64Music');
    }

    function navigateHome() {
        fetchDirectory('C64Music');
    }

    function updatePathBar() {
        const pathDisplay = currentPath ? '/' + currentPath : '/';
        document.getElementById('pathBar').value = pathDisplay;
        document.getElementById('upBtn').disabled = !currentPath || currentPath === '';
    }

    function selectSID() {
        if (currentSelection && !currentSelection.isDirectory) {
            // Use the Netlify function for downloading
            const sidUrl = `/.netlify/functions/hvsc?path=${encodeURIComponent(currentSelection.path)}`;

            window.postMessage({
                type: 'sid-selected',
                name: currentSelection.name,
                path: currentSelection.path,
                url: sidUrl
            }, '*');

            const modal = document.getElementById('hvscModal');
            if (modal) {
                modal.classList.remove('visible');
            }
        }
    }

    // Handle Enter key
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && currentSelection) {
            if (currentSelection.isDirectory) {
                fetchDirectory(currentSelection.path);
            } else {
                selectSID();
            }
        }
    });

    // Public API
    return {
        navigateUp: navigateUp,
        navigateHome: navigateHome,
        fetchDirectory: fetchDirectory
    };
})();