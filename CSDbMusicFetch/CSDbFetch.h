// Standalone CSDb release/music-credit fetcher.
// Modelled on the CSDb scraping logic in C64GFX (CPPTool/CSDbScrape_*).

#pragma once

#include <string>
#include <vector>

namespace csdb {

	// A single "Music" credit on a release. CSDb supplies both the scener ID
	// and the handle name in the same release response (depth=2), so no second
	// lookup is needed for the name.
	struct MusicCredit {
		int scenerId = -1;        // CSDb scener ID
		std::string handle;       // handle name, HTML-entity decoded
	};

	// Everything we pull for one release ID. Any date component may be 0 when
	// CSDb only knows a partial date (e.g. year only).
	struct ReleaseRecord {
		int releaseId = -1;
		bool found = false;       // false if CSDb returned "huh" (no such release) or fetch failed
		std::string name;         // release name, HTML-entity decoded ("Unknown" if empty)
		int releaseDay = 0;
		int releaseMonth = 0;
		int releaseYear = 0;
		std::vector<MusicCredit> music;   // zero or more Music credits
	};

	// One-time process init/cleanup for the underlying HTTP stack (libcurl on
	// non-Windows; a no-op for the WinHTTP backend). Call GlobalInit() once
	// before FetchReleases() and GlobalCleanup() once at shutdown.
	void GlobalInit();
	void GlobalCleanup();

	// Reads a .txt file of release IDs (one integer per line; blank lines and
	// non-numeric lines are skipped). Returns the parsed IDs in file order.
	std::vector<int> LoadReleaseIDs(const std::string& filename);

	// Tweaks for FetchReleases: diagnostics and on-disk caching of the raw XML.
	struct FetchOptions {
		bool verbose = false;     // log every credit/name we read to stderr
		std::string xmlDir;       // if non-empty, save each raw XML response to <xmlDir>/<id>.xml
	};

	// Fetches every release from the CSDb webservice and returns one record per
	// input ID, in the same order. Honors CSDb's rate limit and retries transient
	// failures. Records that could not be fetched have found == false. Warnings
	// (missing release, missing Music credit, unresolvable scener name, ...) are
	// always written to stderr; `options.verbose` adds per-credit detail.
	std::vector<ReleaseRecord> FetchReleases(const std::vector<int>& releaseIDs,
		const FetchOptions& options = {});

	// Decodes HTML entities (&amp; &lt; &gt; &quot; &apos; &nbsp; and numeric
	// &#NNN; / &#xHH;) into UTF-8. CSDb returns text content HTML-pre-encoded.
	std::string DecodeHtmlEntities(std::string_view text);

} // namespace csdb
