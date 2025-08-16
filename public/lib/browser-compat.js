// browser-compat.js - Browser compatibility layer
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

// fs polyfill (not used in browser)
export const fs = {
    readFileSync: () => { throw new Error('fs not available in browser'); },
    writeFileSync: () => { throw new Error('fs not available in browser'); }
};