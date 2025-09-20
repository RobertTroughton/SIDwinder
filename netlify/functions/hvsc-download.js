exports.handler = async (event, context) => {
    // Get the path from the URL (everything after /hvsc-download/)
    const pathParts = event.path.split('/hvsc-download/');
    const filePath = pathParts[1] || '';

    console.log('Download requested for:', filePath);

    const hvscUrl = `https://hvsc.etv.cx/${filePath}`;

    try {
        const response = await fetch(hvscUrl);
        const buffer = await response.arrayBuffer();

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/octet-stream',
                'Content-Disposition': `attachment; filename="${filePath.split('/').pop()}"`,
                'Access-Control-Allow-Origin': '*',
            },
            body: Buffer.from(buffer).toString('base64'),
            isBase64Encoded: true
        };
    } catch (error) {
        console.error('Error downloading from HVSC:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Failed to download from HVSC' })
        };
    }
}