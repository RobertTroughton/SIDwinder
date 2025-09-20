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

        // Find all links in the HTML
        const linkRegex = /<a\s+href="([^"]+)"[^>]*>([^<]+)<\/a>/gi;
        let match;

        while ((match = linkRegex.exec(html)) !== null) {
            const href = match[1];
            const linkText = match[2].trim();

            // Skip navigation links
            if (linkText === 'Home' || linkText === 'About' || linkText === 'HVSC' ||
                linkText === 'SidSearch' || linkText === '..' || linkText === '.' ||
                linkText === 'Parent Directory' || href === '#' || linkText === 'info' ||
                linkText === 'download') {
                continue;
            }

            console.log('Found link:', href, '-> Text:', linkText);

            // Check if it's a directory (has ?path= but NOT info=please)
            if (href.includes('?path=') && !href.includes('info=please')) {
                const pathMatch = href.match(/\?path=([^&]*)/);
                if (pathMatch) {
                    const pathValue = decodeURIComponent(pathMatch[1]);
                    // Only add if it's not empty and not the current path
                    if (pathValue && pathValue !== path) {
                        entries.push({
                            name: linkText.replace(/\/$/, ''),
                            path: pathValue,
                            isDirectory: true
                        });
                        console.log('Added directory:', linkText, 'Path:', pathValue);
                    }
                }
            }
            // Check if it's a SID file info link (has both path= and info=please)
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
                    console.log('Added SID from info link:', fileName, 'Path:', filePath);
                }
            }
            // Check if link text itself indicates a SID file
            else if (linkText.toLowerCase().endsWith('.sid')) {
                // Build the full path
                let filePath = '';
                if (href.startsWith('/')) {
                    filePath = href.substring(1);
                } else if (!href.includes('?')) {
                    // Just a filename, combine with current path
                    filePath = path ? path + '/' + href : href;
                }

                if (filePath) {
                    entries.push({
                        name: linkText,
                        path: filePath,
                        isDirectory: false
                    });
                    console.log('Added SID from text:', linkText, 'Path:', filePath);
                }
            }
        }

        // Sort entries: directories first, then alphabetically
        entries.sort((a, b) => {
            if (a.isDirectory !== b.isDirectory) {
                return b.isDirectory - a.isDirectory;
            }
            return a.name.localeCompare(b.name);
        });

        // Render entries
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

        // Update counts
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

        console.log('Final entries:', entries.length, 'Directories:', dirCount, 'Files:', sidCount);
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