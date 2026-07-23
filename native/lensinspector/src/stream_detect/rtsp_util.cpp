#include "rtsp_util.h"

#include <cctype>

namespace stream_detect {

namespace {

int hexValue(char c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    }
    if (c >= 'a' && c <= 'f') {
        return 10 + (c - 'a');
    }
    if (c >= 'A' && c <= 'F') {
        return 10 + (c - 'A');
    }
    return -1;
}

std::string urlDecode(const std::string& input) {
    std::string out;
    out.reserve(input.size());
    for (size_t i = 0; i < input.size(); ++i) {
        if (input[i] == '%' && i + 2 < input.size()) {
            const int hi = hexValue(input[i + 1]);
            const int lo = hexValue(input[i + 2]);
            if (hi >= 0 && lo >= 0) {
                out.push_back(static_cast<char>((hi << 4) | lo));
                i += 2;
                continue;
            }
        }
        out.push_back(input[i]);
    }
    return out;
}

}  // namespace

bool parseRtspUrl(const std::string& url, ParsedRtspUrl& out) {
    const std::string prefix = "rtsp://";
    if (url.size() <= prefix.size() || url.compare(0, prefix.size(), prefix) != 0) {
        return false;
    }
    std::string rest = url.substr(prefix.size());
    out = ParsedRtspUrl{};

    const size_t at = rest.find('@');
    if (at != std::string::npos) {
        const size_t colon = rest.find(':');
        if (colon != std::string::npos && colon < at) {
            out.user = urlDecode(rest.substr(0, colon));
            out.password = urlDecode(rest.substr(colon + 1, at - colon - 1));
        } else {
            out.user = urlDecode(rest.substr(0, at));
        }
        rest = rest.substr(at + 1);
    }

    const size_t slash = rest.find('/');
    const std::string hostPort = slash == std::string::npos ? rest : rest.substr(0, slash);
    out.path = slash == std::string::npos ? "/" : rest.substr(slash);

    const size_t colon = hostPort.find(':');
    if (colon == std::string::npos) {
        out.host = hostPort;
    } else {
        out.host = hostPort.substr(0, colon);
        try {
            out.port = std::stoi(hostPort.substr(colon + 1));
        } catch (...) {
            return false;
        }
    }
    return !out.host.empty();
}

bool base64Decode(const std::string& input, std::vector<uint8_t>& out) {
    static const int8_t kTable[256] = {
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62,
        -1, -1, -1, 63, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1, -1, 0,
        1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
        23, 24, 25, -1, -1, -1, -1, -1, -1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38,
        39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1};

    out.clear();
    int val = 0;
    int valb = -8;
    for (unsigned char c : input) {
        if (std::isspace(c)) {
            continue;
        }
        const int8_t d = kTable[c];
        if (d == -1) {
            if (c == '=') {
                break;
            }
            continue;
        }
        val = (val << 6) + d;
        valb += 6;
        if (valb >= 0) {
            out.push_back(static_cast<uint8_t>((val >> valb) & 0xFF));
            valb -= 8;
        }
    }
    return !out.empty();
}

void appendAnnexBStartCode(std::vector<uint8_t>& out) {
    out.push_back(0);
    out.push_back(0);
    out.push_back(0);
    out.push_back(1);
}

}  // namespace stream_detect
