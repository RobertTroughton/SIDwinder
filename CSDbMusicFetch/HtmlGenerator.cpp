#include "HtmlGenerator.h"

#include <algorithm>
#include <fstream>
#include <sstream>

namespace csdb {

	// Marker comments delimiting the auto-generated region in the template.
	static const std::string kBeginMarker = "<!-- RELEASES:BEGIN -->";
	static const std::string kEndMarker = "<!-- RELEASES:END -->";

	std::string EscapeHtml(const std::string& text) {
		std::string out;
		out.reserve(text.size());
		for (char c : text) {
			switch (c) {
			case '&': out += "&amp;";  break;
			case '<': out += "&lt;";   break;
			case '>': out += "&gt;";   break;
			case '"': out += "&quot;"; break;
			default:  out.push_back(c); break;
			}
		}
		return out;
	}

	std::string FormatDate(int day, int month, int year) {
		if (year <= 0)
			return std::string();

		static const char* kMonths[] = {
			"January", "February", "March", "April", "May", "June",
			"July", "August", "September", "October", "November", "December"
		};

		std::ostringstream os;
		const bool haveMonth = (month >= 1 && month <= 12);
		if (haveMonth && day >= 1)
			os << day << ' ';
		if (haveMonth)
			os << kMonths[month - 1] << ' ';
		os << year;
		return os.str();
	}

	// Joins one-or-more music handles into the nested-span markup the page uses,
	// e.g.  <span class="release-artist-name">A</span> &amp; <span ...>B</span>
	static std::string BuildArtists(const ReleaseRecord& rec) {
		std::string artists;
		for (size_t i = 0; i < rec.music.size(); ++i) {
			if (i > 0)
				artists += " &amp; ";
			artists += "<span class=\"release-artist-name\">";
			artists += EscapeHtml(rec.music[i].handle);
			artists += "</span>";
		}
		if (artists.empty()) {
			// No Music credit on CSDb - keep the markup shape but mark unknown.
			artists = "<span class=\"release-artist-name\">Unknown</span>";
		}
		return artists;
	}

	std::string BuildReleaseCard(const ReleaseRecord& rec) {
		const std::string id = std::to_string(rec.releaseId);
		const std::string name = EscapeHtml(rec.name);
		const std::string artists = BuildArtists(rec);
		const std::string date = EscapeHtml(FormatDate(rec.releaseDay, rec.releaseMonth, rec.releaseYear));

		std::string card;
		card += "<a href=\"https://csdb.dk/release/?id=" + id + "\" class=\"release-card\" target=\"_blank\" rel=\"noopener\">";
		card += "<div class=\"release-screenshot\"><img src=\"PNG/Releases/" + id + ".png\" alt=\"" + name + "\" loading=\"lazy\" width=\"384\" height=\"272\"></div>";
		card += "<div class=\"release-info\">";
		card += "<span class=\"release-title\">" + name + "</span>";
		card += "<span class=\"release-artist\">by " + artists + "</span>";
		card += "<span class=\"release-date\">" + date + "</span>";
		card += "</div></a>";
		return card;
	}

	std::string BuildReleasesBlock(const std::vector<ReleaseRecord>& records,
		const std::string& indent) {
		// Keep only the releases we actually resolved, then sort newest first.
		// stable_sort preserves the input-file order for releases sharing a date.
		std::vector<const ReleaseRecord*> sorted;
		sorted.reserve(records.size());
		for (const ReleaseRecord& rec : records) {
			if (rec.found)
				sorted.push_back(&rec);
		}

		std::stable_sort(sorted.begin(), sorted.end(),
			[](const ReleaseRecord* a, const ReleaseRecord* b) {
				if (a->releaseYear != b->releaseYear) return a->releaseYear > b->releaseYear;
				if (a->releaseMonth != b->releaseMonth) return a->releaseMonth > b->releaseMonth;
				return a->releaseDay > b->releaseDay;
			});

		std::string block;
		for (size_t i = 0; i < sorted.size(); ++i) {
			if (i > 0)
				block += '\n';
			block += indent;
			block += BuildReleaseCard(*sorted[i]);
		}
		return block;
	}

	// Returns the run of spaces/tabs immediately preceding `pos` on its line.
	static std::string LeadingIndent(const std::string& text, size_t pos) {
		size_t lineStart = text.rfind('\n', pos);
		lineStart = (lineStart == std::string::npos) ? 0 : lineStart + 1;
		std::string indent;
		for (size_t i = lineStart; i < pos; ++i) {
			char c = text[i];
			if (c == ' ' || c == '\t')
				indent.push_back(c);
			else
				break;
		}
		return indent;
	}

	bool ApplyTemplate(const std::string& templatePath,
		const std::string& outputPath,
		const std::vector<ReleaseRecord>& records,
		std::string& error) {
		std::ifstream in(templatePath, std::ios::binary);
		if (!in) {
			error = "Could not open template: " + templatePath;
			return false;
		}
		std::ostringstream ss;
		ss << in.rdbuf();
		in.close();
		std::string html = ss.str();

		const size_t beginPos = html.find(kBeginMarker);
		if (beginPos == std::string::npos) {
			error = "Marker " + kBeginMarker + " not found in " + templatePath;
			return false;
		}
		const size_t endPos = html.find(kEndMarker, beginPos + kBeginMarker.size());
		if (endPos == std::string::npos) {
			error = "Marker " + kEndMarker + " not found after " + kBeginMarker;
			return false;
		}

		const std::string indent = LeadingIndent(html, beginPos);
		const std::string block = BuildReleasesBlock(records, indent);

		std::string result;
		result.reserve(html.size() + block.size());
		result += html.substr(0, beginPos + kBeginMarker.size());
		result += '\n';
		result += block;
		result += '\n';
		result += indent;
		result += html.substr(endPos);

		std::ofstream out(outputPath, std::ios::binary | std::ios::trunc);
		if (!out) {
			error = "Could not write output: " + outputPath;
			return false;
		}
		out << result;
		if (!out) {
			error = "Write failed: " + outputPath;
			return false;
		}
		return true;
	}

} // namespace csdb
