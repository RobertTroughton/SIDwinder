/**
 * Netlify function that proxies requests to hvsc.etv.cx.
 *
 * The browser cannot fetch from hvsc.etv.cx directly due to CORS, so this
 * function forwards three kinds of request:
 *   - no path           -> the HVSC homepage HTML
 *   - path ending .sid  -> the binary SID file (returned base64-encoded)
 *   - any other path    -> the directory listing HTML for that path
 */
exports.handler = async (event, context) => {
    const path = event.queryStringParameters?.path || '';

    if (!path) {
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

    if (path.endsWith('.sid')) {
        // SID files are served at the bare path, not via the ?path= listing endpoint.
        const directUrl = `https://hvsc.etv.cx/${path}`;

        try {
            const response = await fetch(directUrl);

            if (!response.ok) {
                console.error('Failed to fetch SID, status:', response.status);
                throw new Error(`HTTP ${response.status}`);
            }

            const buffer = await response.arrayBuffer();

            // Reject anything that isn't a PSID/RSID payload (e.g. an HTML
            // error page returned with a 200 status).
            const view = new Uint8Array(buffer);
            const magic = String.fromCharCode(view[0], view[1], view[2], view[3]);

            if (magic !== 'PSID' && magic !== 'RSID') {
                console.error('Not a valid SID file!');
                const text = new TextDecoder().decode(view.slice(0, 500));

                return {
                    statusCode: 500,
                    body: JSON.stringify({
                        error: 'Invalid SID file - server returned HTML instead of binary data'
                    })
                };
            }

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