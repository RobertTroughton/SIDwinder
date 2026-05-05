// hvsc-random.js - Random SID selector for the HVSC collection.
// Loads a curated list of starting directories and walks into them randomly
// until at least one .sid file is found.

window.hvscRandom = (function () {
    const HVSC_BASE = '/.netlify/functions/hvsc';

    let curatedPaths = [];
    let isLoaded = false;
    let isLoading = false;

    async function loadPaths() {
        if (isLoaded) return true;
        if (isLoading) {
            while (isLoading) {
                await new Promise(resolve => setTimeout(resolve, 50));
            }
            return isLoaded;
        }

        isLoading = true;
        try {
            const response = await fetch('hvsc-random.json');
            if (!response.ok) {
                throw new Error('Failed to load HVSC paths');
            }
            const data = await response.json();
            curatedPaths = data.paths || [];
            isLoaded = true;
            console.log(`Loaded ${curatedPaths.length} curated HVSC paths`);
            return true;
        } catch (error) {
            console.error('Error loading HVSC paths:', error);
            isLoading = false;
            return false;
        } finally {
            isLoading = false;
        }
    }

    // Parse directory HTML to extract entries (mirrors hvsc-browser logic).
    function parseDirectoryHTML(html) {
        const entries = [];

        const tableRegex = /<table[^>]*>([\s\S]*?)<\/table>/i;
        const tableMatch = html.match(tableRegex);

        if (tableMatch) {
            const tableContent = tableMatch[1];
            const rowRegex = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
            let rowMatch;

            while ((rowMatch = rowRegex.exec(tableContent)) !== null) {
                const row = rowMatch[1];
                const linkMatch = row.match(/<a\s+href="([^"]+)"[^>]*>(?:<img[^>]*>)?([^<]+)<\/a>/i);

                if (linkMatch) {
                    const href = linkMatch[1];
                    let name = linkMatch[2].trim();

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
            // Fallback: scan every <a> when no <table> wrapper is present.
            const linkRegex = /<a\s+href="([^"]+)"[^>]*>([^<]+)<\/a>/gi;
            let match;

            while ((match = linkRegex.exec(html)) !== null) {
                const href = match[1];
                const linkText = match[2].trim();

                if (linkText === 'Home' || linkText === 'About' || linkText === 'HVSC' ||
                    linkText === 'SidSearch' || linkText === '..' || linkText === '.' ||
                    linkText === 'Parent Directory' || href.startsWith('http://') ||
                    href.startsWith('https://') || href === '#') {
                    continue;
                }

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

        return entries;
    }

    async function fetchDirectory(path) {
        if (path.endsWith('/')) {
            path = path.slice(0, -1);
        }

        const encodedPath = encodeURIComponent(path);
        const url = `${HVSC_BASE}?path=${encodedPath}`;

        const response = await fetch(url);
        if (!response.ok) {
            throw new Error('Failed to fetch directory');
        }

        const html = await response.text();
        return parseDirectoryHTML(html);
    }

    /** Pick a random SID by walking down a randomly-chosen curated start path. */
    async function selectRandomSID(maxDepth = 5, onProgress = null) {
        if (!await loadPaths()) {
            throw new Error('Could not load HVSC paths');
        }

        if (curatedPaths.length === 0) {
            throw new Error('No HVSC paths available');
        }

        let attempts = 0;
        const maxAttempts = 10;

        while (attempts < maxAttempts) {
            attempts++;

            const randomIndex = Math.floor(Math.random() * curatedPaths.length);
            let currentPath = curatedPaths[randomIndex];

            if (onProgress) {
                onProgress(`Exploring ${currentPath.split('/').pop()}...`);
            }

            try {
                let depth = 0;
                while (depth < maxDepth) {
                    const entries = await fetchDirectory(currentPath);

                    const sids = entries.filter(e => !e.isDirectory && e.name.toLowerCase().endsWith('.sid'));
                    const dirs = entries.filter(e => e.isDirectory);

                    if (sids.length > 0) {
                        const randomSid = sids[Math.floor(Math.random() * sids.length)];

                        const sidUrl = `${HVSC_BASE}?path=${encodeURIComponent(randomSid.path)}`;

                        return {
                            name: randomSid.name,
                            path: randomSid.path,
                            url: sidUrl,
                            browsePath: currentPath
                        };
                    } else if (dirs.length > 0) {
                        const randomDir = dirs[Math.floor(Math.random() * dirs.length)];
                        currentPath = randomDir.path;
                        depth++;

                        if (onProgress) {
                            const dirName = currentPath.split('/').pop();
                            onProgress(`Exploring ${dirName}...`);
                        }
                    } else {
                        // Dead-end branch; restart from a different curated root.
                        break;
                    }
                }
            } catch (error) {
                console.warn(`Failed to explore ${currentPath}:`, error);
            }
        }

        throw new Error('Could not find a random SID after multiple attempts');
    }

    return {
        loadPaths: loadPaths,
        selectRandomSID: selectRandomSID
    };
})();
