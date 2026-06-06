# CSDbMusicFetch

Standalone C++ console tool that keeps the SIDwinder **Releases** page
(`public/index.html`) up to date from a plain list of CSDb release IDs.

Given `release-ids.txt`, it pulls per release:

- **Release name**
- **Release date** (day / month / year — any may be 0 if CSDb only has a partial date)
- **Music credit(s)** — handle name(s)

…and writes the corresponding release cards straight into `public/index.html`,
**newest first, one compact card per line**. No more hand-editing HTML for every
new tune — add an ID, drop in a screenshot, run the tool.

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

2. **Add a release:** put its CSDb release ID in `release-ids.txt` and drop the
   screenshot at `public/PNG/Releases/<id>.png`.

3. **Regenerate the page:**

   ```bat
   update-releases.bat
   ```

   This runs the tool over `release-ids.txt` and rewrites the cards in
   `..\public\index.html`. Review the diff and commit.

## Building / running manually

```sh
# Windows: build.bat does the two steps below for you.
cmake -B build
cmake --build build --config Release

# Run: <ids file> <template html> [output html] [--print]
./build/csdbmusicfetch release-ids.txt ../public/index.html
```

- If the output path is omitted, the template is updated **in place**.
- `--print` also dumps the fetched records to stdout (handy for debugging).
- On Linux/macOS install libcurl headers first
  (`sudo apt install libcurl4-openssl-dev` / `brew install curl`).

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
