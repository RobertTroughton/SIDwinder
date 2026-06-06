// Standalone CSDb release/music-credit fetcher.
// HTTP via libcurl, XML via tinyxml2. Mirrors the behavior of C64GFX's
// CPPTool/Core.cpp (rate limit + retries) and CPPTool/CSDbScrape_Parser.cpp
// (release/credit parsing).

#include "CSDbFetch.h"

#include <tinyxml2.h>
#include <curl/curl.h>

#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <string>
#include <string_view>
#include <thread>

namespace csdb {

	// CSDb webservice endpoint. depth=2 is required for the <Credits> block.
	static const std::string kReleaseURL = "https://csdb.dk/webservice/?type=release&depth=2&id=";

	// CSDb rejects requests without a Referer. Point this at your own site.
	static const char* kReferer = "https://csdb.dk/";

	// CSDb rate limit: keep at least 200ms between requests (5/sec).
	static const int kMinIntervalMs = 200;

	// Transient-failure retry backoff, matching C64GFX (1s, 2s, 4s).
	static const int kRetryDelaysMs[] = { 1000, 2000, 4000 };
	static const int kMaxRetries = 3;

	// ---- HTML entity decoding (ported from C64GFX HTML_Generator.cpp) -------

	static void appendUtf8(std::string& out, uint32_t cp) {
		if (cp < 0x80) {
			out.push_back(static_cast<char>(cp));
		}
		else if (cp < 0x800) {
			out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
			out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
		}
		else if (cp < 0x10000) {
			out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
			out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
			out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
		}
		else if (cp < 0x110000) {
			out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
			out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
			out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
			out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
		}
	}

	std::string DecodeHtmlEntities(std::string_view text) {
		if (text.find('&') == std::string_view::npos)
			return std::string(text);

		std::string result;
		result.reserve(text.size());

		const size_t n = text.size();
		for (size_t i = 0; i < n; ) {
			if (text[i] != '&') {
				result.push_back(text[i++]);
				continue;
			}

			const size_t semi = text.find(';', i + 1);
			if (semi == std::string_view::npos || semi - i > 10) {
				result.push_back('&');
				++i;
				continue;
			}

			std::string_view body = text.substr(i + 1, semi - i - 1);
			bool decoded = false;

			if (!body.empty() && body[0] == '#') {
				uint32_t cp = 0;
				bool ok = false;
				if (body.size() >= 2 && (body[1] == 'x' || body[1] == 'X')) {
					for (size_t k = 2; k < body.size(); ++k) {
						char c = body[k];
						int v = (c >= '0' && c <= '9') ? c - '0'
							: (c >= 'a' && c <= 'f') ? c - 'a' + 10
							: (c >= 'A' && c <= 'F') ? c - 'A' + 10 : -1;
						if (v < 0) { ok = false; break; }
						cp = (cp << 4) | static_cast<uint32_t>(v);
						ok = true;
					}
				}
				else {
					for (size_t k = 1; k < body.size(); ++k) {
						char c = body[k];
						if (c < '0' || c > '9') { ok = false; break; }
						cp = cp * 10 + static_cast<uint32_t>(c - '0');
						ok = true;
					}
				}
				if (ok && cp != 0 && cp < 0x110000) {
					appendUtf8(result, cp);
					decoded = true;
				}
			}
			else if (body == "lt")   { result.push_back('<');  decoded = true; }
			else if (body == "gt")   { result.push_back('>');  decoded = true; }
			else if (body == "amp")  { result.push_back('&');  decoded = true; }
			else if (body == "quot") { result.push_back('"');  decoded = true; }
			else if (body == "apos") { result.push_back('\''); decoded = true; }
			else if (body == "nbsp") { appendUtf8(result, 0x00A0); decoded = true; }

			if (decoded) {
				i = semi + 1;
			}
			else {
				result.push_back('&');
				++i;
			}
		}

		return result;
	}

	// ---- HTTP ---------------------------------------------------------------

	static size_t WriteCallback(char* ptr, size_t size, size_t nmemb, void* userdata) {
		std::string* out = static_cast<std::string*>(userdata);
		out->append(ptr, size * nmemb);
		return size * nmemb;
	}

	// Single GET. Returns true and fills `out` on a 2xx response with a body.
	static bool HttpGet(CURL* curl, const std::string& url, std::string& out) {
		out.clear();
		curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
		curl_easy_setopt(curl, CURLOPT_REFERER, kReferer);
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
		curl_easy_setopt(curl, CURLOPT_WRITEDATA, &out);
		curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
		curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
		curl_easy_setopt(curl, CURLOPT_USERAGENT, "CSDbMusicFetch/1.0");

		CURLcode res = curl_easy_perform(curl);
		if (res != CURLE_OK)
			return false;

		long httpCode = 0;
		curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &httpCode);
		return httpCode >= 200 && httpCode < 300 && !out.empty();
	}

	// CSDb returns the 3 bytes "huh" for a non-existent entry.
	static bool IsHuhResponse(const std::string& body) {
		return body.size() == 3 && body[0] == 'h' && body[1] == 'u' && body[2] == 'h';
	}

	// ---- XML parsing (mirrors CSDbScrape_Parser.cpp) ------------------------

	static int ChildInt(tinyxml2::XMLElement* parent, const char* name, int fallback = 0) {
		tinyxml2::XMLElement* e = parent->FirstChildElement(name);
		if (e && e->GetText())
			return atoi(e->GetText());
		return fallback;
	}

	static std::string ChildText(tinyxml2::XMLElement* parent, const char* name) {
		tinyxml2::XMLElement* e = parent->FirstChildElement(name);
		if (e && e->GetText())
			return e->GetText();
		return std::string();
	}

	// Parses one <Release> element into a record. Returns false if the element
	// is malformed.
	static bool ParseRelease(tinyxml2::XMLElement* release, ReleaseRecord& rec) {
		rec.releaseId = ChildInt(release, "ID", rec.releaseId);

		std::string name = ChildText(release, "Name");
		rec.name = name.empty() ? "Unknown" : DecodeHtmlEntities(name);

		rec.releaseDay = ChildInt(release, "ReleaseDay", 0);
		rec.releaseMonth = ChildInt(release, "ReleaseMonth", 0);
		rec.releaseYear = ChildInt(release, "ReleaseYear", 0);

		tinyxml2::XMLElement* credits = release->FirstChildElement("Credits");
		if (credits) {
			for (tinyxml2::XMLElement* credit = credits->FirstChildElement("Credit");
				credit;
				credit = credit->NextSiblingElement("Credit")) {

				if (ChildText(credit, "CreditType") != "Music")
					continue;

				// Each <Credit> has a child <Handle> element which itself holds
				// <ID> and a (further nested) <Handle> name element.
				tinyxml2::XMLElement* handle = credit->FirstChildElement("Handle");
				if (!handle)
					continue;

				MusicCredit mc;
				mc.scenerId = ChildInt(handle, "ID", -1);
				mc.handle = DecodeHtmlEntities(ChildText(handle, "Handle"));
				rec.music.push_back(std::move(mc));
			}
		}

		rec.found = true;
		return true;
	}

	// ---- Public API ---------------------------------------------------------

	std::vector<int> LoadReleaseIDs(const std::string& filename) {
		std::vector<int> ids;
		std::ifstream file(filename);
		std::string line;
		while (std::getline(file, line)) {
			// Trim whitespace.
			size_t start = line.find_first_not_of(" \t\r\n");
			if (start == std::string::npos)
				continue;
			size_t end = line.find_last_not_of(" \t\r\n");
			std::string token = line.substr(start, end - start + 1);

			char* parseEnd = nullptr;
			long value = std::strtol(token.c_str(), &parseEnd, 10);
			if (parseEnd != token.c_str() && value > 0)
				ids.push_back(static_cast<int>(value));
		}
		return ids;
	}

	std::vector<ReleaseRecord> FetchReleases(const std::vector<int>& releaseIDs) {
		std::vector<ReleaseRecord> records;
		records.reserve(releaseIDs.size());

		CURL* curl = curl_easy_init();
		if (!curl) {
			// Return empty records (found == false) for every ID.
			for (int id : releaseIDs) {
				ReleaseRecord rec;
				rec.releaseId = id;
				records.push_back(rec);
			}
			return records;
		}

		auto lastRequest = std::chrono::steady_clock::now() - std::chrono::milliseconds(kMinIntervalMs);

		for (int id : releaseIDs) {
			ReleaseRecord rec;
			rec.releaseId = id;

			std::string url = kReleaseURL + std::to_string(id);
			std::string body;
			bool ok = false;

			for (int attempt = 0; attempt <= kMaxRetries; ++attempt) {
				// Maintain the minimum spacing between CSDb requests.
				auto now = std::chrono::steady_clock::now();
				auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - lastRequest).count();
				if (elapsed < kMinIntervalMs)
					std::this_thread::sleep_for(std::chrono::milliseconds(kMinIntervalMs - elapsed));

				if (attempt > 0)
					std::this_thread::sleep_for(std::chrono::milliseconds(kRetryDelaysMs[attempt - 1]));

				ok = HttpGet(curl, url, body);
				lastRequest = std::chrono::steady_clock::now();

				if (ok)
					break;
			}

			if (!ok || IsHuhResponse(body)) {
				// Leave found == false.
				records.push_back(std::move(rec));
				continue;
			}

			tinyxml2::XMLDocument doc;
			if (doc.Parse(body.c_str(), body.size()) != tinyxml2::XML_SUCCESS) {
				records.push_back(std::move(rec));
				continue;
			}

			tinyxml2::XMLElement* root = doc.FirstChildElement("CSDbData");
			tinyxml2::XMLElement* release = root ? root->FirstChildElement("Release") : nullptr;
			if (release)
				ParseRelease(release, rec);

			records.push_back(std::move(rec));
		}

		curl_easy_cleanup(curl);
		return records;
	}

} // namespace csdb
