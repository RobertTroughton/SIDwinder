exports.handler = async (event, context) => {
    // Get the path from query parameters
    const path = event.queryStringParameters?.path || '';

    console.log('HVSC Function called');
    console.log('Query params:', JSON.stringify(event.queryStringParameters));
    console.log('Path:', path);

    if (!path) {
        // Return the HVSC homepage
        const hvscUrl = 'https://hvsc.etv.cx/';
        console.log('Fetching homepage:', hvscUrl);

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
            console.error('Error fetching homepage:', error);
            return {
                statusCode: 500,
                body: JSON.stringify({ error: 'Failed to fetch from HVSC' })
            };
        }
    }

    // Check if this is a SID file request
    if (path.endsWith('.sid')) {
        // For SID files, fetch directly (no query parameter)
        const directUrl = `https://hvsc.etv.cx/${path}`;
        console.log('Fetching SID file from:', directUrl);

        try {
            const response = await fetch(directUrl);

            if (!response.ok) {
                console.log('Failed to fetch SID, status:', response.status);
                throw new Error(`HTTP ${response.status}`);
            }

            const buffer = await response.arrayBuffer();
            console.log('SID file size:', buffer.byteLength);

            // Verify it's actually a SID file
            const view = new Uint8Array(buffer);
            const magic = String.fromCharCode(view[0], view[1], view[2], view[3]);
            console.log('File magic:', magic);

            if (magic !== 'PSID' && magic !== 'RSID') {
                console.error('Not a valid SID file!');
                // Log first part of response to debug
                const text = new TextDecoder().decode(view.slice(0, 500));
                console.log('Received content (first 500 bytes):', text);

                // Return error
                return {
                    statusCode: 500,
                    body: JSON.stringify({
                        error: 'Invalid SID file - server returned HTML instead of binary data'
                    })
                };
            }

            // Return the SID file as base64
            return {
                statusCode: 200,
                headers: {
                    'Content-Type': 'application/octet-stream',
                    'Content-Disposition': `attachment; filename="${path.split('/').pop()}"`,
                    'Access-Control-Allow-Origin': '*',
                },
                body: Buffer.from(buffer).toString('base64'),
                isBase64Encoded: true
            };
        } catch (error) {
            console.error('Error fetching SID:', error);
            return {
                statusCode: 500,
                body: JSON.stringify({ error: `Failed to fetch SID file: ${error.message}` })
            };
        }
    } else {
        // For directories, use the query parameter format
        const hvscUrl = `https://hvsc.etv.cx/?path=${path}`;
        console.log('Fetching directory from:', hvscUrl);

        try {
            const response = await fetch(hvscUrl);
            const body = await response.text();

            console.log('Response status:', response.status);
            console.log('Response length:', body.length);

            // Check if response contains expected content
            if (path && !body.includes('?path=')) {
                console.log('Warning: Response might not be a directory listing');
            }

            return {
                statusCode: 200,
                headers: {
                    'Content-Type': 'text/html; charset=utf-8',
                    'Access-Control-Allow-Origin': '*',
                },
                body: body
            };
        } catch (error) {
            console.error('Error fetching directory:', error);
            return {
                statusCode: 500,
                body: JSON.stringify({ error: `Failed to fetch directory: ${error.message}` })
            };
        }
    }
}