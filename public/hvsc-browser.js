window.hvscBrowser = (function () {
    // Configuration
    const HVSC_BASE = window.location.hostname === 'localhost' 
        ? 'https://hvsc.etv.cx/'
        : '/api/hvsc/';
    
    let currentPath = 'C64Music';
    let currentSelection = null;
    let entries = [];

    // Initialize on load
    window.onload = function() {
        fetchDirectory('C64Music');
    };

    async function fetchDirectory(path) {
        document.getElementById('fileList').innerHTML = '<div class="loading">Loading directory</div>';
        
        try {
            const url = `${HVSC_BASE}?path=${path}`;
            const response = await fetch(url);
            
            if (!response.ok) {
                throw new Error('Failed to fetch directory');
            }
            
            const html = await response.text();
            parseDirectory(html, path);
            currentPath = path;
            updatePathBar();
        } catch (error) {
            document.getElementById('fileList').innerHTML = 
                '<div class="error-message">Failed to load directory. Check your connection and try again.</div>';
        }
    }

    function parseDirectory(html, path) {
        entries = [];
        const fileList = document.getElementById('fileList');
        fileList.innerHTML = '';

        // Look for the directory listing table - this is the key!
        const tableRegex = /<table[^>]*width="99%"[^>]*>([\s\S]*?)<\/table>/i;
        const tableMatch = html.match(tableRegex);

        if (tableMatch) {
            console.log('Found table');
            const tableContent = tableMatch[1];

            // Parse each row for links
            const rowRegex = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
            let rowMatch;

            while ((rowMatch = rowRegex.exec(tableContent)) !== null) {
                const row = rowMatch[1];

                // Look for links in this row
                const linkMatch = row.match(/<a\s+href="([^"]+)"[^>]*>(?:<img[^>]*>)?([^<]+)<\/a>/i);

                if (linkMatch) {
                    const href = linkMatch[1];
                    let name = linkMatch[2].trim();

                    console.log('Table link:', href, '-> Text:', name);

                    // Process directory links
                    if (href.startsWith('?path=') && !href.includes('info=')) {
                        const pathValue = decodeURIComponent(href.substring(6));
                        name = name.replace(/\/$/, ''); // Remove trailing slash

                        entries.push({
                            name: name,
                            path: pathValue,
                            isDirectory: true
                        });
                    }
                    // Process SID file links
                    else if (href.includes('info=please') && href.includes('.sid')) {
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
        } else {
            console.log('No table found - might be on homepage');
            // The fallback code for when there's no table means we're on the wrong page
            return;
        }

        // Sort and render entries...
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
            fetchDirectory(entry.path);
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
            const baseUrl = window.location.hostname === 'localhost'
                ? 'https://hvsc.etv.cx/'
                : '/api/hvsc/';
            const sidUrl = baseUrl + 'download/' + currentSelection.path;

            // Post message to parent window (now same window)
            window.postMessage({
                type: 'sid-selected',
                name: currentSelection.name,
                path: currentSelection.path,
                url: sidUrl
            }, '*');

            // Close modal
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