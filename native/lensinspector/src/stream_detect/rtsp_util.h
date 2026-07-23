#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace stream_detect {

struct ParsedRtspUrl {
    std::string host;
    int port = 554;
    std::string path;
    std::string user;
    std::string password;
};

bool parseRtspUrl(const std::string& url, ParsedRtspUrl& out);

bool base64Decode(const std::string& input, std::vector<uint8_t>& out);

void appendAnnexBStartCode(std::vector<uint8_t>& out);

}  // namespace stream_detect
