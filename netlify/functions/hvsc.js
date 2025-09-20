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
        console.log('First 200 chars:', body.substring(0, 200));
        
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