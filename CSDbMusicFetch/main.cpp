// Demo driver: load release IDs from a .txt file, fetch from CSDb, dump the
// data structure that downstream code (HTML generation) will consume.

#include "CSDbFetch.h"

#include <curl/curl.h>

#include <cstdio>
#include <string>
#include <vector>

int main(int argc, char** argv) {
	if (argc < 2) {
		std::fprintf(stderr, "Usage: %s <release-ids.txt>\n", argv[0]);
		return 1;
	}

	std::vector<int> ids = csdb::LoadReleaseIDs(argv[1]);
	if (ids.empty()) {
		std::fprintf(stderr, "No release IDs found in %s\n", argv[1]);
		return 1;
	}

	curl_global_init(CURL_GLOBAL_DEFAULT);
	std::vector<csdb::ReleaseRecord> records = csdb::FetchReleases(ids);
	curl_global_cleanup();

	for (const csdb::ReleaseRecord& rec : records) {
		if (!rec.found) {
			std::printf("[%d] NOT FOUND\n", rec.releaseId);
			continue;
		}

		std::printf("[%d] \"%s\"  (%04d-%02d-%02d)\n",
			rec.releaseId, rec.name.c_str(),
			rec.releaseYear, rec.releaseMonth, rec.releaseDay);

		if (rec.music.empty()) {
			std::printf("      Music: (none)\n");
		}
		else {
			for (const csdb::MusicCredit& mc : rec.music)
				std::printf("      Music: %s (ID %d)\n", mc.handle.c_str(), mc.scenerId);
		}
	}

	return 0;
}
