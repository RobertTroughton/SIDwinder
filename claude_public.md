### FILE: public/hvsc-browser.html
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HVSC SID Browser</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="stylesheet" href="hvsc-browser.css">
</head>
<body>
    <div class="browser-container">
        <div class="browser-header">
            <div class="browser-title">HVSC SID Collection Browser</div>
            <div class="browser-controls">
                <button class="btn" id="homeBtn" onclick="hvscBrowser.navigateHome()" title="Go to home">
                    <i class="fas fa-home"></i>
                </button>
                <button class="btn" id="upBtn" onclick="hvscBrowser.navigateUp()" title="Go up one directory">
                    <i class="fas fa-level-up-alt"></i>
                </button>
                <input type="text" class="path-bar" id="pathBar" readonly>
            </div>
        </div>
        
        <div class="browser-content">
            <div class="file-panel">
                <div class="panel-header">Files & Directories</div>
                <div class="file-list" id="fileList">
                    <div class="loading">Loading directory</div>
                </div>
            </div>
        </div>
        
        <div class="status-bar">
            <span id="itemCount">0 items</span>
            <span style="margin-left: auto; color: #888; font-size: 11px;">Double-click to select a SID file</span>
        </div>
    </div>

    <script src="hvsc-browser.js"></script>
</body>
</html>
```


### FILE: public/hvsc.html
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HVSC SID Browser</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }

        .browser-container {
            background: #1e1e1e;
            border-radius: 8px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            width: 100%;
            max-width: 900px;
            height: 600px;
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }

        .browser-header {
            background: #2d2d2d;
            padding: 15px;
            border-bottom: 1px solid #444;
        }

        .browser-title {
            color: #fff;
            font-size: 16px;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .browser-title::before {
            content: '🎵';
            font-size: 20px;
        }

        .browser-controls {
            display: flex;
            gap: 10px;
            align-items: center;
        }

        .btn {
            background: #4a4a4a;
            color: #fff;
            border: none;
            padding: 8px 15px;
            border-radius: 4px;
            cursor: pointer;
            transition: background 0.3s;
            font-size: 14px;
        }

        .btn:hover {
            background: #5a5a5a;
        }

        .btn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }

        .btn-primary {
            background: #667eea;
        }

        .btn-primary:hover {
            background: #7b8ff5;
        }

        .path-bar {
            flex: 1;
            background: #3a3a3a;
            color: #fff;
            padding: 8px 12px;
            border-radius: 4px;
            border: 1px solid #555;
            font-family: 'Courier New', monospace;
            font-size: 13px;
        }

        .browser-content {
            display: flex;
            flex: 1;
            overflow: hidden;
        }

        .file-panel {
            flex: 1;
            display: flex;
            flex-direction: column;
            border-right: 1px solid #444;
        }

        .file-panel:last-child {
            border-right: none;
        }

        .panel-header {
            background: #2a2a2a;
            color: #aaa;
            padding: 10px;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 1px;
            border-bottom: 1px solid #444;
        }

        .file-list {
            flex: 1;
            overflow-y: auto;
            background: #1a1a1a;
            user-select: none;  /* Prevent text selection */
        }

        .file-item {
            display: flex;
            align-items: center;
            padding: 8px 12px;
            color: #ccc;
            cursor: pointer;
            transition: background 0.2s;
            border-bottom: 1px solid #2a2a2a;
            font-size: 14px;
            user-select: none;  /* Prevent text selection */
        }

        .file-item:hover {
            background: #2a2a2a;
        }

        .file-item.selected {
            background: #3a3a6a;
            color: #fff;
        }

        .file-item.directory {
            color: #88aaff;
            font-weight: 500;
        }

        .file-icon {
            margin-right: 8px;
            width: 16px;
            text-align: center;
        }

        .file-name {
            flex: 1;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .file-size {
            font-size: 12px;
            color: #888;
            margin-left: 10px;
        }

        .status-bar {
            background: #2d2d2d;
            color: #aaa;
            padding: 8px 15px;
            font-size: 12px;
            border-top: 1px solid #444;
            display: flex;
            justify-content: space-between;
        }

        .loading {
            text-align: center;
            padding: 20px;
            color: #888;
        }

        .loading::after {
            content: '...';
            animation: dots 1s steps(3, end) infinite;
        }

        @keyframes dots {
            0%, 20% { content: '.'; }
            40% { content: '..'; }
            60%, 100% { content: '...'; }
        }

        .preview-panel {
            width: 300px;
            background: #252525;
            padding: 15px;
            overflow-y: auto;
        }

        .preview-title {
            color: #888;
            font-size: 12px;
            text-transform: uppercase;
            margin-bottom: 10px;
        }

        .preview-content {
            color: #ccc;
            font-size: 13px;
            line-height: 1.6;
        }

        .preview-item {
            margin-bottom: 8px;
        }

        .preview-label {
            color: #888;
            display: inline-block;
            width: 80px;
        }

        .error-message {
            color: #ff6b6b;
            padding: 20px;
            text-align: center;
        }

        /* Scrollbar styling */
        .file-list::-webkit-scrollbar {
            width: 8px;
        }

        .file-list::-webkit-scrollbar-track {
            background: #1a1a1a;
        }

        .file-list::-webkit-scrollbar-thumb {
            background: #444;
            border-radius: 4px;
        }

        .file-list::-webkit-scrollbar-thumb:hover {
            background: #555;
        }
    </style>
</head>
<body>
    <div class="browser-container">
        <div class="browser-header">
            <div class="browser-title">HVSC SID Collection Browser</div>
            <div class="browser-controls">
                <button class="btn" id="homeBtn" onclick="navigateHome()" title="Go to home">
                    <i class="fas fa-home"></i>
                </button>
                <button class="btn" id="upBtn" onclick="navigateUp()" title="Go up one directory">
                    <i class="fas fa-level-up-alt"></i>
                </button>
                <input type="text" class="path-bar" id="pathBar" readonly>
            </div>
        </div>
        
        <div class="browser-content">
            <div class="file-panel">
                <div class="panel-header">Files & Directories</div>
                <div class="file-list" id="fileList">
                    <div class="loading">Loading directory</div>
                </div>
            </div>
        </div>
        
        <div class="status-bar">
            <span id="itemCount">0 items</span>
            <span style="margin-left: auto; color: #888; font-size: 11px;">Double-click to select a SID file</span>
        </div>
    </div>

    <script>
        // Configuration
        const HVSC_BASE = window.location.hostname === 'localhost' 
            ? 'https://hvsc.etv.cx/'  // Direct for local testing
            : '/api/hvsc/';  // Proxied through Netlify in production
        
        let currentPath = 'C64Music';
        let currentSelection = null;
        let entries = [];

        // Initialize on load
        window.onload = function() {
            // Start at root to see what directories are available
            fetchDirectory('');
        };

        async function fetchDirectory(path) {
            document.getElementById('fileList').innerHTML = '<div class="loading">Loading directory</div>';
            
            try {
                // Build the URL based on environment
                const url = `${HVSC_BASE}?path=${path}`;
                
                const response = await fetch(url);
                
                if (!response.ok) {
                    throw new Error('Failed to fetch directory');
                }
                
                const html = await response.text();
                parseDirectory(html, path);
                currentPath = path;  // Update current path AFTER successful parse
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
            
            // Look for the directory listing table
            const tableRegex = /<table[^>]*width="99%"[^>]*>([\s\S]*?)<\/table>/i;
            const tableMatch = html.match(tableRegex);
            
            if (tableMatch) {
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
                        // Process SID file links (both formats)
                        else if (href.toLowerCase().includes('.sid')) {
                            let filePath = '';
                            let fileName = name;
                            
                            // Format 1: /download/path/to/file.sid
                            if (href.startsWith('/download/')) {
                                filePath = href.substring(10);
                                // Extract filename from path if name is generic
                                if (name === 'info' || name === 'download') {
                                    fileName = filePath.split('/').pop();
                                }
                            }
                            // Format 2: ?info=please&path=path/to/file.sid
                            else if (href.includes('info=please')) {
                                const pathMatch = href.match(/path=([^&]+)/);
                                if (pathMatch) {
                                    filePath = decodeURIComponent(pathMatch[1]);
                                    // Extract filename from path
                                    fileName = filePath.split('/').pop();
                                }
                            }
                            // Format 3: Direct path
                            else if (href.startsWith('/')) {
                                filePath = href.substring(1);
                                if (name === 'info') {
                                    fileName = filePath.split('/').pop();
                                }
                            }
                            
                            if (filePath) {
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
                // Fallback: look for any links with ?path= or .sid
                const linkRegex = /<a\s+href="([^"]+)"[^>]*>(?:<img[^>]*>)?([^<]+)<\/a>/gi;
                let match;
                
                while ((match = linkRegex.exec(html)) !== null) {
                    const href = match[1];
                    let text = match[2].trim();
                    
                    // Skip navigation links
                    if (text === 'Home' || text === 'About' || text === 'HVSC' || 
                        text === 'SidSearch' || text === '..' || text === '.') {
                        continue;
                    }
                    
                    if (href.startsWith('?path=') && !href.includes('info=')) {
                        const pathValue = decodeURIComponent(href.substring(6));
                        text = text.replace(/\/$/, '');
                        
                        entries.push({
                            name: text,
                            path: pathValue,
                            isDirectory: true
                        });
                    } else if (href.toLowerCase().includes('.sid')) {
                        let filePath = '';
                        let fileName = text;
                        
                        if (href.startsWith('/download/')) {
                            filePath = href.substring(10);
                            if (text === 'info' || text === 'download') {
                                fileName = filePath.split('/').pop();
                            }
                        } else if (href.includes('info=please')) {
                            const pathMatch = href.match(/path=([^&]+)/);
                            if (pathMatch) {
                                filePath = decodeURIComponent(pathMatch[1]);
                                fileName = filePath.split('/').pop();
                            }
                        }
                        
                        if (filePath) {
                            entries.push({
                                name: fileName,
                                path: filePath,
                                isDirectory: false
                            });
                        }
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
            
            // Update item count - only count SID files
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
            // Update selection
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
            if (!currentPath || currentPath === '') {
                return; // Already at root
            }
            
            // Remove trailing slash if present
            let cleanPath = currentPath;
            if (cleanPath.endsWith('/')) {
                cleanPath = cleanPath.slice(0, -1);
            }
            
            // Split the path and remove the last segment
            const parts = cleanPath.split('/');
            parts.pop(); // Remove current directory
            
            const parentPath = parts.join('/');
            fetchDirectory(parentPath);
        }

        function navigateHome() {
            fetchDirectory('');
        }

        function updatePathBar() {
            const pathDisplay = currentPath ? '/' + currentPath : '/';
            document.getElementById('pathBar').value = pathDisplay;
            
            // Disable up button if at root
            document.getElementById('upBtn').disabled = !currentPath || currentPath === '';
        }

        function updateStatus(message) {
            document.getElementById('statusText').textContent = message;
        }

        function selectSID() {
        	if (currentSelection && !currentSelection.isDirectory) {
        		// Build correct URL format: base + C64Music/ + path
        		const baseUrl = window.location.hostname === 'localhost' 
        			? 'https://hvsc.etv.cx/' 
        			: '/api/hvsc/';
        		
        		// Ensure the path starts with C64Music/
        		let fullPath = currentSelection.path;
        		if (!fullPath.startsWith('C64Music/')) {
        			fullPath = 'C64Music/' + fullPath;
        		}
        		
        		const sidUrl = baseUrl + fullPath;
        		
        		if (window.opener) {
        			window.opener.postMessage({
        				type: 'sid-selected',
        				name: currentSelection.name,
        				path: currentSelection.path,
        				url: sidUrl
        			}, '*');
        			
        			updateStatus('SID selected: ' + currentSelection.name);
        			
        			// Optionally close the window
        			setTimeout(() => {
        				window.close();
        			}, 500);
        		} else {
        			// If not in popup, just log or handle differently
        			console.log('Selected SID:', sidUrl);
        			alert('Selected: ' + currentSelection.name + '\nURL: ' + sidUrl);
        		}
        	}
        }

        // Handle Enter key for quick selection
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && currentSelection) {
                if (currentSelection.isDirectory) {
                    fetchDirectory(currentSelection.path);
                } else {
                    selectSID();
                }
            }
        });
    </script>
</body>
</html>
```


### FILE: public/index.html
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SIDquake - C64 SID Music Linker</title>
    <link rel="stylesheet" href="genesis-header.css">
    <link rel="stylesheet" href="styles.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
</head>
<body>
    
    <header class="genesis-header">
        <div class="genesis-header-inner">
            <nav class="genesis-nav">
                <span class="genesis-nav-label">Genesis Project Sites</span>
                <ul class="genesis-nav-links">
                    <li><a href="https://c64gfx.com">C64GFX</a></li>
                    <li><a href="https://c64demo.com">C64Demo</a></li>
                    <li><a href="https://sidquake.c64demo.com" class="active">SIDquake</a></li>
                    <li><a href="https://dirquake.c64demo.com">DIRquake</a></li>
                </ul>
            </nav>
        </div>
    </header>

    <div class="container">
        <div class="header">
            <div class="logo-container">
                <img src="SIDquake.png" alt="SIDquake" class="logo" />
                <div class="header-info">
                    <h1>SIDquake</h1>
                    <p class="tagline">C64 SID Analyzer, Linker & Tool Suite</p>
                    <div class="version-badge">PREVIEW</div>
                </div>
            </div>
        </div>

        <div class="main-content">
            
            <div class="upload-container">
                
                <div class="upload-section" id="uploadSection">
                    <div class="upload-icon">📂</div>
                    <div class="upload-text">Drop your SID file here</div>
                    <div class="upload-subtext">or use the buttons below</div>
                </div>

                <div class="upload-buttons">
                    <button class="upload-btn" id="uploadBtn">
                        <span class="upload-btn-icon">📁</span>
                        <span>Upload SID</span>
                    </button>
                    <button class="upload-btn" id="hvscBtn">
                        <span class="upload-btn-icon">🎵</span>
                        <span>Browse HVSC</span>
                    </button>
                </div>

                <div class="hvsc-selected" id="hvscSelected" style="display: none;">
                    <span class="selected-label">Selected:</span>
                    <span class="selected-file" id="selectedFile"></span>
                </div>

                <input type="file" id="fileInput" accept=".sid" style="display: none;">
            </div>

            <div class="song-title-section disabled" id="songTitleSection">
                <div class="song-title" id="songTitle">[ No SID Loaded ]</div>
                <div class="song-author" id="songAuthor">Load a SID file to begin</div>
            </div>

            <div class="loading" id="loading">
                <div class="spinner"></div>
                <div>Analyzing SID file...</div>
                <div class="progress-bar" id="progressBar">
                    <div class="progress-fill" id="progressFill"></div>
                </div>
                <div class="progress-text" id="progressText"></div>
            </div>

            <div class="error-message" id="errorMessage"></div>

            <div class="section-group info-section disabled" id="infoSection">
                <div class="info-panels" id="infoPanels">
                    
                    <div class="panel">
                        <h2>📄 File Information</h2>
                        <div class="info-row">
                            <span class="info-label">Title:</span>
                            <span class="info-value editable" id="sidTitle" data-field="title" title="Click to edit">
                                <span class="text">-</span>
                                <span class="edit-icon">✏️</span>
                            </span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Author:</span>
                            <span class="info-value editable" id="sidAuthor" data-field="author" title="Click to edit">
                                <span class="text">-</span>
                                <span class="edit-icon">✏️</span>
                            </span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Copyright:</span>
                            <span class="info-value editable" id="sidCopyright" data-field="copyright" title="Click to edit">
                                <span class="text">-</span>
                                <span class="edit-icon">✏️</span>
                            </span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Format:</span>
                            <span class="info-value" id="sidFormat">-</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Version:</span>
                            <span class="info-value" id="sidVersion">-</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Songs:</span>
                            <span class="info-value" id="sidSongs">-</span>
                        </div>
                    </div>

                    <div class="panel">
                        <h2>⚙️ Technical Details</h2>
                        <div class="info-row">
                            <span class="info-label">Load Address:</span>
                            <span class="info-value" id="loadAddress">-</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Init Address:</span>
                            <span class="info-value" id="initAddress">-</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Play Address:</span>
                            <span class="info-value" id="playAddress">-</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Memory Range:</span>
                            <span class="info-value" id="memoryRange">-</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">File Size:</span>
                            <span class="info-value" id="fileSize">-</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Zero Page Usage:</span>
                            <span class="info-value" id="zpUsage">-</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Clock:</span>
                            <span class="info-value" id="clockType">-</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">SID Model:</span>
                            <span class="info-value" id="sidModel">-</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Play Calls/Frame:</span>
                            <span class="info-value" id="numCallsPerFrame">-</span>
                        </div>
                    </div>
                </div>

                <div class="export-modified-container">
                    <button class="export-button" id="exportModifiedSIDButton" disabled>
                        💾 Export Modified SID
                    </button>
                    <div class="export-hint" id="exportHint">Edit the metadata above to enable export</div>
                </div>
            </div>

            <div class="section-group export-section disabled" id="exportSection">
                <h2>🎮 Choose Your Visualizer</h2>

                <div class="visualizer-grid" id="visualizerGrid">
                    
                </div>

                <div class="visualizer-options" id="visualizerOptions" style="display: none;">
                    
                </div>

                <div class="export-buttons">
                    <button class="export-button" id="exportPRGButton" disabled>
                        🎮 Export PRG
                    </button>
                </div>

                <div class="export-status" id="exportStatus"></div>
            </div>
        </div>
    </div>
    </div> 
    
    <div class="modal-overlay" id="modalOverlay">
        <div class="modal-content">
            <div class="modal-icon" id="modalIcon">✔</div>
            <div class="modal-message" id="modalMessage">Success!</div>
        </div>
    </div>

    <script type="module">
        import { Cruncher, createSFX } from './lib/index.js';

        // Buffer polyfill for browser
        if (typeof Buffer === 'undefined') {
            window.Buffer = {
                from: function (data) {
                    if (data instanceof Uint8Array) return data;
                    if (Array.isArray(data)) return new Uint8Array(data);
                    return new Uint8Array(0);
                }
            };
        }

        // Make TSCrunch available globally
        window.TSCrunch = {
            compress: function (data, options = {}) {
                const {
                    prg = true,
                    sfx = true,
                    sfxMode = 0,
                    jumpAddress = 0x1000,
                    blank = false,
                    inplace = false
                } = options;

                // Convert data to array if needed
                const dataArray = Array.from(data);

                // Handle PRG format (skip load address)
                let sourceData = dataArray;
                let loadAddress = 0x0801;

                if (prg && dataArray.length >= 2) {
                    loadAddress = dataArray[0] | (dataArray[1] << 8);
                    sourceData = dataArray.slice(2);
                }

                // Create cruncher
                const cruncher = new Cruncher(sourceData);

                // Compress
                cruncher.ocrunch({
                    inplace: inplace,
                    verbose: false,
                    sfxMode: sfx
                });

                // Get compressed data
                let compressed = cruncher.crunched;

                // Create SFX if requested
                if (sfx) {
                    compressed = Array.from(createSFX(Buffer.from(compressed), {
                        jumpAddress: jumpAddress,
                        decrunchAddress: loadAddress,
                        optimalRun: cruncher.optimalRun,
                        sfxMode: sfxMode,
                        blank: blank
                    }));
                }

                // The SFX already has the load address from createSFX
                // Don't add it again!
                return new Uint8Array(compressed);
            }
        };

        // Signal that TSCrunch is ready
        window.dispatchEvent(new Event('tscrunch-ready'));
    </script>

    <div class="hvsc-modal" id="hvscModal">
        <div class="hvsc-modal-content">
            <button class="hvsc-modal-close" id="hvscModalClose">✕</button>
            <div class="hvsc-modal-body">
                <div class="browser-container" style="height: 100%; background: transparent;">
                    <div class="browser-header">
                        <div class="browser-title">HVSC SID Collection Browser</div>
                        <div class="browser-controls">
                            <button class="btn" id="homeBtn" onclick="hvscBrowser.navigateHome()" title="Go to home">
                                <i class="fas fa-home"></i>
                            </button>
                            <button class="btn" id="upBtn" onclick="hvscBrowser.navigateUp()" title="Go up one directory">
                                <i class="fas fa-level-up-alt"></i>
                            </button>
                            <input type="text" class="path-bar" id="pathBar" readonly>
                        </div>
                    </div>

                    <div class="browser-content">
                        <div class="file-panel">
                            <div class="panel-header">Files & Directories</div>
                            <div class="file-list" id="fileList">
                                <div class="loading">Loading directory</div>
                            </div>
                        </div>
                    </div>

                    <div class="status-bar">
                        <span id="itemCount">0 items</span>
                        <span style="margin-left: auto; color: #888; font-size: 11px;">Double-click to select a SID file</span>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="gallery-modal" id="galleryModal">
        <div class="gallery-modal-content">
            <button class="gallery-modal-close" id="galleryModalClose">✕</button>
            <div class="gallery-modal-body">
                <div class="gallery-container">
                    <div class="gallery-header">
                        <div class="gallery-title">🎨 Image Gallery</div>
                        <div class="gallery-subtitle" id="gallerySubtitle">Select an image</div>
                    </div>

                    <div class="gallery-content">
                        <div class="gallery-grid-container" id="galleryGridContainer">
                        </div>
                    </div>

                    <div class="gallery-status-bar">
                        <span id="galleryItemCount">0 items</span>
                        <span style="margin-left: auto; color: #888; font-size: 11px;">Click to select an image</span>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="sidwinder.js"></script>
    <script src="sidwinder-core.js"></script>
    <script src="png-converter.js"></script>
    <script src="image-preview-manager.js"></script>
    <script src="compressor-manager.js"></script>
    <script src="prg-builder.js"></script>
    <script src="hvsc-browser.js"></script>
    <script src="ui.js"></script>
    <script src="visualizer-registry.js"></script>
    <script src="visualizer-configs.js"></script>
    <script src="floating-notes.js"></script>
    <script src="text-drop-zone.js"></script>
    <script src="petscii-sanitizer.js"></script>

</body>
</html>
```


### FILE: public/genesis-header.css
```css
.genesis-header {
	background-color: #1a1a1a;
	border-bottom: 2px solid #404040;
	padding: 0;
	margin: 0;
	font-family: -apple-system, system-ui, sans-serif;
	position: relative;
	z-index: 1000;
	display: flex;
	justify-content: center;
	width: 100%;
	box-sizing: border-box;
}

.genesis-header-inner {
	max-width: 80em;
	margin: 0 auto;
	display: flex;
	justify-content: flex-start;
	align-items: center;
	padding: 0.5rem 2rem;
	box-sizing: border-box;
}

.genesis-nav {
	display: flex;
	gap: 2rem;
	align-items: center;
}

.genesis-nav-label {
	color: #606060;
	font-size: 0.7rem;
	text-transform: uppercase;
	letter-spacing: 0.15em;
	margin-right: -1rem;
	font-weight: 500;
}

.genesis-nav-links {
	display: flex;
	gap: 1.25rem;
	list-style: none;
	margin: 0;
	padding: 0;
}

	.genesis-nav-links li {
		margin: 0;
	}

.genesis-header .genesis-nav-links a[href],
.genesis-header .genesis-nav-links a[href]:link,
.genesis-header .genesis-nav-links a[href]:visited {
	color: #b0b0b0;
	text-decoration: none;
	font-weight: 500;
	font-size: 0.85rem;
	text-transform: uppercase;
	letter-spacing: 0.05em;
	transition: all 0.2s ease;
	padding: 0.25rem 0.5rem;
	border-radius: 2px;
	display: block;
	position: relative;
}

	.genesis-header .genesis-nav-links a[href]:hover,
	.genesis-header .genesis-nav-links a[href]:active {
		color: #e0e0e0;
		background-color: #2a2a2a;
	}

	.genesis-header .genesis-nav-links a[href].active,
	.genesis-header .genesis-nav-links a[href].active:link,
	.genesis-header .genesis-nav-links a[href].active:visited,
	.genesis-header .genesis-nav-links a[href].active:hover {
		color: #ffffff;
		background-color: #303030;
	}

.genesis-nav-links a.active::after {
	content: '';
	position: absolute;
	bottom: -8px;
	left: 50%;
	transform: translateX(-50%);
	width: 30%;
	height: 2px;
	background-color: #606060;
}

@media (max-width: 768px) {
	.genesis-header-inner {
		flex-direction: column;
		padding: 0.75rem 1rem;
		gap: 0.5rem;
	}

	.genesis-nav {
		flex-direction: column;
		gap: 0.25rem;
		width: 100%;
	}

	.genesis-nav-label {
		margin-right: 0;
		margin-bottom: 0.25rem;
	}

	.genesis-nav-links {
		gap: 0.5rem;
		flex-wrap: wrap;
		justify-content: center;
	}

	.genesis-header .genesis-nav-links a[href],
	.genesis-header .genesis-nav-links a[href]:link,
	.genesis-header .genesis-nav-links a[href]:visited {
		font-size: 0.8rem;
		padding: 0.35rem 0.6rem;
	}

	.genesis-nav-links a.active::after {
		display: none;
	}
}

@media (max-width: 480px) {
	.genesis-nav-links {
		width: 100%;
	}

	.genesis-header .genesis-nav-links a[href],
	.genesis-header .genesis-nav-links a[href]:link,
	.genesis-header .genesis-nav-links a[href]:visited {
		flex: 1;
		text-align: center;
		min-width: 80px;
	}
}
```


### FILE: public/hvsc-browser.css
```css
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 20px;
}
```


### FILE: public/styles.css
```css
﻿* {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

body {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    min-height: 100vh;
    padding: 0;
}

.container {
    background: rgba(255, 255, 255, 0.95);
    border-radius: 20px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    justify-content: center;
    margin: 0 auto;
    margin-top: 20px;
    max-width: 1200px;
    min-height: calc(100vh - 40px);
    overflow: hidden;
    padding: 20px;
    position: relative;
    width: 100%;
}

.header {
    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
    border-bottom: 3px solid #00d4ff;
    box-shadow: 0 4px 20px rgba(0, 212, 255, 0.3);
    overflow: hidden;
    position: relative;
}

    .header::before {
        content: '';
        position: absolute;
        top: 0;
        left: -100%;
        width: 100%;
        height: 100%;
        background: linear-gradient(90deg, transparent, rgba(0, 212, 255, 0.1), transparent);
        animation: shimmer 3s infinite;
        pointer-events: none;
    }

@keyframes shimmer {
    0% {
        left: -100%;
    }

    100% {
        left: 100%;
    }
}

.logo-container {
    display: flex;
    align-items: center;
    padding: 1.5rem 2rem;
    max-width: 1200px;
    margin: 0 auto;
    position: relative;
    z-index: 1;
    justify-content: center;
}

.logo {
    height: 80px;
    width: auto;
    margin-right: 2rem;
    filter: drop-shadow(0 0 10px rgba(0, 212, 255, 0.5));
    transition: filter 0.3s ease;
}

    .logo:hover {
        filter: drop-shadow(0 0 15px rgba(0, 212, 255, 0.8));
    }

.header-info {
    display: flex;
    flex-direction: column;
    color: white;
    position: relative;
}

.header h1 {
    font-size: 2.5rem;
    font-weight: 700;
    margin: 0;
    color: #00d4ff;
    text-shadow: 0 0 10px rgba(0, 212, 255, 0.5);
    letter-spacing: -0.5px;
}

.header p,
.tagline {
    font-size: 1.1rem;
    color: #b0c4de;
    margin: 0.25rem 0 0.5rem 0;
    font-weight: 300;
    letter-spacing: 0.5px;
    opacity: 1;
}

.version-badge {
    display: inline-block;
    background: linear-gradient(45deg, #ff6b6b, #ff8e8e);
    color: white;
    padding: 0.25rem 0.75rem;
    border-radius: 15px;
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 1px;
    box-shadow: 0 2px 10px rgba(255, 107, 107, 0.4);
    animation: pulse-badge 2s infinite;
    align-self: flex-start;
}

.main-content {
    padding: 40px;
}

.upload-container {
    background: rgba(102, 126, 234, 0.03);
    border: 2px solid rgba(102, 126, 234, 0.15);
    border-radius: 20px;
    padding: 25px;
    margin-bottom: 30px;
    box-shadow: 0 4px 15px rgba(0, 0, 0, 0.05);
}

.upload-section {
    border: 3px dashed #667eea;
    border-radius: 15px;
    padding: 40px;
    text-align: center;
    transition: all 0.3s ease;
    cursor: pointer;
    background: rgba(102, 126, 234, 0.05);
    position: relative;
    overflow: hidden;
    margin-bottom: 20px;
}

    .upload-section::before {
        content: '';
        position: absolute;
        top: -50%;
        left: -50%;
        width: 200%;
        height: 200%;
        background: radial-gradient(circle, rgba(102, 126, 234, 0.1) 0%, transparent 70%);
        animation: pulse 3s ease-in-out infinite;
        pointer-events: none;
    }

@keyframes pulse {
    0%, 100% {
        transform: scale(0.8);
        opacity: 0;
    }

    50% {
        transform: scale(1);
        opacity: 1;
    }
}

.upload-section:hover {
    border-color: #764ba2;
    background: rgba(102, 126, 234, 0.1);
    transform: translateY(-2px);
}

.upload-section.dragover {
    background: rgba(102, 126, 234, 0.2);
    border-color: #764ba2;
}

.upload-icon {
    font-size: 4em;
    margin-bottom: 20px;
    color: #667eea;
}

.upload-text {
    font-size: 1.2em;
    color: #333;
    margin-bottom: 10px;
}

.upload-subtext {
    color: #666;
    font-size: 0.9em;
}

.upload-buttons {
    display: flex;
    gap: 15px;
    justify-content: center;
}

.upload-btn {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border: none;
    padding: 12px 25px;
    border-radius: 8px;
    font-size: 1em;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
    display: flex;
    align-items: center;
    gap: 8px;
}

    .upload-btn:hover {
        transform: translateY(-2px);
        box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
    }

    .upload-btn:active {
        transform: translateY(0);
    }

.upload-btn-icon {
    font-size: 1.2em;
}

.hvsc-selected {
    margin-top: 20px;
    padding: 15px;
    background: rgba(102, 126, 234, 0.1);
    border-radius: 8px;
    border: 1px solid rgba(102, 126, 234, 0.3);
    text-align: center;
}

.selected-label {
    font-weight: 600;
    color: #667eea;
    margin-right: 10px;
}

.selected-file {
    color: #333;
    font-family: 'Courier New', monospace;
}

#fileInput {
    display: none;
}

.section-group {
    background: rgba(102, 126, 234, 0.03);
    border: 2px solid rgba(102, 126, 234, 0.15);
    border-radius: 20px;
    padding: 25px;
    margin-bottom: 30px;
    box-shadow: 0 4px 15px rgba(0, 0, 0, 0.05);
    transition: all 0.3s ease;
}

    .section-group:hover:not(.disabled) {
        border-color: rgba(102, 126, 234, 0.25);
        box-shadow: 0 6px 20px rgba(0, 0, 0, 0.08);
    }

    .section-group.disabled {
        cursor: not-allowed;
        user-select: none;
    }

.info-section {
    opacity: 1;
    transition: all 0.5s ease;
}

    .info-section.disabled {
        opacity: 0.5;
        filter: grayscale(50%);
        pointer-events: none;
    }

    .info-section.visible {
        opacity: 1;
        filter: none;
        pointer-events: auto;
    }

.song-title-section {
    background: linear-gradient(135deg, #667eea20 0%, #764ba220 100%);
    border-radius: 15px;
    padding: 20px;
    margin: 20px 0;
    text-align: center;
    display: block;
    transition: all 0.5s ease;
}

    .song-title-section.disabled {
        opacity: 0.5;
        filter: grayscale(50%);
    }

    .song-title-section.visible {
        display: block;
        opacity: 1;
        filter: none;
    }

.song-title {
    font-size: 1.5em;
    color: #667eea;
    font-weight: 600;
    margin-bottom: 5px;
}

.song-author {
    font-size: 1.1em;
    color: #764ba2;
}

.info-panels {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 30px;
    margin-bottom: 20px;
}

.panel {
    background: white;
    border-radius: 15px;
    padding: 25px;
    box-shadow: 0 5px 20px rgba(0, 0, 0, 0.1);
    transition: all 0.3s ease;
}

.disabled .panel {
    background: rgba(255, 255, 255, 0.7);
    box-shadow: 0 3px 10px rgba(0, 0, 0, 0.05);
}

.panel h2 {
    color: #667eea;
    margin-bottom: 20px;
    font-size: 1.3em;
    border-bottom: 2px solid #f0f0f0;
    padding-bottom: 10px;
}

.panel.full-width {
    grid-column: 1 / -1;
}

.info-row {
    display: flex;
    justify-content: space-between;
    padding: 10px 0;
    border-bottom: 1px solid #f5f5f5;
}

    .info-row:last-child {
        border-bottom: none;
    }

.info-label {
    font-weight: 600;
    color: #555;
}

.info-value {
    color: #333;
    font-family: 'Courier New', monospace;
}

    .info-value.editable {
        cursor: pointer;
        padding: 2px 6px;
        border-radius: 4px;
        transition: all 0.2s;
        border: 1px dashed transparent;
        position: relative;
        display: inline-flex;
        align-items: center;
        gap: 8px;
    }

        .info-value.editable:hover {
            background: rgba(102, 126, 234, 0.1);
            border: 1px dashed #667eea;
        }

        .info-value.editable .text {
            display: inline-block;
        }

        .info-value.editable .edit-icon {
            color: #667eea;
            font-size: 0.9em;
            opacity: 0.6;
            transition: opacity 0.2s;
        }

        .info-value.editable:hover .edit-icon {
            opacity: 1;
        }

    .info-value.editing {
        background: white;
        border: 2px solid #667eea;
        padding: 4px 8px;
        outline: none;
    }

        .info-value.editing .edit-icon {
            display: none;
        }

.export-modified-container {
    text-align: center;
    padding-top: 10px;
}

.export-hint {
    color: #888;
    font-size: 0.9em;
    margin-top: 10px;
    font-style: italic;
}

.export-section {
    display: block;
    opacity: 1;
    transition: all 0.5s ease;
}

    .export-section.disabled {
        opacity: 0.5;
        filter: grayscale(50%);
        pointer-events: none;
    }

    .export-section.visible {
        display: block;
        opacity: 1;
        filter: none;
        pointer-events: auto;
    }

    .export-section h2 {
        color: #667eea;
        margin-bottom: 20px;
        font-size: 1.3em;
        border-bottom: 2px solid rgba(102, 126, 234, 0.2);
        padding-bottom: 10px;
    }

    .export-section.disabled h2::after {
        content: ' (Load a SID file to enable)';
        font-size: 0.8em;
        color: #999;
        font-weight: normal;
    }

.song-selector-container {
    margin-bottom: 20px;
    padding: 15px;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 8px;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

    .song-selector-container label {
        margin-right: 10px;
        color: #667eea;
        font-weight: 600;
    }

    .song-selector-container select {
        padding: 8px 12px;
        background: white;
        border: 2px solid #dee2e6;
        border-radius: 6px;
        color: #333;
        min-width: 200px;
        cursor: pointer;
        transition: all 0.2s;
    }

        .song-selector-container select:hover {
            border-color: #667eea;
        }

        .song-selector-container select:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }

.visualizer-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 20px;
    margin: 20px 0;
}

.visualizer-card {
    background: white;
    border: 2px solid #e0e0e0;
    border-radius: 12px;
    overflow: hidden;
    cursor: pointer;
    transition: all 0.3s ease;
    position: relative;
}

    .visualizer-card:hover {
        transform: translateY(-4px);
        box-shadow: 0 8px 20px rgba(0, 0, 0, 0.1);
        border-color: #667eea;
    }

    .visualizer-card.selected {
        border-color: #667eea;
        box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.2);
    }

    .visualizer-card.disabled {
        opacity: 0.5;
        cursor: not-allowed;
        filter: grayscale(70%);
    }

        .visualizer-card.disabled:hover {
            transform: none;
            box-shadow: none;
            border-color: #e0e0e0;
        }

        .visualizer-card.disabled .visualizer-info::after {
            content: attr(data-reason);
            position: absolute;
            bottom: 5px;
            left: 15px;
            right: 15px;
            font-size: 0.8em;
            color: #ff6b6b;
            font-weight: 600;
        }

.disabled .visualizer-card {
    opacity: 0.6;
    filter: grayscale(30%);
}

    .disabled .visualizer-card:hover {
        transform: none;
        cursor: default;
    }

.visualizer-preview {
    width: 100%;
    height: 150px;
    background: #f0f0f0;
    overflow: hidden;
}

    .visualizer-preview img {
        width: 100%;
        height: 100%;
        object-fit: cover;
    }

.visualizer-info {
    padding: 15px;
    position: relative;
}

    .visualizer-info h3 {
        margin: 0 0 8px 0;
        color: #333;
        font-size: 1.1em;
    }

    .visualizer-info p {
        margin: 0;
        color: #666;
        font-size: 0.9em;
        line-height: 1.4;
    }

.visualizer-selected-badge {
    position: absolute;
    top: 10px;
    right: 10px;
    background: #667eea;
    color: white;
    padding: 5px 10px;
    border-radius: 20px;
    font-size: 0.8em;
    font-weight: 600;
    display: none;
}

.visualizer-card.selected .visualizer-selected-badge {
    display: block;
}

.visualizer-separator {
    grid-column: 1 / -1;
    text-align: center;
    padding: 20px;
    color: #666;
    font-style: italic;
    border-top: 1px dashed #333;
    margin: 10px 0;
}

.visualizer-options-panel {
    background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
    border: 2px solid rgba(102, 126, 234, 0.2);
    border-radius: 16px;
    margin: 30px auto;
    max-width: 700px;
    overflow: hidden;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
    animation: slideIn 0.3s ease;
}

@keyframes slideIn {
    from {
        opacity: 0;
        transform: translateY(-10px);
    }

    to {
        opacity: 1;
        transform: translateY(0);
    }
}

.options-header {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    padding: 18px 25px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.2);
}

    .options-header h3 {
        margin: 0;
        color: white;
        font-size: 1.2em;
        font-weight: 600;
        text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    }

.options-content {
    padding: 25px;
}

.option-group {
    margin-bottom: 25px;
}

    .option-group:last-child {
        margin-bottom: 0;
    }

.option-group-title {
    font-size: 0.85em;
    font-weight: 600;
    text-transform: uppercase;
    color: #6c757d;
    margin-bottom: 15px;
    padding-bottom: 8px;
    border-bottom: 1px solid #dee2e6;
    letter-spacing: 0.5px;
}

.option-row {
    display: flex;
    align-items: center;
    margin-bottom: 15px;
    min-height: 40px;
}

    .option-row:last-child {
        margin-bottom: 0;
    }

.option-row-full {
    flex-direction: column;
    align-items: stretch;
    min-height: auto;
}

    .option-row-full .option-label {
        flex: none;
        margin-bottom: 10px;
        text-align: center;
    }

    .option-row-full .option-control {
        width: 100%;
        justify-content: center;
    }

.option-label {
    flex: 0 0 140px;
    font-weight: 600;
    color: #495057;
    font-size: 0.95em;
}

.option-control {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 12px;
}

.image-input-container {
    display: flex;
    justify-content: center;
    width: 100%;
}

.layout-options {
    display: flex;
    flex-direction: column;
    gap: 10px;
}

.layout-radio-option {
    display: flex;
    align-items: center;
    padding: 12px;
    background: white;
    border: 2px solid #dee2e6;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s;
}

    .layout-radio-option:hover:not(.disabled) {
        border-color: #667eea;
        background: rgba(102, 126, 234, 0.05);
        transform: translateX(4px);
    }

    .layout-radio-option input[type="radio"] {
        margin-right: 12px;
        width: 18px;
        height: 18px;
        cursor: pointer;
    }

    .layout-radio-option:has(input:checked) {
        border-color: #667eea;
        background: rgba(102, 126, 234, 0.08);
        box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.15);
    }

.layout-details {
    flex: 1;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.layout-name {
    font-weight: 600;
    color: #333;
}

.layout-range {
    font-family: 'Courier New', monospace;
    color: #6c757d;
    font-size: 0.9em;
    background: #f8f9fa;
    padding: 2px 8px;
    border-radius: 4px;
}

.layout-radio-option.disabled {
    opacity: 0.5;
    cursor: not-allowed;
    background: #f8f9fa;
}

.layout-divider {
    margin: 15px 0 10px;
    color: #adb5bd;
    font-size: 0.85em;
    font-style: italic;
}

.file-button {
    background: #667eea;
    color: white;
    border: none;
    padding: 8px 16px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.9em;
    font-weight: 500;
    transition: all 0.2s;
}

    .file-button:hover {
        background: #764ba2;
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
    }

.file-status {
    color: #6c757d;
    font-size: 0.9em;
    font-style: italic;
}

    .file-status.has-file {
        color: #28a745;
        font-style: normal;
        font-weight: 500;
    }

.number-input, .select-input, .date-input {
    padding: 8px 12px;
    border: 2px solid #dee2e6;
    border-radius: 6px;
    font-size: 0.95em;
    transition: all 0.2s;
    background: white;
}

.number-input {
    width: 80px;
    text-align: center;
    font-family: 'Courier New', monospace;
}

.select-input {
    min-width: 150px;
    cursor: pointer;
}

    .number-input:focus, .select-input:focus, .date-input:focus {
        outline: none;
        border-color: #667eea;
        box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
    }

.option-hint {
    color: #6c757d;
    font-size: 0.85em;
    font-style: italic;
}

.date-preview {
    color: #495057;
    font-size: 0.9em;
    padding: 4px 8px;
    background: #f8f9fa;
    border-radius: 4px;
}

.option-warning {
    padding: 12px;
    background: #fff3cd;
    border: 1px solid #ffc107;
    border-radius: 6px;
    color: #856404;
    text-align: center;
}

.image-preview-container {
    width: 100%;
    max-width: 400px;
}

.image-preview-wrapper {
    position: relative;
    cursor: pointer;
    transition: all 0.2s ease;
    border-radius: 8px;
    overflow: hidden;
    background: #f8f9fa;
}

    .image-preview-wrapper:hover {
        transform: translateY(-2px);
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    }

.image-preview-frame {
    position: relative;
    width: 320px;
    height: 200px;
    margin: 0 auto;
    border: 2px solid #dee2e6;
    border-radius: 6px;
    overflow: hidden;
    background: #000;
}

.image-preview-img {
    width: 100%;
    height: 100%;
    object-fit: contain;
    display: block;
    image-rendering: pixelated;
    image-rendering: -moz-crisp-edges;
    image-rendering: crisp-edges;
}

.image-preview-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.7);
    display: flex;
    align-items: center;
    justify-content: center;
    opacity: 0;
    transition: opacity 0.2s ease;
}

.image-preview-wrapper:hover .image-preview-overlay {
    opacity: 1;
}

.image-preview-loading {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(248, 249, 250, 0.95);
    display: none;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 10px;
}

.preview-filename {
    font-weight: 600;
    color: #495057;
    flex: 1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.preview-size {
    color: #6c757d;
    font-family: monospace;
}

.export-buttons {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    justify-content: center;
}

.export-button {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border: none;
    padding: 10px 20px;
    border-radius: 8px;
    font-size: 1em;
    font-weight: 600;
    cursor: pointer;
    transition: transform 0.2s, box-shadow 0.2s;
    display: flex;
    align-items: center;
    gap: 8px;
}

    .export-button:hover:not(:disabled) {
        transform: translateY(-2px);
        box-shadow: 0 5px 20px rgba(102, 126, 234, 0.4);
    }

    .export-button:disabled {
        opacity: 0.5;
        cursor: not-allowed;
        transform: none;
        background: linear-gradient(135deg, #999 0%, #777 100%);
    }

.disabled .export-button:not(:disabled) {
    opacity: 0.7;
    background: linear-gradient(135deg, #999 0%, #777 100%);
}

.export-button:active:not(:disabled) {
    transform: translateY(0);
}

#exportModifiedSIDButton {
    width: auto;
    margin: 0 auto;
}

.export-status {
    margin-top: 15px;
    padding: 10px;
    border-radius: 8px;
    display: none;
}

    .export-status.visible {
        display: block;
    }

    .export-status.success {
        background: #d4f4dd;
        color: #1e7e34;
        border: 1px solid #28a745;
    }

    .export-status.error {
        background: #f8d7da;
        color: #721c24;
        border: 1px solid #f5c6cb;
    }

    .export-status.info {
        background: #d1ecf1;
        color: #0c5460;
        border: 1px solid #bee5eb;
    }

.loading {
    display: none;
    text-align: center;
    padding: 20px;
}

    .loading.active {
        display: block;
    }

.spinner {
    border: 4px solid #f3f3f3;
    border-top: 4px solid #667eea;
    border-radius: 50%;
    width: 40px;
    height: 40px;
    animation: spin 1s linear infinite;
    margin: 0 auto 20px;
}

@keyframes spin {
    0% {
        transform: rotate(0deg);
    }

    100% {
        transform: rotate(360deg);
    }
}

.progress-bar {
    width: 100%;
    height: 20px;
    background: #f0f0f0;
    border-radius: 10px;
    overflow: hidden;
    margin-top: 10px;
    display: none;
}

    .progress-bar.active {
        display: block;
    }

.progress-fill {
    height: 100%;
    background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
    width: 0%;
    transition: width 0.3s ease;
}

.progress-text {
    text-align: center;
    margin-top: 5px;
    font-size: 0.9em;
    color: #666;
}

.error-message {
    background: #ff6b6b20;
    border: 1px solid #ff6b6b;
    color: #c92a2a;
    padding: 15px;
    border-radius: 10px;
    margin-top: 20px;
    display: none;
}

    .error-message.visible {
        display: block;
    }

.modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: none;
    justify-content: center;
    align-items: center;
    z-index: 1000;
    opacity: 0;
    transition: opacity 0.3s ease;
}

    .modal-overlay.visible {
        display: flex;
        opacity: 1;
    }

.modal-content {
    background: white;
    border-radius: 20px;
    padding: 30px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    text-align: center;
    transform: scale(0.9);
    transition: transform 0.3s ease;
}

.modal-overlay.visible .modal-content {
    transform: scale(1);
}

.modal-icon {
    font-size: 3em;
    margin-bottom: 15px;
}

    .modal-icon.success {
        color: #51cf66;
    }

    .modal-icon.error {
        color: #ff6b6b;
    }

.modal-message {
    font-size: 1.2em;
    color: #333;
}

.compression-options {
    display: flex;
    flex-direction: column;
    gap: 10px;
}

.compression-radio-option {
    display: flex;
    align-items: center;
    padding: 12px;
    background: white;
    border: 2px solid #dee2e6;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s;
}

    .compression-radio-option:hover {
        border-color: #667eea;
        background: rgba(102, 126, 234, 0.05);
        transform: translateX(4px);
    }

    .compression-radio-option input[type="radio"] {
        margin-right: 12px;
        width: 18px;
        height: 18px;
        cursor: pointer;
    }

    .compression-radio-option:has(input:checked) {
        border-color: #667eea;
        background: rgba(102, 126, 234, 0.08);
        box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.15);
    }

.compression-details {
    flex: 1;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.compression-name {
    font-weight: 600;
    color: #333;
}

.compression-desc {
    color: #6c757d;
    font-size: 0.9em;
}

.color-slider-control {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 15px;
}

.slider-wrapper {
    flex: 1;
    position: relative;
    height: 30px;
}

.color-slider {
    width: 100%;
    height: 30px;
    -webkit-appearance: none;
    appearance: none;
    background: transparent;
    outline: none;
    position: absolute;
    top: 50%;
    transform: translateY(-50%);
    z-index: 3;
    cursor: pointer;
    pointer-events: none;
}

.color-slider-track {
    position: absolute;
    top: 50%;
    transform: translateY(-50%);
    left: 0;
    right: 0;
    height: 24px;
    display: flex;
    border-radius: 12px;
    border: 2px solid #dee2e6;
    overflow: hidden;
    box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.1);
}

.color-segment {
    flex: 1;
    position: relative;
    cursor: pointer;
    transition: all 0.2s;
    pointer-events: auto;
}

    .color-segment:not(:last-child)::after {
        content: '';
        position: absolute;
        right: 0;
        top: 0;
        bottom: 0;
        width: 1px;
        background: rgba(0, 0, 0, 0.2);
    }

    .color-segment:hover {
        opacity: 0.8;
        transform: scaleY(1.1);
    }

.color-slider::-webkit-slider-thumb {
    -webkit-appearance: none;
    appearance: none;
    width: 0;
    height: 0;
    opacity: 0;
    cursor: pointer;
}

.color-slider::-moz-range-thumb {
    width: 0;
    height: 0;
    opacity: 0;
    cursor: pointer;
    border: none;
}

.color-slider::-webkit-slider-runnable-track {
    height: 30px;
    background: transparent;
    cursor: pointer;
}

.color-slider::-moz-range-track {
    height: 30px;
    background: transparent;
    cursor: pointer;
}

.color-value {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 180px;
    padding: 4px 8px;
    background: white;
    border: 2px solid #dee2e6;
    border-radius: 6px;
}

.color-swatch {
    width: 18px;
    height: 18px;
    border-radius: 3px;
    border: 1px solid #333;
    flex-shrink: 0;
}

.color-text {
    font-size: 0.9em;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    flex: 1;
}

.color-number {
    font-family: 'Courier New', monospace;
    font-weight: bold;
    color: #667eea;
}

.color-name {
    color: #495057;
}

.textarea-container {
    display: flex;
    flex-direction: column;
    gap: 8px;
    width: 100%;
}

    .textarea-container textarea {
        width: 100%;
        min-height: 60px;
        padding: 8px 12px;
        border: 2px solid #dee2e6;
        border-radius: 6px;
        background: white;
        color: #333;
        font-family: 'Courier New', monospace;
        font-size: 0.9em;
        resize: vertical;
        transition: all 0.2s;
    }

        .textarea-container textarea:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }

.textarea-controls {
    display: flex;
    gap: 8px;
}

.load-text-btn, .save-text-btn {
    padding: 6px 12px;
    font-size: 0.85em;
    background: #667eea;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s;
}

    .load-text-btn:hover, .save-text-btn:hover {
        background: #764ba2;
        transform: translateY(-1px);
        box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
    }

@media (max-width: 768px) {
    .upload-buttons {
        flex-direction: column;
    }

    .upload-btn {
        width: 100%;
    }

    .info-panels {
        grid-template-columns: 1fr;
    }

    .header h1 {
        font-size: 2em;
    }

    .main-content {
        padding: 20px;
    }

    .section-group {
        padding: 15px;
    }

    .export-buttons {
        flex-direction: column;
    }

    .export-button {
        width: 100%;
        justify-content: center;
    }

    .visualizer-grid {
        grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
        gap: 15px;
    }

    .visualizer-preview {
        height: 120px;
    }

    .visualizer-options-panel {
        margin: 20px 10px;
    }

    .option-row {
        flex-direction: column;
        align-items: flex-start;
        gap: 8px;
    }

    .option-label {
        flex: none;
    }

    .option-control {
        width: 100%;
    }

    .color-slider-control {
        flex-direction: column;
        gap: 12px;
        width: 100%;
    }

    .slider-wrapper {
        width: 100%;
    }

    .color-value {
        width: 100%;
        justify-content: center;
        padding: 8px 12px;
        background: linear-gradient(135deg, rgba(102, 126, 234, 0.05) 0%, rgba(118, 75, 162, 0.05) 100%);
        border: 2px solid #667eea;
    }

    .color-swatch {
        width: 24px;
        height: 24px;
    }

    .color-text {
        font-size: 1em;
        font-weight: 500;
    }

    .layout-details {
        flex-direction: column;
        align-items: flex-start;
        gap: 5px;
    }

    .image-preview-frame {
        width: 280px;
        height: 175px;
    }
}

@media (max-width: 480px) {
    .logo {
        height: 50px;
    }

    .header h1 {
        font-size: 1.5rem;
    }

    .header p,
    .tagline {
        font-size: 0.9rem;
    }

    .version-badge {
        font-size: 0.7rem;
        padding: 0.2rem 0.6rem;
    }
}

.floating-notes-container {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    z-index: -1;
    overflow: hidden;
}

.floating-note {
    position: absolute;
    pointer-events: none;
    font-size: 8rem;
    opacity: 0;
    color: rgba(0, 212, 255, 0.2);
}

@keyframes float-up {
    0% {
        opacity: 0;
        transform: translateY(0px) scale(0.5);
    }

    20% {
        opacity: 1;
        transform: translateY(-50px) scale(1);
    }

    80% {
        opacity: 1;
        transform: translateY(-200px) scale(1.2);
    }

    100% {
        opacity: 0;
        transform: translateY(-300px) scale(0.8);
    }
}

@keyframes float-down {
    0% {
        opacity: 0;
        transform: translateY(0px) scale(0.5);
    }

    20% {
        opacity: 1;
        transform: translateY(50px) scale(1);
    }

    80% {
        opacity: 1;
        transform: translateY(200px) scale(1.2);
    }

    100% {
        opacity: 0;
        transform: translateY(300px) scale(0.8);
    }
}

@keyframes diagonal-up-right {
    0% {
        opacity: 0;
        transform: translate(0px, 0px) rotate(0deg);
    }

    25% {
        opacity: 1;
        transform: translate(100px, -100px) rotate(90deg);
    }

    75% {
        opacity: 1;
        transform: translate(200px, -200px) rotate(270deg);
    }

    100% {
        opacity: 0;
        transform: translate(300px, -300px) rotate(360deg);
    }
}

@keyframes diagonal-down-left {
    0% {
        opacity: 0;
        transform: translate(0px, 0px) rotate(0deg);
    }

    25% {
        opacity: 1;
        transform: translate(-100px, 100px) rotate(90deg);
    }

    75% {
        opacity: 1;
        transform: translate(-200px, 200px) rotate(270deg);
    }

    100% {
        opacity: 0;
        transform: translate(-300px, 300px) rotate(360deg);
    }
}

@keyframes diagonal-up-left {
    0% {
        opacity: 0;
        transform: translate(0px, 0px) rotate(0deg);
    }

    25% {
        opacity: 1;
        transform: translate(-100px, -100px) rotate(90deg);
    }

    75% {
        opacity: 1;
        transform: translate(-200px, -200px) rotate(270deg);
    }

    100% {
        opacity: 0;
        transform: translate(-300px, -300px) rotate(360deg);
    }
}

@keyframes diagonal-down-right {
    0% {
        opacity: 0;
        transform: translate(0px, 0px) rotate(0deg);
    }

    25% {
        opacity: 1;
        transform: translate(100px, 100px) rotate(90deg);
    }

    75% {
        opacity: 1;
        transform: translate(200px, 200px) rotate(270deg);
    }

    100% {
        opacity: 0;
        transform: translate(300px, 300px) rotate(360deg);
    }
}

@keyframes float-left {
    0% {
        opacity: 0;
        transform: translateX(0px) rotate(0deg);
    }

    20% {
        opacity: 1;
        transform: translateX(-80px) rotate(60deg);
    }

    80% {
        opacity: 1;
        transform: translateX(-200px) rotate(300deg);
    }

    100% {
        opacity: 0;
        transform: translateX(-320px) rotate(360deg);
    }
}

@keyframes float-right {
    0% {
        opacity: 0;
        transform: translateX(0px) rotate(0deg);
    }

    20% {
        opacity: 1;
        transform: translateX(80px) rotate(60deg);
    }

    80% {
        opacity: 1;
        transform: translateX(200px) rotate(300deg);
    }

    100% {
        opacity: 0;
        transform: translateX(320px) rotate(360deg);
    }
}

.hvsc-modal {
    display: none;
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.7);
    z-index: 10000;
    justify-content: center;
    align-items: center;
    padding: 20px;
}

    .hvsc-modal.visible {
        display: flex;
    }

.hvsc-modal-content {
    background: #1e1e1e;
    border-radius: 12px;
    width: 100%;
    max-width: 950px;
    height: 90vh;
    max-height: 650px;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
    position: relative;
}

.hvsc-modal-close {
    position: absolute;
    top: 10px;
    right: 10px;
    background: rgba(0, 0, 0, 0.9);
    color: #fff;
    border: 2px solid #666;
    width: 30px;
    height: 30px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 18px;
    font-weight: bold;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s;
    z-index: 100;
}

    .hvsc-modal-close:hover {
        background: #ff3333;
        transform: scale(1.1);
        border-color: #ff6666;
    }

.hvsc-modal-body {
    flex: 1;
    overflow: hidden;
    display: flex;
    flex-direction: column;
}

.browser-container {
    background: #1e1e1e;
    border-radius: 8px;
    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
    width: 100%;
    height: 600px;
    display: flex;
    flex-direction: column;
    overflow: hidden;
}

.browser-header {
    background: #2d2d2d;
    padding: 15px;
    border-bottom: 1px solid #444;
    position: relative;
}

.browser-title {
    color: #fff;
    font-size: 16px;
    margin-bottom: 10px;
    display: flex;
    align-items: center;
    gap: 10px;
}

    .browser-title::before {
        content: '🎵';
        font-size: 20px;
    }

.browser-controls {
    display: flex;
    gap: 10px;
    align-items: center;
}

.btn {
    background: #4a4a4a;
    color: #fff;
    border: none;
    padding: 8px 15px;
    border-radius: 4px;
    cursor: pointer;
    transition: background 0.3s;
    font-size: 14px;
}

    .btn:hover {
        background: #5a5a5a;
    }

    .btn:disabled {
        opacity: 0.5;
        cursor: not-allowed;
    }

.path-bar {
    flex: 1;
    background: #3a3a3a;
    color: #fff;
    padding: 8px 12px;
    border-radius: 4px;
    border: 1px solid #555;
    font-family: 'Courier New', monospace;
    font-size: 13px;
}

.browser-content {
    display: flex;
    flex: 1;
    overflow: hidden;
}

.file-panel {
    flex: 1;
    display: flex;
    flex-direction: column;
}

.panel-header {
    background: #2a2a2a;
    color: #aaa;
    padding: 10px;
    font-size: 12px;
    text-transform: uppercase;
    letter-spacing: 1px;
    border-bottom: 1px solid #444;
}

.file-list {
    flex: 1;
    overflow-y: auto;
    background: #1a1a1a;
    user-select: none;
}

.file-item {
    display: flex;
    align-items: center;
    padding: 8px 12px;
    color: #ccc;
    cursor: pointer;
    transition: background 0.2s;
    border-bottom: 1px solid #2a2a2a;
    font-size: 14px;
    user-select: none;
}

    .file-item:hover {
        background: #2a2a2a;
    }

    .file-item.selected {
        background: #3a3a6a;
        color: #fff;
    }

    .file-item.directory {
        color: #88aaff;
        font-weight: 500;
    }

.file-icon {
    margin-right: 8px;
    width: 16px;
    text-align: center;
}

.file-name {
    flex: 1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.status-bar {
    background: #2d2d2d;
    color: #aaa;
    padding: 8px 15px;
    font-size: 12px;
    border-top: 1px solid #444;
    display: flex;
    justify-content: space-between;
}

.loading {
    text-align: center;
    padding: 20px;
    color: #888;
}

    .loading::after {
        content: '...';
        animation: dots 1s steps(3, end) infinite;
    }

@keyframes dots {
    0%, 20% {
        content: '.';
    }

    40% {
        content: '..';
    }

    60%, 100% {
        content: '...';
    }
}

.error-message {
    color: #ff6b6b;
    padding: 20px;
    text-align: center;
}

.file-list::-webkit-scrollbar {
    width: 8px;
}

.file-list::-webkit-scrollbar-track {
    background: #1a1a1a;
}

.file-list::-webkit-scrollbar-thumb {
    background: #444;
    border-radius: 4px;
}

    .file-list::-webkit-scrollbar-thumb:hover {
        background: #555;
    }

.image-preview-drop-zone {
    position: relative;
    transition: all 0.3s ease;
    border: 2px dashed transparent;
    border-radius: 8px;
    padding: 4px;
}

    .image-preview-drop-zone.drag-active {
        border-color: #667eea;
        background: rgba(102, 126, 234, 0.05);
        transform: scale(1.02);
    }

.image-gallery-toggle {
    margin-top: 10px;
    text-align: center;
}

.gallery-btn {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border: none;
    padding: 8px 16px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.9em;
    transition: all 0.2s;
}

    .gallery-btn:hover {
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
    }

    .gallery-btn.active {
        background: linear-gradient(135deg, #764ba2 0%, #667eea 100%);
    }

.text-drop-zone {
    position: relative;
    padding: 12px;
    background: rgba(102, 126, 234, 0.03);
    border: 2px dashed rgba(102, 126, 234, 0.3);
    border-radius: 8px;
    transition: all 0.3s ease;
}

    .text-drop-zone:hover {
        border-color: rgba(102, 126, 234, 0.5);
        background: rgba(102, 126, 234, 0.05);
    }

.text-drop-hint {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 10px;
    color: #667eea;
    font-size: 0.9em;
    font-weight: 500;
}

    .text-drop-hint i {
        opacity: 0.7;
    }

.text-drop-zone textarea {
    width: 100%;
    background: white;
    border: 1px solid #dee2e6;
    transition: all 0.2s;
}

    .text-drop-zone textarea:focus {
        border-color: #667eea;
        box-shadow: 0 0 0 2px rgba(102, 126, 234, 0.1);
    }

.text-drop-indicator {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 24px 36px;
    border-radius: 12px;
    font-weight: 600;
    font-size: 1.1em;
    pointer-events: none;
    opacity: 0;
    transition: opacity 0.2s;
    z-index: 10;
    box-shadow: 0 10px 30px rgba(102, 126, 234, 0.4);
}

.text-drop-zone.drag-active {
    border-color: #667eea;
    background: rgba(102, 126, 234, 0.08);
    box-shadow: 0 0 20px rgba(102, 126, 234, 0.2);
}

    .text-drop-zone.drag-active .text-drop-indicator {
        opacity: 1;
    }

    .text-drop-zone.drag-active textarea {
        opacity: 0.2;
    }

    .text-drop-zone.drag-active .text-drop-hint {
        opacity: 0.2;
    }

.gallery-modal {
    display: none;
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.7);
    z-index: 10000;
    justify-content: center;
    align-items: center;
    padding: 20px;
}

    .gallery-modal.visible {
        display: flex;
    }

.gallery-modal-content {
    background: #1e1e1e;
    border-radius: 12px;
    width: 100%;
    max-width: 950px;
    height: 90vh;
    max-height: 650px;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
    position: relative;
}

.gallery-modal-close {
    position: absolute;
    top: 10px;
    right: 10px;
    background: rgba(0, 0, 0, 0.9);
    color: #fff;
    border: 2px solid #666;
    width: 30px;
    height: 30px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 18px;
    font-weight: bold;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s;
    z-index: 100;
}

    .gallery-modal-close:hover {
        background: #ff3333;
        transform: scale(1.1);
        border-color: #ff6666;
    }

.gallery-modal-body {
    flex: 1;
    overflow: hidden;
    display: flex;
    flex-direction: column;
}

.gallery-container {
    background: #1e1e1e;
    height: 100%;
    display: flex;
    flex-direction: column;
    overflow: hidden;
}

.gallery-header {
    background: #2d2d2d;
    padding: 15px;
    border-bottom: 1px solid #444;
}

.gallery-title {
    color: #fff;
    font-size: 16px;
    margin-bottom: 5px;
    display: flex;
    align-items: center;
    gap: 10px;
}

.gallery-subtitle {
    color: #aaa;
    font-size: 13px;
    font-style: italic;
}

.gallery-content {
    flex: 1;
    overflow-y: auto;
    background: #1a1a1a;
    padding: 20px;
}

.gallery-grid-container {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
    gap: 20px;
}

.gallery-item-card {
    background: #2a2a2a;
    border: 2px solid #3a3a3a;
    border-radius: 8px;
    overflow: hidden;
    cursor: pointer;
    transition: all 0.3s ease;
    position: relative;
}

    .gallery-item-card:hover {
        transform: translateY(-4px);
        box-shadow: 0 8px 20px rgba(102, 126, 234, 0.3);
        border-color: #667eea;
    }

    .gallery-item-card.selected {
        border-color: #667eea;
        box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.2);
    }

.gallery-item-preview {
    width: 100%;
    aspect-ratio: 320/200;
    background: #000;
    position: relative;
    overflow: hidden;
}

    .gallery-item-preview img {
        width: 100%;
        height: 100%;
        object-fit: contain;
        image-rendering: pixelated;
        image-rendering: -moz-crisp-edges;
        image-rendering: crisp-edges;
    }

.gallery-item-info {
    padding: 10px;
    background: #2a2a2a;
}

.gallery-item-name {
    color: #ccc;
    font-size: 12px;
    font-weight: 500;
    text-align: center;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.gallery-item-selected-badge {
    position: absolute;
    top: 5px;
    right: 5px;
    background: #667eea;
    color: white;
    padding: 4px 8px;
    border-radius: 12px;
    font-size: 10px;
    font-weight: 600;
    display: none;
}

.gallery-item-card.selected .gallery-item-selected-badge {
    display: block;
}

.gallery-status-bar {
    background: #2d2d2d;
    color: #aaa;
    padding: 8px 15px;
    font-size: 12px;
    border-top: 1px solid #444;
    display: flex;
    justify-content: space-between;
}

.gallery-content::-webkit-scrollbar {
    width: 8px;
}

.gallery-content::-webkit-scrollbar-track {
    background: #1a1a1a;
}

.gallery-content::-webkit-scrollbar-thumb {
    background: #444;
    border-radius: 4px;
}

    .gallery-content::-webkit-scrollbar-thumb:hover {
        background: #555;
    }

.gallery-loading {
    text-align: center;
    padding: 40px;
    color: #888;
}

    .gallery-loading::after {
        content: '...';
        animation: dots 1s steps(3, end) infinite;
    }

@keyframes dots {
    0%, 20% {
        content: '.';
    }

    40% {
        content: '..';
    }

    60%, 100% {
        content: '...';
    }
}
```


### FILE: public/compressor-manager.js
```js
class CompressorManager {
    constructor() {
        this.compressors = {
            'none': null,
            'tscrunch': null
        };

        this.initialized = false;
        this.initPromise = this.initializeCompressors();
    }

    async initializeCompressors() {
        
        if (!window.TSCrunch) {
            await new Promise(resolve => {
                if (window.TSCrunch) {
                    resolve();
                } else {
                    window.addEventListener('tscrunch-ready', resolve, { once: true });
                }
            });
        }

        if (window.TSCrunch) {
            try {
                this.compressors.tscrunch = new TSCrunchCompressor();
            } catch (error) {
                console.warn('TSCrunch initialization failed:', error);
            }
        }

        this.initialized = true;
    }

    async waitForInit() {
        if (!this.initialized) {
            await this.initPromise;
        }
    }

    isAvailable(type) {
        if (type === 'none') return true;
        return this.compressors[type] !== null;
    }

    async compress(data, type, uncompressedStart, executeAddress) {
        
        await this.waitForInit();

        if (type === 'none') {
            return {
                data: data,
                type: 'none',
                originalSize: data.length,
                compressedSize: data.length,
                ratio: 1.0
            };
        }

        const compressor = this.compressors[type];
        if (!compressor) {
            throw new Error(`Compressor '${type}' not available`);
        }

        const hasLoadAddress = data.length >= 2 &&
            (data[0] | (data[1] << 8)) === uncompressedStart;

        const dataToCompress = hasLoadAddress ? data.slice(2) : data;

        let result = await compressor.compressPRG(
            dataToCompress,
            uncompressedStart,
            executeAddress
        );

        return {
            data: result.data || result,
            type: type,
            originalSize: result.originalSize || data.length,
            compressedSize: result.compressedSize || (result.data ? result.data.length : result.length)
        };
    }
}

class TSCrunchCompressor {
    constructor() {
        this.originalSize = 0;
        this.compressedSize = 0;
    }

    async compressPRG(data, uncompressedStart, executeAddress) {
        try {
            this.originalSize = data.length;

            let prgData;

            if (data.length >= 2 && (data[0] | (data[1] << 8)) === uncompressedStart) {
                
                prgData = data;
            } else {
                
                prgData = new Uint8Array(data.length + 2);
                prgData[0] = uncompressedStart & 0xFF;
                prgData[1] = (uncompressedStart >> 8) & 0xFF;
                prgData.set(data, 2);
            }

            const options = {
                prg: true,           
                sfx: true,           
                sfxMode: 0,          
                jumpAddress: executeAddress,
                blank: false,        
                inplace: false       
            };

            const compressed = TSCrunch.compress(prgData, options);

            this.compressedSize = compressed.length;

            return {
                data: compressed,
                originalSize: this.originalSize,
                compressedSize: this.compressedSize,
                ratio: this.compressedSize / this.originalSize
            };

        } catch (error) {
            console.error('TSCrunch compression failed:', error);
            throw error;
        }
    }
}

window.CompressorManager = CompressorManager;
```


### FILE: public/cpu6510.js
```js
var CPU6510Module=(()=>{var _scriptName=typeof document!="undefined"?document.currentScript?.src:undefined;return async function(moduleArg={}){var moduleRtn;var Module=moduleArg;var ENVIRONMENT_IS_WEB=typeof window=="object";var ENVIRONMENT_IS_WORKER=typeof WorkerGlobalScope!="undefined";var ENVIRONMENT_IS_NODE=typeof process=="object"&&process.versions?.node&&process.type!="renderer";var arguments_=[];var thisProgram="./this.program";var quit_=(status,toThrow)=>{throw toThrow};if(typeof __filename!="undefined"){_scriptName=__filename}else if(ENVIRONMENT_IS_WORKER){_scriptName=self.location.href}var scriptDirectory="";function locateFile(path){if(Module["locateFile"]){return Module["locateFile"](path,scriptDirectory)}return scriptDirectory+path}var readAsync,readBinary;if(ENVIRONMENT_IS_NODE){var fs=require("fs");scriptDirectory=__dirname+"/";readBinary=filename=>{filename=isFileURI(filename)?new URL(filename):filename;var ret=fs.readFileSync(filename);return ret};readAsync=async(filename,binary=true)=>{filename=isFileURI(filename)?new URL(filename):filename;var ret=fs.readFileSync(filename,binary?undefined:"utf8");return ret};if(process.argv.length>1){thisProgram=process.argv[1].replace(/\\/g,"/")}arguments_=process.argv.slice(2);quit_=(status,toThrow)=>{process.exitCode=status;throw toThrow}}else if(ENVIRONMENT_IS_WEB||ENVIRONMENT_IS_WORKER){try{scriptDirectory=new URL(".",_scriptName).href}catch{}{if(ENVIRONMENT_IS_WORKER){readBinary=url=>{var xhr=new XMLHttpRequest;xhr.open("GET",url,false);xhr.responseType="arraybuffer";xhr.send(null);return new Uint8Array(xhr.response)}}readAsync=async url=>{if(isFileURI(url)){return new Promise((resolve,reject)=>{var xhr=new XMLHttpRequest;xhr.open("GET",url,true);xhr.responseType="arraybuffer";xhr.onload=()=>{if(xhr.status==200||xhr.status==0&&xhr.response){resolve(xhr.response);return}reject(xhr.status)};xhr.onerror=reject;xhr.send(null)})}var response=await fetch(url,{credentials:"same-origin"});if(response.ok){return response.arrayBuffer()}throw new Error(response.status+" : "+response.url)}}}else{}var out=console.log.bind(console);var err=console.error.bind(console);var wasmBinary;var ABORT=false;var isFileURI=filename=>filename.startsWith("file:
;return moduleRtn}})();if(typeof exports==="object"&&typeof module==="object"){module.exports=CPU6510Module;module.exports.default=CPU6510Module}else if(typeof define==="function"&&define["amd"])define([],()=>CPU6510Module);
```


### FILE: public/floating-notes.js
```js
﻿
class FreshFloatingNotes {
    constructor() {
        this.container = null;
        this.musicNotes = ['♪', '♫', '♬', '♩', '♭', '♯', '𝄞', '𝄢'];
        this.isActive = false;

        this.init();
    }

    init() {
        this.createContainer();
        this.startFloating();
    }

    createContainer() {
        if (!this.container) {
            this.container = document.createElement('div');
            this.container.className = 'floating-notes-container';
            document.body.appendChild(this.container);
        }
    }

    createNote() {
        const note = document.createElement('div');
        note.className = 'floating-note';

        const symbol = this.musicNotes[Math.floor(Math.random() * this.musicNotes.length)];
        note.textContent = symbol;

        const colors = [
            'rgba(0, 212, 255, 0.4)',   
            'rgba(118, 75, 162, 0.35)', 
            'rgba(102, 126, 234, 0.45)', 
            'rgba(255, 107, 107, 0.3)',  
            'rgba(52, 211, 153, 0.4)',   
            'rgba(251, 191, 36, 0.35)',  
            'rgba(244, 114, 182, 0.4)',  
            'rgba(156, 163, 175, 0.4)',  
            'rgba(245, 101, 101, 0.35)', 
            'rgba(139, 92, 246, 0.4)'    
        ];

        const randomColor = colors[Math.floor(Math.random() * colors.length)];
        note.style.color = randomColor;

        const x = Math.random() * (window.innerWidth - 200);
        const y = Math.random() * (window.innerHeight - 200);
        note.style.left = x + 'px';
        note.style.top = y + 'px';

        const animations = [
            'float-up', 'float-down',                    
            'diagonal-up-right', 'diagonal-down-left',   
            'diagonal-up-left', 'diagonal-down-right',   
            'float-left', 'float-right'                  
        ];
        const anim = animations[Math.floor(Math.random() * animations.length)];

        note.style.animation = anim + ' 7s ease-in-out forwards';

        this.container.appendChild(note);

        setTimeout(() => {
            if (note.parentNode) {
                note.parentNode.removeChild(note);
            }
        }, 8000); 

        return note;
    }

    startFloating() {
        this.isActive = true;

        for (let i = 0; i < 24; i++) {
            setTimeout(() => {
                if (this.isActive) {
                    this.createNote();
                }
            }, i * 100); 
        }

        setInterval(() => {
            if (this.isActive) {
                this.createNote();
            }
        }, 167);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    setTimeout(() => {
        window.freshFloatingNotes = new FreshFloatingNotes();
    }, 1000);
});
```


### FILE: public/hvsc-browser.js
```js
window.hvscBrowser = (function () {

    const HVSC_BASE = '/.netlify/functions/hvsc';

    let currentPath = 'C64Music';
    let currentSelection = null;
    let entries = [];

    let hvscInitialized = false;

    function initializeHVSC() {
        if (!hvscInitialized) {
            fetchDirectory('C64Music');
            hvscInitialized = true;
        }
    }

    async function fetchDirectory(path) {
        
        if (path.endsWith('/')) {
            path = path.slice(0, -1);
        }

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
            
            const linkRegex = /<a\s+href="([^"]+)"[^>]*>([^<]+)<\/a>/gi;
            let match;

            while ((match = linkRegex.exec(html)) !== null) {
                const href = match[1];
                const linkText = match[2].trim();

                if (linkText === 'Home' || linkText === 'About' || linkText === 'HVSC' ||
                    linkText === 'SidSearch' || linkText === '..' || linkText === '.' ||
                    linkText === 'Parent Directory' || href.startsWith('http:
                    href.startsWith('https:
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

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && currentSelection) {
            if (currentSelection.isDirectory) {
                fetchDirectory(currentSelection.path);
            } else {
                selectSID();
            }
        }
    });

    return {
        navigateUp: navigateUp,
        navigateHome: navigateHome,
        fetchDirectory: fetchDirectory
    };
})();
```


### FILE: public/image-preview-manager.js
```js
﻿

class GalleryModal {
    constructor() {
        this.modal = null;
        this.currentConfig = null;
        this.currentContainer = null;
        this.selectedItem = null;
        this.initialized = false;
    }

    init() {
        if (this.initialized) return;

        this.modal = document.getElementById('galleryModal');
        if (!this.modal) {
            console.warn('Gallery modal element not found in DOM');
            return;
        }

        const closeBtn = document.getElementById('galleryModalClose');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => this.close());
        }

        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.modal && this.modal.classList.contains('visible')) {
                this.close();
            }
        });

        this.modal.addEventListener('click', (e) => {
            if (e.target === this.modal) {
                this.close();
            }
        });

        this.initialized = true;
    }

    open(config, container) {
        if (!this.initialized) this.init();
        if (!this.modal) return;

        this.currentConfig = config;
        this.currentContainer = container;
        this.selectedItem = null;

        const subtitle = document.getElementById('gallerySubtitle');
        if (subtitle) {
            subtitle.textContent = `Select ${config.label || 'an image'}`;
        }

        this.buildGallery(config.gallery);

        this.modal.classList.add('visible');
    }

    buildGallery(galleryItems) {
        const gridContainer = document.getElementById('galleryGridContainer');
        if (!gridContainer) return;

        gridContainer.innerHTML = '';

        if (!galleryItems || galleryItems.length === 0) {
            gridContainer.innerHTML = '<div class="gallery-loading">No images available</div>';
            this.updateItemCount(0);
            return;
        }

        galleryItems.forEach((item, index) => {
            const card = document.createElement('div');
            card.className = 'gallery-item-card';
            card.dataset.file = item.file;
            card.dataset.name = item.name;
            card.dataset.index = index;

            card.innerHTML = `
                <div class="gallery-item-preview">
                    <img src="${item.file}" alt="${item.name}" />
                </div>
                <div class="gallery-item-info">
                    <div class="gallery-item-name">${item.name}</div>
                </div>
                <div class="gallery-item-selected-badge">✓ Selected</div>
            `;

            card.addEventListener('click', () => this.selectItem(card, item));
            gridContainer.appendChild(card);
        });

        this.updateItemCount(galleryItems.length);
    }

    selectItem(card, item) {
        
        document.querySelectorAll('.gallery-item-card').forEach(c => {
            c.classList.remove('selected');
        });

        card.classList.add('selected');
        this.selectedItem = item;

        setTimeout(() => {
            this.applySelection(item);
            this.close();
        }, 200);
    }

    async applySelection(item) {
        if (!this.currentContainer || !this.currentConfig) return;

        if (window.imagePreviewManager) {
            await window.imagePreviewManager.loadGalleryImage(
                this.currentContainer,
                this.currentConfig,
                item.file,
                item.name
            );
        }
    }

    updateItemCount(count) {
        const countElement = document.getElementById('galleryItemCount');
        if (countElement) {
            countElement.textContent = `${count} image${count !== 1 ? 's' : ''}`;
        }
    }

    close() {
        if (this.modal) {
            this.modal.classList.remove('visible');
        }
        this.currentConfig = null;
        this.currentContainer = null;
        this.selectedItem = null;
    }
}

class ImagePreviewManager {
    constructor() {
        this.previewCache = new Map();
        this.defaultImages = new Map();
        this.loadingPromises = new Map();
        this.galleryModal = null;
    }

    initGalleryModal() {
        if (!this.galleryModal) {
            this.galleryModal = new GalleryModal();
            this.galleryModal.init();
        }
        return this.galleryModal;
    }

    createImagePreview(config) {
        const container = document.createElement('div');
        container.className = 'image-preview-container';

        const hasGallery = config.gallery && config.gallery.length > 0;

        container.innerHTML = `
            <div class="image-preview-wrapper ${hasGallery ? 'with-gallery' : ''}" data-input-id="${config.id}">
                <div class="image-preview-drop-zone">
                    <div class="image-preview-frame">
                        <img class="image-preview-img" 
                             src="" 
                             alt="${config.label} preview"
                             width="320" 
                             height="200">
                        <div class="image-preview-overlay">
                            <div class="preview-overlay-content">
                                <i class="fas fa-upload"></i>
                                <div class="preview-click-hint">Click to browse or drag image here</div>
                            </div>
                        </div>
                        <div class="image-preview-loading">
                            <div class="preview-spinner"></div>
                            <div>Loading...</div>
                        </div>
                    </div>
                    <div class="image-preview-info">
                        <span class="preview-filename">Loading default...</span>
                        <span class="preview-size"></span>
                    </div>
                </div>
                ${hasGallery ? `
                    <div class="image-gallery-toggle">
                        <button type="button" class="gallery-btn">
                            <i class="fas fa-images"></i>
                            Choose from Gallery
                        </button>
                    </div>
                ` : ''}
            </div>
            <input type="file" 
                   id="${config.id}" 
                   accept="${config.accept}" 
                   style="display: none;">
        `;

        this.attachDragDropHandlers(container, config);
        this.attachGalleryHandlers(container, config);

        const wrapper = container.querySelector('.image-preview-wrapper');
        const fileInput = container.querySelector('input[type="file"]');

        const previewFrame = wrapper.querySelector('.image-preview-frame');
        previewFrame.addEventListener('click', () => {
            fileInput.click();
        });

        fileInput.addEventListener('change', (e) => {
            this.handleFileChange(e, config);
        });

        return container;
    }

    attachDragDropHandlers(container, config) {
        const dropZone = container.querySelector('.image-preview-drop-zone');

        ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
            dropZone.addEventListener(eventName, (e) => {
                e.preventDefault();
                e.stopPropagation();
            });
        });

        ['dragenter', 'dragover'].forEach(eventName => {
            dropZone.addEventListener(eventName, () => {
                dropZone.classList.add('drag-active');
            });
        });

        ['dragleave', 'drop'].forEach(eventName => {
            dropZone.addEventListener(eventName, () => {
                dropZone.classList.remove('drag-active');
            });
        });

        dropZone.addEventListener('drop', (e) => {
            const files = e.dataTransfer.files;
            if (files.length > 0) {
                const file = files[0];
                if (this.isValidImageFile(file, config)) {
                    const fileInput = container.querySelector(`#${config.id}`);
                    if (fileInput) {
                        delete fileInput.dataset.gallerySelected;
                        delete fileInput.dataset.galleryFile;
                    }
                    this.handleFileChange({ target: { files: [file] } }, config);
                } else {
                    this.showError(container, 'Please drop a valid image file');
                }
            }
        });
    }

    attachGalleryHandlers(container, config) {
        const toggleBtn = container.querySelector('.gallery-btn');

        if (toggleBtn && config.gallery && config.gallery.length > 0) {
            toggleBtn.addEventListener('click', () => {
                const modal = this.initGalleryModal();
                modal.open(config, container);
            });
        }
    }

    isValidImageFile(file, config) {
        if (!config.accept) return true;

        const acceptTypes = config.accept.split(',').map(t => t.trim());

        for (const acceptType of acceptTypes) {
            if (acceptType.startsWith('.')) {
                
                if (file.name.toLowerCase().endsWith(acceptType.toLowerCase())) {
                    return true;
                }
            } else if (acceptType.includes('*')) {
                
                const [type, subtype] = acceptType.split('/');
                if (file.type.startsWith(type + '/')) {
                    return true;
                }
            } else if (file.type === acceptType) {
                
                return true;
            }
        }

        return false;
    }

    showError(container, message) {
        console.error(message);
        
    }

    async loadDefaultImage(config) {
        const wrapper = document.querySelector(`[data-input-id="${config.id}"]`);
        if (!wrapper) return;

        const img = wrapper.querySelector('.image-preview-img');
        const info = wrapper.querySelector('.preview-filename');
        const sizeInfo = wrapper.querySelector('.preview-size');
        const loadingDiv = wrapper.querySelector('.image-preview-loading');

        try {
            loadingDiv.style.display = 'flex';

            if (config.default) {
                
                if (this.previewCache.has(config.default)) {
                    const cached = this.previewCache.get(config.default);
                    img.src = cached.dataUrl;
                    info.textContent = `Default: ${config.default.split('/').pop()}`;
                    sizeInfo.textContent = cached.sizeText;
                    loadingDiv.style.display = 'none';
                    return;
                }

                const fileData = await this.loadDefaultFile(config.default);

                if (config.default.toLowerCase().endsWith('.png') && this.isPNGFile(fileData)) {
                    
                    const preview = await this.createPreviewFromPNGData(fileData);
                    this.previewCache.set(config.default, preview);

                    img.src = preview.dataUrl;
                    info.textContent = `Default: ${config.default.split('/').pop()}`;
                    sizeInfo.textContent = preview.sizeText;
                } else {
                    
                    const preview = await this.createPreviewFromData(fileData, config.default);
                    this.previewCache.set(config.default, preview);

                    img.src = preview.dataUrl;
                    info.textContent = `Default: ${config.default.split('/').pop()}`;
                    sizeInfo.textContent = preview.sizeText;
                }
            }
        } catch (error) {
            console.error('Error loading default image:', error);
            info.textContent = 'Error loading default';
            sizeInfo.textContent = '';
            this.showErrorPlaceholder(img);
        } finally {
            loadingDiv.style.display = 'none';
        }
    }

    async loadGalleryImage(container, config, filename, name) {
        const wrapper = container.querySelector(`[data-input-id="${config.id}"]`);
        if (!wrapper) return;

        const img = wrapper.querySelector('.image-preview-img');
        const info = wrapper.querySelector('.preview-filename');
        const sizeInfo = wrapper.querySelector('.preview-size');
        const loadingDiv = wrapper.querySelector('.image-preview-loading');

        try {
            loadingDiv.style.display = 'flex';

            const response = await fetch(filename);
            if (!response.ok) {
                throw new Error(`Failed to load gallery image: ${filename}`);
            }

            const arrayBuffer = await response.arrayBuffer();
            const fileData = new Uint8Array(arrayBuffer);

            if (filename.toLowerCase().endsWith('.png') && this.isPNGFile(fileData)) {
                const preview = await this.createPreviewFromPNGData(fileData);

                img.src = preview.dataUrl;
                info.textContent = name;
                sizeInfo.textContent = preview.sizeText;

                const blob = new Blob([fileData], { type: 'image/png' });
                const file = new File([blob], name + '.png', { type: 'image/png' });

                const dataTransfer = new DataTransfer();
                dataTransfer.items.add(file);
                const fileInput = container.querySelector(`#${config.id}`);
                if (fileInput) {
                    fileInput.files = dataTransfer.files;
                    fileInput.dataset.gallerySelected = 'true';
                    fileInput.dataset.galleryFile = filename;
                }
            } else {
                const preview = await this.createPreviewFromData(fileData, name);

                img.src = preview.dataUrl;
                info.textContent = name;
                sizeInfo.textContent = preview.sizeText;

                const blob = new Blob([fileData], { type: 'application/octet-stream' });
                const file = new File([blob], name, { type: 'application/octet-stream' });

                const dataTransfer = new DataTransfer();
                dataTransfer.items.add(file);
                const fileInput = container.querySelector(`#${config.id}`);
                if (fileInput) {
                    fileInput.files = dataTransfer.files;
                }
            }

        } catch (error) {
            console.error('Error loading gallery image:', error);
            info.textContent = `Error: ${name}`;
            sizeInfo.textContent = error.message;
            this.showErrorPlaceholder(img);
        } finally {
            loadingDiv.style.display = 'none';
        }
    }

    async loadDefaultFile(defaultPath) {
        if (!window.currentVisualizerConfig) {
            window.currentVisualizerConfig = new VisualizerConfig();
        }
        return await window.currentVisualizerConfig.loadDefaultFile(defaultPath);
    }

    async handleFileChange(event, config) {
        const file = event.target.files[0];

        const fileInput = event.target;
        if (fileInput) {
            delete fileInput.dataset.gallerySelected;
            delete fileInput.dataset.galleryFile;
        }

        const wrapper = document.querySelector(`[data-input-id="${config.id}"]`);
        if (!wrapper) return;

        const img = wrapper.querySelector('.image-preview-img');
        const info = wrapper.querySelector('.preview-filename');
        const sizeInfo = wrapper.querySelector('.preview-size');
        const loadingDiv = wrapper.querySelector('.image-preview-loading');

        if (!file) return;

        try {
            loadingDiv.style.display = 'flex';

            let previewData;

            if (file.type === 'image/png') {
                previewData = await this.createPreviewFromPNG(file);
            }

            img.src = previewData.dataUrl;
            info.textContent = file.name;
            sizeInfo.textContent = previewData.sizeText;

        } catch (error) {
            console.error('Error processing file:', error);
            info.textContent = `Error: ${file.name}`;
            sizeInfo.textContent = error.message;
            this.showErrorPlaceholder(img);
        } finally {
            loadingDiv.style.display = 'none';
        }
    }

    async createPreviewFromPNG(file) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');

            img.onload = () => {
                canvas.width = 320;
                canvas.height = 200;

                ctx.imageSmoothingEnabled = false;
                ctx.drawImage(img, 0, 0, 320, 200);

                const dataUrl = canvas.toDataURL();

                resolve({
                    dataUrl: dataUrl,
                    sizeText: `${(file.size / 1024).toFixed(1)}KB (PNG)`
                });
            };

            img.onerror = () => {
                reject(new Error('Invalid PNG file'));
            };

            const objectUrl = URL.createObjectURL(file);
            img.src = objectUrl;

            img.addEventListener('load', () => {
                URL.revokeObjectURL(objectUrl);
            }, { once: true });
        });
    }

    async createPreviewFromPNGData(pngData) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');

            img.onload = () => {
                canvas.width = 320;
                canvas.height = 200;

                ctx.imageSmoothingEnabled = false;
                ctx.drawImage(img, 0, 0, 320, 200);

                const dataUrl = canvas.toDataURL();

                URL.revokeObjectURL(img.src);

                resolve({
                    dataUrl: dataUrl,
                    sizeText: `${(pngData.length / 1024).toFixed(1)}KB (PNG)`
                });
            };

            img.onerror = () => {
                URL.revokeObjectURL(img.src);
                reject(new Error('Invalid PNG data'));
            };

            const blob = new Blob([pngData], { type: 'image/png' });
            const blobUrl = URL.createObjectURL(blob);
            img.src = blobUrl;
        });
    }

    async createPreviewFromData(data, filename) {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = 320;
        canvas.height = 200;

        this.renderBinaryPlaceholder(ctx, filename);

        return {
            dataUrl: canvas.toDataURL(),
            sizeText: `${(data.length / 1024).toFixed(1)}KB (Binary)`
        };
    }

    isPNGFile(data) {
        if (data.length < 8) return false;
        return data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4E && data[3] === 0x47 &&
            data[4] === 0x0D && data[5] === 0x0A && data[6] === 0x1A && data[7] === 0x0A;
    }

    renderBinaryPlaceholder(ctx, filename) {
        ctx.fillStyle = '#222';
        ctx.fillRect(0, 0, 320, 200);

        ctx.strokeStyle = '#444';
        ctx.lineWidth = 1;
        for (let i = 0; i < 320; i += 16) {
            ctx.beginPath();
            ctx.moveTo(i, 0);
            ctx.lineTo(i, 200);
            ctx.stroke();
        }
        for (let i = 0; i < 200; i += 16) {
            ctx.beginPath();
            ctx.moveTo(0, i);
            ctx.lineTo(320, i);
            ctx.stroke();
        }

        ctx.fillStyle = '#888';
        ctx.font = '16px monospace';
        ctx.textAlign = 'center';
        ctx.fillText('BINARY FILE', 160, 90);

        ctx.font = '12px monospace';
        const shortName = filename.length > 25 ? filename.substring(0, 22) + '...' : filename;
        ctx.fillText(shortName, 160, 110);
    }

    getFileType(data) {
        if (this.isPNGFile(data)) {
            return 'PNG';
        }
        return 'Binary';
    }

    showErrorPlaceholder(img) {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = 320;
        canvas.height = 200;

        ctx.fillStyle = '#400';
        ctx.fillRect(0, 0, 320, 200);

        ctx.fillStyle = '#fff';
        ctx.font = '16px monospace';
        ctx.textAlign = 'center';
        ctx.fillText('ERROR', 160, 90);
        ctx.font = '12px monospace';
        ctx.fillText('Unable to load image', 160, 110);

        img.src = canvas.toDataURL();
    }
}

window.ImagePreviewManager = ImagePreviewManager;

window.imagePreviewManager = new ImagePreviewManager();
```


### FILE: public/petscii-sanitizer.js
```js
class PETSCIISanitizer {
    constructor() {
        
        this.charMap = {
            
            0x201C: 34,  
            0x201D: 34,  
            0x201E: 34,  

            0x2018: 39,  
            0x2019: 39,  
            0x201A: 39,  

            0x2010: 45,  
            0x2011: 45,  
            0x2012: 45,  
            0x2013: 45,  
            0x2014: 45,  
            0x2015: 45,  
            0x2212: 45,  

            0x00A0: 32,  
            0x2000: 32,  
            0x2001: 32,  
            0x2002: 32,  
            0x2003: 32,  
            0x2004: 32,  
            0x2005: 32,  
            0x2006: 32,  
            0x2007: 32,  
            0x2008: 32,  
            0x2009: 32,  
            0x200A: 32,  
            0x202F: 32,  
            0x205F: 32,  

            0x2022: 42,  
            0x00B7: 46,  
        };

        this.warnings = [];
    }

    sanitize(text, options = {}) {
        const {
            maxLength = null,
            padToLength = null,
            center = false,
            reportUnknown = true
        } = options;

        this.warnings = [];
        if (!text) {
            return {
                text: padToLength ? ' '.repeat(padToLength) : '',
                warnings: [],
                hasWarnings: false,
                originalLength: 0,
                sanitizedLength: padToLength || 0
            };
        }

        const unknownChars = new Set();
        const result = [];

        for (let i = 0; i < text.length; i++) {
            const char = text[i];
            const code = char.charCodeAt(0);

            if (code === 0x2026) {
                result.push(46, 46, 46); 
            }
            
            else if (this.charMap[code] !== undefined) {
                result.push(this.charMap[code]);
            }
            
            else if (code === 10 || code === 13) {
                result.push(32); 
            }
            
            else if (code === 9) {
                result.push(32); 
            }
            
            else if (code >= 32 && code <= 126) {
                result.push(code);
            }
            
            else if (code >= 0x00E0 && code <= 0x00FF) {
                
                if ((code >= 0x00E0 && code <= 0x00E6) || code === 0x00E0) result.push(97); 
                else if (code >= 0x00E8 && code <= 0x00EB) result.push(101); 
                else if (code >= 0x00EC && code <= 0x00EF) result.push(105); 
                else if ((code >= 0x00F2 && code <= 0x00F6) || code === 0x00F8) result.push(111); 
                else if (code >= 0x00F9 && code <= 0x00FC) result.push(117); 
                else if (code === 0x00F1) result.push(110); 
                else if (code === 0x00E7) result.push(99); 
                else if (code === 0x00FD || code === 0x00FF) result.push(121); 
                else result.push(32); 
            }
            
            else if (code >= 0x00C0 && code <= 0x00DF) {
                
                if (code >= 0x00C0 && code <= 0x00C6) result.push(65); 
                else if (code >= 0x00C8 && code <= 0x00CB) result.push(69); 
                else if (code >= 0x00CC && code <= 0x00CF) result.push(73); 
                else if ((code >= 0x00D2 && code <= 0x00D6) || code === 0x00D8) result.push(79); 
                else if (code >= 0x00D9 && code <= 0x00DC) result.push(85); 
                else if (code === 0x00D1) result.push(78); 
                else if (code === 0x00C7) result.push(67); 
                else if (code === 0x00DD) result.push(89); 
                else result.push(32); 
            }
            
            else {
                unknownChars.add(char);
                result.push(32); 
            }
        }

        let sanitized = String.fromCharCode(...result);

        if (reportUnknown && unknownChars.size > 0) {
            const charList = Array.from(unknownChars).map(c => {
                const code = c.charCodeAt(0);
                if (code >= 32 && code < 127) {
                    return `"${c}"`;
                } else {
                    return `U+${code.toString(16).toUpperCase().padStart(4, '0')}`;
                }
            });

            this.warnings.push({
                type: 'unknown_characters',
                message: `Replaced ${unknownChars.size} incompatible character(s) with spaces`,
                characters: charList
            });
        }

        if (maxLength && sanitized.length > maxLength) {
            sanitized = sanitized.substring(0, maxLength);
            this.warnings.push({
                type: 'truncated',
                message: `Text truncated to ${maxLength} characters`,
                originalLength: text.length
            });
        }

        if (padToLength && sanitized.length < padToLength) {
            if (center) {
                const totalPadding = padToLength - sanitized.length;
                const leftPad = Math.floor(totalPadding / 2);
                const rightPad = totalPadding - leftPad;
                sanitized = ' '.repeat(leftPad) + sanitized + ' '.repeat(rightPad);
            } else {
                sanitized = sanitized.padEnd(padToLength, ' ');
            }
        }

        return {
            text: sanitized,
            warnings: this.warnings,
            hasWarnings: this.warnings.length > 0,
            originalLength: text.length,
            sanitizedLength: sanitized.length
        };
    }

    toPETSCIIBytes(text, lowercase = true) {
        const bytes = [];

        for (let i = 0; i < text.length; i++) {
            const code = text.charCodeAt(i);
            let petscii;

            if (lowercase) {
                
                if (code >= 65 && code <= 90) {
                    
                    petscii = code;
                } else if (code >= 97 && code <= 122) {
                    
                    petscii = code - 96;
                } else if (code >= 32 && code <= 64) {
                    
                    petscii = code;
                } else if (code >= 91 && code <= 96) {
                    
                    petscii = code;
                } else if (code >= 123 && code <= 126) {
                    
                    petscii = code;
                } else {
                    
                    petscii = 32;
                }
            } else {
                
                if (code >= 97 && code <= 122) {
                    
                    petscii = code - 32;
                } else if (code >= 32 && code <= 126) {
                    
                    petscii = code;
                } else {
                    
                    petscii = 32;
                }
            }

            bytes.push(petscii & 0xFF);
        }

        return new Uint8Array(bytes);
    }

    showWarningDialog(warnings) {
        if (!warnings || warnings.length === 0) return;

        console.warn('PETSCII Sanitization Warnings:');
        warnings.forEach(w => console.warn(`  - ${w.message}`));
    }
}

window.PETSCIISanitizer = PETSCIISanitizer;
```


### FILE: public/png-converter.js
```js
﻿
class PNGConverter {
    constructor(wasmModule) {
        this.Module = wasmModule;
        this.initialized = false;
    }

    init() {
        if (!this.Module) {
            throw new Error('WASM module not available');
        }

        const result = this.Module.ccall(
            'png_converter_init',
            'number',
            [],
            []
        );

        this.initialized = (result === 1);
        return this.initialized;
    }

    async convertPNGToC64(file) {
        if (!this.initialized) {
            throw new Error('PNG converter not initialized');
        }

        if (!file.type.startsWith('image/png')) {
            throw new Error('File must be a PNG image');
        }

        try {
            const imageData = await this.loadPNGImageData(file);

            if (!((imageData.width === 320 && imageData.height === 200) || (imageData.width === 384 && imageData.height === 272))) {
                throw new Error(`Image must be 320x200 pixels (got ${imageData.width}x${imageData.height})`);
            }

            const dataSize = imageData.width * imageData.height * 4;
            const dataPtr = this.Module._malloc(dataSize);

            try {
                this.Module.HEAPU8.set(imageData.data, dataPtr);

                const setResult = this.Module.ccall(
                    'png_converter_set_image',
                    'number',
                    ['number', 'number', 'number'],
                    [dataPtr, imageData.width, imageData.height]
                );

                if (setResult !== 1) {
                    throw new Error('Failed to set image data in converter');
                }

                const convertResult = this.Module.ccall(
                    'png_converter_convert',
                    'number',
                    [],
                    []
                );

                if (convertResult !== 1) {
                    throw new Error('Image contains too many colors per 8x8 character cell (max 4 colors allowed)');
                }

                const backgroundColor = this.Module.ccall(
                    'png_converter_get_background_color',
                    'number',
                    [],
                    []
                );

                const exactPtr = this.Module._malloc(4);
                const distancePtr = this.Module._malloc(4);

                try {
                    this.Module.ccall(
                        'png_converter_get_color_stats',
                        'null',
                        ['number', 'number'],
                        [exactPtr, distancePtr]
                    );
                } finally {
                    this.Module._free(exactPtr);
                    this.Module._free(distancePtr);
                }
                const c64BitmapSize = 10003;
                const bitmapPtr = this.Module._malloc(c64BitmapSize);

                try {
                    const actualSize = this.Module.ccall(
                        'png_converter_create_c64_bitmap',
                        'number',
                        ['number'],
                        [bitmapPtr]
                    );

                    const bitmapData = new Uint8Array(actualSize);
                    bitmapData.set(this.Module.HEAPU8.subarray(bitmapPtr, bitmapPtr + actualSize));

                    if (actualSize !== 10003) {
                        console.warn(`Unexpected bitmap output size: ${actualSize} (should be 10003)`);
                    }
                    if (bitmapData[0] !== 0x00 || bitmapData[1] !== 0x60) {
                        console.warn(`Unexpected load address: ${bitmapData[1].toString(16)}${bitmapData[0].toString(16)} (should be $6000)`);
                    }

                    return {
                        success: true,
                        data: bitmapData,
                        backgroundColor: backgroundColor,
                        backgroundColorName: this.getColorName(backgroundColor),
                        format: 'C64_BITMAP',
                        width: 320,
                        height: 200
                    };

                } finally {
                    this.Module._free(bitmapPtr);
                }

            } finally {
                this.Module._free(dataPtr);
            }

        } catch (error) {
            console.error('PNG conversion error:', error);
            throw error;
        }
    }

    async loadPNGImageData(file) {
        return new Promise((resolve, reject) => {
            const img = new Image();

            img.onload = () => {
                try {
                    const canvas = document.createElement('canvas');
                    const ctx = canvas.getContext('2d');

                    canvas.width = img.width;
                    canvas.height = img.height;

                    ctx.drawImage(img, 0, 0);

                    const imageData = ctx.getImageData(0, 0, img.width, img.height);

                    resolve(imageData);

                } catch (error) {
                    reject(new Error(`Failed to process image: ${error.message}`));
                }
            };

            img.onerror = () => {
                reject(new Error('Failed to load PNG image'));
            };

            const url = URL.createObjectURL(file);
            img.src = url;

            img.onload = (originalOnLoad => function (...args) {
                URL.revokeObjectURL(url);
                return originalOnLoad.apply(this, args);
            })(img.onload);

            img.onerror = (originalOnError => function (...args) {
                URL.revokeObjectURL(url);
                return originalOnError.apply(this, args);
            })(img.onerror);
        });
    }

    getColorName(colorIndex) {
        const colorNames = [
            'Black', 'White', 'Red', 'Cyan', 'Purple', 'Green', 'Blue', 'Yellow',
            'Orange', 'Brown', 'Light Red', 'Dark Grey', 'Grey', 'Light Green',
            'Light Blue', 'Light Grey'
        ];

        return colorNames[colorIndex] || 'Unknown';
    }

    async getComponentData() {
        if (!this.initialized) {
            throw new Error('PNG converter not initialized');
        }

        const mapPtr = this.Module._malloc(8000);
        const scrPtr = this.Module._malloc(1000);
        const colPtr = this.Module._malloc(1000);

        try {
            this.Module.ccall('png_converter_get_map_data', 'number', ['number'], [mapPtr]);
            const mapData = new Uint8Array(8000);
            mapData.set(this.Module.HEAPU8.subarray(mapPtr, mapPtr + 8000));

            this.Module.ccall('png_converter_get_scr_data', 'number', ['number'], [scrPtr]);
            const scrData = new Uint8Array(1000);
            scrData.set(this.Module.HEAPU8.subarray(scrPtr, scrPtr + 1000));

            this.Module.ccall('png_converter_get_col_data', 'number', ['number'], [colPtr]);
            const colData = new Uint8Array(1000);
            colData.set(this.Module.HEAPU8.subarray(colPtr, colPtr + 1000));

            return {
                bitmap: mapData,
                screen: scrData,
                color: colData,
                background: this.Module.ccall('png_converter_get_background_color', 'number', [], [])
            };

        } finally {
            this.Module._free(mapPtr);
            this.Module._free(scrPtr);
            this.Module._free(colPtr);
        }
    }

    cleanup() {
        if (this.initialized) {
            this.Module.ccall('png_converter_cleanup', 'null', [], []);
            this.initialized = false;
        }
    }
}

window.PNGConverter = PNGConverter;
```


### FILE: public/prg-builder.js
```js
﻿

class PRGBuilder {
    constructor() {
        this.components = [];
        this.lowestAddress = 0xFFFF;
        this.highestAddress = 0x0000;
    }

    addComponent(data, loadAddress, name) {
        if (!data || data.length === 0) {
            throw new Error(`Component ${name} has no data`);
        }

        this.components.push({
            data: data,
            loadAddress: loadAddress,
            size: data.length,
            name: name
        });

        this.lowestAddress = Math.min(this.lowestAddress, loadAddress);
        this.highestAddress = Math.max(this.highestAddress, loadAddress + data.length - 1);
    }

    build() {
        if (this.components.length === 0) {
            throw new Error('No components added to PRG');
        }

        this.components.sort((a, b) => a.loadAddress - b.loadAddress);

        const totalSize = (this.highestAddress - this.lowestAddress + 1) + 2;
        const prgData = new Uint8Array(totalSize);

        prgData[0] = this.lowestAddress & 0xFF;
        prgData[1] = (this.lowestAddress >> 8) & 0xFF;

        for (let i = 2; i < totalSize; i++) {
            prgData[i] = 0x00;
        }

        for (const component of this.components) {
            const offset = component.loadAddress - this.lowestAddress + 2;
            for (let i = 0; i < component.data.length; i++) {
                prgData[offset + i] = component.data[i];
            }
        }

        return prgData;
    }

    clear() {
        this.components = [];
        this.lowestAddress = 0xFFFF;
        this.highestAddress = 0x0000;
    }

    getInfo() {
        return {
            components: this.components.map(c => ({
                name: c.name,
                loadAddress: c.loadAddress,
                size: c.size,
                endAddress: c.loadAddress + c.size - 1
            })),
            lowestAddress: this.lowestAddress,
            highestAddress: this.highestAddress,
            totalSize: this.highestAddress - this.lowestAddress + 1
        };
    }
}

class SIDwinderPRGExporter {
    constructor(analyzer) {
        this.analyzer = analyzer;
        this.builder = new PRGBuilder();
        this.compressorManager = new CompressorManager();
        this.saveRoutineAddress = 0;
        this.restoreRoutineAddress = 0;
    }

    alignToPage(address) {
        return (address + 0xFF) & 0xFF00;
    }

    calculateSaveRestoreSize(modifiedAddresses) {
        const filtered = modifiedAddresses.filter(addr => {
            if (addr >= 0x0100 && addr <= 0x01FF) return false;
            if (addr >= 0xD400 && addr <= 0xD7FF) return false;
            return true;
        });

        let saveSize = 1; 
        let restoreSize = 1; 
        for (const addr of filtered) {
            if (addr < 256) {
                saveSize += 5; 
                restoreSize += 4; 
            } else {
                saveSize += 6; 
                restoreSize += 5; 
            }
        }

        return {
            saveSize,
            restoreSize,
            totalSize: saveSize + restoreSize,
            addressCount: filtered.length
        };
    }

    selectValidLayouts(vizConfig, sidLoadAddress, sidSize, modifiedAddresses = null) {
        const validLayouts = [];
        const sidEnd = sidLoadAddress + sidSize;

        for (const [key, layout] of Object.entries(vizConfig.layouts)) {
            const vizStart = parseInt(layout.baseAddress);
            const vizEnd = vizStart + parseInt(layout.size || '0x4000');

            let saveRestoreStart = vizStart;
            let saveRestoreEnd = vizStart;

            if (modifiedAddresses && modifiedAddresses.length > 0) {
                
                const sizes = this.calculateSaveRestoreSize(modifiedAddresses);

                if (layout.saveRestoreLocation === 'before') {
                    const saveRestoreAddr = layout.saveRestoreAddress ?
                        parseInt(layout.saveRestoreAddress) :
                        vizStart - sizes.totalSize;
                    saveRestoreStart = saveRestoreAddr;
                    saveRestoreEnd = saveRestoreAddr + sizes.totalSize;
                } else {
                    
                    saveRestoreStart = vizEnd;
                    saveRestoreEnd = vizEnd + sizes.totalSize;
                }
            } else if (modifiedAddresses === null) {
                
                saveRestoreStart = vizStart;
                saveRestoreEnd = vizStart;
            }

            const effectiveStart = Math.min(vizStart, saveRestoreStart);
            const effectiveEnd = Math.max(vizEnd, saveRestoreEnd);
            const hasOverlap = !(effectiveEnd <= sidLoadAddress || effectiveStart >= sidEnd);

            const sidStartHex = '$' + sidLoadAddress.toString(16).toUpperCase().padStart(4, '0');
            const sidEndHex = '$' + sidEnd.toString(16).toUpperCase().padStart(4, '0');

            validLayouts.push({
                key: key,
                layout: layout,
                valid: !hasOverlap,
                vizStart: vizStart,
                vizEnd: vizEnd,
                saveRestoreStart: saveRestoreStart,
                saveRestoreEnd: saveRestoreEnd,
                overlapReason: hasOverlap ?
                    `Overlaps with SID (${sidStartHex}-${sidEndHex})` :
                    null
            });
        }

        return validLayouts;
    }

    generateOptimizedSaveRoutine(modifiedAddresses, restoreRoutineAddr) {
        const code = [];
        let restoreOffset = 0;

        const filtered = modifiedAddresses
            .filter(addr => {
                if (addr >= 0x0100 && addr <= 0x01FF) return false;
                if (addr >= 0xD400 && addr <= 0xD7FF) return false;
                return true;
            })
            .sort((a, b) => a - b);

        for (const addr of filtered) {
            
            if (addr < 256) {
                code.push(0xA5); 
                code.push(addr);
            } else {
                code.push(0xAD); 
                code.push(addr & 0xFF);
                code.push((addr >> 8) & 0xFF);
            }

            const targetAddr = restoreRoutineAddr + restoreOffset + 1;
            code.push(0x8D); 
            code.push(targetAddr & 0xFF);
            code.push((targetAddr >> 8) & 0xFF);

            if (addr < 256) {
                restoreOffset += 4; 
            } else {
                restoreOffset += 5; 
            }
        }

        code.push(0x60); 
        return new Uint8Array(code);
    }

    generateOptimizedRestoreRoutine(modifiedAddresses) {
        const code = [];

        const filtered = modifiedAddresses
            .filter(addr => {
                if (addr >= 0x0100 && addr <= 0x01FF) return false;
                if (addr >= 0xD400 && addr <= 0xD7FF) return false;
                return true;
            })
            .sort((a, b) => a - b);

        for (const addr of filtered) {
            
            code.push(0xA9); 
            code.push(0x00); 

            if (addr < 256) {
                code.push(0x85); 
                code.push(addr);
            } else {
                code.push(0x8D); 
                code.push(addr & 0xFF);
                code.push((addr >> 8) & 0xFF);
            }
        }

        code.push(0x60); 
        return new Uint8Array(code);
    }

    generateDataBlock(sidInfo, analysisResults, header, saveRoutineAddr, restoreRoutineAddr, numCallsPerFrame, maxCallsPerFrame, selectedSong = 0, modifiedCount = 0) {
        const data = new Uint8Array(0x100);

        let effectiveCallsPerFrame = numCallsPerFrame;
        if (maxCallsPerFrame !== null && numCallsPerFrame > maxCallsPerFrame) {
            console.warn(`SID requires ${numCallsPerFrame} calls per frame, but visualizer supports max ${maxCallsPerFrame}. Limiting to ${maxCallsPerFrame}.`);
            effectiveCallsPerFrame = maxCallsPerFrame;
        }

        data[0] = 0x4C;
        data[1] = sidInfo.initAddress & 0xFF;
        data[2] = (sidInfo.initAddress >> 8) & 0xFF;

        data[3] = 0x4C;
        data[4] = sidInfo.playAddress & 0xFF;
        data[5] = (sidInfo.playAddress >> 8) & 0xFF;

        data[6] = 0x4C;
        data[7] = saveRoutineAddr & 0xFF;
        data[8] = (saveRoutineAddr >> 8) & 0xFF;

        data[9] = 0x4C;
        data[10] = restoreRoutineAddr & 0xFF;
        data[11] = (restoreRoutineAddr >> 8) & 0xFF;

        data[0x0C] = effectiveCallsPerFrame & 0xFF;
        data[0x0D] = 0x00; 
        data[0x0E] = 0x00; 
        data[0x0F] = selectedSong & 0xFF;

        const nameBytes = this.stringToPETSCII(this.centerString(header.name || '', 32), 32);
        for (let i = 0; i < 32; i++) {
            data[0x10 + i] = nameBytes[i];
        }

        const authorBytes = this.stringToPETSCII(this.centerString(header.author || '', 32), 32);
        for (let i = 0; i < 32; i++) {
            data[0x30 + i] = authorBytes[i];
        }

        const copyrightBytes = this.stringToPETSCII(this.centerString(header.copyright || '', 32), 32);
        for (let i = 0; i < 32; i++) {
            data[0x50 + i] = copyrightBytes[i];
        }

        data[0xC0] = sidInfo.loadAddress & 0xFF;
        data[0xC1] = (sidInfo.loadAddress >> 8) & 0xFF;

        data[0xC2] = sidInfo.initAddress & 0xFF;
        data[0xC3] = (sidInfo.initAddress >> 8) & 0xFF;

        data[0xC4] = sidInfo.playAddress & 0xFF;
        data[0xC5] = (sidInfo.playAddress >> 8) & 0xFF;

        const endAddress = sidInfo.loadAddress + (sidInfo.dataSize || 0x1000) - 1;
        data[0xC6] = endAddress & 0xFF;
        data[0xC7] = (endAddress >> 8) & 0xFF;

        data[0xC8] = (header.songs || 1) & 0xFF;

        const clockType = (header.clockType === 'NTSC') ? 1 : 0;
        data[0xC9] = clockType;

        const sidModel = (header.sidModel && header.sidModel.includes('8580')) ? 1 : 0;
        data[0xCA] = sidModel;

        data[0xCB] = modifiedCount & 0xFF;
        data[0xCC] = (modifiedCount >> 8) & 0xFF;

        let zpString = 'NONE';
        if (analysisResults) {
            zpString = this.formatZPUsage(analysisResults.zpAddresses);
        }
        const zpBytes = this.stringToPETSCII(zpString, 32);
        for (let i = 0; i < 32; i++) {
            data[0xE0 + i] = zpBytes[i];
        }

        return data;
    }

    formatZPUsage(zpAddresses) {
        if (!zpAddresses || zpAddresses.length === 0) {
            return 'NONE';
        }

        const sorted = [...zpAddresses].sort((a, b) => a - b);
        const ranges = [];
        let currentRange = { start: sorted[0], end: sorted[0] };

        for (let i = 1; i < sorted.length; i++) {
            if (sorted[i] === currentRange.end + 1) {
                currentRange.end = sorted[i];
            } else {
                ranges.push(currentRange);
                currentRange = { start: sorted[i], end: sorted[i] };
            }
        }
        ranges.push(currentRange);

        const parts = ranges.map(r => {
            if (r.start === r.end) {
                return `$${r.start.toString(16).toUpperCase().padStart(2, '0')}`;
            } else {
                return `$${r.start.toString(16).toUpperCase().padStart(2, '0')}-$${r.end.toString(16).toUpperCase().padStart(2, '0')}`;
            }
        });

        let result = '';
        const maxLength = 20;
        const ellipsis = '...';
        const ellipsisLength = ellipsis.length;

        for (let i = 0; i < parts.length; i++) {
            const part = parts[i];
            const separator = i === 0 ? '' : ', ';
            const testString = result + separator + part;

            if (testString.length > maxLength) {
                
                if (result === '') {
                    
                    if (part.length > maxLength - ellipsisLength) {
                        result = part.substring(0, maxLength - ellipsisLength) + ellipsis;
                    } else {
                        result = part;
                    }
                } else {
                    
                    if (result.length <= maxLength - ellipsisLength) {
                        result = result + ellipsis;
                    } else {
                        
                        const lastComma = result.lastIndexOf(',');
                        if (lastComma > 0 && lastComma <= maxLength - ellipsisLength) {
                            result = result.substring(0, lastComma) + ellipsis;
                        } else {
                            
                            result = result.substring(0, maxLength - ellipsisLength) + ellipsis;
                        }
                    }
                }
                break;
            }

            result = testString;
        }

        return result;
    }

    stringToPETSCII(str, length) {
        const bytes = new Uint8Array(length);
        bytes.fill(0x20);

        if (str && str.length > 0) {
            const maxLen = Math.min(str.length, length);

            for (let i = 0; i < maxLen; i++) {
                const code = str.charCodeAt(i);
                let petscii = 0x20;

                if (code >= 65 && code <= 90) {
                    petscii = code;
                } else if (code >= 97 && code <= 122) {
                    petscii = code - 32;
                } else if (code >= 48 && code <= 57) {
                    petscii = code;
                } else if (code === 32) {
                    petscii = 0x20;
                } else {
                    petscii = code;
                }

                bytes[i] = petscii & 0xFF;
            }
        }

        return bytes;
    }

    centerString(str, length) {
        if (!str || str.length === 0) {
            return str;
        }

        str = str.trim();
        if (str.length >= length) {
            return str.substring(0, length);
        }

        const padding = Math.floor((length - str.length) / 2);
        const paddingStr = ' '.repeat(padding);
        const result = paddingStr + str;

        return result.padEnd(length, ' ');
    }

    getOrdinalSuffix(day) {
        if (day > 3 && day < 21) return 'th';
        switch (day % 10) {
            case 1: return 'st';
            case 2: return 'nd';
            case 3: return 'rd';
            default: return 'th';
        }
    }

    async loadBinaryFile(url) {
        try {
            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`Failed to load ${url}: ${response.statusText}`);
            }
            const arrayBuffer = await response.arrayBuffer();
            return new Uint8Array(arrayBuffer);
        } catch (error) {
            console.error(`Error loading ${url}:`, error);
            throw error;
        }
    }

    extractSIDMusicData() {
        const modifiedSID = this.analyzer.createModifiedSID();
        if (!modifiedSID) {
            throw new Error('Failed to get SID data');
        }

        const view = new DataView(modifiedSID.buffer);
        const version = view.getUint16(0x04, false);
        const headerSize = (version === 1) ? 0x76 : 0x7C;

        let loadAddress = view.getUint16(0x08, false);
        let dataStart = headerSize;

        if (loadAddress === 0) {
            loadAddress = view.getUint16(headerSize, true);
            dataStart = headerSize + 2;
        }

        const musicData = modifiedSID.slice(dataStart);

        if (musicData.length >= 2) {
            const firstTwo = (musicData[0] | (musicData[1] << 8));
            if (firstTwo === loadAddress) {
                return {
                    data: musicData.slice(2),
                    loadAddress: loadAddress,
                    dataSize: musicData.slice(2).length
                };
            }
        }

        return {
            data: musicData,
            loadAddress: loadAddress,
            dataSize: musicData.length
        };
    }

    async processVisualizerInputs(visualizerType, layoutKey = 'bank4000') {
        const config = new VisualizerConfig();
        const vizConfig = await config.loadConfig(visualizerType);

        if (!vizConfig || !vizConfig.inputs) {
            return [];
        }

        const additionalComponents = [];

        for (const inputConfig of vizConfig.inputs) {
            const inputElement = document.getElementById(inputConfig.id);
            let fileData = null;

            if (inputElement && inputElement.files.length > 0) {
                const file = inputElement.files[0];

                if (file.type === 'image/png' && file.name.toLowerCase().endsWith('.png')) {
                    
                    if (typeof PNGConverter === 'undefined') {
                        console.error('PNGConverter not available');
                        throw new Error('PNG converter not loaded. Please refresh the page and try again.');
                    }

                    if (!window.SIDwinderModule) {
                        console.error('SIDwinderModule not available');
                        throw new Error('WASM module not ready. Please wait a moment and try again.');
                    }

                    try {
                        const converter = new PNGConverter(window.SIDwinderModule);
                        converter.init();
                        const result = await converter.convertPNGToC64(file);
                        fileData = result.data;

                        if (fileData.length === 10003 && fileData[0] === 0x00 && fileData[1] === 0x60) {
                            
                        } else {
                            console.warn('Unexpected C64 image format - this may cause issues');
                        }
                    } catch (pngError) {
                        console.error('PNG conversion failed:', pngError);
                        throw new Error(`PNG conversion failed: ${pngError.message}`);
                    }
                } else {
                    
                    try {
                        const arrayBuffer = await file.arrayBuffer();
                        fileData = new Uint8Array(arrayBuffer);
                    } catch (loadError) {
                        console.error('File loading failed:', loadError);
                        throw new Error(`Failed to load file ${file.name}: ${loadError.message}`);
                    }
                }
            } else if (inputConfig.default) {
                try {
                    const rawFileData = await config.loadDefaultFile(inputConfig.default);

                    if (inputConfig.default.toLowerCase().endsWith('.png') && this.isPNGFile(rawFileData)) {
                        
                        if (typeof PNGConverter === 'undefined') {
                            console.error('PNGConverter not available');
                            throw new Error('PNG converter not loaded. Please refresh the page and try again.');
                        }

                        if (!window.SIDwinderModule) {
                            console.error('SIDwinderModule not available');
                            throw new Error('WASM module not ready. Please wait a moment and try again.');
                        }

                        try {
                            
                            const blob = new Blob([rawFileData], { type: 'image/png' });
                            const file = new File([blob], inputConfig.default.split('/').pop(), { type: 'image/png' });

                            const converter = new PNGConverter(window.SIDwinderModule);
                            converter.init();
                            const result = await converter.convertPNGToC64(file);
                            fileData = result.data;

                            if (fileData.length === 10003 && fileData[0] === 0x00 && fileData[1] === 0x60) {
                                console.log('Default PNG converted to valid C64 image format');
                            } else {
                                console.warn('Default PNG conversion resulted in unexpected C64 image format');
                            }
                        } catch (pngError) {
                            console.error('Default PNG conversion failed:', pngError);
                            throw new Error(`Default PNG conversion failed: ${pngError.message}`);
                        }
                    } else {
                        
                        fileData = rawFileData;
                    }
                } catch (defaultError) {
                    console.error('Default file loading failed:', defaultError);
                    throw new Error(`Failed to load default file ${inputConfig.default}: ${defaultError.message}`);
                }
            }

            if (fileData && inputConfig.memory && inputConfig.memory[layoutKey]) {
                const memoryRegions = inputConfig.memory[layoutKey];

                for (const memConfig of memoryRegions) {
                    const sourceOffset = parseInt(memConfig.sourceOffset);
                    const targetAddress = parseInt(memConfig.targetAddress);
                    const size = parseInt(memConfig.size);

                    if (sourceOffset >= fileData.length) {
                        console.warn(`Offset ${sourceOffset} exceeds file size ${fileData.length} for component ${memConfig.name}`);
                        continue;
                    }

                    const endOffset = Math.min(sourceOffset + size, fileData.length);
                    const data = fileData.slice(sourceOffset, endOffset);

                    if (data.length === 0) {
                        console.warn(`No data extracted for component ${memConfig.name}`);
                        continue;
                    }

                    additionalComponents.push({
                        data: data,
                        loadAddress: targetAddress,
                        name: `${inputConfig.id}_${memConfig.name}`
                    });
                }
            }
        }

        return additionalComponents;
    }

    isPNGFile(data) {
        if (data.length < 8) return false;
        return data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4E && data[3] === 0x47 &&
            data[4] === 0x0D && data[5] === 0x0A && data[6] === 0x1A && data[7] === 0x0A;
    }

    async processVisualizerOptions(visualizerType, layoutKey = 'bank4000') {
        const config = new VisualizerConfig();
        const vizConfig = await config.loadConfig(visualizerType);

        if (!vizConfig || !vizConfig.options) {
            return [];
        }

        const layout = vizConfig.layouts[layoutKey];
        if (!layout) {
            console.warn(`Layout ${layoutKey} not found`);
            return [];
        }

        if (!this.sanitizer) {
            this.sanitizer = new PETSCIISanitizer();
        }

        const optionComponents = [];

        for (const optionConfig of vizConfig.options) {
            const element = document.getElementById(optionConfig.id);
            if (!element) continue;

            if (optionConfig.dataField && layout[optionConfig.dataField]) {
                const targetAddress = parseInt(layout[optionConfig.dataField]);

                if (optionConfig.type === 'date') {
                    const dateValue = element.value;
                    let formattedDate = '';

                    if (dateValue) {
                        const date = new Date(dateValue);
                        const day = date.getDate();
                        const months = ['January', 'February', 'March', 'April', 'May', 'June',
                            'July', 'August', 'September', 'October', 'November', 'December'];
                        const month = months[date.getMonth()];
                        const year = date.getFullYear();

                        const suffix = this.getOrdinalSuffix(day);
                        formattedDate = `${day}${suffix} ${month} ${year}`;
                    }

                    const sanitized = this.sanitizer.sanitize(formattedDate, {
                        maxLength: 32,
                        padToLength: 32,
                        center: true,
                        reportUnknown: false
                    });

                    const data = this.sanitizer.toPETSCIIBytes(sanitized.text, true);

                    optionComponents.push({
                        data: data,
                        loadAddress: targetAddress,
                        name: `option_${optionConfig.id}`
                    });

                } else if (optionConfig.type === 'number') {
                    let value = parseInt(element.value) || optionConfig.default || 0;
                    const data = new Uint8Array(1);
                    data[0] = value & 0xFF;

                    optionComponents.push({
                        data: data,
                        loadAddress: targetAddress,
                        name: `option_${optionConfig.id}`
                    });

                } else if (optionConfig.type === 'textarea') {
                    const textValue = element.value || optionConfig.default || '';

                    const sanitized = this.sanitizer.sanitize(textValue, {
                        maxLength: optionConfig.maxLength || 255,
                        preserveNewlines: false,  
                        reportUnknown: true
                    });

                    if (sanitized.hasWarnings) {
                        this.sanitizer.showWarningDialog(sanitized.warnings);
                    }

                    const petsciiData = this.sanitizer.toPETSCIIBytes(sanitized.text, true);

                    const data = new Uint8Array(petsciiData.length + 1);
                    data.set(petsciiData);
                    data[data.length - 1] = 0x00; 

                    optionComponents.push({
                        data: data,
                        loadAddress: targetAddress,
                        name: `option_${optionConfig.id}`
                    });
                }
            }
        }

        return optionComponents;
    }

    stringToPETSCII(str, length) {
        
        if (!this.sanitizer) {
            this.sanitizer = new PETSCIISanitizer();
        }

        const sanitized = this.sanitizer.sanitize(str || '', {
            maxLength: length,
            padToLength: length,
            center: false,
            reportUnknown: false  
        });

        return this.sanitizer.toPETSCIIBytes(sanitized.text, true);
    }

    centerString(str, length) {
        if (!this.sanitizer) {
            this.sanitizer = new PETSCIISanitizer();
        }

        const sanitized = this.sanitizer.sanitize(str || '', {
            maxLength: length,
            padToLength: length,
            center: true,
            reportUnknown: false
        });

        return sanitized.text;
    }

    async createPRG(options = {}) {
        const {
            sidLoadAddress = null,
            sidInitAddress = null,
            sidPlayAddress = null,
            preferredAddress = null,
            visualizerFile = 'prg/TextInput.bin',
            compressionType = 'tscrunch',
            maxCallsPerFrame = null,
            visualizerId = null,
            selectedSong = 0
        } = options;

        try {
            this.builder.clear();

            const sidInfo = this.extractSIDMusicData();

            let header = null;
            if (this.analyzer.sidHeader) {
                header = this.analyzer.sidHeader;
            } else {
                const modifiedSID = this.analyzer.createModifiedSID();
                if (modifiedSID) {
                    header = await this.analyzer.loadSID(modifiedSID);
                    this.analyzer.sidHeader = header;
                }
            }

            if (!header) {
                header = {
                    name: 'Unknown',
                    author: 'Unknown',
                    copyright: '',
                    songs: 1,
                    clockType: 'PAL',
                    sidModel: '6581',
                    fileSize: sidInfo.data.length
                };
            }

            const config = new VisualizerConfig();
            const visualizerName = options.visualizerId || options.visualizerFile.replace('prg/', '').replace('.bin', '');
            const vizConfig = await config.loadConfig(visualizerName);
            const configMaxCallsPerFrame = vizConfig?.maxCallsPerFrame || null;

            const modifiedCount = this.analyzer.analysisResults?.modifiedAddresses?.length || 0;

            let layoutKey = options.layoutKey;
            if (!layoutKey) {
                const validLayouts = this.selectValidLayouts(vizConfig, sidInfo.loadAddress, sidInfo.dataSize, modifiedAddresses);
                const firstValid = validLayouts.find(l => l.valid);
                if (!firstValid) {
                    throw new Error(`No valid layout found for visualizer ${visualizerName}`);
                }
                layoutKey = firstValid.key;
            }

            const layout = vizConfig?.layouts?.[layoutKey];

            if (!layout) {
                throw new Error(`No valid layout found for visualizer ${visualizerName}`);
            }

            const dataLoadAddress = parseInt(layout.dataAddress);
            const visualizerLoadAddress = parseInt(layout.sysAddress);

            const actualSidAddress = sidLoadAddress || sidInfo.loadAddress;
            const actualInitAddress = sidInitAddress || sidInfo.initAddress || actualSidAddress;
            const actualPlayAddress = sidPlayAddress || sidInfo.playAddress || (actualSidAddress + 3);

            this.builder.addComponent(sidInfo.data, actualSidAddress, 'SID Music');

            let nextAvailableAddress = visualizerLoadAddress;

            if (layout.binary) {
                const visualizerBytes = await this.loadBinaryFile(layout.binary);
                const binaryLoadAddress = parseInt(layout.binaryDataStart || layout.baseAddress);
                this.builder.addComponent(visualizerBytes, binaryLoadAddress, 'Visualizer Binary');
                const binaryEndAddress = parseInt(layout.binaryDataEnd || (binaryLoadAddress + visualizerBytes.length));
                nextAvailableAddress = binaryEndAddress + 1;
            }

            const additionalComponents = await this.processVisualizerInputs(visualizerName, layoutKey);
            for (const component of additionalComponents) {
                this.builder.addComponent(component.data, component.loadAddress, component.name);
            }

            let saveRoutineAddr = 0;
            let restoreRoutineAddr = 0;

            if (this.analyzer.analysisResults && this.analyzer.analysisResults.modifiedAddresses) {
                const modifiedAddrs = Array.from(this.analyzer.analysisResults.modifiedAddresses);

                const restoreRoutine = this.generateOptimizedRestoreRoutine(modifiedAddrs);
                const tempSaveRoutine = this.generateOptimizedSaveRoutine(modifiedAddrs, 0); 

                if (layout.saveRestoreLocation === 'before' && layout.saveRestoreEndAddress) {
                    
                    const endAddress = parseInt(layout.saveRestoreEndAddress);
                    const totalSize = restoreRoutine.length + tempSaveRoutine.length;

                    const maxSize = layout.saveRestoreMaxSize ? parseInt(layout.saveRestoreMaxSize) : 0x800;
                    if (totalSize > maxSize) {
                        throw new Error(`Save/restore routines (${totalSize} bytes) exceed maximum ${maxSize} bytes for this layout`);
                    }

                    restoreRoutineAddr = endAddress - totalSize;
                    saveRoutineAddr = restoreRoutineAddr + restoreRoutine.length;

                    const finalSaveRoutine = this.generateOptimizedSaveRoutine(modifiedAddrs, restoreRoutineAddr);

                    this.builder.addComponent(restoreRoutine, restoreRoutineAddr, 'Restore Routine');
                    this.builder.addComponent(finalSaveRoutine, saveRoutineAddr, 'Save Routine');
                } else {
                    
                    const baseAddress = parseInt(layout.baseAddress);
                    const vizSize = parseInt(layout.size || '0x4000');

                    restoreRoutineAddr = baseAddress + vizSize;
                    saveRoutineAddr = restoreRoutineAddr + restoreRoutine.length;

                    const finalSaveRoutine = this.generateOptimizedSaveRoutine(modifiedAddrs, restoreRoutineAddr);

                    this.builder.addComponent(restoreRoutine, restoreRoutineAddr, 'Restore Routine');
                    this.builder.addComponent(finalSaveRoutine, saveRoutineAddr, 'Save Routine');
                }
            } else {
                console.warn('No analysis results for save/restore routines');
                const dummyRoutine = new Uint8Array([0x60]); 
                saveRoutineAddr = 0x3F00;
                restoreRoutineAddr = 0x3F80;
                this.builder.addComponent(dummyRoutine, saveRoutineAddr, 'Dummy Save');
                this.builder.addComponent(dummyRoutine, restoreRoutineAddr, 'Dummy Restore');
            }

            const numCallsPerFrame = this.analyzer.analysisResults?.numCallsPerFrame || 1;

            const dataBlock = this.generateDataBlock(
                {
                    initAddress: actualInitAddress,
                    playAddress: actualPlayAddress,
                    loadAddress: actualSidAddress,
                    dataSize: sidInfo.dataSize
                },
                this.analyzer.analysisResults,
                header,
                saveRoutineAddr,
                restoreRoutineAddr,
                numCallsPerFrame,
                configMaxCallsPerFrame,
                selectedSong,
                modifiedCount
            );

            this.builder.addComponent(dataBlock, dataLoadAddress, 'Data Block');

            const optionComponents = await this.processVisualizerOptions(visualizerName, layoutKey);
            for (const component of optionComponents) {
                this.builder.addComponent(component.data, component.loadAddress, component.name);
            }

            const prgData = this.builder.build();

            this.saveRoutineAddress = saveRoutineAddr;
            this.restoreRoutineAddress = restoreRoutineAddr;

            if (compressionType !== 'none') {
                try {
                    if (!this.compressorManager) {
                        this.compressorManager = new CompressorManager();
                    }

                    if (!this.compressorManager.isAvailable(compressionType)) {
                        console.warn(`${compressionType} compressor not available, returning uncompressed`);
                        return prgData;
                    }

                    const uncompressedStart = this.builder.lowestAddress;
                    const executeAddress = visualizerLoadAddress;

                    const result = await this.compressorManager.compress(
                        prgData,
                        compressionType,
                        uncompressedStart,
                        executeAddress
                    );

                    const result_ratio = result.compressedSize / result.originalSize;

                    return result.data;

                } catch (error) {
                    console.error(`${compressionType} compression failed:`, error);
                    return prgData;
                }
            }

            return prgData;

        } catch (error) {
            console.error('Error creating PRG:', error);
            throw error;
        }
    }
}

window.PRGBuilder = PRGBuilder;
window.SIDwinderPRGExporter = SIDwinderPRGExporter;
```


### FILE: public/sidwinder-core.js
```js
class SIDAnalyzer {
    constructor() {
        this.wasmModule = null;
        this.wasmReady = false;
        this.api = null;
        this.Module = null; 
        this.initPromise = this.initWASM();
    }

    async initWASM() {
        try {
            this.Module = await SIDwinderModule();
            this.wasmModule = this.Module;
            window.SIDwinderModule = this.Module; 

            if (!this.Module.HEAPU8) {
                console.error('HEAPU8 not found in module');
                throw new Error('WASM memory arrays not available');
            }

            this.api = {
                
                sid_init: this.Module.cwrap('sid_init', null, []),
                sid_load: this.Module.cwrap('sid_load', 'number', ['number', 'number']),
                sid_analyze: this.Module.cwrap('sid_analyze', 'number', ['number', 'number']),
                sid_get_header_string: this.Module.cwrap('sid_get_header_string', 'string', ['number']),
                sid_get_header_value: this.Module.cwrap('sid_get_header_value', 'number', ['number']),
                sid_set_header_string: this.Module.cwrap('sid_set_header_string', null, ['number', 'string']),
                sid_create_modified: this.Module.cwrap('sid_create_modified', 'number', ['number']),
                sid_get_modified_count: this.Module.cwrap('sid_get_modified_count', 'number', []),
                sid_get_modified_address: this.Module.cwrap('sid_get_modified_address', 'number', ['number']),
                sid_get_zp_count: this.Module.cwrap('sid_get_zp_count', 'number', []),
                sid_get_zp_address: this.Module.cwrap('sid_get_zp_address', 'number', ['number']),
                sid_get_code_bytes: this.Module.cwrap('sid_get_code_bytes', 'number', []),
                sid_get_data_bytes: this.Module.cwrap('sid_get_data_bytes', 'number', []),
                sid_get_sid_writes: this.Module.cwrap('sid_get_sid_writes', 'number', ['number']),
                sid_get_clock_type: this.Module.cwrap('sid_get_clock_type', 'string', []),
                sid_get_sid_model: this.Module.cwrap('sid_get_sid_model', 'string', []),
                sid_get_num_calls_per_frame: this.Module.cwrap('sid_get_num_calls_per_frame', 'number', []),
                sid_get_cia_timer_detected: this.Module.cwrap('sid_get_cia_timer_detected', 'number', []),
                sid_get_cia_timer_value: this.Module.cwrap('sid_get_cia_timer_value', 'number', []),
                sid_cleanup: this.Module.cwrap('sid_cleanup', null, []),

                malloc: (size) => this.Module._malloc(size),
                free: (ptr) => this.Module._free(ptr)
            };

            this.api.sid_init();
            this.wasmReady = true;

            return true;

        } catch (error) {
            console.error('Failed to initialize WASM module:', error);
            this.wasmReady = false;
            throw error;
        }
    }

    async waitForWASM() {
        
        try {
            await this.initPromise;
            return this.wasmReady;
        } catch (error) {
            console.error('WASM initialization failed:', error);
            return false;
        }
    }

    async loadSID(arrayBuffer) {
        if (!await this.waitForWASM()) {
            throw new Error('WASM module not ready');
        }

        if (!this.Module) {
            throw new Error('WASM Module not available');
        }

        if (!this.Module.HEAPU8) {
            console.error('Available Module properties:', Object.keys(this.Module));
            throw new Error('WASM memory (HEAPU8) not available - module may not be properly initialized');
        }

        const data = new Uint8Array(arrayBuffer);
        let ptr = null;

        try {
            
            ptr = this.api.malloc(data.length);

            if (!ptr) {
                throw new Error('Failed to allocate memory in WASM heap');
            }

            this.Module.HEAPU8.set(data, ptr);

            const result = this.api.sid_load(ptr, data.length);

            if (result < 0) {
                const errors = {
                    '-1': 'File too small',
                    '-2': 'Invalid SID file format',
                    '-3': 'RSID format not supported',
                    '-4': 'Unsupported SID version',
                    '-5': 'Missing load address'
                };
                throw new Error(errors[result] || `Unknown error: ${result}`);
            }

            return {
                name: this.api.sid_get_header_string(0),
                author: this.api.sid_get_header_string(1),
                copyright: this.api.sid_get_header_string(2),
                format: this.api.sid_get_header_string(3),
                version: this.api.sid_get_header_value(0),
                loadAddress: this.api.sid_get_header_value(1),
                initAddress: this.api.sid_get_header_value(2),
                playAddress: this.api.sid_get_header_value(3),
                songs: this.api.sid_get_header_value(4),
                startSong: this.api.sid_get_header_value(5),
                flags: this.api.sid_get_header_value(6),
                fileSize: this.api.sid_get_header_value(7),
                clockType: this.api.sid_get_clock_type(),
                sidModel: this.api.sid_get_sid_model()
            };

        } catch (error) {
            console.error('Error in loadSID:', error);
            throw error;
        } finally {
            
            if (ptr !== null) {
                this.api.free(ptr);
            }
        }
    }

    async analyze(frameCount = 30000, progressCallback = null) {
        if (!await this.waitForWASM()) {
            throw new Error('WASM module not ready');
        }

        let callbackPtr = 0;
        let progressInterval = null;

        if (progressCallback) {
            
            let currentProgress = 0;
            const progressIncrement = 100 / (frameCount / 1000); 

            progressInterval = setInterval(() => {
                currentProgress = Math.min(currentProgress + progressIncrement, 99);
                progressCallback(Math.floor(currentProgress * frameCount / 100), frameCount);
            }, 50);
        }

        try {
            
            const result = this.api.sid_analyze(frameCount, callbackPtr);

            if (result < 0) {
                throw new Error(`Analysis failed: ${result}`);
            }

            const modifiedAddresses = [];
            const modifiedCount = this.api.sid_get_modified_count();
            for (let i = 0; i < modifiedCount; i++) {
                const addr = this.api.sid_get_modified_address(i);
                if (addr !== 0xFFFF) { 
                    modifiedAddresses.push(addr);
                }
            }

            const zpAddresses = [];
            const zpCount = this.api.sid_get_zp_count();
            for (let i = 0; i < zpCount; i++) {
                const addr = this.api.sid_get_zp_address(i);
                if (addr !== 0xFF) { 
                    zpAddresses.push(addr);
                }
            }

            const sidWrites = new Map();
            for (let reg = 0; reg < 0x20; reg++) {
                const count = this.api.sid_get_sid_writes(reg);
                if (count > 0) {
                    sidWrites.set(reg, count);
                }
            }

            if (progressCallback) {
                progressCallback(frameCount, frameCount);
            }

            const numCallsPerFrame = this.api.sid_get_num_calls_per_frame();
            const ciaTimerDetected = this.api.sid_get_cia_timer_detected() ? true : false;
            const ciaTimerValue = this.api.sid_get_cia_timer_value();

            return {
                modifiedAddresses,
                zpAddresses,
                sidWrites,
                codeBytes: this.api.sid_get_code_bytes(),
                dataBytes: this.api.sid_get_data_bytes(),
                numCallsPerFrame,
                ciaTimerDetected,
                ciaTimerValue
            };
        } finally {
            if (progressInterval) {
                clearInterval(progressInterval);
            }
        }
    }

    updateMetadata(field, value) {
        if (!this.wasmReady) {
            console.warn('WASM not ready, cannot update metadata');
            return false;
        }

        const fields = {
            'name': 0,
            'author': 1,
            'copyright': 2
        };

        if (field in fields) {
            this.api.sid_set_header_string(fields[field], value.substring(0, 31));
            return true;
        }

        return false;
    }

    createModifiedSID() {
        if (!this.wasmReady || !this.Module) {
            console.error('WASM not ready, cannot create modified SID');
            return null;
        }

        const sizePtr = this.api.malloc(4);

        try {
            
            const dataPtr = this.api.sid_create_modified(sizePtr);

            if (!dataPtr) {
                console.error('Failed to create modified SID - null pointer returned');
                return null;
            }

            const size = this.Module.HEAP32[sizePtr >> 2];

            if (size <= 0 || size > 65536) {
                console.error(`Invalid SID size: ${size}`);
                return null;
            }

            const data = new Uint8Array(size);
            data.set(this.Module.HEAPU8.subarray(dataPtr, dataPtr + size));

            this.api.free(dataPtr);

            return data;

        } catch (error) {
            console.error('Error creating modified SID:', error);
            return null;
        } finally {
            
            this.api.free(sizePtr);
        }
    }

    cleanup() {
        if (this.wasmReady && this.api) {
            this.api.sid_cleanup();
        }
    }
}

window.SIDAnalyzer = SIDAnalyzer;
```


### FILE: public/sidwinder.js
```js
var SIDwinderModule=(()=>{var _scriptName=typeof document!="undefined"?document.currentScript?.src:undefined;return async function(moduleArg={}){var moduleRtn;var Module=moduleArg;var ENVIRONMENT_IS_WEB=true;var ENVIRONMENT_IS_WORKER=false;var arguments_=[];var thisProgram="./this.program";var scriptDirectory="";function locateFile(path){if(Module["locateFile"]){return Module["locateFile"](path,scriptDirectory)}return scriptDirectory+path}var readAsync,readBinary;if(ENVIRONMENT_IS_WEB||ENVIRONMENT_IS_WORKER){try{scriptDirectory=new URL(".",_scriptName).href}catch{}{readAsync=async url=>{var response=await fetch(url,{credentials:"same-origin"});if(response.ok){return response.arrayBuffer()}throw new Error(response.status+" : "+response.url)}}}else{}var out=console.log.bind(console);var err=console.error.bind(console);var wasmBinary;var ABORT=false;var readyPromiseResolve,readyPromiseReject;var wasmMemory;var HEAP8,HEAPU8,HEAP16,HEAPU16,HEAP32,HEAPU32,HEAPF32,HEAPF64;var HEAP64,HEAPU64;var runtimeInitialized=false;function updateMemoryViews(){var b=wasmMemory.buffer;Module["HEAP8"]=HEAP8=new Int8Array(b);Module["HEAP16"]=HEAP16=new Int16Array(b);Module["HEAPU8"]=HEAPU8=new Uint8Array(b);Module["HEAPU16"]=HEAPU16=new Uint16Array(b);Module["HEAP32"]=HEAP32=new Int32Array(b);Module["HEAPU32"]=HEAPU32=new Uint32Array(b);Module["HEAPF32"]=HEAPF32=new Float32Array(b);Module["HEAPF64"]=HEAPF64=new Float64Array(b);HEAP64=new BigInt64Array(b);HEAPU64=new BigUint64Array(b)}function preRun(){if(Module["preRun"]){if(typeof Module["preRun"]=="function")Module["preRun"]=[Module["preRun"]];while(Module["preRun"].length){addOnPreRun(Module["preRun"].shift())}}callRuntimeCallbacks(onPreRuns)}function initRuntime(){runtimeInitialized=true;wasmExports["f"]()}function postRun(){if(Module["postRun"]){if(typeof Module["postRun"]=="function")Module["postRun"]=[Module["postRun"]];while(Module["postRun"].length){addOnPostRun(Module["postRun"].shift())}}callRuntimeCallbacks(onPostRuns)}var runDependencies=0;var dependenciesFulfilled=null;function addRunDependency(id){runDependencies++;Module["monitorRunDependencies"]?.(runDependencies)}function removeRunDependency(id){runDependencies--;Module["monitorRunDependencies"]?.(runDependencies);if(runDependencies==0){if(dependenciesFulfilled){var callback=dependenciesFulfilled;dependenciesFulfilled=null;callback()}}}function abort(what){Module["onAbort"]?.(what);what="Aborted("+what+")";err(what);ABORT=true;what+=". Build with -sASSERTIONS for more info.";var e=new WebAssembly.RuntimeError(what);readyPromiseReject?.(e);throw e}var wasmBinaryFile;function findWasmBinary(){return locateFile("sidwinder.wasm")}function getBinarySync(file){if(file==wasmBinaryFile&&wasmBinary){return new Uint8Array(wasmBinary)}if(readBinary){return readBinary(file)}throw"both async and sync fetching of the wasm failed"}async function getWasmBinary(binaryFile){if(!wasmBinary){try{var response=await readAsync(binaryFile);return new Uint8Array(response)}catch{}}return getBinarySync(binaryFile)}async function instantiateArrayBuffer(binaryFile,imports){try{var binary=await getWasmBinary(binaryFile);var instance=await WebAssembly.instantiate(binary,imports);return instance}catch(reason){err(`failed to asynchronously prepare wasm: ${reason}`);abort(reason)}}async function instantiateAsync(binary,binaryFile,imports){if(!binary){try{var response=fetch(binaryFile,{credentials:"same-origin"});var instantiationResult=await WebAssembly.instantiateStreaming(response,imports);return instantiationResult}catch(reason){err(`wasm streaming compile failed: ${reason}`);err("falling back to ArrayBuffer instantiation")}}return instantiateArrayBuffer(binaryFile,imports)}function getWasmImports(){return{a:wasmImports}}async function createWasm(){function receiveInstance(instance,module){wasmExports=instance.exports;wasmMemory=wasmExports["e"];updateMemoryViews();assignWasmExports(wasmExports);removeRunDependency("wasm-instantiate");return wasmExports}addRunDependency("wasm-instantiate");function receiveInstantiationResult(result){return receiveInstance(result["instance"])}var info=getWasmImports();if(Module["instantiateWasm"]){return new Promise((resolve,reject)=>{Module["instantiateWasm"](info,(mod,inst)=>{resolve(receiveInstance(mod,inst))})})}wasmBinaryFile??=findWasmBinary();var result=await instantiateAsync(wasmBinary,wasmBinaryFile,info);var exports=receiveInstantiationResult(result);return exports}class ExitStatus{name="ExitStatus";constructor(status){this.message=`Program terminated with exit(${status})`;this.status=status}}var callRuntimeCallbacks=callbacks=>{while(callbacks.length>0){callbacks.shift()(Module)}};var onPostRuns=[];var addOnPostRun=cb=>onPostRuns.push(cb);var onPreRuns=[];var addOnPreRun=cb=>onPreRuns.push(cb);function getValue(ptr,type="i8"){if(type.endsWith("*"))type="*";switch(type){case"i1":return HEAP8[ptr];case"i8":return HEAP8[ptr];case"i16":return HEAP16[ptr>>1];case"i32":return HEAP32[ptr>>2];case"i64":return HEAP64[ptr>>3];case"float":return HEAPF32[ptr>>2];case"double":return HEAPF64[ptr>>3];case"*":return HEAPU32[ptr>>2];default:abort(`invalid type for getValue: ${type}`)}}var noExitRuntime=true;function setValue(ptr,value,type="i8"){if(type.endsWith("*"))type="*";switch(type){case"i1":HEAP8[ptr]=value;break;case"i8":HEAP8[ptr]=value;break;case"i16":HEAP16[ptr>>1]=value;break;case"i32":HEAP32[ptr>>2]=value;break;case"i64":HEAP64[ptr>>3]=BigInt(value);break;case"float":HEAPF32[ptr>>2]=value;break;case"double":HEAPF64[ptr>>3]=value;break;case"*":HEAPU32[ptr>>2]=value;break;default:abort(`invalid type for setValue: ${type}`)}}var stackRestore=val=>__emscripten_stack_restore(val);var stackSave=()=>_emscripten_stack_get_current();class ExceptionInfo{constructor(excPtr){this.excPtr=excPtr;this.ptr=excPtr-24}set_type(type){HEAPU32[this.ptr+4>>2]=type}get_type(){return HEAPU32[this.ptr+4>>2]}set_destructor(destructor){HEAPU32[this.ptr+8>>2]=destructor}get_destructor(){return HEAPU32[this.ptr+8>>2]}set_caught(caught){caught=caught?1:0;HEAP8[this.ptr+12]=caught}get_caught(){return HEAP8[this.ptr+12]!=0}set_rethrown(rethrown){rethrown=rethrown?1:0;HEAP8[this.ptr+13]=rethrown}get_rethrown(){return HEAP8[this.ptr+13]!=0}init(type,destructor){this.set_adjusted_ptr(0);this.set_type(type);this.set_destructor(destructor)}set_adjusted_ptr(adjustedPtr){HEAPU32[this.ptr+16>>2]=adjustedPtr}get_adjusted_ptr(){return HEAPU32[this.ptr+16>>2]}}var exceptionLast=0;var uncaughtExceptionCount=0;var ___cxa_throw=(ptr,type,destructor)=>{var info=new ExceptionInfo(ptr);info.init(type,destructor);exceptionLast=ptr;uncaughtExceptionCount++;throw exceptionLast};var __abort_js=()=>abort("");var getHeapMax=()=>67108864;var alignMemory=(size,alignment)=>Math.ceil(size/alignment)*alignment;var growMemory=size=>{var oldHeapSize=wasmMemory.buffer.byteLength;var pages=(size-oldHeapSize+65535)/65536|0;try{wasmMemory.grow(pages);updateMemoryViews();return 1}catch(e){}};var _emscripten_resize_heap=requestedSize=>{var oldSize=HEAPU8.length;requestedSize>>>=0;var maxHeapSize=getHeapMax();if(requestedSize>maxHeapSize){return false}for(var cutDown=1;cutDown<=4;cutDown*=2){var overGrownHeapSize=oldSize*(1+.2/cutDown);overGrownHeapSize=Math.min(overGrownHeapSize,requestedSize+100663296);var newSize=Math.min(maxHeapSize,alignMemory(Math.max(requestedSize,overGrownHeapSize),65536));var replacement=growMemory(newSize);if(replacement){return true}}return false};var printCharBuffers=[null,[],[]];var UTF8Decoder=typeof TextDecoder!="undefined"?new TextDecoder:undefined;var findStringEnd=(heapOrArray,idx,maxBytesToRead,ignoreNul)=>{var maxIdx=idx+maxBytesToRead;if(ignoreNul)return maxIdx;while(heapOrArray[idx]&&!(idx>=maxIdx))++idx;return idx};var UTF8ArrayToString=(heapOrArray,idx=0,maxBytesToRead,ignoreNul)=>{var endPtr=findStringEnd(heapOrArray,idx,maxBytesToRead,ignoreNul);if(endPtr-idx>16&&heapOrArray.buffer&&UTF8Decoder){return UTF8Decoder.decode(heapOrArray.subarray(idx,endPtr))}var str="";while(idx<endPtr){var u0=heapOrArray[idx++];if(!(u0&128)){str+=String.fromCharCode(u0);continue}var u1=heapOrArray[idx++]&63;if((u0&224)==192){str+=String.fromCharCode((u0&31)<<6|u1);continue}var u2=heapOrArray[idx++]&63;if((u0&240)==224){u0=(u0&15)<<12|u1<<6|u2}else{u0=(u0&7)<<18|u1<<12|u2<<6|heapOrArray[idx++]&63}if(u0<65536){str+=String.fromCharCode(u0)}else{var ch=u0-65536;str+=String.fromCharCode(55296|ch>>10,56320|ch&1023)}}return str};var printChar=(stream,curr)=>{var buffer=printCharBuffers[stream];if(curr===0||curr===10){(stream===1?out:err)(UTF8ArrayToString(buffer));buffer.length=0}else{buffer.push(curr)}};var UTF8ToString=(ptr,maxBytesToRead,ignoreNul)=>ptr?UTF8ArrayToString(HEAPU8,ptr,maxBytesToRead,ignoreNul):"";var _fd_write=(fd,iov,iovcnt,pnum)=>{var num=0;for(var i=0;i<iovcnt;i++){var ptr=HEAPU32[iov>>2];var len=HEAPU32[iov+4>>2];iov+=8;for(var j=0;j<len;j++){printChar(fd,HEAPU8[ptr+j])}num+=len}HEAPU32[pnum>>2]=num;return 0};var getCFunc=ident=>{var func=Module["_"+ident];return func};var writeArrayToMemory=(array,buffer)=>{HEAP8.set(array,buffer)};var lengthBytesUTF8=str=>{var len=0;for(var i=0;i<str.length;++i){var c=str.charCodeAt(i);if(c<=127){len++}else if(c<=2047){len+=2}else if(c>=55296&&c<=57343){len+=4;++i}else{len+=3}}return len};var stringToUTF8Array=(str,heap,outIdx,maxBytesToWrite)=>{if(!(maxBytesToWrite>0))return 0;var startIdx=outIdx;var endIdx=outIdx+maxBytesToWrite-1;for(var i=0;i<str.length;++i){var u=str.codePointAt(i);if(u<=127){if(outIdx>=endIdx)break;heap[outIdx++]=u}else if(u<=2047){if(outIdx+1>=endIdx)break;heap[outIdx++]=192|u>>6;heap[outIdx++]=128|u&63}else if(u<=65535){if(outIdx+2>=endIdx)break;heap[outIdx++]=224|u>>12;heap[outIdx++]=128|u>>6&63;heap[outIdx++]=128|u&63}else{if(outIdx+3>=endIdx)break;heap[outIdx++]=240|u>>18;heap[outIdx++]=128|u>>12&63;heap[outIdx++]=128|u>>6&63;heap[outIdx++]=128|u&63;i++}}heap[outIdx]=0;return outIdx-startIdx};var stringToUTF8=(str,outPtr,maxBytesToWrite)=>stringToUTF8Array(str,HEAPU8,outPtr,maxBytesToWrite);var stackAlloc=sz=>__emscripten_stack_alloc(sz);var stringToUTF8OnStack=str=>{var size=lengthBytesUTF8(str)+1;var ret=stackAlloc(size);stringToUTF8(str,ret,size);return ret};var ccall=(ident,returnType,argTypes,args,opts)=>{var toC={string:str=>{var ret=0;if(str!==null&&str!==undefined&&str!==0){ret=stringToUTF8OnStack(str)}return ret},array:arr=>{var ret=stackAlloc(arr.length);writeArrayToMemory(arr,ret);return ret}};function convertReturnValue(ret){if(returnType==="string"){return UTF8ToString(ret)}if(returnType==="boolean")return Boolean(ret);return ret}var func=getCFunc(ident);var cArgs=[];var stack=0;if(args){for(var i=0;i<args.length;i++){var converter=toC[argTypes[i]];if(converter){if(stack===0)stack=stackSave();cArgs[i]=converter(args[i])}else{cArgs[i]=args[i]}}}var ret=func(...cArgs);function onDone(ret){if(stack!==0)stackRestore(stack);return convertReturnValue(ret)}ret=onDone(ret);return ret};var cwrap=(ident,returnType,argTypes,opts)=>{var numericArgs=!argTypes||argTypes.every(type=>type==="number"||type==="boolean");var numericRet=returnType!=="string";if(numericRet&&numericArgs&&!opts){return getCFunc(ident)}return(...args)=>ccall(ident,returnType,argTypes,args,opts)};{if(Module["noExitRuntime"])noExitRuntime=Module["noExitRuntime"];if(Module["print"])out=Module["print"];if(Module["printErr"])err=Module["printErr"];if(Module["wasmBinary"])wasmBinary=Module["wasmBinary"];if(Module["arguments"])arguments_=Module["arguments"];if(Module["thisProgram"])thisProgram=Module["thisProgram"]}Module["ccall"]=ccall;Module["cwrap"]=cwrap;Module["setValue"]=setValue;Module["getValue"]=getValue;var _cpu_init,_cpu_set_tracking,_cpu_load_memory,_cpu_read_memory,_cpu_write_memory,_cpu_step,_cpu_execute_function,_cpu_get_pc,_cpu_set_pc,_cpu_get_sp,_cpu_get_a,_cpu_get_x,_cpu_get_y,_cpu_get_cia_timer_lo,_cpu_get_cia_timer_hi,_cpu_get_cia_timer_written,_cpu_get_cycles,_cpu_get_memory_access,_cpu_get_sid_writes,_cpu_get_total_sid_writes,_cpu_get_zp_writes,_cpu_get_total_zp_writes,_cpu_set_record_writes,_cpu_get_write_sequence_length,_cpu_get_write_sequence_item,_cpu_analyze_memory,_cpu_get_last_write_pc,_allocate_memory,_malloc,_free_memory,_free,_cpu_set_accumulator,_cpu_set_xreg,_cpu_set_yreg,_cpu_save_memory,_cpu_restore_memory,_cpu_reset_state_only,_sid_init,_sid_load,_sid_analyze,_sid_get_header_string,_sid_get_header_value,_sid_set_header_string,_sid_create_modified,_sid_get_modified_count,_sid_get_modified_address,_sid_get_zp_count,_sid_get_zp_address,_sid_get_code_bytes,_sid_get_data_bytes,_sid_get_sid_writes,_sid_get_clock_type,_sid_get_sid_model,_sid_get_num_calls_per_frame,_sid_get_cia_timer_detected,_sid_get_cia_timer_value,_sid_cleanup,_png_converter_init,_png_converter_set_image,_png_converter_convert,_png_converter_create_c64_bitmap,_png_converter_get_background_color,_png_converter_get_map_data,_png_converter_get_scr_data,_png_converter_get_col_data,_png_converter_get_color_stats,_png_converter_set_palette,_png_converter_get_palette_count,_png_converter_get_palette_name,_png_converter_get_current_palette,_png_converter_get_palette_color,_png_converter_cleanup,__emscripten_stack_restore,__emscripten_stack_alloc,_emscripten_stack_get_current;function assignWasmExports(wasmExports){Module["_cpu_init"]=_cpu_init=wasmExports["g"];Module["_cpu_set_tracking"]=_cpu_set_tracking=wasmExports["h"];Module["_cpu_load_memory"]=_cpu_load_memory=wasmExports["i"];Module["_cpu_read_memory"]=_cpu_read_memory=wasmExports["j"];Module["_cpu_write_memory"]=_cpu_write_memory=wasmExports["k"];Module["_cpu_step"]=_cpu_step=wasmExports["l"];Module["_cpu_execute_function"]=_cpu_execute_function=wasmExports["m"];Module["_cpu_get_pc"]=_cpu_get_pc=wasmExports["n"];Module["_cpu_set_pc"]=_cpu_set_pc=wasmExports["o"];Module["_cpu_get_sp"]=_cpu_get_sp=wasmExports["p"];Module["_cpu_get_a"]=_cpu_get_a=wasmExports["q"];Module["_cpu_get_x"]=_cpu_get_x=wasmExports["r"];Module["_cpu_get_y"]=_cpu_get_y=wasmExports["s"];Module["_cpu_get_cia_timer_lo"]=_cpu_get_cia_timer_lo=wasmExports["t"];Module["_cpu_get_cia_timer_hi"]=_cpu_get_cia_timer_hi=wasmExports["u"];Module["_cpu_get_cia_timer_written"]=_cpu_get_cia_timer_written=wasmExports["v"];Module["_cpu_get_cycles"]=_cpu_get_cycles=wasmExports["w"];Module["_cpu_get_memory_access"]=_cpu_get_memory_access=wasmExports["x"];Module["_cpu_get_sid_writes"]=_cpu_get_sid_writes=wasmExports["y"];Module["_cpu_get_total_sid_writes"]=_cpu_get_total_sid_writes=wasmExports["z"];Module["_cpu_get_zp_writes"]=_cpu_get_zp_writes=wasmExports["A"];Module["_cpu_get_total_zp_writes"]=_cpu_get_total_zp_writes=wasmExports["B"];Module["_cpu_set_record_writes"]=_cpu_set_record_writes=wasmExports["C"];Module["_cpu_get_write_sequence_length"]=_cpu_get_write_sequence_length=wasmExports["D"];Module["_cpu_get_write_sequence_item"]=_cpu_get_write_sequence_item=wasmExports["E"];Module["_cpu_analyze_memory"]=_cpu_analyze_memory=wasmExports["F"];Module["_cpu_get_last_write_pc"]=_cpu_get_last_write_pc=wasmExports["G"];Module["_allocate_memory"]=_allocate_memory=wasmExports["H"];Module["_malloc"]=_malloc=wasmExports["I"];Module["_free_memory"]=_free_memory=wasmExports["J"];Module["_free"]=_free=wasmExports["K"];Module["_cpu_set_accumulator"]=_cpu_set_accumulator=wasmExports["L"];Module["_cpu_set_xreg"]=_cpu_set_xreg=wasmExports["M"];Module["_cpu_set_yreg"]=_cpu_set_yreg=wasmExports["N"];Module["_cpu_save_memory"]=_cpu_save_memory=wasmExports["O"];Module["_cpu_restore_memory"]=_cpu_restore_memory=wasmExports["P"];Module["_cpu_reset_state_only"]=_cpu_reset_state_only=wasmExports["Q"];Module["_sid_init"]=_sid_init=wasmExports["R"];Module["_sid_load"]=_sid_load=wasmExports["S"];Module["_sid_analyze"]=_sid_analyze=wasmExports["T"];Module["_sid_get_header_string"]=_sid_get_header_string=wasmExports["U"];Module["_sid_get_header_value"]=_sid_get_header_value=wasmExports["V"];Module["_sid_set_header_string"]=_sid_set_header_string=wasmExports["W"];Module["_sid_create_modified"]=_sid_create_modified=wasmExports["X"];Module["_sid_get_modified_count"]=_sid_get_modified_count=wasmExports["Y"];Module["_sid_get_modified_address"]=_sid_get_modified_address=wasmExports["Z"];Module["_sid_get_zp_count"]=_sid_get_zp_count=wasmExports["_"];Module["_sid_get_zp_address"]=_sid_get_zp_address=wasmExports["$"];Module["_sid_get_code_bytes"]=_sid_get_code_bytes=wasmExports["aa"];Module["_sid_get_data_bytes"]=_sid_get_data_bytes=wasmExports["ba"];Module["_sid_get_sid_writes"]=_sid_get_sid_writes=wasmExports["ca"];Module["_sid_get_clock_type"]=_sid_get_clock_type=wasmExports["da"];Module["_sid_get_sid_model"]=_sid_get_sid_model=wasmExports["ea"];Module["_sid_get_num_calls_per_frame"]=_sid_get_num_calls_per_frame=wasmExports["fa"];Module["_sid_get_cia_timer_detected"]=_sid_get_cia_timer_detected=wasmExports["ga"];Module["_sid_get_cia_timer_value"]=_sid_get_cia_timer_value=wasmExports["ha"];Module["_sid_cleanup"]=_sid_cleanup=wasmExports["ia"];Module["_png_converter_init"]=_png_converter_init=wasmExports["ja"];Module["_png_converter_set_image"]=_png_converter_set_image=wasmExports["ka"];Module["_png_converter_convert"]=_png_converter_convert=wasmExports["la"];Module["_png_converter_create_c64_bitmap"]=_png_converter_create_c64_bitmap=wasmExports["ma"];Module["_png_converter_get_background_color"]=_png_converter_get_background_color=wasmExports["na"];Module["_png_converter_get_map_data"]=_png_converter_get_map_data=wasmExports["oa"];Module["_png_converter_get_scr_data"]=_png_converter_get_scr_data=wasmExports["pa"];Module["_png_converter_get_col_data"]=_png_converter_get_col_data=wasmExports["qa"];Module["_png_converter_get_color_stats"]=_png_converter_get_color_stats=wasmExports["ra"];Module["_png_converter_set_palette"]=_png_converter_set_palette=wasmExports["sa"];Module["_png_converter_get_palette_count"]=_png_converter_get_palette_count=wasmExports["ta"];Module["_png_converter_get_palette_name"]=_png_converter_get_palette_name=wasmExports["ua"];Module["_png_converter_get_current_palette"]=_png_converter_get_current_palette=wasmExports["va"];Module["_png_converter_get_palette_color"]=_png_converter_get_palette_color=wasmExports["wa"];Module["_png_converter_cleanup"]=_png_converter_cleanup=wasmExports["xa"];__emscripten_stack_restore=wasmExports["ya"];__emscripten_stack_alloc=wasmExports["za"];_emscripten_stack_get_current=wasmExports["Aa"]}var wasmImports={b:___cxa_throw,c:__abort_js,d:_emscripten_resize_heap,a:_fd_write};var wasmExports=await createWasm();function run(){if(runDependencies>0){dependenciesFulfilled=run;return}preRun();if(runDependencies>0){dependenciesFulfilled=run;return}function doRun(){Module["calledRun"]=true;if(ABORT)return;initRuntime();readyPromiseResolve?.(Module);Module["onRuntimeInitialized"]?.();postRun()}if(Module["setStatus"]){Module["setStatus"]("Running...");setTimeout(()=>{setTimeout(()=>Module["setStatus"](""),1);doRun()},1)}else{doRun()}}function preInit(){if(Module["preInit"]){if(typeof Module["preInit"]=="function")Module["preInit"]=[Module["preInit"]];while(Module["preInit"].length>0){Module["preInit"].shift()()}}}preInit();run();if(runtimeInitialized){moduleRtn=Module}else{moduleRtn=new Promise((resolve,reject)=>{readyPromiseResolve=resolve;readyPromiseReject=reject})}
;return moduleRtn}})();if(typeof exports==="object"&&typeof module==="object"){module.exports=SIDwinderModule;module.exports.default=SIDwinderModule}else if(typeof define==="function"&&define["amd"])define([],()=>SIDwinderModule);
```


### FILE: public/text-drop-zone.js
```js
class TextDropZone {
    static create(textareaId, config = {}) {
        const textarea = document.getElementById(textareaId);
        if (!textarea) return;

        const wrapper = document.createElement('div');
        wrapper.className = 'text-drop-zone';
        textarea.parentNode.insertBefore(wrapper, textarea);
        wrapper.appendChild(textarea);

        const dropIndicator = document.createElement('div');
        dropIndicator.className = 'text-drop-indicator';
        dropIndicator.innerHTML = '<i class="fas fa-file-alt"></i> Drop text file here';
        wrapper.appendChild(dropIndicator);

        const dropHint = document.createElement('div');
        dropHint.className = 'text-drop-hint';
        dropHint.innerHTML = '<i class="fas fa-upload"></i> Drag & drop .txt file or type below';
        wrapper.insertBefore(dropHint, textarea);

        if (textareaId.toLowerCase().includes('scroll')) {
            textarea.rows = 6; 
        }

        this.attachDragDrop(wrapper, textarea);
    }

    static attachDragDrop(wrapper, textarea) {
        ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
            wrapper.addEventListener(eventName, (e) => {
                e.preventDefault();
                e.stopPropagation();
            });
        });

        ['dragenter', 'dragover'].forEach(eventName => {
            wrapper.addEventListener(eventName, () => {
                wrapper.classList.add('drag-active');
            });
        });

        ['dragleave', 'drop'].forEach(eventName => {
            wrapper.addEventListener(eventName, () => {
                wrapper.classList.remove('drag-active');
            });
        });

        wrapper.addEventListener('drop', async (e) => {
            const file = e.dataTransfer.files[0];
            if (file && (file.type.startsWith('text/') || file.name.endsWith('.txt'))) {
                const text = await file.text();
                textarea.value = text;
                textarea.dispatchEvent(new Event('change'));
            }
        });
    }
}

window.TextDropZone = TextDropZone;
```


### FILE: public/ui.js
```js
﻿

const C64_COLORS = [
    { value: 0, name: 'Black', hex: '#000000' },
    { value: 1, name: 'White', hex: '#FFFFFF' },
    { value: 2, name: 'Red', hex: '#753d3d' },
    { value: 3, name: 'Cyan', hex: '#7bb4b4' },
    { value: 4, name: 'Purple', hex: '#7d4488' },
    { value: 5, name: 'Green', hex: '#5c985c' },
    { value: 6, name: 'Blue', hex: '#343383' },
    { value: 7, name: 'Yellow', hex: '#cbcc7c' },
    { value: 8, name: 'Orange', hex: '#7c552f' },
    { value: 9, name: 'Brown', hex: '#523e00' },
    { value: 10, name: 'Light Red', hex: '#a76f6f' },
    { value: 11, name: 'Dark Grey', hex: '#4e4e4e' },
    { value: 12, name: 'Grey', hex: '#767676' },
    { value: 13, name: 'Light Green', hex: '#9fdb9f' },
    { value: 14, name: 'Light Blue', hex: '#6d6cbc' },
    { value: 15, name: 'Light Grey', hex: '#a3a3a3' }
];

class UIController {
    constructor() {
        this.analyzer = new SIDAnalyzer();
        this.currentFileName = null;
        this.hasModifications = false;
        this.analysisResults = null;
        this.prgExporter = null;
        this.sidHeader = null;
        this.originalMetadata = {}; 
        this.selectedVisualizer = null;
        this.visualizerConfig = null;
        this.hvscBrowserWindow = null;
        this.elements = this.cacheElements();
        this.initEventListeners();
    }

    cacheElements() {
        return {
            
            uploadSection: document.getElementById('uploadSection'),
            uploadBtn: document.getElementById('uploadBtn'),
            hvscBtn: document.getElementById('hvscBtn'),
            hvscSelected: document.getElementById('hvscSelected'),
            selectedFile: document.getElementById('selectedFile'),

            fileInput: document.getElementById('fileInput'),
            songTitleSection: document.getElementById('songTitleSection'),
            songTitle: document.getElementById('songTitle'),
            songAuthor: document.getElementById('songAuthor'),
            loading: document.getElementById('loading'),
            progressBar: document.getElementById('progressBar'),
            progressFill: document.getElementById('progressFill'),
            progressText: document.getElementById('progressText'),
            errorMessage: document.getElementById('errorMessage'),
            infoSection: document.getElementById('infoSection'),
            infoPanels: document.getElementById('infoPanels'),
            modalOverlay: document.getElementById('modalOverlay'),
            modalIcon: document.getElementById('modalIcon'),
            modalMessage: document.getElementById('modalMessage'),
            
            sidTitle: document.getElementById('sidTitle'),
            sidAuthor: document.getElementById('sidAuthor'),
            sidCopyright: document.getElementById('sidCopyright'),
            
            sidFormat: document.getElementById('sidFormat'),
            sidVersion: document.getElementById('sidVersion'),
            sidSongs: document.getElementById('sidSongs'),
            loadAddress: document.getElementById('loadAddress'),
            initAddress: document.getElementById('initAddress'),
            playAddress: document.getElementById('playAddress'),
            memoryRange: document.getElementById('memoryRange'),
            fileSize: document.getElementById('fileSize'),
            zpUsage: document.getElementById('zpUsage'),
            clockType: document.getElementById('clockType'),
            sidModel: document.getElementById('sidModel'),
            
            exportSection: document.getElementById('exportSection'),
            visualizerGrid: document.getElementById('visualizerGrid'),
            visualizerOptions: document.getElementById('visualizerOptions'),
            compressionType: document.getElementById('compressionType'),
            exportModifiedSIDButton: document.getElementById('exportModifiedSIDButton'),
            exportPRGButton: document.getElementById('exportPRGButton'),
            exportStatus: document.getElementById('exportStatus'),
            exportHint: document.getElementById('exportHint')
        };
    }

    initEventListeners() {
        
        this.elements.uploadBtn.addEventListener('click', () => {
            this.elements.fileInput.click();
        });

        this.elements.hvscBtn.addEventListener('click', () => {
            this.openHVSCBrowser();
        });

        this.elements.uploadSection.addEventListener('click', () => {
            this.elements.fileInput.click();
        });

        this.elements.fileInput.addEventListener('change', (e) => {
            this.handleFileSelect(e);
        });

        this.elements.exportModifiedSIDButton.addEventListener('click', () => {
            this.exportModifiedSID();
        });

        this.elements.exportPRGButton.addEventListener('click', () => {
            this.exportPRGWithVisualizer();
        });

        this.setupDragAndDrop();

        this.setupEditableFields();

        window.addEventListener('message', (e) => {
            if (e.data && e.data.type === 'sid-selected') {
                this.handleHVSCSelection(e.data);
            }
        });

        const closeBtn = document.getElementById('hvscModalClose');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => {
                document.getElementById('hvscModal').classList.remove('visible');
            });
        }

        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                const modal = document.getElementById('hvscModal');
                if (modal.classList.contains('visible')) {
                    modal.classList.remove('visible');
                }
            }
        });

        this.initializeAttractMode();
    }

    openHVSCBrowser() {
        const modal = document.getElementById('hvscModal');
        modal.classList.add('visible');

        if (typeof hvscBrowser.initializeHVSC === 'function') {
            hvscBrowser.initializeHVSC();
        } else if (!window.hvscBrowserInitialized) {
            hvscBrowser.fetchDirectory('C64Music');
            window.hvscBrowserInitialized = true;
        }
    }

    async handleHVSCSelection(data) {

        this.elements.hvscSelected.style.display = 'block';
        this.elements.selectedFile.textContent = data.name;

        const modal = document.getElementById('hvscModal');
        modal.classList.remove('visible');

        this.showLoading(true);
        this.showModal('Downloading SID from HVSC...', true);

        try {
            
            const response = await fetch(data.url);

            if (!response.ok) {
                throw new Error('Failed to download SID file');
            }

            const blob = await response.blob();
            const file = new File([blob], data.name, { type: 'application/octet-stream' });

            await this.processFile(file);

        } catch (error) {
            console.error('Error downloading HVSC file:', error);
            this.showModal('Failed to download SID from HVSC', false);
            this.showLoading(false);
        }
    }

    initializeAttractMode() {
        
        this.elements.sidTitle.querySelector('.text').textContent = 'Song Title';
        this.elements.sidAuthor.querySelector('.text').textContent = 'Artist Name';
        this.elements.sidCopyright.querySelector('.text').textContent = 'Copyright Info';

        this.elements.sidFormat.textContent = 'PSID';
        this.elements.sidVersion.textContent = 'v2';
        this.elements.sidSongs.textContent = '1/1';

        this.elements.loadAddress.textContent = '$1000';
        this.elements.initAddress.textContent = '$1000';
        this.elements.playAddress.textContent = '$1003';
        this.elements.memoryRange.textContent = '$1000 - $2FFF';
        this.elements.fileSize.textContent = '8192 bytes';
        this.elements.zpUsage.textContent = '$02-$FF';
        this.elements.clockType.textContent = 'PAL';
        this.elements.sidModel.textContent = 'MOS 6581';

        const numCallsElement = document.getElementById('numCallsPerFrame');
        if (numCallsElement) {
            numCallsElement.textContent = '1';
        }

        const modifiedMemoryElement = document.getElementById('modifiedMemoryCount');
        if (!modifiedMemoryElement) {
            
            const infoPanels = document.getElementById('infoPanels');
            const technicalPanel = infoPanels.querySelector('.panel:nth-child(2)');

            const modifiedRow = document.createElement('div');
            modifiedRow.id = 'modifiedMemoryRow';
            modifiedRow.className = 'info-row';
            modifiedRow.innerHTML = `
        <span class="info-label">Modified Memory:</span>
        <span class="info-value" id="modifiedMemoryCount">0 locations</span>
    `;

            const clockTypeRow = technicalPanel.querySelector('.info-row:nth-last-child(3)');
            if (clockTypeRow) {
                technicalPanel.insertBefore(modifiedRow, clockTypeRow);
            } else {
                technicalPanel.appendChild(modifiedRow);
            }
        } else {
            modifiedMemoryElement.textContent = '0 locations';
        }

        this.buildAttractModeVisualizerGrid();
    }

    buildAttractModeVisualizerGrid() {
        const grid = document.getElementById('visualizerGrid');
        if (!grid) return;

        grid.innerHTML = '';

        for (let i = 0; i < VISUALIZERS.length; i++) {
            const viz = VISUALIZERS[i];
            const card = this.createVisualizerCard(viz);
            card.classList.add('disabled');
            card.style.pointerEvents = 'none';

            if (i === 0) {
                card.classList.add('selected');
            }

            grid.appendChild(card);
        }
    }

    setupDragAndDrop() {
        const uploadSection = this.elements.uploadSection;

        uploadSection.addEventListener('dragover', (e) => {
            e.preventDefault();
            uploadSection.classList.add('dragover');
        });

        uploadSection.addEventListener('dragleave', () => {
            uploadSection.classList.remove('dragover');
        });

        uploadSection.addEventListener('drop', (e) => {
            e.preventDefault();
            uploadSection.classList.remove('dragover');
            const files = e.dataTransfer.files;
            if (files.length > 0) {
                this.processFile(files[0]);
            }
        });
    }

    setupEditableFields() {
        const editableFields = [this.elements.sidTitle, this.elements.sidAuthor, this.elements.sidCopyright];

        editableFields.forEach(field => {
            const textSpan = field.querySelector('.text');

            field.addEventListener('click', (e) => {
                if (!field.classList.contains('editing') && !field.classList.contains('disabled')) {
                    this.startEditing(field);
                }
            });

            field.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    this.stopEditing(field);
                } else if (e.key === 'Escape') {
                    e.preventDefault();
                    this.cancelEditing(field);
                }
            });

            textSpan.addEventListener('blur', () => {
                if (field.classList.contains('editing')) {
                    
                    setTimeout(() => {
                        if (field.classList.contains('editing')) {
                            this.stopEditing(field);
                        }
                    }, 200);
                }
            });

            textSpan.addEventListener('paste', (e) => {
                e.preventDefault();

                let text = '';
                if (e.clipboardData || e.originalEvent.clipboardData) {
                    text = (e.clipboardData || e.originalEvent.clipboardData).getData('text/plain');
                } else if (window.clipboardData) {
                    text = window.clipboardData.getData('Text');
                }

                text = text.replace(/[\r\n\t]/g, ' '); 
                text = text.replace(/\s+/g, ' '); 
                text = text.trim();

                if (window.getSelection) {
                    const selection = window.getSelection();
                    if (!selection.rangeCount) return;
                    selection.deleteFromDocument();
                    selection.getRangeAt(0).insertNode(document.createTextNode(text));

                    selection.collapseToEnd();
                }
            });
        });
    }

    startEditing(field) {
        field.classList.add('editing');

        const textSpan = field.querySelector('.text');
        textSpan.contentEditable = 'true';
        textSpan.focus();

        field.dataset.originalValue = textSpan.textContent;

        const range = document.createRange();
        range.selectNodeContents(textSpan);
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
    }

    stopEditing(field) {
        field.classList.remove('editing');

        const textSpan = field.querySelector('.text');
        textSpan.contentEditable = 'false';

        let text = textSpan.textContent || '';

        text = text.replace(/<[^>]*>/g, '');

        text = text.replace(/[\r\n\t]/g, ' ');
        text = text.replace(/\s+/g, ' ');
        text = text.trim();

        if (text.length > 31) {
            text = text.substring(0, 31);
        }

        textSpan.textContent = text;

        const fieldName = field.dataset.field;
        let analyzerFieldName = fieldName;
        if (fieldName === 'title') analyzerFieldName = 'name';

        this.analyzer.updateMetadata(analyzerFieldName, text);

        this.checkForModifications();
    }

    cancelEditing(field) {
        const textSpan = field.querySelector('.text');
        textSpan.textContent = field.dataset.originalValue || '';
        field.classList.remove('editing');
        textSpan.contentEditable = 'false';
    }

    checkForModifications() {
        
        const currentTitle = this.elements.sidTitle.querySelector('.text').textContent.trim();
        const currentAuthor = this.elements.sidAuthor.querySelector('.text').textContent.trim();
        const currentCopyright = this.elements.sidCopyright.querySelector('.text').textContent.trim();

        const hasChanges =
            currentTitle !== this.originalMetadata.title ||
            currentAuthor !== this.originalMetadata.author ||
            currentCopyright !== this.originalMetadata.copyright;

        this.hasModifications = hasChanges;

        this.elements.exportModifiedSIDButton.disabled = !hasChanges;

        if (this.elements.exportHint) {
            this.elements.exportHint.style.display = hasChanges ? 'none' : 'block';
        }
    }

    async handleFileSelect(event) {
        const file = event.target.files[0];
        if (file) {
            
            this.elements.hvscSelected.style.display = 'none';
            await this.processFile(file);
        }
    }

    async processFile(file) {
        if (!file.name.toLowerCase().endsWith('.sid')) {
            this.showModal('Please select a valid SID file', false);
            return;
        }

        this.currentFileName = file.name;
        this.hasModifications = false;
        this.elements.exportModifiedSIDButton.disabled = true;

        this.showLoading(true);
        this.hideMessages();

        try {
            
            const buffer = await file.arrayBuffer();

            const header = await this.analyzer.loadSID(buffer);
            this.sidHeader = header;
            this.analyzer.sidHeader = header;

            this.originalMetadata = {
                title: header.name || '',
                author: header.author || '',
                copyright: header.copyright || ''
            };

            this.updateFileInfo(header);
            this.updateTechnicalInfo(header);
            this.updateSongTitle(header);

            this.elements.progressBar.classList.add('active');

            const frameCount = 30000;
            let lastProgress = 0;

            this.analysisResults = await this.analyzer.analyze(frameCount, (current, total) => {
                const percent = Math.floor((current / total) * 100);
                if (percent !== lastProgress) {
                    lastProgress = percent;
                    this.elements.progressFill.style.width = percent + '%';
                    this.elements.progressText.textContent = `Analyzing: ${percent}%`;
                }
            });

            this.analyzer.analysisResults = this.analysisResults;

            this.updateZeroPageInfo(this.analysisResults.zpAddresses);
            this.updateModifiedMemoryCount();
            this.updateNumCallsPerFrame(this.analysisResults.numCallsPerFrame);

            this.elements.infoSection.classList.remove('disabled');
            this.elements.infoSection.classList.add('visible');
            this.elements.songTitleSection.classList.remove('disabled');
            this.elements.songTitleSection.classList.add('visible');

            this.showExportSection();

            this.showModal(`Successfully analyzed: ${file.name}`, true);
        } catch (error) {
            this.showModal(`Error: ${error.message}`, false);
            console.error(error);
        } finally {
            this.showLoading(false);
            this.elements.progressBar.classList.remove('active');
        }
    }

    showExportSection() {
        if (this.elements.exportSection) {
            
            this.elements.exportSection.classList.remove('disabled');
            this.elements.exportSection.classList.add('visible');

            const header = this.elements.exportSection.querySelector('h2');
            if (header && this.analysisResults) {
                const calls = this.analysisResults.numCallsPerFrame || 1;
                header.innerHTML = `🎮 Choose Your Visualizer <span style="font-size: 0.8em; color: #666;"></span>`;
            }

            this.addSongSelector();

            this.initVisualizerSelection();

            if (!this.prgExporter && this.analyzer) {
                
                if (typeof SIDwinderPRGExporter !== 'undefined') {
                    this.prgExporter = new SIDwinderPRGExporter(this.analyzer);
                    window.currentAnalyzer = this.analyzer;
                } else {
                    console.error('SIDwinderPRGExporter not loaded yet');
                    
                    setTimeout(() => {
                        if (typeof SIDwinderPRGExporter !== 'undefined' && !this.prgExporter) {
                            this.prgExporter = new SIDwinderPRGExporter(this.analyzer);
                            window.currentAnalyzer = this.analyzer;
                        }
                    }, 500);
                }
            }
        }
    }

    addSongSelector() {
        
        const existingSelector = document.getElementById('songSelectorContainer');
        if (existingSelector) {
            existingSelector.remove();
        }

        if (this.sidHeader && this.sidHeader.songs > 1) {
            const visualizerGrid = document.getElementById('visualizerGrid');
            const selectorContainer = document.createElement('div');
            selectorContainer.id = 'songSelectorContainer';
            selectorContainer.className = 'export-option song-selector-container';
            selectorContainer.innerHTML = `
            <label for="songSelector">Select Song:</label>
            <select id="songSelector">
                ${Array.from({ length: Math.min(this.sidHeader.songs, 256) }, (_, i) => i + 1)
                    .map(num => `<option value="${num}" ${num === this.sidHeader.startSong ? 'selected' : ''}>
                        Song ${num} of ${this.sidHeader.songs}${num === this.sidHeader.startSong ? ' (default)' : ''}
                    </option>`).join('')}
            </select>
        `;

            visualizerGrid.parentNode.insertBefore(selectorContainer, visualizerGrid);
        }
    }

    async initVisualizerSelection() {
        this.selectedVisualizer = null;
        this.visualizerConfig = new VisualizerConfig();
        await this.loadAllVisualizerConfigs();
        this.buildVisualizerGrid();
    }

    async loadAllVisualizerConfigs() {
        
        for (const viz of VISUALIZERS) {
            if (viz.config) {
                try {
                    const config = await this.visualizerConfig.loadConfig(viz.id);
                    if (config && config.maxCallsPerFrame !== undefined) {
                        viz.maxCallsPerFrame = config.maxCallsPerFrame;
                    }
                    
                    viz.configData = config; 
                } catch (error) {
                    console.warn(`Could not load config for ${viz.id}:`, error);
                }
            }
        }
    }

    buildVisualizerGrid() {
        const grid = document.getElementById('visualizerGrid');
        if (!grid) return;

        grid.innerHTML = '';

        const requiredCalls = this.analysisResults?.numCallsPerFrame || 1;

        const compatible = [];
        const incompatible = [];

        const modifiedAddresses = this.analysisResults?.modifiedAddresses || [];

        for (const viz of VISUALIZERS) {
            
            if (viz.configData) {
                const validLayouts = this.prgExporter.selectValidLayouts(
                    viz.configData,
                    this.sidHeader.loadAddress,
                    this.analysisResults?.dataBytes || 0x2000,
                    modifiedAddresses  
                );

                if (validLayouts.filter(l => l.valid).length === 0) {
                    incompatible.push(viz);
                } else {
                    compatible.push(viz);
                }
            } else {
                compatible.push(viz);
            }
        }

        compatible.sort((a, b) => a.name.localeCompare(b.name));
        incompatible.sort((a, b) => a.name.localeCompare(b.name));

        for (let i = 0; i < compatible.length; i++) {
            const viz = compatible[i];
            const card = this.createVisualizerCard(viz);
            grid.appendChild(card);

            if (i === 0) {
                this.selectVisualizer(viz);
                card.classList.add('selected');
            }
        }

        if (compatible.length > 0 && incompatible.length > 0) {
            const separator = document.createElement('div');
            separator.className = 'visualizer-separator';
            separator.innerHTML = '<span>Incompatible with this SID (requires fewer calls/frame)</span>';
            separator.style.cssText = `
            grid-column: 1 / -1;
            text-align: center;
            padding: 20px;
            color: #666;
            font-style: italic;
            border-top: 1px dashed #333;
            margin: 10px 0;
        `;
            grid.appendChild(separator);
        }

        for (const viz of incompatible) {
            const card = this.createVisualizerCard(viz);
            grid.appendChild(card);
        }
    }

    createVisualizerCard(visualizer) {
        const card = document.createElement('div');
        card.className = 'visualizer-card';
        card.dataset.id = visualizer.id;

        const requiredCalls = this.analysisResults?.numCallsPerFrame || 1;
        const maxCalls = visualizer.configData?.maxCallsPerFrame || Infinity;
        const isDisabled = requiredCalls > maxCalls;

        if (isDisabled) {
            card.classList.add('disabled');
        }

        const disabledMessage = isDisabled ?
            `Requires max ${maxCalls} call${maxCalls > 1 ? 's' : ''}/frame` : '';

        card.innerHTML = `
        <div class="visualizer-preview">
            <img src="${visualizer.preview}" alt="${visualizer.name}" 
                 onerror="this.src='previews/default.png'">
        </div>
        <div class="visualizer-info" ${isDisabled ? `data-reason="${disabledMessage}"` : ''}>
            <h3>${visualizer.name}</h3>
            <p>${visualizer.description}</p>
        </div>
        <div class="visualizer-selected-badge">✓ Selected</div>
    `;

        if (!isDisabled) {
            card.addEventListener('click', () => {
                this.selectVisualizer(visualizer);
            });
        }

        return card;
    }

    selectVisualizer(visualizer) {
        
        const cards = document.querySelectorAll('.visualizer-card');
        cards.forEach(card => {
            card.classList.toggle('selected', card.dataset.id === visualizer.id);
        });

        this.selectedVisualizer = visualizer;

        this.elements.exportPRGButton.disabled = false;

        this.loadVisualizerOptions(visualizer);
    }

    async loadVisualizerOptions(visualizer) {
        const optionsContainer = document.getElementById('visualizerOptions');
        optionsContainer.innerHTML = '';

        if (!visualizer.config) {
            optionsContainer.style.display = 'none';
            return;
        }

        const config = await this.visualizerConfig.loadConfig(visualizer.id);

        const hasLayouts = config?.layouts && Object.keys(config.layouts).length > 1;
        const hasInputs = config?.inputs && config.inputs.length > 0;
        const hasOptions = config?.options && config.options.length > 0;

        if (!hasLayouts && !hasInputs && !hasOptions) {
            
            optionsContainer.style.display = 'block';
            optionsContainer.className = 'visualizer-options-panel';
            optionsContainer.innerHTML = `
            <div class="options-header">
                <h3>📎 Export Configuration</h3>
            </div>
            <div class="options-content">
                ${this.createCompressionOptionsHTML()}
            </div>
        `;
            return;
        }

        optionsContainer.style.display = 'block';
        optionsContainer.className = 'visualizer-options-panel';

        let html = `
        <div class="options-header">
            <h3>📎 ${visualizer.name} Configuration</h3>
        </div>
        <div class="options-content">
    `;

        if (hasLayouts) {
            const layoutHTML = this.createLayoutSelectorHTML(visualizer, config);
            if (layoutHTML) {
                html += `
                <div class="option-group">
                    <div class="option-group-title">Memory Location</div>
                    ${layoutHTML}
                </div>
            `;
            }
        }

        if (hasInputs) {
            html += '<div class="option-group"><div class="option-group-title">Resources</div>';
            for (const input of config.inputs) {
                html += this.createFileInputHTML(input);
            }
            html += '</div>';
        }

        if (hasOptions) {
            html += '<div class="option-group"><div class="option-group-title">Settings</div>';
            for (const option of config.options) {
                html += this.createOptionHTML(option);
            }
            html += '</div>';
        }

        html += this.createCompressionOptionsHTML();

        html += '</div>'; 

        optionsContainer.innerHTML = html;

        this.attachOptionEventListeners(config);
    }

    createCompressionOptionsHTML() {
        return `
        <div class="option-group">
            <div class="option-group-title">Compression</div>
            <div class="compression-options">
                <label class="compression-radio-option">
                    <input type="radio" 
                           name="compression-type" 
                           value="none">
                    <div class="compression-details">
                        <span class="compression-name">None</span>
                        <span class="compression-desc">Uncompressed PRG</span>
                    </div>
                </label>
                <label class="compression-radio-option">
                    <input type="radio" 
                           name="compression-type" 
                           value="tscrunch"
                           checked>
                    <div class="compression-details">
                        <span class="compression-name">TSCrunch</span>
                        <span class="compression-desc">Best compression ratio</span>
                    </div>
                </label>
            </div>
        </div>
    `;
    }

    createLayoutSelectorHTML(visualizer, config) {
        const sidLoadAddress = this.sidHeader?.loadAddress || 0x1000;
        const sidSize = this.analysisResults?.dataBytes || 0x2000;
        const modifiedAddresses = this.analysisResults?.modifiedAddresses || 0;
        const modifiedCount = this.analysisResults?.modifiedAddresses?.length || 0;

        if (!this.prgExporter) {
            this.prgExporter = new SIDwinderPRGExporter(this.analyzer);
        }

        const layouts = this.prgExporter.selectValidLayouts(config, sidLoadAddress, sidSize, modifiedAddresses);

        layouts.sort((a, b) => a.vizStart - b.vizStart);

        const validLayouts = layouts.filter(l => l.valid);

        if (validLayouts.length === 0) {
            return '<div class="option-warning">⚠️ No compatible memory layouts available</div>';
        }

        let html = '<div class="layout-options">';

        let firstValidIndex = -1;
        layouts.forEach((layoutInfo, index) => {
            const layout = layoutInfo.layout;

            let rangeStart, rangeEnd;
            if (modifiedCount > 0 && layoutInfo.saveRestoreStart < layoutInfo.vizStart) {
                
                rangeStart = this.formatHex(layoutInfo.saveRestoreStart, 4);
                rangeEnd = this.formatHex(layoutInfo.vizEnd - 1, 4);
            } else if (modifiedCount > 0 && layoutInfo.saveRestoreEnd > layoutInfo.vizEnd) {
                
                rangeStart = this.formatHex(layoutInfo.vizStart, 4);
                rangeEnd = this.formatHex(layoutInfo.saveRestoreEnd - 1, 4);
            } else {
                
                rangeStart = this.formatHex(layoutInfo.vizStart, 4);
                rangeEnd = this.formatHex(layoutInfo.vizEnd - 1, 4);
            }

            const isValid = layoutInfo.valid;

            if (isValid && firstValidIndex === -1) {
                firstValidIndex = index;
            }

            const bankName = `bank${(layoutInfo.vizStart >> 12).toString(16).toUpperCase()}000`;

            html += `
        <label class="layout-radio-option ${!isValid ? 'disabled' : ''}" 
               ${!isValid ? `title="${layoutInfo.overlapReason}"` : ''}>
            <input type="radio" 
                   name="memory-layout" 
                   value="${layoutInfo.key}" 
                   ${isValid && index === firstValidIndex ? 'checked' : ''}
                   ${!isValid ? 'disabled' : ''}>
            <div class="layout-details">
                <span class="layout-name">${layout.name || bankName}</span>
                <span class="layout-range">${rangeStart}-${rangeEnd}</span>
            </div>
        </label>
    `;
        });

        html += '</div>';
        return html;
    }

    createFileInputHTML(config) {
        
        const isImageInput = config.accept && (
            config.accept.includes('image/') ||
            config.accept.includes('.png')
        );

        if (isImageInput) {
            
            return `
        <div class="option-row option-row-full">
            <label class="option-label">${config.label}</label>
            <div class="option-control">
                <div id="${config.id}-preview-container" class="image-input-container">
                    <!-- Preview will be inserted here -->
                </div>
            </div>
        </div>
    `;
        } else {
            
            return `
        <div class="option-row">
            <label class="option-label">${config.label}</label>
            <div class="option-control">
                <input type="file" 
                       id="${config.id}" 
                       accept="${config.accept}" 
                       style="display: none;">
                <button type="button" 
                        class="file-button" 
                        data-file-input="${config.id}">
                    Choose File
                </button>
                <span class="file-status" id="${config.id}-status">
                    ${config.default ? 'Using default' : 'No file selected'}
                </span>
            </div>
        </div>
    `;
        }
    }

    createOptionHTML(config) {
        let html = `<div class="option-row">`;

        if (config.type === 'number') {
            
            if (config.id && config.id.toLowerCase().includes('color') &&
                config.min === 0 && config.max === 15) {
                
                html += this.createColorSliderHTML(config);
            } else {
                
                html += `
                <label class="option-label">${config.label}</label>
                <div class="option-control">
                    <input type="number" 
                           id="${config.id}" 
                           class="number-input"
                           value="${config.default || 0}" 
                           min="${config.min || 0}" 
                           max="${config.max || 255}">
                    ${config.description ? `<span class="option-hint">${config.description}</span>` : ''}
                </div>
            `;
            }
        } else if (config.type === 'select') {
            html += `
            <label class="option-label">${config.label}</label>
            <div class="option-control">
                <select id="${config.id}" class="select-input">
                    ${config.values.map(v =>
                `<option value="${v.value}" ${v.value === config.default ? 'selected' : ''}>
                            ${v.label}
                        </option>`
            ).join('')}
                </select>
            </div>
        `;
        } else if (config.type === 'date') {
            html += `
            <label class="option-label">${config.label}</label>
            <div class="option-control">
                <input type="date" id="${config.id}" class="date-input">
                <span class="date-preview" id="${config.id}-preview">Not set</span>
            </div>
        `;
        } else if (config.type === 'textarea') {
            
            html += `
            <label class="option-label">${config.label}</label>
            <div class="option-control">
                <div class="textarea-container">
                    <textarea 
                        id="${config.id}" 
                        maxlength="${config.maxLength || 255}"
                        rows="3"
                        placeholder="${config.description || ''}"
                    >${config.default || ''}</textarea>
                    ${config.loadSave ? `
                        <div class="textarea-controls">
                            <button type="button" class="load-text-btn" data-target="${config.id}">Load</button>
                            <button type="button" class="save-text-btn" data-target="${config.id}">Save</button>
                        </div>
                    ` : ''}
                </div>
            </div>
        `;
        }

        html += '</div>';
        return html;
    }

    createColorSliderHTML(config) {
        const defaultValue = config.default || 0;
        const defaultColor = C64_COLORS[defaultValue];

        return `
        <label class="option-label">${config.label}</label>
        <div class="option-control color-slider-control">
            <div class="slider-wrapper">
                <input type="range" 
                       id="${config.id}" 
                       class="color-slider"
                       min="0" 
                       max="15" 
                       value="${defaultValue}"
                       data-config-id="${config.id}">
                <div class="color-slider-track">
                    ${C64_COLORS.map(c => `
                        <div class="color-segment" 
                             style="background: ${c.hex}"
                             data-value="${c.value}"
                             data-name="${c.name}"
                             title="${c.value}: ${c.name}">
                        </div>
                    `).join('')}
                </div>
            </div>
            <div class="color-value" id="${config.id}-display">
                <span class="color-swatch" style="background: ${defaultColor.hex}"></span>
                <span class="color-text">
                    <span class="color-number">${defaultValue}</span>: 
                    <span class="color-name">${defaultColor.name}</span>
                </span>
            </div>
        </div>
    `;
    }

    attachOptionEventListeners(config) {
        
        if (!window.imagePreviewManager) {
            window.imagePreviewManager = new ImagePreviewManager();
        }

        if (config && config.inputs) {
            config.inputs.forEach(inputConfig => {
                const isImageInput = inputConfig.accept && (inputConfig.accept.includes('image/') || inputConfig.accept.includes('.png'));
                if (isImageInput) {
                    const container = document.getElementById(`${inputConfig.id}-preview-container`);
                    if (container) {
                        const previewElement = window.imagePreviewManager.createImagePreview(inputConfig);
                        container.appendChild(previewElement);
                        window.imagePreviewManager.loadDefaultImage(inputConfig);
                    }
                }
            });
        }

        if (config && config.options) {
            config.options.forEach(optionConfig => {
                if (optionConfig.type === 'textarea') {
                    const textarea = document.getElementById(optionConfig.id);
                    if (!textarea) return;

                    TextDropZone.create(optionConfig.id);

                    if (!window.petsciiSanitizer) {
                        window.petsciiSanitizer = new PETSCIISanitizer();
                    }

                    if (!document.getElementById(`${optionConfig.id}-warnings`)) {
                        const warningDiv = document.createElement('div');
                        warningDiv.id = `${optionConfig.id}-warnings`;
                        warningDiv.className = 'textarea-warnings';
                        warningDiv.style.cssText = `
                        margin-top: 5px;
                        padding: 8px;
                        background: #fff3cd;
                        border: 1px solid #ffc107;
                        border-radius: 4px;
                        color: #856404;
                        font-size: 0.85em;
                        display: none;
                    `;
                        textarea.parentNode.appendChild(warningDiv);
                    }

                    if (optionConfig.maxLength) {
                        const counterDiv = document.createElement('div');
                        counterDiv.id = `${optionConfig.id}-counter`;
                        counterDiv.className = 'textarea-counter';
                        counterDiv.style.cssText = `
                        margin-top: 3px;
                        text-align: right;
                        color: #6c757d;
                        font-size: 0.85em;
                    `;
                        textarea.parentNode.appendChild(counterDiv);
                    }

                    const validateTextarea = () => {
                        const text = textarea.value;
                        const warningDiv = document.getElementById(`${optionConfig.id}-warnings`);
                        const counterDiv = document.getElementById(`${optionConfig.id}-counter`);

                        const result = window.petsciiSanitizer.sanitize(text, {
                            maxLength: optionConfig.maxLength,
                            preserveNewlines: false,
                            reportUnknown: true
                        });

                        if (counterDiv && optionConfig.maxLength) {
                            const remaining = optionConfig.maxLength - text.length;
                            counterDiv.textContent = `${text.length} / ${optionConfig.maxLength} characters`;

                            if (remaining < 0) {
                                counterDiv.style.color = '#dc3545';
                            } else if (remaining < 20) {
                                counterDiv.style.color = '#ffc107';
                            } else {
                                counterDiv.style.color = '#6c757d';
                            }
                        }

                        if (result.hasWarnings && warningDiv) {
                            let warningHTML = '<strong>⚠️ Character compatibility issues:</strong><br>';

                            result.warnings.forEach(warning => {
                                if (warning.type === 'unknown_characters') {
                                    warningHTML += `Found incompatible characters: `;
                                    warning.characters.forEach((char, idx) => {
                                        if (idx > 0) warningHTML += ', ';
                                        warningHTML += `"${char}"`;
                                    });
                                    warningHTML += '<br>These will be replaced with spaces on export.';
                                } else if (warning.type === 'truncated') {
                                    warningHTML += `Text will be truncated to ${optionConfig.maxLength} characters.`;
                                }
                            });

                            warningDiv.innerHTML = warningHTML;
                            warningDiv.style.display = 'block';
                        } else if (warningDiv) {
                            warningDiv.style.display = 'none';
                        }
                    };

                    textarea.addEventListener('input', validateTextarea);
                    textarea.addEventListener('paste', () => {
                        setTimeout(validateTextarea, 10); 
                    });

                    if (textarea.value) {
                        validateTextarea();
                    }
                }
            });
        }

        document.querySelectorAll('.file-button').forEach(button => {
            button.addEventListener('click', (e) => {
                const inputId = e.target.dataset.fileInput;
                document.getElementById(inputId).click();
            });
        });

        document.querySelectorAll('input[type="file"]:not([accept*="image"]):not([accept*=".png"])').forEach(input => {
            input.addEventListener('change', (e) => {
                const statusEl = document.getElementById(`${e.target.id}-status`);
                if (statusEl && e.target.files.length > 0) {
                    statusEl.textContent = e.target.files[0].name;
                    statusEl.classList.add('has-file');
                }
            });
        });

        document.querySelectorAll('input[type="date"]').forEach(input => {
            input.addEventListener('change', (e) => {
                const previewEl = document.getElementById(`${e.target.id}-preview`);
                if (previewEl) {
                    previewEl.textContent = this.formatDateForDisplay(e.target.value);
                }
            });
        });

        document.querySelectorAll('.color-slider').forEach(slider => {
            
            slider.addEventListener('input', (e) => {
                this.updateColorDisplay(e.target);
            });
        });

        document.querySelectorAll('.color-segment').forEach(segment => {
            segment.addEventListener('click', (e) => {
                e.stopPropagation(); 
                const value = parseInt(e.target.dataset.value);
                const slider = e.target.closest('.slider-wrapper').querySelector('.color-slider');
                if (slider) {
                    slider.value = value;
                    
                    const event = new Event('input', { bubbles: true });
                    slider.dispatchEvent(event);
                }
            });
        });

        document.querySelectorAll('.load-text-btn').forEach(button => {
            button.addEventListener('click', (e) => {
                this.loadScrollText(e.target.getAttribute('data-target'));
            });
        });

        document.querySelectorAll('.save-text-btn').forEach(button => {
            button.addEventListener('click', (e) => {
                this.saveScrollText(e.target.getAttribute('data-target'));
            });
        });
    }

    updateColorDisplay(slider) {
        const value = parseInt(slider.value);
        const color = C64_COLORS[value];
        const displayEl = document.getElementById(`${slider.id}-display`);

        if (displayEl) {
            displayEl.innerHTML = `
            <span class="color-swatch" style="background: ${color.hex}"></span>
            <span class="color-text">
                <span class="color-number">${value}</span>: 
                <span class="color-name">${color.name}</span>
            </span>
        `;
        }
    }

    updateFileInfo(header) {
        this.elements.sidTitle.querySelector('.text').textContent = header.name || 'Unknown';
        this.elements.sidAuthor.querySelector('.text').textContent = header.author || 'Unknown';
        this.elements.sidCopyright.querySelector('.text').textContent = header.copyright || 'Unknown';

        this.elements.sidFormat.textContent = header.format;
        this.elements.sidVersion.textContent = `v${header.version}`;
        this.elements.sidSongs.textContent = `${header.startSong}/${header.songs}`;
    }

    updateTechnicalInfo(header) {
        this.elements.loadAddress.textContent = this.formatHex(header.loadAddress, 4);
        this.elements.initAddress.textContent = this.formatHex(header.initAddress, 4);
        this.elements.playAddress.textContent = this.formatHex(header.playAddress, 4);

        const endAddr = header.loadAddress + header.fileSize - 1;
        this.elements.memoryRange.textContent =
            `${this.formatHex(header.loadAddress, 4)} - ${this.formatHex(endAddr, 4)}`;

        this.elements.fileSize.textContent = `${header.fileSize} bytes`;
        this.elements.clockType.textContent = header.clockType;
        this.elements.sidModel.textContent = header.sidModel;

        this.updateModifiedMemoryCount();
    }

    updateModifiedMemoryCount() {
        const allModified = this.analysisResults?.modifiedAddresses || [];

        const filtered = allModified.filter(addr => {
            if (addr >= 0x0100 && addr <= 0x01FF) return false; 
            if (addr >= 0xD400 && addr <= 0xD7FF) return false; 
            return true;
        });

        const modifiedCount = filtered.length;

        let modifiedRow = document.getElementById('modifiedMemoryRow');
        if (!modifiedRow) {
            
            const infoPanels = document.getElementById('infoPanels');
            const technicalPanel = infoPanels.querySelector('.panel:nth-child(2)'); 

            modifiedRow = document.createElement('div');
            modifiedRow.id = 'modifiedMemoryRow';
            modifiedRow.className = 'info-row';
            modifiedRow.innerHTML = `
            <span class="info-label">Modified Memory:</span>
            <span class="info-value" id="modifiedMemoryCount">-</span>
        `;

            const clockRow = technicalPanel.querySelector('#clockType').closest('.info-row');
            technicalPanel.insertBefore(modifiedRow, clockRow);
        }

        const countElement = document.getElementById('modifiedMemoryCount');
        if (modifiedCount === 0) {
            countElement.textContent = 'None';
        } else if (modifiedCount === 1) {
            countElement.textContent = '1 location';
        } else {
            countElement.textContent = `${modifiedCount} locations`;
        }
    }

    updateSongTitle(header) {
        this.elements.songTitle.textContent = header.name || 'Unknown Title';
        this.elements.songAuthor.textContent = header.author || 'Unknown Author';
    }

    updateZeroPageInfo(zpAddresses) {
        if (!zpAddresses || zpAddresses.length === 0) {
            this.elements.zpUsage.textContent = 'None';
            return;
        }

        const sorted = [...zpAddresses].sort((a, b) => a - b);

        const ranges = [];
        let currentRange = { start: sorted[0], end: sorted[0] };

        for (let i = 1; i < sorted.length; i++) {
            if (sorted[i] === currentRange.end + 1) {
                currentRange.end = sorted[i];
            } else {
                ranges.push(currentRange);
                currentRange = { start: sorted[i], end: sorted[i] };
            }
        }
        ranges.push(currentRange);

        const formatted = ranges.map(r => {
            if (r.start === r.end) {
                return this.formatHex(r.start, 2);
            } else {
                return `${this.formatHex(r.start, 2)}-${this.formatHex(r.end, 2)}`;
            }
        });

        this.elements.zpUsage.textContent = formatted.join(', ');
    }

    updateNumCallsPerFrame(numCalls) {
        const element = document.getElementById('numCallsPerFrame');
        if (element) {
            element.textContent = numCalls || '1';
        }
    }

    exportModifiedSID() {
        const modifiedData = this.analyzer.createModifiedSID();

        if (!modifiedData) {
            this.showExportStatus('Failed to create modified SID', 'error');
            return;
        }

        const baseName = this.currentFileName ?
            this.currentFileName.replace('.sid', '') : 'modified';

        this.downloadFile(modifiedData, `${baseName}_edited.sid`);
        this.showExportStatus('SID file exported successfully!', 'success');

        this.originalMetadata = {
            title: this.elements.sidTitle.querySelector('.text').textContent.trim(),
            author: this.elements.sidAuthor.querySelector('.text').textContent.trim(),
            copyright: this.elements.sidCopyright.querySelector('.text').textContent.trim()
        };

        this.hasModifications = false;
        this.elements.exportModifiedSIDButton.disabled = true;
        if (this.elements.exportHint) {
            this.elements.exportHint.style.display = 'block';
        }
    }

    async exportPRGWithVisualizer() {
        if (!this.selectedVisualizer) {
            this.showExportStatus('Please select a visualizer', 'error');
            return;
        }

        const layoutRadio = document.querySelector('input[name="memory-layout"]:checked');
        const selectedLayoutKey = layoutRadio ? layoutRadio.value : null;

        if (!selectedLayoutKey && this.selectedVisualizer.config) {
            
            this.showExportStatus('Please select a memory layout', 'error');
            return;
        }

        const compressionRadio = document.querySelector('input[name="compression-type"]:checked');
        const compressionType = compressionRadio ? compressionRadio.value : 'tscrunch';

        this.showExportStatus('Building PRG file...', 'info');

        const songSelector = document.getElementById('songSelector');
        const selectedSong = songSelector ? parseInt(songSelector.value) : this.sidHeader.startSong;

        try {
            const baseName = this.currentFileName ?
                this.currentFileName.replace('.sid', '') : 'output';

            const vizConfig = await this.visualizerConfig.loadConfig(this.selectedVisualizer.id);
            let visualizerSysAddress = 0x4100; 

            if (selectedLayoutKey && vizConfig && vizConfig.layouts[selectedLayoutKey]) {
                const layout = vizConfig.layouts[selectedLayoutKey];
                
                if (layout.sysAddress) {
                    visualizerSysAddress = parseInt(layout.sysAddress);
                } else if (layout.baseAddress) {
                    visualizerSysAddress = parseInt(layout.baseAddress) + 0x100;
                }
            }

            const options = {
                sidLoadAddress: this.sidHeader.loadAddress,
                sidInitAddress: this.sidHeader.initAddress,
                sidPlayAddress: this.sidHeader.playAddress,
                visualizerFile: this.selectedVisualizer.binary,
                visualizerLoadAddress: visualizerSysAddress,  
                compressionType: compressionType,
                visualizerId: this.selectedVisualizer.id,
                selectedSong: selectedSong - 1,
                layoutKey: selectedLayoutKey
            };

            const prgData = await this.prgExporter.createPRG(options);

            const isCompressed = compressionType !== 'none';
            let filename;

            if (isCompressed) {
                
                filename = `${baseName}.prg`;
            } else {
                
                filename = `${baseName}-sys${visualizerSysAddress}.prg`;
            }

            this.downloadFile(prgData, filename);

            const sizeKB = (prgData.length / 1024).toFixed(2);
            let statusMsg = `PRG exported successfully! Size: ${sizeKB}KB`;

            if (compressionType !== 'none') {
                statusMsg += ` (${compressionType.toUpperCase()} compressed)`;
            }

            this.showExportStatus(statusMsg, 'success');

        } catch (error) {
            console.error('Export error:', error);
            this.showExportStatus(`Export failed: ${error.message}`, 'error');
        }
    }

    downloadFile(data, filename) {
        const blob = new Blob([data], { type: 'application/octet-stream' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    showExportStatus(message, type) {
        const status = this.elements.exportStatus;
        if (status) {
            status.textContent = message;
            status.className = `export-status visible ${type}`;

            if (type !== 'info') {
                setTimeout(() => {
                    status.classList.remove('visible');
                }, 5000);
            }
        }
    }

    formatHex(value, digits) {
        return '$' + value.toString(16).toUpperCase().padStart(digits, '0');
    }

    formatDateForDisplay(dateString) {
        if (!dateString) return 'Not Set';

        const date = new Date(dateString);
        const months = ['January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'];

        const day = date.getDate();
        const month = months[date.getMonth()];
        const year = date.getFullYear();

        const suffix = this.getOrdinalSuffix(day);

        return `${day}${suffix} ${month} ${year}`;
    }

    getOrdinalSuffix(day) {
        if (day > 3 && day < 21) return 'th';
        switch (day % 10) {
            case 1: return 'st';
            case 2: return 'nd';
            case 3: return 'rd';
            default: return 'th';
        }
    }

    showLoading(show) {
        this.elements.loading.classList.toggle('active', show);
    }

    showModal(message, isSuccess) {
        this.elements.modalIcon.textContent = isSuccess ? '✓' : '✗';
        this.elements.modalIcon.className = isSuccess ? 'modal-icon success' : 'modal-icon error';
        this.elements.modalMessage.textContent = message;

        this.elements.modalOverlay.classList.add('visible');

        setTimeout(() => {
            this.elements.modalOverlay.classList.remove('visible');
        }, 2000);
    }

    hideMessages() {
        this.elements.errorMessage.classList.remove('visible');

        this.elements.songTitleSection.classList.remove('visible');
        this.elements.songTitleSection.classList.add('disabled');

        if (this.elements.exportSection) {
            this.elements.exportSection.classList.remove('visible');
            this.elements.exportSection.classList.add('disabled');
        }

        if (this.elements.infoSection) {
            this.elements.infoSection.classList.remove('visible');
            this.elements.infoSection.classList.add('disabled');
        }

        this.initializeAttractMode();
    }

    loadScrollText(textareaId) {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = '.txt';

        input.onchange = (e) => {
            const file = e.target.files[0];
            if (file) {
                const reader = new FileReader();
                reader.onload = (e) => {
                    const textarea = document.getElementById(textareaId);
                    if (textarea) {
                        textarea.value = e.target.result;
                    }
                };
                reader.readAsText(file);
            }
        };

        input.click();
    }

    saveScrollText(textareaId) {
        const textarea = document.getElementById(textareaId);
        if (!textarea) return;

        const text = textarea.value;
        const blob = new Blob([text], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);

        const a = document.createElement('a');
        a.href = url;
        a.download = 'scrolltext.txt';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    
    setTimeout(() => {
        
        if (typeof SIDAnalyzer === 'undefined') {
            console.error('SIDAnalyzer not loaded');
            alert('Error: Core components not loaded. Please refresh the page.');
            return;
        }

        if (typeof SIDwinderPRGExporter === 'undefined') {
            console.error('WARNING: SIDwinderPRGExporter not loaded yet');
            
            setTimeout(() => {
                if (typeof SIDwinderPRGExporter === 'undefined') {
                    console.error('ERROR: SIDwinderPRGExporter still not available after waiting');
                }
            }, 1000);
        }

        window.uiController = new UIController();
    }, 100);
});
```


### FILE: public/visualizer-configs.js
```js
class VisualizerConfig {
    constructor() {
        this.configs = new Map();
        this.galleryCache = new Map(); 
    }

    async loadConfig(visualizerId) {
        const visualizer = VISUALIZERS.find(v => v.id === visualizerId);
        if (!visualizer || !visualizer.config) {
            return null;
        }

        try {
            const response = await fetch(visualizer.config);
            if (!response.ok) {
                console.warn(`Could not load config for ${visualizerId}`);
                return null;
            }

            const config = await response.json();

            if (config.inputs) {
                for (const input of config.inputs) {
                    if (input.galleryFiles || input.gallery) {
                        input.gallery = await this.loadAndMergeGalleries(
                            input.galleryFiles || [],
                            input.gallery || []
                        );
                    }
                }
            }

            return config;
        } catch (error) {
            console.error(`Error loading config for ${visualizerId}:`, error);
            return null;
        }
    }

    async loadAndMergeGalleries(galleryFiles, inlineGallery) {
        const mergedGallery = [];
        const seenFiles = new Set();

        for (const galleryFile of galleryFiles) {
            try {
                const items = await this.loadGalleryFile(galleryFile);
                for (const item of items) {
                    if (!seenFiles.has(item.file)) {
                        mergedGallery.push(item);
                        seenFiles.add(item.file);
                    }
                }
            } catch (error) {
                console.warn(`Failed to load gallery file ${galleryFile}:`, error);
            }
        }

        for (const item of inlineGallery) {
            if (!seenFiles.has(item.file)) {
                mergedGallery.push(item);
                seenFiles.add(item.file);
            }
        }

        return mergedGallery;
    }

    async loadGalleryFile(galleryFile) {
        
        if (this.galleryCache.has(galleryFile)) {
            return this.galleryCache.get(galleryFile);
        }

        try {
            const response = await fetch(galleryFile);
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const items = await response.json();

            if (!Array.isArray(items)) {
                throw new Error('Gallery file must contain an array');
            }

            for (const item of items) {
                if (!item.name || !item.file) {
                    throw new Error('Gallery items must have "name" and "file" properties');
                }
            }

            this.galleryCache.set(galleryFile, items);
            return items;
        } catch (error) {
            console.error(`Error loading gallery file ${galleryFile}:`, error);
            return [];
        }
    }

    async loadDefaultFile(filename) {
        try {
            const response = await fetch(filename);
            if (!response.ok) {
                console.warn(`Could not load default file: ${filename}`);
                return null;
            }
            const arrayBuffer = await response.arrayBuffer();
            return new Uint8Array(arrayBuffer);
        } catch (error) {
            console.error(`Error loading default file ${filename}:`, error);
            return null;
        }
    }

    extractMemoryRegions(fileData, memoryConfig) {
        const regions = [];

        for (const region of memoryConfig) {
            const offset = parseInt(region.sourceOffset, 16);
            const size = parseInt(region.size, 16);
            const targetAddr = parseInt(region.targetAddress, 16);

            if (offset + size > fileData.length) {
                throw new Error(`Invalid region ${region.name}: exceeds file size`);
            }

            regions.push({
                name: region.name,
                data: fileData.slice(offset, offset + size),
                targetAddress: targetAddr,
                size: size
            });
        }

        return regions;
    }

    clearGalleryCache() {
        this.galleryCache.clear();
    }
}

window.VisualizerConfig = VisualizerConfig;
```


### FILE: public/visualizer-registry.js
```js
const VISUALIZERS = [
    {
        id: 'default',
        name: 'Default',
        description: 'Minimal player with textual information',
        preview: 'prg/default.png',
        config: 'prg/default.json'
    },
    {
        id: 'RaistlinBars',
        name: 'Raistlin Bars',
        description: 'Spectrometer bars',
        preview: 'prg/raistlinbars.png',
        config: 'prg/raistlinbars.json'
    },
    {
        id: 'RaistlinBarsWithLogo',
        name: 'Raistlin Bars With Logo',
        description: 'Spectrometer bars below an 80px tall logo',
        preview: 'prg/raistlinbarswithlogo.png',
        config: 'prg/raistlinbarswithlogo.json'
    },
    {
        id: 'RaistlinMirrorBars',
        name: 'Raistlin Mirror Bars',
        description: 'Spectrometer mirrored bars',
        preview: 'prg/raistlinmirrorbars.png',
        config: 'prg/raistlinmirrorbars.json'
    },
    {
        id: 'RaistlinMirrorBarsWithLogo',
        name: 'Raistlin Mirror Bars With Logo',
        description: 'Spectrometer mirrored bars below an 80px tall logo',
        preview: 'prg/raistlinmirrorbarswithlogo.png',
        config: 'prg/raistlinmirrorbarswithlogo.json'
    },
    {
        id: 'SimpleBitmap',
        name: 'Simple Bitmap',
        description: 'Full-screen bitmap',
        preview: 'prg/simplebitmap.png',
        config: 'prg/simplebitmap.json'
    },
    {
        id: 'SimpleBitmapWithScroller',
        name: 'Simple Bitmap With Scroller',
        description: 'Full-screen bitmap - with a scroller on top',
        preview: 'prg/simplebitmapwithscroller.png',
        config: 'prg/simplebitmapwithscroller.json'
    },
    {
        id: 'SimpleRaster',
        name: 'Simple Raster',
        description: 'Minimal rasterbar effect',
        preview: 'prg/simpleraster.png',
        config: 'prg/simpleraster.json'
    }
];

window.VISUALIZERS = VISUALIZERS;
```


### FILE: public/lib/browser-compat.js
```js
export const Buffer = {
    from: function(data) {
        if (data instanceof Uint8Array) return data;
        if (Array.isArray(data)) return new Uint8Array(data);
        if (typeof data === 'string') {
            const encoder = new TextEncoder();
            return encoder.encode(data);
        }
        return new Uint8Array(0);
    }
};

export const fs = {
    readFileSync: () => { throw new Error('fs not available in browser'); },
    writeFileSync: () => { throw new Error('fs not available in browser'); }
};
```


### FILE: public/lib/graph.js
```js
class PriorityQueue {
    constructor() {
        this.heap = [];
        this.size = 0;
    }
    
    enqueue(item, priority) {
        const node = { item, priority };
        this.heap[this.size] = node;
        this._heapifyUp(this.size);
        this.size++;
    }
    
    dequeue() {
        if (this.size === 0) return undefined;
        
        const min = this.heap[0];
        this.size--;
        
        if (this.size > 0) {
            this.heap[0] = this.heap[this.size];
            this._heapifyDown(0);
        }
        
        return min;
    }
    
    isEmpty() {
        return this.size === 0;
    }
    
    _heapifyUp(index) {
        if (index === 0) return;
        
        const parentIndex = Math.floor((index - 1) / 2);
        if (this.heap[index].priority < this.heap[parentIndex].priority) {
            [this.heap[index], this.heap[parentIndex]] = [this.heap[parentIndex], this.heap[index]];
            this._heapifyUp(parentIndex);
        }
    }
    
    _heapifyDown(index) {
        const leftChild = 2 * index + 1;
        const rightChild = 2 * index + 2;
        let smallest = index;
        
        if (leftChild < this.size && this.heap[leftChild].priority < this.heap[smallest].priority) {
            smallest = leftChild;
        }
        
        if (rightChild < this.size && this.heap[rightChild].priority < this.heap[smallest].priority) {
            smallest = rightChild;
        }
        
        if (smallest !== index) {
            [this.heap[index], this.heap[smallest]] = [this.heap[smallest], this.heap[index]];
            this._heapifyDown(smallest);
        }
    }
}

function dijkstra(graph, start) {
    const distances = {};
    const predecessors = {};
    const visited = new Set();
    const pq = new PriorityQueue();
    
    const allNodes = new Set();
    for (const node in graph) {
        allNodes.add(parseInt(node));
        for (const neighbor in graph[node]) {
            allNodes.add(parseInt(neighbor));
        }
    }
    
    for (const node of allNodes) {
        distances[node] = Infinity;
        predecessors[node] = -1;
    }
    distances[start] = 0;
    
    pq.enqueue(start, 0);
    
    while (!pq.isEmpty()) {
        const {item: current, priority: currentDistance} = pq.dequeue();
        
        if (visited.has(current)) continue;
        visited.add(current);
        
        if (currentDistance > distances[current]) continue;
        
        if (!graph[current]) continue;
        
        for (const neighbor in graph[current]) {
            const weight = graph[current][neighbor];
            const distance = distances[current] + weight;
            const neighborInt = parseInt(neighbor);
            
            if (distance < distances[neighborInt]) {
                distances[neighborInt] = distance;
                predecessors[neighborInt] = parseInt(current);
                pq.enqueue(neighborInt, distance);
            }
        }
    }
    
    return {distances, predecessors};
}

function getPath(predecessors, target) {
    const path = [];
    let current = target;
    
    while (predecessors[current] >= 0) {
        path.unshift([predecessors[current], current]);
        current = predecessors[current];
    }
    
    return path;
}

function buildDijkstraGraph(tokenGraph) {
    const dijkstraGraph = {};
    let tokenCount = 0;
    
    for (const [key, token] of Object.entries(tokenGraph)) {
        const [start, end] = key.split(',').map(n => parseInt(n));
        
        if (!dijkstraGraph[start]) {
            dijkstraGraph[start] = {};
        }
        dijkstraGraph[start][end] = token.getCost();
        tokenCount++;
    }
    
    return dijkstraGraph;
}

export {
    PriorityQueue,
    dijkstra,
    getPath,
    buildDijkstraGraph
};
```


### FILE: public/lib/index.js
```js
import {
    Token, ZERORUN, RLE, LZ, LZ2, LIT,
    findOptimalZero,
    LONGESTRLE, LONGESTLONGLZ, LONGESTLZ, LONGESTLITERAL,
    MINRLE, MINLZ, LZ2SIZE, TERMINATOR
} from './tokens.js';
import { dijkstra, getPath, buildDijkstraGraph } from './graph.js';
import { Decruncher, createSFX, boot, blankBoot, boot2 } from './sfx.js';

const Buffer = {
    from: function (data) {
        if (data instanceof Uint8Array) return data;
        if (Array.isArray(data)) return new Uint8Array(data);
        return new Uint8Array(0);
    }
};

function loadRaw(filename) {
    throw new Error('File operations not available in browser');
}

function saveRaw(filename, data) {
    throw new Error('File operations not available in browser');
}

class Cruncher {
    constructor(src = null) {
        this.crunched = [];
        this.tokenList = [];
        this.src = src;
        this.graph = {};
        this.crunchedSize = 0;
        this.optimalRun = LONGESTRLE;
    }
    
    ocrunch(options = {}) {
        const { inplace = false, verbose = false, sfxMode = false, progressCallback } = options;
        
        const progress = (description, current, total) => {
            if (progressCallback) {
                progressCallback(description, current, total);
            } else if (verbose) {
                const percentage = Math.floor(100 * current / total);
                const tchars = Math.floor(16 * current / total);
                const bar = '*'.repeat(tchars) + ' '.repeat(16 - tchars);
                process.stdout.write(`\r${description} [${bar}]${percentage.toString().padStart(2, '0')}%`);
            }
        };
        
        let src;
        let remainder = [];
        
        if (inplace) {
            remainder = Array.from(this.src.slice(-1));
            src = this.src.slice(0, -1);
        } else {
            src = this.src;
        }
        
        this.optimalRun = findOptimalZero(src);
        
        if (verbose || progressCallback) {
            progress("Populating LZ layer", 0, 1);
        }
        
        const tokenGraph = {};
        
        for (let i = 0; i < src.length; i++) {
            const rle = new RLE(src, i);
            let rlesize = Math.min(rle.size, LONGESTRLE);
            
            let lz;
            if (rlesize < LONGESTLONGLZ - 1) {
                lz = new LZ(src, i, null, null, Math.max(rlesize + 1, MINLZ));
            } else {
                lz = new LZ(src, i, 1);
            }
            
            while (lz.size >= MINLZ && lz.size > rlesize) {
                const key = `${i},${i + lz.size}`;
                if (!tokenGraph[key] || tokenGraph[key].getCost() > lz.getCost()) {
                    tokenGraph[key] = lz;
                }
                lz = new LZ(src, i, lz.size - 1, lz.offset);
            }
            
            if (rle.size > LONGESTRLE) {
                const rleToken = new RLE(src, i, LONGESTRLE);
                const key = `${i},${i + LONGESTRLE}`;
                if (!tokenGraph[key] || tokenGraph[key].getCost() > rleToken.getCost()) {
                    tokenGraph[key] = rleToken;
                }
            } else {
                for (let size = rle.size; size >= MINRLE; size--) {
                    const rleToken = new RLE(src, i, size);
                    const key = `${i},${i + size}`;
                    if (!tokenGraph[key] || tokenGraph[key].getCost() > rleToken.getCost()) {
                        tokenGraph[key] = rleToken;
                    }
                }
            }
            
            const lz2 = new LZ2(src, i);
            if (lz2.offset > 0) {
                const key = `${i},${i + LZ2SIZE}`;
                if (!tokenGraph[key] || tokenGraph[key].getCost() > lz2.getCost()) {
                    tokenGraph[key] = lz2;
                }
            }
            
            const zero = new ZERORUN(src, i, this.optimalRun);
            if (zero.size > 0) {
                const key = `${i},${i + this.optimalRun}`;
                if (!tokenGraph[key] || tokenGraph[key].getCost() > zero.getCost()) {
                    tokenGraph[key] = zero;
                }
            }
        }
        
        if (verbose || progressCallback) {
            progress("Populating LZ layer", 1, 1);
            if (verbose) process.stdout.write('\n');
        }
        
        if (verbose || progressCallback) {
            progress("Closing gaps", 0, 1);
        }
        
        for (let i = 0; i < src.length; i++) {
            for (let j = 1; j <= Math.min(LONGESTLITERAL, src.length - i); j++) {
                const key = `${i},${i + j}`;
                if (!tokenGraph[key]) {
                    const lit = new LIT(src, i);
                    lit.size = j;
                    tokenGraph[key] = lit;
                }
            }
        }
        
        if (verbose || progressCallback) {
            progress("Closing gaps", 1, 1);
            if (verbose) process.stdout.write('\n');
        }
        
        if (verbose || progressCallback) {
            progress("Populating graph", 0, 3);
        }
        
        const dijkstraGraph = buildDijkstraGraph(tokenGraph);
        
        if (verbose || progressCallback) {
            progress("Populating graph", 3, 3);
            if (verbose) process.stdout.write('\ncomputing shortest path\n');
        }
        
        const {distances, predecessors} = dijkstra(dijkstraGraph, 0);
        const path = getPath(predecessors, src.length);
        
        for (const [start, end] of path) {
            const key = `${start},${end}`;
            if (tokenGraph[key]) {
                this.tokenList.push(tokenGraph[key]);
            }
        }
        
        if (inplace) {
            
            for (const token of this.tokenList) {
                this.crunched = this.crunched.concat(token.getPayload());
            }
            this.crunched = this.crunched.concat([TERMINATOR]).concat(remainder.slice(1));
            
            const addr = [0, 0]; 
            this.crunched = addr.concat([this.optimalRun - 1]).concat(remainder.slice(0, 1)).concat(this.crunched);
        } else {
            
            if (!sfxMode) {
                
                this.crunched = this.crunched.concat([this.optimalRun - 1]);
            }
            for (const token of this.tokenList) {
                this.crunched = this.crunched.concat(token.getPayload());
            }
            this.crunched.push(TERMINATOR);
        }
        
        this.crunchedSize = this.crunched.length;
    }
}

export {
    
    Cruncher,
    Decruncher,
    
    Token,
    ZERORUN,
    RLE,
    LZ,
    LZ2,
    LIT,
    
    loadRaw,
    saveRaw,
    createSFX,
    
    boot,
    blankBoot,
    boot2,
    
        LONGESTRLE,
        LONGESTLONGLZ,
        LONGESTLZ,
        LONGESTLITERAL,
        MINRLE,
        MINLZ,
        TERMINATOR
};
```


### FILE: public/lib/sfx.js
```js
import { TERMINATOR, LZ2SIZE, RLEMASK, LZMASK, LITERALMASK, LZ2MASK } from './tokens.js';

const boot = [
    0x01, 0x08, 0x0B, 0x08, 0x0A, 0x00, 0x9E, 0x32, 0x30, 0x36, 0x31, 0x00,
    0x00, 0x00, 0x78, 0xA2, 0xCC, 0xBD, 0x1A, 0x08, 0x95, 0x00, 0xCA, 0xD0,
    0xF8, 0x4C, 0x02, 0x00, 0x34, 0xBD, 0x00, 0x10, 0x9D, 0x00, 0xFF, 0xE8,
    0xD0, 0xF7, 0xC6, 0x07, 0xA9, 0x06, 0xC7, 0x04, 0x90, 0xEF, 0xA0, 0x00,
    0xB3, 0x24, 0x30, 0x29, 0xC9, 0x20, 0xB0, 0x47, 0xE6, 0x24, 0xD0, 0x02,
    0xE6, 0x25, 0xB9, 0xFF, 0xFF, 0x99, 0xFF, 0xFF, 0xC8, 0xCA, 0xD0, 0xF6,
    0x98, 0xAA, 0xA0, 0x00, 0x65, 0x27, 0x85, 0x27, 0xB0, 0x74, 0x8A, 0x65,
    0x24, 0x85, 0x24, 0x90, 0xD7, 0xE6, 0x25, 0xB0, 0xD3, 0x4B, 0x7F, 0x90,
    0x39, 0xF0, 0x68, 0xA2, 0x02, 0x85, 0x59, 0xC8, 0xB1, 0x24, 0xA4, 0x59,
    0x91, 0x27, 0x88, 0x91, 0x27, 0xD0, 0xFB, 0xA9, 0x00, 0xB0, 0xD5, 0xA9,
    0x37, 0x85, 0x01, 0x58, 0x4C, 0x61, 0x00, 0xF0, 0xF6, 0x09, 0x80, 0x65,
    0x27, 0x85, 0xA0, 0xA5, 0x28, 0xE9, 0x00, 0x85, 0xA1, 0xB1, 0xA0, 0x91,
    0x27, 0xC8, 0xB1, 0xA0, 0x91, 0x27, 0x98, 0xAA, 0xD0, 0xB0, 0x4A, 0x85,
    0xA5, 0xC8, 0xA5, 0x27, 0x90, 0x31, 0xF1, 0x24, 0x85, 0xA0, 0xA5, 0x28,
    0xE9, 0x00, 0x85, 0xA1, 0xA2, 0x02, 0xA0, 0x00, 0xB1, 0xA0, 0x91, 0x27,
    0xC8, 0xB1, 0xA0, 0x91, 0x27, 0xC8, 0xB9, 0xA0, 0x00, 0x91, 0x27, 0xC0,
    0x00, 0xD0, 0xF6, 0x98, 0xB0, 0x84, 0xE6, 0x28, 0x18, 0x90, 0x87, 0xA0,
    0xFF, 0x84, 0x59, 0xA2, 0x01, 0xD0, 0x99, 0x71, 0x24, 0x85, 0xA0, 0xC8,
    0xB3, 0x24, 0x09, 0x80, 0x65, 0x28, 0x85, 0xA1, 0xE0, 0x80, 0x26, 0xA5,
    0xA2, 0x03, 0xD0, 0xC6
];

const blankBoot = [
    0x01, 0x08, 0x0B, 0x08, 0x0A, 0x00, 0x9E, 0x32, 0x30, 0x36, 0x31, 0x00,
    0x00, 0x00, 0x78, 0xA9, 0x0B, 0x8D, 0x11, 0xD0, 0xA2, 0xCC, 0xBD, 0x1F,
    0x08, 0x95, 0x00, 0xCA, 0xD0, 0xF8, 0x4C, 0x02, 0x00, 0x34, 0xBD, 0x00,
    0x10, 0x9D, 0x00, 0xFF, 0xE8, 0xD0, 0xF7, 0xC6, 0x07, 0xA9, 0x06, 0xC7,
    0x04, 0x90, 0xEF, 0xA0, 0x00, 0xB3, 0x24, 0x30, 0x29, 0xC9, 0x20, 0xB0,
    0x47, 0xE6, 0x24, 0xD0, 0x02, 0xE6, 0x25, 0xB9, 0xFF, 0xFF, 0x99, 0xFF,
    0xFF, 0xC8, 0xCA, 0xD0, 0xF6, 0x98, 0xAA, 0xA0, 0x00, 0x65, 0x27, 0x85,
    0x27, 0xB0, 0x74, 0x8A, 0x65, 0x24, 0x85, 0x24, 0x90, 0xD7, 0xE6, 0x25,
    0xB0, 0xD3, 0x4B, 0x7F, 0x90, 0x39, 0xF0, 0x68, 0xA2, 0x02, 0x85, 0x59,
    0xC8, 0xB1, 0x24, 0xA4, 0x59, 0x91, 0x27, 0x88, 0x91, 0x27, 0xD0, 0xFB,
    0xA9, 0x00, 0xB0, 0xD5, 0xA9, 0x37, 0x85, 0x01, 0x58, 0x4C, 0x61, 0x00,
    0xF0, 0xF6, 0x09, 0x80, 0x65, 0x27, 0x85, 0xA0, 0xA5, 0x28, 0xE9, 0x00,
    0x85, 0xA1, 0xB1, 0xA0, 0x91, 0x27, 0xC8, 0xB1, 0xA0, 0x91, 0x27, 0x98,
    0xAA, 0xD0, 0xB0, 0x4A, 0x85, 0xA5, 0xC8, 0xA5, 0x27, 0x90, 0x31, 0xF1,
    0x24, 0x85, 0xA0, 0xA5, 0x28, 0xE9, 0x00, 0x85, 0xA1, 0xA2, 0x02, 0xA0,
    0x00, 0xB1, 0xA0, 0x91, 0x27, 0xC8, 0xB1, 0xA0, 0x91, 0x27, 0xC8, 0xB9,
    0xA0, 0x00, 0x91, 0x27, 0xC0, 0x00, 0xD0, 0xF6, 0x98, 0xB0, 0x84, 0xE6,
    0x28, 0x18, 0x90, 0x87, 0xA0, 0xFF, 0x84, 0x59, 0xA2, 0x01, 0xD0, 0x99,
    0x71, 0x24, 0x85, 0xA0, 0xC8, 0xB3, 0x24, 0x09, 0x80, 0x65, 0x28, 0x85,
    0xA1, 0xE0, 0x80, 0x26, 0xA5, 0xA2, 0x03, 0xD0, 0xC6
];

const boot2 = [
    0x01, 0x08, 0x0B, 0x08, 0x0A, 0x00, 0x9E, 0x32, 0x30, 0x36, 0x31, 0x00,
    0x00, 0x00, 0x78, 0xA9, 0x34, 0x85, 0x01, 0xA2, 0xD0, 0xBD, 0x1F, 0x08,
    0x9D, 0xFB, 0x00, 0xCA, 0xD0, 0xF7, 0x4C, 0x00, 0x01, 0xAA, 0xAA, 0xAA,
    0xAA, 0xBD, 0x00, 0x10, 0x9D, 0x00, 0xFF, 0xE8, 0xD0, 0xF7, 0xCE, 0x05,
    0x01, 0xA9, 0x06, 0xCF, 0x02, 0x01, 0x90, 0xED, 0xA0, 0x00, 0xB3, 0xFC,
    0x30, 0x27, 0xC9, 0x20, 0xB0, 0x45, 0xE6, 0xFC, 0xD0, 0x02, 0xE6, 0xFD,
    0xB1, 0xFC, 0x91, 0xFE, 0xC8, 0xCA, 0xD0, 0xF8, 0x98, 0xAA, 0xA0, 0x00,
    0x65, 0xFE, 0x85, 0xFE, 0xB0, 0x74, 0x8A, 0x65, 0xFC, 0x85, 0xFC, 0x90,
    0xD9, 0xE6, 0xFD, 0xB0, 0xD5, 0x4B, 0x7F, 0x90, 0x39, 0xF0, 0x68, 0xA2,
    0x02, 0x85, 0xF9, 0xC8, 0xB1, 0xFC, 0xA4, 0xF9, 0x91, 0xFE, 0x88, 0x91,
    0xFE, 0xD0, 0xFB, 0xA5, 0xF9, 0xB0, 0xD5, 0xA9, 0x37, 0x85, 0x01, 0x58,
    0x4C, 0x5F, 0x01, 0xF0, 0xF6, 0x09, 0x80, 0x65, 0xFE, 0x85, 0xFA, 0xA5,
    0xFF, 0xE9, 0x00, 0x85, 0xFB, 0xB1, 0xFA, 0x91, 0xFE, 0xC8, 0xB1, 0xFA,
    0x91, 0xFE, 0x98, 0xAA, 0xD0, 0xB0, 0x4A, 0x8D, 0xA3, 0x01, 0xC8, 0xA5,
    0xFE, 0x90, 0x30, 0xF1, 0xFC, 0x85, 0xFA, 0xA5, 0xFF, 0xE9, 0x00, 0x85,
    0xFB, 0xA2, 0x02, 0xA0, 0x00, 0xB1, 0xFA, 0x91, 0xFE, 0xC8, 0xB1, 0xFA,
    0x91, 0xFE, 0xC8, 0xB1, 0xFA, 0x91, 0xFE, 0xC0, 0x00, 0xD0, 0xF7, 0x98,
    0xB0, 0x84, 0xE6, 0xFF, 0x18, 0x90, 0x87, 0xA0, 0xAA, 0x84, 0xF9, 0xA2,
    0x01, 0xD0, 0x99, 0x71, 0xFC, 0x85, 0xFA, 0xC8, 0xB3, 0xFC, 0x09, 0x80,
    0x65, 0xFF, 0x85, 0xFB, 0xE0, 0x80, 0x2E, 0xA3, 0x01, 0xA2, 0x03, 0xD0,
    0xC6
];

class Decruncher {
    constructor(src = null, reverseliteral = false) {
        this.src = src;
        this.decrunched = [];
        this.reverseliteral = reverseliteral;
        if (src) {
            this.decrunch();
        }
    }
    
    decrunch(src = null) {
        if (src !== null) {
            this.src = src;
        }
        if (!this.src) {
            this.decrunched = null;
            return;
        }
        
        this.decrunched = [];
        const optimalRun = this.src[0] + 1;
        let i = 1;
        
        while (this.src[i] !== TERMINATOR) {
            const code = this.src[i];
            
            if ((code & 0x80) === LITERALMASK && (code & 0x7f) < 32) {
                const run = code & 0x1f;
                const chunk = Array.from(this.src.slice(i + 1, i + run + 1));
                if (this.reverseliteral) {
                    chunk.reverse();
                }
                this.decrunched = this.decrunched.concat(chunk);
                i += run + 1;
            }
            
            else if ((code & 0x80) === LZ2MASK) {
                const run = LZ2SIZE;
                const offset = 127 - (code & 0x7f);
                const p = this.decrunched.length;
                for (let l = 0; l < run; l++) {
                    this.decrunched.push(this.decrunched[p - offset + l]);
                }
                i += 1;
            }
            
            else if ((code & 0x81) === RLEMASK && (code & 0x7e) !== 0) {
                const run = ((code & 0x7f) >> 1) + 1;
                const byte = this.src[i + 1];
                for (let l = 0; l < run; l++) {
                    this.decrunched.push(byte);
                }
                i += 2;
            }
            
            else if ((code & 0x81) === RLEMASK && (code & 0x7e) === 0) {
                const run = optimalRun;
                for (let l = 0; l < run; l++) {
                    this.decrunched.push(0);
                }
                i += 1;
            }
            
            else {
                let run, offset;
                if ((code & 2) === 2) {
                    
                    run = ((code & 0x7f) >> 2) + 1;
                    offset = this.src[i + 1];
                    i += 2;
                } else {
                    
                    const lookahead = this.src[i + 2];
                    run = 1 + (((code & 0x7f) >> 2) << 1) + ((lookahead & 128) === 128 ? 1 : 0);
                    offset = 32768 - (this.src[i + 1] + 256 * (lookahead & 0x7f));
                    i += 3;
                }
                const p = this.decrunched.length;
                for (let l = 0; l < run; l++) {
                    this.decrunched.push(this.decrunched[p - offset + l]);
                }
            }
        }
    }
}

function createSFX(compressedData, options) {
    const {
        jumpAddress,
        decrunchAddress,
        optimalRun,
        sfxMode = 0,
        blank = false
    } = options;
    
    let bootLoader;
    let gap = 0;
    
    if (sfxMode === 0) {
        bootLoader = blank ? [...blankBoot] : [...boot];
        if (blank) gap = 5;
        
        const fileLen = bootLoader.length + compressedData.length;
        const startAddress = 0x10000 - compressedData.length;
        const transfAddress = fileLen + 0x6ff;
        
        bootLoader[0x1e + gap] = transfAddress & 0xff;
        bootLoader[0x1f + gap] = transfAddress >> 8;
        
        bootLoader[0x3f + gap] = startAddress & 0xff;
        bootLoader[0x40 + gap] = startAddress >> 8;
        
        bootLoader[0x42 + gap] = decrunchAddress & 0xff;
        bootLoader[0x43 + gap] = decrunchAddress >> 8;
        
        bootLoader[0x7d + gap] = jumpAddress & 0xff;
        bootLoader[0x7e + gap] = jumpAddress >> 8;
        
        bootLoader[0xcc + gap] = optimalRun - 1;
    } else {
        bootLoader = [...boot2];
        const fileLen = bootLoader.length + compressedData.length;
        const startAddress = 0x10000 - compressedData.length;
        const transfAddress = fileLen + 0x6ff;
        
        bootLoader[0x26] = transfAddress & 0xff;
        bootLoader[0x27] = transfAddress >> 8;
        
        bootLoader[0x21] = startAddress & 0xff;
        bootLoader[0x22] = startAddress >> 8;
        
        bootLoader[0x23] = decrunchAddress & 0xff;
        bootLoader[0x24] = decrunchAddress >> 8;
        
        bootLoader[0x85] = jumpAddress & 0xff;
        bootLoader[0x86] = jumpAddress >> 8;
        
        bootLoader[0xd4] = optimalRun - 1;
    }
    
    return Buffer.from(bootLoader.concat(Array.from(compressedData)));
}

export {
    Decruncher,
    createSFX,
    boot,
    blankBoot,
    boot2
};
```


### FILE: public/lib/tokens.js
```js
const LONGESTRLE = 64;
const LONGESTLONGLZ = 64;
const LONGESTLZ = 32;
const LONGESTLITERAL = 31;
const MINRLE = 2;
const MINLZ = 3;
const LZOFFSET = 256;
const LONGLZOFFSET = 32767;
const LZ2OFFSET = 94;
const LZ2SIZE = 2;

const RLEMASK = 0x81;
const LZMASK = 0x80;
const LITERALMASK = 0x00;
const LZ2MASK = 0x00;

const TERMINATOR = LONGESTLITERAL + 1;

const ZERORUNID = 4;
const LZ2ID = 3;
const LZID = 2;
const RLEID = 1;
const LITERALID = 0;

class Token {
    constructor() {
        this.type = null;
    }
}

class ZERORUN extends Token {
    constructor(src, i, size = LONGESTRLE) {
        super();
        this.type = ZERORUNID;
        this.size = size;
        
        if (!(i + size < src.length && src.slice(i, i + size).every(b => b === 0))) {
            this.size = 0;
        }
    }
    
    getCost() {
        return 1;
    }
    
    getPayload() {
        return [RLEMASK];
    }
}

class RLE extends Token {
    constructor(src, i, size = null) {
        super();
        this.type = RLEID;
        this.rleByte = src[i];
        
        if (size === null) {
            let x = 0;
            while (i + x < src.length && x < LONGESTRLE + 1 && src[i + x] === src[i]) {
                x++;
            }
            this.size = x;
        } else {
            this.size = size;
        }
    }
    
    getCost() {
        return 2 + 0.00128 - 0.00001 * this.size;
    }
    
    getPayload() {
        return [RLEMASK | (((this.size - 1) << 1) & 0x7f), this.rleByte];
    }
}

class LZ extends Token {
    constructor(src, i, size = null, offset = null, minlz = MINLZ) {
        super();
        this.type = LZID;
        
        if (size === null) {
            let bestpos = i - 1;
            let bestlen = 0;
            
            if (src.length - i >= minlz) {
                const prefix = src.slice(i, i + minlz);
                const positions = findall(src, prefix, i, minlz);
                
                for (const j of positions) {
                    let l = minlz;
                    while (i + l < src.length && l < LONGESTLONGLZ && src[j + l] === src[i + l]) {
                        l++;
                    }
                    if ((l > bestlen && (i - j < LZOFFSET || i - bestpos >= LZOFFSET || l > LONGESTLZ)) || (l > bestlen + 1)) {
                        bestpos = j;
                        bestlen = l;
                    }
                }
            }
            
            this.size = bestlen;
            this.offset = i - bestpos;
        } else {
            this.size = size;
            if (offset !== null) {
                this.offset = offset;
            }
        }
    }
    
    getCost() {
        if (this.offset < LZOFFSET && this.size <= LONGESTLZ) {
            return 2 + 0.00134 - 0.00001 * this.size;
        } else {
            return 3 + 0.00138 - 0.00001 * this.size;
        }
    }
    
    getPayload() {
        if (this.offset >= LZOFFSET || this.size > LONGESTLZ) {
            const negoffset = (0 - this.offset);
            return [
                LZMASK | ((((this.size - 1) >> 1) << 2) & 0x7f) | 0,
                (negoffset & 0xff),
                ((negoffset >> 8) & 0x7f) | (((this.size - 1) & 1) << 7)
            ];
        } else {
            return [
                LZMASK | (((this.size - 1) << 2) & 0x7f) | 2,
                (this.offset & 0xff)
            ];
        }
    }
}

class LZ2 extends Token {
    constructor(src, i, offset = null) {
        super();
        this.type = LZ2ID;
        this.size = 2;
        
        if (offset === null) {
            if (i + 2 < src.length) {
                const pattern = src.slice(i, i + LZ2SIZE);
                const searchStart = Math.max(0, i - LZ2OFFSET);
                const searchEnd = i + 1;
                
                let o = -1;
                for (let pos = searchEnd - LZ2SIZE; pos >= searchStart; pos--) {
                    let match = true;
                    for (let j = 0; j < LZ2SIZE; j++) {
                        if (src[pos + j] !== pattern[j]) {
                            match = false;
                            break;
                        }
                    }
                    if (match) {
                        o = pos;
                        break;
                    }
                }
                
                this.offset = o >= 0 ? i - o : -1;
            } else {
                this.offset = -1;
            }
        } else {
            this.offset = offset;
        }
    }
    
    getCost() {
        return 1 + 0.00132 - 0.00001 * this.size;
    }
    
    getPayload() {
        return [LZ2MASK | (127 - this.offset)];
    }
}

class LIT extends Token {
    constructor(src, i) {
        super();
        this.type = LITERALID;
        this.size = 1;
        this.start = i;
        this.src = src;
    }
    
    getCost() {
        return this.size + 1 + 0.00130 - 0.00001 * this.size;
    }
    
    getPayload() {
        return [LITERALMASK | this.size].concat(Array.from(this.src.slice(this.start, this.start + this.size)));
    }
}

function findall(data, prefix, i, minlz = MINLZ) {
    const results = [];
    const x0 = Math.max(0, i - LONGLZOFFSET);
    let x1 = Math.min(i + minlz - 1, data.length);
    
    while (true) {
        let f = -1;
        
        for (let pos = x1 - prefix.length; pos >= x0; pos--) {
            let match = true;
            for (let j = 0; j < prefix.length; j++) {
                if (pos + j >= data.length || data[pos + j] !== prefix[j]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                f = pos;
                break;
            }
        }
        
        if (f >= 0) {
            results.push(f);
            x1 = f + minlz - 1;
        } else {
            break;
        }
    }
    
    return results;
}

function findOptimalZero(src) {
    const zeroruns = {};
    let i = 0;
    
    while (i < src.length - 1) {
        if (src[i] === 0) {
            let j = i + 1;
            while (j < src.length && src[j] === 0 && j - i < 256) {
                j++;
            }
            if (j - i >= MINRLE) {
                const len = j - i;
                zeroruns[len] = (zeroruns[len] || 0) + 1;
            }
            i = j;
        } else {
            i++;
        }
    }
    
    if (Object.keys(zeroruns).length > 0) {
        const items = Object.entries(zeroruns).map(([k, v]) => [parseInt(k), v]);
        return items.reduce((best, [k, v]) => {
            const score = -k * Math.pow(v, 1.1);
            return score < best.score ? {len: k, score} : best;
        }, {len: LONGESTRLE, score: 0}).len;
    } else {
        return LONGESTRLE;
    }
}

export {
    
    Token,
    ZERORUN,
    RLE,
    LZ,
    LZ2,
    LIT,
    
    findall,
    findOptimalZero,
    
    LONGESTRLE,
    LONGESTLONGLZ,
    LONGESTLZ,
    LONGESTLITERAL,
    MINRLE,
    MINLZ,
    LZOFFSET,
    LONGLZOFFSET,
    LZ2OFFSET,
    LZ2SIZE,
    RLEMASK,
    LZMASK,
    LITERALMASK,
    LZ2MASK,
    TERMINATOR,
    ZERORUNID,
    LZ2ID,
    LZID,
    RLEID,
    LITERALID
};
```
