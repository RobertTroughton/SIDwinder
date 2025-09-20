exports.handler = async (event, context) => {
    const path = event.queryStringParameters?.path || '';
    console.log('HVSC Function called with path:', path);

    // Check if this is a SID file request
    if (path.endsWith('.sid')) {
        // For SID files, fetch directly without query parameter
        const directUrl = `https://hvsc.etv.cx/${path}`;
        console.log('Direct fetching SID from:', directUrl);

        try {
            const response = await fetch(directUrl);
            const buffer = await response.arrayBuffer();

            console.log('SID file size:', buffer.byteLength);

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
        // For directories, use the query parameter approach
        const hvscUrl = `https://hvsc.etv.cx/?path=${path}`;
        console.log('Fetching directory from:', hvscUrl);

        try {
            const response = await fetch(hvscUrl);
            const body = await response.text();

            console.log('Response status:', response.status);
            console.log('Response length:', body.length);

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