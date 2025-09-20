exports.handler = async (event, context) => {
    const path = event.queryStringParameters.path || '';
    const hvscUrl = `https://hvsc.etv.cx/?path=${path}`;
    
    try {
        const response = await fetch(hvscUrl);
        const body = await response.text();
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'text/html',
            },
            body: body
        };
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Failed to fetch from HVSC' })
        };
    }
}