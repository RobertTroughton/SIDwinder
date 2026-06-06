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
#include <cstdlib>
#include <fstream>
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

	std::vector<ReleaseRecord> FetchReleases(const std::vector<int>& releaseIDs) {
		std::vector<ReleaseRecord> records;
		records.reserve(releaseIDs.size());

		HttpHandle http = HttpOpen();
		if (!http) {
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

				ok = HttpGet(http, url, body);
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

		HttpClose(http);
		return records;
	}

} // namespace csdb
