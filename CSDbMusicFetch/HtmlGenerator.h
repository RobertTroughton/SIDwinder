// Turns CSDb release records into the static HTML used on the SIDwinder
// "Releases" page, and splices that HTML into a template file.
//
// Pure string work: no network, no XML. Depends only on the data structs in
// CSDbFetch.h so it can be tested in isolation.

#pragma once

#include "CSDbFetch.h"

#include <string>
#include <vector>

namespace csdb {

	// HTML-escapes the five characters that matter inside element text /
	// double-quoted attributes: & < > ".
	std::string EscapeHtml(const std::string& text);

	// Formats a CSDb date into the page style ("5 June 2026"). Gracefully
	// handles the partial dates CSDb sometimes returns:
	//   day/month/year -> "5 June 2026"
	//   month/year      -> "June 2026"   (day == 0)
	//   year            -> "2026"        (day == month == 0)
	//   nothing         -> ""            (year == 0)
	std::string FormatDate(int day, int month, int year);

	// Builds the single-line <a class="release-card"> markup for one release.
	// One release == one line of HTML (no embedded newlines).
	std::string BuildReleaseCard(const ReleaseRecord& rec);

	// Builds the full block of release cards, newest first, one card per line,
	// each prefixed with `indent`. Records with found == false are skipped.
	std::string BuildReleasesBlock(const std::vector<ReleaseRecord>& records,
		const std::string& indent);

	// Reads `templatePath`, replaces everything between the marker comments
	//   <!-- RELEASES:BEGIN -->  ...  <!-- RELEASES:END -->
	// with freshly generated cards, and writes the result to `outputPath`
	// (which may equal templatePath for an in-place update). The indentation of
	// the BEGIN marker is reused for the generated cards. Returns false and
	// fills `error` on any failure (missing file, missing markers, write error).
	bool ApplyTemplate(const std::string& templatePath,
		const std::string& outputPath,
		const std::vector<ReleaseRecord>& records,
		std::string& error);

} // namespace csdb
