exports.handler = async (event, context) => {
    const path = event.queryStringParameters?.path || '';
    console.log('HVSC Function called with path:', path);

    const hvscUrl = `https://hvsc.etv.cx/?path=${path}`;
    console.log('Fetching from:', hvscUrl);

    try {
        const response = await fetch(hvscUrl);
        const body = await response.text();

        console.log('Response status:', response.status);
        console.log('Response length:', body.length);

        // Check if it contains the table we're looking for
        if (body.includes('width="99%"')) {
            console.log('Contains expected table');
        } else {
            console.log('No width=99% table found');
            // Log what tables exist
            const tables = body.match(/<table[^>]*>/gi);
            console.log('Tables found:', tables ? tables.length : 0);
            if (tables) {
                console.log('First table tag:', tables[0]);
            }
        }

        // Check for path links
        const pathLinks = body.match(/\?path=[^"&]+/g);
        console.log('Path links found:', pathLinks ? pathLinks.slice(0, 5) : 'none');

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