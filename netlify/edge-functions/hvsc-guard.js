// Guards the self-hosted HVSC assets against bulk scraping and crawlers.
//
//  * Blocks known AI/crawler/scraper user-agents outright (they don't need our
//    copy — HVSC is a free download at hvsc.c64.org).
//  * Requires a valid short-lived token (?t=, issued by /hvsc-token) to fetch
//    a .sid file, so hitting file URLs straight from the index fails.
//
// Non-.sid assets under /HVSC (the DOCUMENTS/ text files we link to) and the
// metadata index pass through after the UA check. If HVSC_TOKEN_SECRET is not
// set, token enforcement is skipped (rollout-safe) but UA blocking still runs.

import { verifyToken } from './lib/token.js';

// Well-known AI-training / SEO / generic-scraper agents. Humans and normal
// browsers are unaffected. Easy to extend.
const BLOCKED_UA = [
    /GPTBot/i, /OAI-SearchBot/i, /ChatGPT-User/i, /CCBot/i, /anthropic/i,
    /ClaudeBot/i, /Claude-Web/i, /Google-Extended/i, /PerplexityBot/i,
    /Bytespider/i, /Amazonbot/i, /Applebot-Extended/i, /Meta-ExternalAgent/i,
    /FacebookBot/i, /Diffbot/i, /ImagesiftBot/i, /DataForSeoBot/i,
    /SemrushBot/i, /AhrefsBot/i, /MJ12bot/i, /DotBot/i, /PetalBot/i,
    /Scrapy/i, /python-requests/i, /python-urllib/i, /libwww-perl/i,
    /Go-http-client/i, /node-fetch/i, /HTTrack/i, /wget/i, /curl\//i,
];

export default async (request, context) => {
    const ua = request.headers.get('user-agent') || '';
    if (BLOCKED_UA.some((re) => re.test(ua))) {
        return new Response('Not available here — get HVSC at https://hvsc.c64.org/',
            { status: 403, headers: { 'content-type': 'text/plain' } });
    }

    const url = new URL(request.url);
    // Only .sid payloads are token-gated; docs and the index just pass through.
    if (!url.pathname.toLowerCase().endsWith('.sid')) {
        return context.next();
    }

    const secret = Netlify.env.get('HVSC_TOKEN_SECRET');
    if (!secret) {
        return context.next(); // gate disabled until the secret is configured
    }

    const token = url.searchParams.get('t');
    const ok = await verifyToken(secret, token, Date.now());
    if (!ok) {
        return new Response('Forbidden — SID access requires a valid session token.',
            { status: 403, headers: { 'content-type': 'text/plain' } });
    }

    return context.next();
};

export const config = { path: ['/HVSC/*', '/hvsc-index.json'] };
