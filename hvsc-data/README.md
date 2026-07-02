# HVSC archive

Drop the High Voltage SID Collection archive here as a single `.7z` (or `.zip`)
whose top-level folder is `C64Music/`. This archive **is** committed (the raw
~61k `.sid` files are not); the build extracts it into `public/HVSC/`.

Typical name: `C64Music-85.7z` (the update number keeps it obvious which
version is shipped).

## Workflow after an HVSC update

```
# 1. Replace the archive in this folder with the new one.
# 2. Unpack it locally:
npm run extract-hvsc -- --force        # -> public/HVSC/C64Music/... (gitignored)
# 3. Rebuild the search index (reads public/HVSC + DOCUMENTS/STIL.txt):
npm run build-hvsc-index               # -> public/hvsc-index.json
# 4. Commit the new archive + public/hvsc-index.json.
```

On Netlify, `scripts/extract-hvsc.js` runs during the build (see `netlify.toml`)
to unpack this archive into the publish directory, so the raw SIDs are served
from `/HVSC/...`.
