# CSDbMusicFetch

Standalone C++ console tool that keeps the SIDwinder **Releases** page
(`public/index.html`) up to date directly from the release screenshots.

The list of releases is driven by the PNG files in `public/PNG/Releases/`: every
`<id>.png` there is one release. For each, the tool pulls from CSDb:

- **Release name**
- **Release date** (day / month / year — any may be 0 if CSDb only has a partial date)
- **Music credit(s)** — handle name(s)

…and writes the corresponding release cards straight into `public/index.html`,
**newest first, one compact card per line**. No more hand-editing HTML, and no
separate ID list to maintain — drop in a screenshot, run the tool.

Modelled on the CSDb scraping logic in C64GFX (`CPPTool/CSDbScrape_*` and
`CPPTool/Core.cpp`), XML via **tinyxml2**. HTTP uses **WinHTTP** on Windows (no
external dependency) and **libcurl** elsewhere.

## How it fits together

`public/index.html` is the template. The release grid is delimited by two marker
comments:

```html
<div class="releases-grid">
    <!-- RELEASES:BEGIN -->
    ... auto-generated cards go here, one per line ...
    <!-- RELEASES:END -->
</div>
```

The tool replaces everything **between** those markers and leaves the rest of the
page byte-for-byte untouched, so it is safe to re-run any time.

## Workflow (Windows)

1. **Build once:**

   ```bat
   build.bat
   ```

   Requires CMake, a C++17 compiler (MSVC / Visual Studio Build Tools) and Git
   (CMake fetches tinyxml2). Nothing else — WinHTTP ships with Windows.

2. **Add a release:** drop its screenshot at `public/PNG/Releases/<id>.png`
   (the filename's number is the CSDb release ID). That's the only step.

3. **Regenerate the page:**

   ```bat
   update-releases.bat
   ```

   This scans `..\public\PNG\Releases` for `<id>.png` files and rewrites the
   cards in `..\public\index.html`. Review the diff and commit.

## Building / running manually

```sh
# Windows: build.bat does the two steps below for you.
cmake -B build
cmake --build build --config Release

# Run: <png-dir> <template html> [output html] [options]
./build/csdbmusicfetch ../public/PNG/Releases ../public/index.html
```

- IDs are taken from the `<id>.png` filenames in `<png-dir>`, sorted newest
  (highest ID) first; the cards are then ordered by release date.
- If the output path is omitted, the template is updated **in place**.
- On Linux/macOS install libcurl headers first
  (`sudo apt install libcurl4-openssl-dev` / `brew install curl`).

### Options / diagnostics

| Option           | Effect                                                            |
|------------------|------------------------------------------------------------------|
| `--verbose`      | Log every credit and resolved name as it's read from CSDb.       |
| `--xml-dir <d>`  | Save each raw XML response to `<d>/<id>.xml` (default: `xml`).    |
| `--no-xml`       | Don't save the raw XML.                                          |
| `--print`        | Also dump the fetched records to stdout.                          |

Every run prints a per-release line and a final summary. **Warnings always
print** when something would leave a card without a proper artist, e.g.:

```
[13/31] release 236972: 4821 bytes
  [warn] release 236972: Music credit Handle ID 4711 has no resolvable name. Raw credit XML:
  <Credit> ... </Credit>
...
Summary: 31/31 releases resolved, 1 with no artist name.
```

### Why is a scener's name missing?

The tool resolves a music credit's name from the CSDb `<Credit>` element,
trying a `<Handle>` (individual scener) first and then a `<Group>`, and within
those the `<Handle>`/`<Nick>`/`<Name>` tags in turn. If none of those hold a
name it warns and dumps the raw `<Credit>` XML so you can see what CSDb actually
returned. The full responses are also saved under `xml/` (by default) **and
committed to the repo**, so you can open `xml/<id>.xml` and inspect the
`<Credits>` block directly without re-running the tool. A card with no
resolvable name falls back to "Unknown" rather than rendering blank.

## Data structures

`csdb::FetchReleases()` returns one `ReleaseRecord` per input ID, in order:

```cpp
struct MusicCredit {
    int scenerId;        // CSDb scener ID
    std::string handle;  // handle name, HTML-entity decoded
};

struct ReleaseRecord {
    int releaseId;
    bool found;          // false if CSDb returned "huh" (no such release) or fetch failed
    std::string name;    // release name, decoded ("Unknown" if empty)
    int releaseDay, releaseMonth, releaseYear;
    std::vector<MusicCredit> music;
};
```

`HtmlGenerator.*` turns those records into the page markup
(`BuildReleaseCard`, `BuildReleasesBlock`, `ApplyTemplate`) — pure string work,
no network, so it is easy to test in isolation.

## Notes on talking to CSDb

These match what C64GFX does and are baked into `CSDbFetch.cpp`:

- Endpoint: `https://csdb.dk/webservice/?type=release&depth=2&id=<ID>`
  (`depth=2` is required for the `<Credits>` block).
- A **Referer** header is sent — CSDb rejects requests without one.
- Requests are **rate-limited to one per 200ms** (5/sec); CSDb throttles faster.
- Transient failures retry up to 3× with 1s/2s/4s backoff.
- A non-existent ID returns the 3 bytes `huh` instead of XML; those records come
  back with `found == false` and are skipped (with a warning) when generating HTML.
