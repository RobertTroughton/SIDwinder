// CSDbMusicFetch: read a list of CSDb release IDs, pull each release's name,
// date and music credit(s) from the CSDb webservice, and splice freshly
// generated release cards into the SIDwinder "Releases" page template.
//
//   csdbmusicfetch <release-ids.txt> <template.html> [output.html] [--print]
//
// If [output.html] is omitted the template is updated in place. With --print
// the fetched records are also dumped to stdout (handy for debugging).

#include "CSDbFetch.h"
#include "HtmlGenerator.h"

#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

namespace {

	void PrintUsage(const char* exe) {
		std::fprintf(stderr,
			"Usage: %s <png-dir> <template.html> [output.html] [options]\n"
			"\n"
			"  <png-dir>          Folder of release screenshots named <id>.png; their IDs\n"
			"                     drive the page (e.g. ..\\public\\PNG\\Releases).\n"
			"  <template.html>    HTML containing <!-- RELEASES:BEGIN --> / <!-- RELEASES:END --> markers.\n"
			"  [output.html]      Where to write the result. Defaults to <template.html> (in place).\n"
			"\n"
			"Options:\n"
			"  --verbose          Log every credit and name read from CSDb.\n"
			"  --xml-dir <dir>    Save each raw XML response to <dir>/<id>.xml (default: xml).\n"
			"  --no-xml           Do not save raw XML responses.\n"
			"  --print            Also print the fetched records to stdout.\n",
			exe);
	}

	void PrintRecords(const std::vector<csdb::ReleaseRecord>& records) {
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
	}

} // namespace

int main(int argc, char** argv) {
	std::string pngDir;
	std::string templateFile;
	std::string outputFile;
	bool printRecords = false;
	bool verbose = false;
	std::string xmlDir = "xml"; // save raw XML by default

	std::vector<std::string> positionals;
	for (int i = 1; i < argc; ++i) {
		if (std::strcmp(argv[i], "--print") == 0)
			printRecords = true;
		else if (std::strcmp(argv[i], "--verbose") == 0)
			verbose = true;
		else if (std::strcmp(argv[i], "--no-xml") == 0)
			xmlDir.clear();
		else if (std::strcmp(argv[i], "--xml-dir") == 0) {
			if (i + 1 >= argc) {
				std::fprintf(stderr, "Error: --xml-dir needs a directory argument.\n");
				return 1;
			}
			xmlDir = argv[++i];
		}
		else if (std::strcmp(argv[i], "--help") == 0 || std::strcmp(argv[i], "-h") == 0) {
			PrintUsage(argv[0]);
			return 0;
		}
		else
			positionals.push_back(argv[i]);
	}

	if (positionals.size() < 2 || positionals.size() > 3) {
		PrintUsage(argv[0]);
		return 1;
	}
	pngDir = positionals[0];
	templateFile = positionals[1];
	outputFile = (positionals.size() == 3) ? positionals[2] : templateFile;

	std::vector<int> ids = csdb::LoadReleaseIDsFromPngDir(pngDir);
	if (ids.empty()) {
		std::fprintf(stderr, "No <id>.png screenshots found in %s\n", pngDir.c_str());
		return 1;
	}
	std::fprintf(stderr, "Fetching %zu release(s) from CSDb...\n", ids.size());
	if (!xmlDir.empty())
		std::fprintf(stderr, "Saving raw XML to '%s'\n", xmlDir.c_str());

	csdb::FetchOptions options;
	options.verbose = verbose;
	options.xmlDir = xmlDir;

	csdb::GlobalInit();
	std::vector<csdb::ReleaseRecord> records = csdb::FetchReleases(ids, options);
	csdb::GlobalCleanup();

	if (printRecords)
		PrintRecords(records);

	size_t found = 0;
	size_t missingArtist = 0;
	for (const csdb::ReleaseRecord& rec : records) {
		if (!rec.found)
			continue;
		++found;

		bool hasNamedArtist = false;
		for (const csdb::MusicCredit& mc : rec.music) {
			if (!mc.handle.empty()) {
				hasNamedArtist = true;
				break;
			}
		}
		if (!hasNamedArtist) {
			++missingArtist;
			std::fprintf(stderr, "Note: release %d (\"%s\") has no resolved artist name - card will show \"Unknown\".\n",
				rec.releaseId, rec.name.c_str());
		}
	}
	if (found == 0) {
		std::fprintf(stderr, "No releases could be fetched; leaving %s untouched.\n", templateFile.c_str());
		return 1;
	}
	std::fprintf(stderr, "\nSummary: %zu/%zu releases resolved, %zu with no artist name.\n",
		found, ids.size(), missingArtist);

	std::string error;
	if (!csdb::ApplyTemplate(templateFile, outputFile, records, error)) {
		std::fprintf(stderr, "Error: %s\n", error.c_str());
		return 1;
	}

	std::fprintf(stderr, "Wrote %zu release card(s) to %s\n", found, outputFile.c_str());
	return 0;
}
