# CSDbMusicFetch

Standalone C++ tool that takes a list of CSDb release IDs and pulls, per release:

- **Release name**
- **Release date** (day / month / year — any may be 0 if CSDb only has a partial date)
- **Music credit(s)** — handle name **and** scener ID (zero or more per release)

Modelled on the CSDb scraping logic in C64GFX (`CPPTool/CSDbScrape_*` and
`CPPTool/Core.cpp`), but cross-platform: HTTP via **libcurl**, XML via **tinyxml2**.

## What it gives you

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

Downstream code (e.g. HTML generation) consumes this vector directly — the
data is already decoded and ready to format.

## Build

Requires CMake 3.14+, a C++17 compiler, and libcurl development headers.
tinyxml2 is fetched automatically by CMake.

```sh
# Debian/Ubuntu: sudo apt install libcurl4-openssl-dev cmake build-essential
# macOS:         brew install curl cmake
cmake -B build
cmake --build build
```

## Run

```sh
./build/csdbmusicfetch release-ids.txt
```

`release-ids.txt` is one release ID per line; blank and non-numeric lines are
skipped.

## Notes on talking to CSDb

These match what C64GFX does and are baked into `CSDbFetch.cpp`:

- Endpoint: `https://csdb.dk/webservice/?type=release&depth=2&id=<ID>`
  (`depth=2` is required for the `<Credits>` block).
- A **Referer** header is sent — CSDb rejects requests without one. Change
  `kReferer` in `CSDbFetch.cpp` to your own site.
- Requests are **rate-limited to one per 200ms** (5/sec); CSDb throttles faster.
- Transient failures retry up to 3× with 1s/2s/4s backoff.
- A non-existent ID returns the 3 bytes `huh` instead of XML; those records
  come back with `found == false`.
