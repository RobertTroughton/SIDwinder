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

	// Reads a .txt file of release IDs (one integer per line; blank lines and
	// non-numeric lines are skipped). Returns the parsed IDs in file order.
	std::vector<int> LoadReleaseIDs(const std::string& filename);

	// Fetches every release from the CSDb webservice and returns one record per
	// input ID, in the same order. Honors CSDb's rate limit and retries transient
	// failures. Records that could not be fetched have found == false.
	std::vector<ReleaseRecord> FetchReleases(const std::vector<int>& releaseIDs);

	// Decodes HTML entities (&amp; &lt; &gt; &quot; &apos; &nbsp; and numeric
	// &#NNN; / &#xHH;) into UTF-8. CSDb returns text content HTML-pre-encoded.
	std::string DecodeHtmlEntities(std::string_view text);

} // namespace csdb
