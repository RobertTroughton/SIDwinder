# Embedding the SIDquake HVSC browser

SIDquake self-hosts the High Voltage SID Collection and exposes the browser as
an embeddable widget, so other sites can let visitors search, preview and pick
SID tunes from our mirror. The supported integration is an **iframe** that
talks to the host page via `postMessage`.

> Please read and honour [`/embed-terms.html`](public/embed-terms.html): keep
> the attribution visible, and don't use the embed to scrape/bulk-download the
> collection (it's a free download at <https://hvsc.c64.org/>).

## Quick start

```html
<iframe
  src="https://sidquake.c64demo.com/hvsc-embed.html?mode=link&origin=https://your-site.example"
  width="900" height="600" style="border:0"
  title="HVSC Browser"></iframe>

<script>
  window.addEventListener('message', (e) => {
    if (e.origin !== 'https://sidquake.c64demo.com') return;   // trust only us
    const msg = e.data || {};
    if (msg.type === 'hvsc:selected') {
      console.log('Picked', msg.title, 'by', msg.author, '->', msg.url);
      // msg.url is a short-lived SID URL you can load/play.
    }
  });
</script>
```

## URL parameters (`hvsc-embed.html?...`)

| Param    | Values                    | Meaning |
|----------|---------------------------|---------|
| `mode`   | `link` (default), `file`, `play` | How selections are returned (see below). |
| `origin` | an origin, e.g. `https://your-site.example` | Where results are posted. Defaults to the referrer's origin, else `*`. Set it. |
| `start`  | an HVSC path, e.g. `C64Music/MUSICIANS/D/Drax` | Open the browser at a folder (deep-link). |

## Messages sent to the host (`window.parent.postMessage`)

All payloads include: `name`, `path`, `url`, `title`, `author`, `released`, `stil`.

| `type`           | When | Extra |
|------------------|------|-------|
| `hvsc:ready`     | Widget loaded. | — |
| `hvsc:selected`  | User chose a tune in `link`/`file` mode. | `mode`; in `file` mode also `bytes` (an `ArrayBuffer` of the SID, transferred). |
| `hvsc:playing`   | User chose a tune in `play` mode (preview only). | — |
| `hvsc:error`     | A selection couldn't be fetched (`file` mode). | `message` |

### Modes

- **`link`** — returns metadata + a short-lived SID `url`. Lightest; the host
  fetches/plays the URL itself. URLs carry an access token and expire (~10 min),
  so treat them as ephemeral, not permanent hotlinks.
- **`file`** — as `link`, plus the SID `bytes` (`ArrayBuffer`), handy for
  sandboxed hosts that can't fetch cross-origin.
- **`play`** — discovery only: the widget previews tunes in-place and just
  announces what's playing; nothing is handed over.

Always check `event.origin === 'https://sidquake.c64demo.com'` before trusting a
message.

## Server configuration (SIDquake operators)

Access to raw `.sid` files is gated by a short-lived HMAC token so the mirror
isn't a free bulk-download endpoint (see `netlify/edge-functions/`).

- **`HVSC_TOKEN_SECRET`** — set this in the Netlify environment to enable token
  gating. Any non-empty random string. **Until it's set, gating is disabled**
  (SIDs serve normally), so deploys don't break before you configure it.
- **`HVSC_EMBED_ORIGINS`** — optional comma-separated list of third-party
  origins allowed to request tokens *cross-origin* (the iframe itself is
  same-origin and always works, so most setups don't need this).

Also in effect: `robots.txt` + `X-Robots-Tag: noindex` keep the raw files and
index out of search; the edge guard blocks known AI/crawler/scraper user-agents.

## Notes & limits

- The iframe is served from our origin, so its own requests are same-origin —
  no CORS setup needed on the embedder's side.
- A determined scraper spoofing headers isn't fully stopped; this is
  deliberate "raise the bar" protection, not DRM. The collection is freely
  available at its source regardless.
