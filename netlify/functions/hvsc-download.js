exports.handler = async (event, context) => {
    // Log everything to debug
    console.log('Full event object:', JSON.stringify(event, null, 2));

    const path = event.queryStringParameters?.path || '';
    console.log('Extracted path:', path);

    if (!path) {
        return {
            statusCode: 400,
            body: JSON.stringify({ error: 'No path provided' })
        };
    }

    // Check if this is a SID file request
    if (path.endsWith('.sid')) {
        // For SID files, fetch directly without query parameter
        const directUrl = `https://hvsc.etv.cx/${path}`;
        console.log('Direct fetching SID from:', directUrl);

        try {
            const response = await fetch(directUrl);

            if (!response.ok) {
                console.log('Failed to fetch SID, status:', response.status);
                throw new Error(`HTTP ${response.status}`);
            }

            const buffer = await response.arrayBuffer();
            console.log('SID file size:', buffer.byteLength);

            // Check if it's actually a SID file (should start with PSID or RSID)
            const view = new Uint8Array(buffer);
            const magic = String.fromCharCode(view[0], view[1], view[2], view[3]);
            console.log('File magic:', magic);

            if (magic !== 'PSID' && magic !== 'RSID') {
                console.log('Not a valid SID file, got HTML page instead?');
                // Try to log some of the content
                const text = new TextDecoder().decode(view.slice(0, 200));
                console.log('First 200 chars:', text);
            }

            return {
                statusCode: 200,
                headers: {
                    'Content-Type': 'application/octet-stream',
                    'Access-Control-Allow-Origin': '*',
                },
                body: Buffer.from(buffer).toString('base64'),
                isBase64Encoded: true
            };
        } catch (error) {
            console.error('Error fetching SID:', error);
            return {
                statusCode: 500,
                body: JSON.stringify({ error: 'Failed to fetch SID file' })
            };
        }
    } else {
        // Directory browsing code...
        const hvscUrl = `https://hvsc.etv.cx/?path=${path}`;
        console.log('Fetching directory from:', hvscUrl);

        try {
            const response = await fetch(hvscUrl);
            const body = await response.text();

            return {
                statusCode: 200,
                headers: {
                    'Content-Type': 'text/html; charset=utf-8',
                    'Access-Control-Allow-Origin': '*',
                },
                body: body
            };
        } catch (error) {
            console.error('Error fetching from HVSC:', error);
            return {
                statusCode: 500,
                body: JSON.stringify({ error: 'Failed to fetch from HVSC' })
            };
        }
    }
}