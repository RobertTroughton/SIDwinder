exports.handler = async (event, context) => {
    // Get the path from query parameters
    const path = event.queryStringParameters?.path || '';

    if (!path) {
        // Return the HVSC homepage
        const hvscUrl = 'https://hvsc.etv.cx/';

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

        try {
            const response = await fetch(directUrl);

            if (!response.ok) {
                console.error('Failed to fetch SID, status:', response.status);
                throw new Error(`HTTP ${response.status}`);
            }

            const buffer = await response.arrayBuffer();

            // Verify it's actually a SID file
            const view = new Uint8Array(buffer);
            const magic = String.fromCharCode(view[0], view[1], view[2], view[3]);

            if (magic !== 'PSID' && magic !== 'RSID') {
                console.error('Not a valid SID file!');
                // Log first part of response to debug
                const text = new TextDecoder().decode(view.slice(0, 500));

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
            console.error('Error fetching directory:', error);
            return {
                statusCode: 500,
                body: JSON.stringify({ error: `Failed to fetch directory: ${error.message}` })
            };
        }
    }
}