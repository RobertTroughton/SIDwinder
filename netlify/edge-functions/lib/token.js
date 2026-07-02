// Stateless, short-lived access tokens for gating HVSC SID downloads.
//
// A token is `<exp>.<base64url(HMAC-SHA256(secret, exp))>` where exp is a unix
// timestamp (seconds). Verification recomputes the HMAC and checks expiry — no
// server-side state, so it works at the edge. The secret comes from the
// HVSC_TOKEN_SECRET environment variable (set in Netlify).
//
// Uses Web Crypto (crypto.subtle) + btoa/atob, which are available in both
// Deno (Netlify edge runtime) and modern Node (for the unit test).

const encoder = new TextEncoder();

async function hmacKey(secret) {
    return crypto.subtle.importKey(
        'raw', encoder.encode(secret),
        { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']
    );
}

function toBase64Url(bytes) {
    let bin = '';
    const arr = new Uint8Array(bytes);
    for (let i = 0; i < arr.length; i++) bin += String.fromCharCode(arr[i]);
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function fromBase64Url(str) {
    str = str.replace(/-/g, '+').replace(/_/g, '/');
    const pad = str.length % 4 === 0 ? 0 : 4 - (str.length % 4);
    str += '='.repeat(pad);
    const bin = atob(str);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes;
}

/** Issue a token valid for ttlSeconds from nowMs (Date.now()). */
export async function issueToken(secret, ttlSeconds, nowMs) {
    const exp = Math.floor(nowMs / 1000) + ttlSeconds;
    const key = await hmacKey(secret);
    const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(String(exp)));
    return `${exp}.${toBase64Url(sig)}`;
}

/** True if token is well-formed, unexpired at nowMs, and correctly signed. */
export async function verifyToken(secret, token, nowMs) {
    if (!secret || !token || typeof token !== 'string') return false;
    const dot = token.indexOf('.');
    if (dot <= 0) return false;
    const expStr = token.slice(0, dot);
    const sigStr = token.slice(dot + 1);
    const exp = parseInt(expStr, 10);
    if (!Number.isFinite(exp)) return false;
    if (exp < Math.floor(nowMs / 1000)) return false; // expired
    let sigBytes;
    try { sigBytes = fromBase64Url(sigStr); } catch (_) { return false; }
    const key = await hmacKey(secret);
    return crypto.subtle.verify('HMAC', key, sigBytes, encoder.encode(expStr));
}
