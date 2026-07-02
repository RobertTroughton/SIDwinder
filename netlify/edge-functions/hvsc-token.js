// Issues short-lived access tokens for HVSC SID downloads.
//
// The HVSC browser/embed calls GET /hvsc-token once and reuses the token
// (query param ?t=) for every SID fetch until it expires. This makes casual
// file-loop scraping fail (a scraper hitting /HVSC/....sid directly has no
// token) while humans switch tunes freely within the token's lifetime.
//
// Enable by setting HVSC_TOKEN_SECRET in the Netlify environment. Until it's
// set, this returns {disabled:true} and the guard lets SIDs through, so the
// site keeps working during rollout.

import { issueToken } from './lib/token.js';

const TTL_SECONDS = 600; // 10 minutes

function allowedOrigins() {
    const raw = Netlify.env.get('HVSC_EMBED_ORIGINS') || '';
    return raw.split(',').map((s) => s.trim()).filter(Boolean);
}

export default async (request) => {
    const selfOrigin = new URL(request.url).origin;
    const origin = request.headers.get('origin');
    const allowList = allowedOrigins();

    // Same-origin requests often omit Origin; those are always fine.
    const crossOriginAllowed = origin
        && (origin === selfOrigin || allowList.includes(origin));

    const headers = {
        'content-type': 'application/json',
        'cache-control': 'no-store',
    };
    // Only expose the response cross-origin to explicitly allowed embedders.
    if (origin && crossOriginAllowed) {
        headers['access-control-allow-origin'] = origin;
        headers['vary'] = 'Origin';
    }

    if (request.method === 'OPTIONS') {
        return new Response(null, {
            status: 204,
            headers: { ...headers, 'access-control-allow-methods': 'GET, OPTIONS' },
        });
    }

    // Reject cross-origin issuance from origins we don't recognise.
    if (origin && !crossOriginAllowed) {
        return new Response(JSON.stringify({ error: 'origin not allowed' }), {
            status: 403, headers,
        });
    }

    const secret = Netlify.env.get('HVSC_TOKEN_SECRET');
    if (!secret) {
        return new Response(JSON.stringify({ disabled: true, token: '' }), { headers });
    }

    const now = Date.now();
    const token = await issueToken(secret, TTL_SECONDS, now);
    return new Response(JSON.stringify({
        token,
        exp: Math.floor(now / 1000) + TTL_SECONDS,
        ttl: TTL_SECONDS,
    }), { headers });
};

export const config = { path: '/hvsc-token' };
