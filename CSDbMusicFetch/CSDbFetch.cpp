// Standalone CSDb release/music-credit fetcher.
// HTTP via libcurl, XML via tinyxml2. Mirrors the behavior of C64GFX's
// CPPTool/Core.cpp (rate limit + retries) and CPPTool/CSDbScrape_Parser.cpp
// (release/credit parsing).

#include "CSDbFetch.h"

#include <tinyxml2.h>

// HTTP backend: WinHTTP on Windows (no external dependency), libcurl elsewhere.
#ifdef _WIN32
#  define WIN32_LEAN_AND_MEAN
#  include <windows.h>
#  include <winhttp.h>
#else
#  include <curl/curl.h>
#endif

#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <initializer_list>
#include <map>
#include <string>
#include <string_view>
#include <thread>

namespace csdb {

	// CSDb webservice endpoint. depth=2 is required for the <Credits> block.
	static const std::string kReleaseURL = "https://csdb.dk/webservice/?type=release&depth=2&id=";

#ifndef _WIN32
	// CSDb rejects requests without a Referer. Point this at your own site.
	// (The WinHTTP backend sets the Referer header inline; see HttpGet below.)
	static const char* kReferer = "https://csdb.dk/";
#endif

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
	//
	// A tiny client abstraction over the platform HTTP stack. HttpOpen() returns
	// a reusable handle (one per FetchReleases run), HttpGet() performs a single
	// GET, HttpClose() releases it. Two backends share this interface so the
	// release/credit parsing below is platform-agnostic.

#ifdef _WIN32

	// ---- WinHTTP backend ----------------------------------------------------

	using HttpHandle = HINTERNET; // a WinHTTP session handle

	static HttpHandle HttpOpen() {
		return WinHttpOpen(L"CSDbMusicFetch/1.0",
			WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
			WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
	}

	static void HttpClose(HttpHandle session) {
		if (session)
			WinHttpCloseHandle(session);
	}

	static bool HttpGet(HttpHandle session, const std::string& url, std::string& out) {
		out.clear();
		if (!session)
			return false;

		// CSDb URLs are ASCII; widen for the WinHTTP wide-char API.
		std::wstring wurl(url.begin(), url.end());

		wchar_t host[256] = { 0 };
		wchar_t path[2048] = { 0 };
		wchar_t extra[2048] = { 0 };

		URL_COMPONENTS uc;
		ZeroMemory(&uc, sizeof(uc));
		uc.dwStructSize = sizeof(uc);
		uc.lpszHostName = host;       uc.dwHostNameLength = 255;
		uc.lpszUrlPath = path;        uc.dwUrlPathLength = 2047;
		uc.lpszExtraInfo = extra;     uc.dwExtraInfoLength = 2047;

		if (!WinHttpCrackUrl(wurl.c_str(), static_cast<DWORD>(wurl.size()), 0, &uc))
			return false;

		host[uc.dwHostNameLength] = 0;
		path[uc.dwUrlPathLength] = 0;
		extra[uc.dwExtraInfoLength] = 0;
		std::wstring resource = std::wstring(path) + std::wstring(extra);

		const bool secure = (uc.nScheme == INTERNET_SCHEME_HTTPS);

		HINTERNET hConnect = WinHttpConnect(session, host, uc.nPort, 0);
		if (!hConnect)
			return false;

		HINTERNET hRequest = WinHttpOpenRequest(hConnect, L"GET",
			resource.c_str(), nullptr,
			WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
			secure ? WINHTTP_FLAG_SECURE : 0);
		if (!hRequest) {
			WinHttpCloseHandle(hConnect);
			return false;
		}

		// CSDb rejects requests without a Referer.
		static const wchar_t* kRefererHeader = L"Referer: https://csdb.dk/\r\n";
		WinHttpAddRequestHeaders(hRequest, kRefererHeader, (DWORD)-1L,
			WINHTTP_ADDREQ_FLAG_ADD);

		bool ok = false;
		if (WinHttpSendRequest(hRequest, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
			WINHTTP_NO_REQUEST_DATA, 0, 0, 0) &&
			WinHttpReceiveResponse(hRequest, nullptr)) {

			DWORD status = 0, statusLen = sizeof(status);
			WinHttpQueryHeaders(hRequest,
				WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
				WINHTTP_HEADER_NAME_BY_INDEX, &status, &statusLen,
				WINHTTP_NO_HEADER_INDEX);

			DWORD avail = 0;
			do {
				avail = 0;
				if (!WinHttpQueryDataAvailable(hRequest, &avail))
					break;
				if (avail == 0)
					break;
				std::string chunk(avail, '\0');
				DWORD read = 0;
				if (!WinHttpReadData(hRequest, &chunk[0], avail, &read))
					break;
				out.append(chunk.data(), read);
			} while (avail > 0);

			ok = (status >= 200 && status < 300 && !out.empty());
		}

		WinHttpCloseHandle(hRequest);
		WinHttpCloseHandle(hConnect);
		return ok;
	}

#else

	// ---- libcurl backend ----------------------------------------------------

	static const char* kUserAgent = "CSDbMusicFetch/1.0";

	using HttpHandle = CURL*;

	static size_t WriteCallback(char* ptr, size_t size, size_t nmemb, void* userdata) {
		std::string* out = static_cast<std::string*>(userdata);
		out->append(ptr, size * nmemb);
		return size * nmemb;
	}

	static HttpHandle HttpOpen() {
		return curl_easy_init();
	}

	static void HttpClose(HttpHandle curl) {
		if (curl)
			curl_easy_cleanup(curl);
	}

	// Single GET. Returns true and fills `out` on a 2xx response with a body.
	static bool HttpGet(HttpHandle curl, const std::string& url, std::string& out) {
		out.clear();
		if (!curl)
			return false;
		curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
		curl_easy_setopt(curl, CURLOPT_REFERER, kReferer);
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
		curl_easy_setopt(curl, CURLOPT_WRITEDATA, &out);
		curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
		curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
		curl_easy_setopt(curl, CURLOPT_USERAGENT, kUserAgent);

		CURLcode res = curl_easy_perform(curl);
		if (res != CURLE_OK)
			return false;

		long httpCode = 0;
		curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &httpCode);
		return httpCode >= 200 && httpCode < 300 && !out.empty();
	}

#endif

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

	// Serialises an element back to XML text - used to show exactly what CSDb
	// returned when we can't resolve a name.
	static std::string ElementToString(tinyxml2::XMLElement* e) {
		if (!e)
			return std::string();
		tinyxml2::XMLPrinter printer;
		e->Accept(&printer);
		return printer.CStr() ? printer.CStr() : std::string();
	}

	// Returns the first non-empty text among the named child elements of `parent`.
	static std::string FirstChildText(tinyxml2::XMLElement* parent,
		std::initializer_list<const char*> names) {
		for (const char* name : names) {
			std::string t = ChildText(parent, name);
			if (!t.empty())
				return t;
		}
		return std::string();
	}

	// A single resolved credit entity (a scener handle, or a group).
	struct CreditEntity {
		int id = -1;
		std::string name;       // decoded display name ("" if unresolved)
		const char* kind = "?"; // "Handle", "Group", ...
		bool found = false;     // an entity element was present at all
	};

	// Pulls the entity (and its display name) out of a <Credit>. CSDb credits a
	// release's music either to a <Handle> (an individual scener) or, less often,
	// to a <Group>. The display name has historically lived under a couple of
	// different child tags, so we try the likely ones in order.
	static CreditEntity ResolveCreditEntity(tinyxml2::XMLElement* credit) {
		CreditEntity ce;

		if (tinyxml2::XMLElement* handle = credit->FirstChildElement("Handle")) {
			ce.found = true;
			ce.kind = "Handle";
			ce.id = ChildInt(handle, "ID", -1);
			// The nick normally lives in a nested <Handle>; fall back to <Nick>/<Name>.
			ce.name = DecodeHtmlEntities(FirstChildText(handle, { "Handle", "Nick", "Name" }));
			return ce;
		}

		if (tinyxml2::XMLElement* group = credit->FirstChildElement("Group")) {
			ce.found = true;
			ce.kind = "Group";
			ce.id = ChildInt(group, "ID", -1);
			ce.name = DecodeHtmlEntities(FirstChildText(group, { "Name", "Group" }));
			return ce;
		}

		return ce;
	}

	// CSDb's webservice expands each referenced object (a handle, a group, ...)
	// only the FIRST time it appears in a response; every later reference to the
	// same ID collapses to just <ID>. So a Music credit can carry only an <ID>
	// while the actual name sits in an expanded copy elsewhere (the release's
	// <ReleasedBy>, another credit, ...). This walks the whole subtree once and
	// records id -> name for every expanded Handle/Group so collapsed references
	// can be resolved.
	static void CollectEntityNames(tinyxml2::XMLElement* el,
		std::map<int, std::string>& handleNames,
		std::map<int, std::string>& groupNames) {
		for (tinyxml2::XMLElement* c = el->FirstChildElement(); c; c = c->NextSiblingElement()) {
			const char* tag = c->Name();
			if (tag && std::strcmp(tag, "Handle") == 0) {
				const int id = ChildInt(c, "ID", -1);
				const std::string name = FirstChildText(c, { "Handle", "Nick" });
				if (id > 0 && !name.empty())
					handleNames.emplace(id, DecodeHtmlEntities(name)); // first (expanded) wins
			}
			else if (tag && std::strcmp(tag, "Group") == 0) {
				const int id = ChildInt(c, "ID", -1);
				const std::string name = FirstChildText(c, { "Name", "Group" });
				if (id > 0 && !name.empty())
					groupNames.emplace(id, DecodeHtmlEntities(name));
			}
			CollectEntityNames(c, handleNames, groupNames);
		}
	}

	// Parses one <Release> element into a record. Returns false if the element
	// is malformed. Always warns to stderr about anything that would leave a
	// card without a proper artist name; `verbose` adds per-credit tracing.
	static bool ParseRelease(tinyxml2::XMLElement* release, ReleaseRecord& rec, bool verbose) {
		rec.releaseId = ChildInt(release, "ID", rec.releaseId);

		std::string name = ChildText(release, "Name");
		rec.name = name.empty() ? "Unknown" : DecodeHtmlEntities(name);

		rec.releaseDay = ChildInt(release, "ReleaseDay", 0);
		rec.releaseMonth = ChildInt(release, "ReleaseMonth", 0);
		rec.releaseYear = ChildInt(release, "ReleaseYear", 0);

		if (verbose) {
			std::fprintf(stderr, "  name=\"%s\" date=%04d-%02d-%02d\n",
				rec.name.c_str(), rec.releaseYear, rec.releaseMonth, rec.releaseDay);
		}

		tinyxml2::XMLElement* credits = release->FirstChildElement("Credits");
		if (!credits) {
			std::fprintf(stderr, "  [warn] release %d has no <Credits> block.\n", rec.releaseId);
			rec.found = true;
			return true;
		}

		// Index every expanded handle/group in the response so we can fill in
		// names for credits that CSDb collapsed to an <ID>-only reference.
		std::map<int, std::string> handleNames, groupNames;
		CollectEntityNames(release, handleNames, groupNames);

		int musicCount = 0;
		for (tinyxml2::XMLElement* credit = credits->FirstChildElement("Credit");
			credit;
			credit = credit->NextSiblingElement("Credit")) {

			const std::string type = ChildText(credit, "CreditType");
			if (verbose)
				std::fprintf(stderr, "  credit type=\"%s\"\n", type.c_str());

			if (type != "Music")
				continue;

			++musicCount;
			CreditEntity ce = ResolveCreditEntity(credit);

			// Recover a collapsed name from an expanded copy elsewhere in the doc.
			if (ce.name.empty() && ce.id > 0) {
				const std::map<int, std::string>& names =
					(std::strcmp(ce.kind, "Group") == 0) ? groupNames : handleNames;
				auto it = names.find(ce.id);
				if (it != names.end()) {
					ce.name = it->second;
					if (verbose)
						std::fprintf(stderr, "    (recovered name for %s ID %d from elsewhere in the response)\n",
							ce.kind, ce.id);
				}
			}

			if (!ce.found) {
				std::fprintf(stderr,
					"  [warn] release %d: Music credit has no <Handle> or <Group>. Raw credit XML:\n%s\n",
					rec.releaseId, ElementToString(credit).c_str());
			}
			else if (ce.name.empty()) {
				std::fprintf(stderr,
					"  [warn] release %d: Music credit %s ID %d has no resolvable name. Raw credit XML:\n%s\n",
					rec.releaseId, ce.kind, ce.id, ElementToString(credit).c_str());
			}
			else if (verbose) {
				std::fprintf(stderr, "    -> music: \"%s\" (%s ID %d)\n",
					ce.name.c_str(), ce.kind, ce.id);
			}

			MusicCredit mc;
			mc.scenerId = ce.id;
			mc.handle = ce.name;
			rec.music.push_back(std::move(mc));
		}

		if (musicCount == 0)
			std::fprintf(stderr, "  [warn] release %d has no Music credits.\n", rec.releaseId);

		rec.found = true;
		return true;
	}

	// ---- Public API ---------------------------------------------------------

	void GlobalInit() {
#ifndef _WIN32
		curl_global_init(CURL_GLOBAL_DEFAULT);
#endif
	}

	void GlobalCleanup() {
#ifndef _WIN32
		curl_global_cleanup();
#endif
	}

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

	// Writes the raw XML for one release to <xmlDir>/<id>.xml. Best-effort: any
	// failure is reported but does not abort the run.
	static void SaveXml(const std::string& xmlDir, int id, const std::string& body) {
		std::error_code ec;
		std::filesystem::create_directories(xmlDir, ec);
		const std::string path = (std::filesystem::path(xmlDir) / (std::to_string(id) + ".xml")).string();
		std::ofstream f(path, std::ios::binary | std::ios::trunc);
		if (!f) {
			std::fprintf(stderr, "  [warn] could not write %s\n", path.c_str());
			return;
		}
		f.write(body.data(), static_cast<std::streamsize>(body.size()));
	}

	std::vector<ReleaseRecord> FetchReleases(const std::vector<int>& releaseIDs,
		const FetchOptions& options) {
		std::vector<ReleaseRecord> records;
		records.reserve(releaseIDs.size());

		HttpHandle http = HttpOpen();
		if (!http) {
			std::fprintf(stderr, "[error] could not initialise the HTTP client.\n");
			// Return empty records (found == false) for every ID.
			for (int id : releaseIDs) {
				ReleaseRecord rec;
				rec.releaseId = id;
				records.push_back(rec);
			}
			return records;
		}

		auto lastRequest = std::chrono::steady_clock::now() - std::chrono::milliseconds(kMinIntervalMs);

		size_t index = 0;
		for (int id : releaseIDs) {
			++index;
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

				if (attempt > 0) {
					std::fprintf(stderr, "  [retry %d/%d] release %d\n", attempt, kMaxRetries, id);
					std::this_thread::sleep_for(std::chrono::milliseconds(kRetryDelaysMs[attempt - 1]));
				}

				ok = HttpGet(http, url, body);
				lastRequest = std::chrono::steady_clock::now();

				if (ok)
					break;
			}

			std::fprintf(stderr, "[%zu/%zu] release %d: %zu bytes\n",
				index, releaseIDs.size(), id, body.size());

			// Cache the raw XML (also captures "huh"/error bodies for inspection).
			if (!options.xmlDir.empty() && !body.empty())
				SaveXml(options.xmlDir, id, body);

			if (!ok) {
				std::fprintf(stderr, "  [warn] release %d: fetch failed after %d attempts.\n", id, kMaxRetries + 1);
				records.push_back(std::move(rec));
				continue;
			}
			if (IsHuhResponse(body)) {
				std::fprintf(stderr, "  [warn] release %d: CSDb returned \"huh\" (no such release).\n", id);
				records.push_back(std::move(rec));
				continue;
			}

			tinyxml2::XMLDocument doc;
			if (doc.Parse(body.c_str(), body.size()) != tinyxml2::XML_SUCCESS) {
				std::fprintf(stderr, "  [warn] release %d: XML parse error (%s).\n", id, doc.ErrorStr());
				records.push_back(std::move(rec));
				continue;
			}

			tinyxml2::XMLElement* root = doc.FirstChildElement("CSDbData");
			tinyxml2::XMLElement* release = root ? root->FirstChildElement("Release") : nullptr;
			if (release) {
				ParseRelease(release, rec, options.verbose);
			}
			else {
				std::fprintf(stderr, "  [warn] release %d: no <CSDbData><Release> in response.\n", id);
			}

			records.push_back(std::move(rec));
		}

		HttpClose(http);
		return records;
	}

} // namespace csdb
