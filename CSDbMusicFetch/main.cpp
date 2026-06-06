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
			"Usage: %s <release-ids.txt> <template.html> [output.html] [--print]\n"
			"\n"
			"  <release-ids.txt>  One CSDb release ID per line (blank/non-numeric lines ignored).\n"
			"  <template.html>    HTML containing <!-- RELEASES:BEGIN --> / <!-- RELEASES:END --> markers.\n"
			"  [output.html]      Where to write the result. Defaults to <template.html> (in place).\n"
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
	std::string idsFile;
	std::string templateFile;
	std::string outputFile;
	bool printRecords = false;

	std::vector<std::string> positionals;
	for (int i = 1; i < argc; ++i) {
		if (std::strcmp(argv[i], "--print") == 0)
			printRecords = true;
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
	idsFile = positionals[0];
	templateFile = positionals[1];
	outputFile = (positionals.size() == 3) ? positionals[2] : templateFile;

	std::vector<int> ids = csdb::LoadReleaseIDs(idsFile);
	if (ids.empty()) {
		std::fprintf(stderr, "No release IDs found in %s\n", idsFile.c_str());
		return 1;
	}
	std::fprintf(stderr, "Fetching %zu release(s) from CSDb...\n", ids.size());

	csdb::GlobalInit();
	std::vector<csdb::ReleaseRecord> records = csdb::FetchReleases(ids);
	csdb::GlobalCleanup();

	if (printRecords)
		PrintRecords(records);

	size_t found = 0;
	for (const csdb::ReleaseRecord& rec : records) {
		if (rec.found)
			++found;
		else
			std::fprintf(stderr, "Warning: release %d not found on CSDb - skipping.\n", rec.releaseId);
	}
	if (found == 0) {
		std::fprintf(stderr, "No releases could be fetched; leaving %s untouched.\n", templateFile.c_str());
		return 1;
	}

	std::string error;
	if (!csdb::ApplyTemplate(templateFile, outputFile, records, error)) {
		std::fprintf(stderr, "Error: %s\n", error.c_str());
		return 1;
	}

	std::fprintf(stderr, "Wrote %zu release card(s) to %s\n", found, outputFile.c_str());
	return 0;
}
