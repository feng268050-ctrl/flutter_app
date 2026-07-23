#pragma once

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>

namespace lws::daemon {

inline int64_t now_ms() {
    using namespace std::chrono;
    return duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
}

/** Minimal escape for JSON string values. */
inline std::string json_escape(std::string_view s) {
    std::string out;
    out.reserve(s.size() + 8);
    for (char c : s) {
        switch (c) {
            case '\\': out += "\\\\"; break;
            case '"': out += "\\\""; break;
            case '\n': out += "\\n"; break;
            case '\r': out += "\\r"; break;
            case '\t': out += "\\t"; break;
            default: out += c; break;
        }
    }
    return out;
}

/** Unescape a JSON string value (handles \\ \/ \" \n \r \t \uXXXX minimally for \/ \\ "). */
inline std::string json_unescape(std::string_view s) {
    std::string out;
    out.reserve(s.size());
    for (size_t i = 0; i < s.size(); ++i) {
        if (s[i] != '\\' || i + 1 >= s.size()) {
            out.push_back(s[i]);
            continue;
        }
        const char n = s[++i];
        switch (n) {
            case '"':
            case '\\':
            case '/':
                out.push_back(n);
                break;
            case 'n':
                out.push_back('\n');
                break;
            case 'r':
                out.push_back('\r');
                break;
            case 't':
                out.push_back('\t');
                break;
            case 'u':
                // Skip \uXXXX (4 hex); keep as empty on failure to avoid hanging parse.
                if (i + 4 < s.size()) {
                    i += 4;
                }
                break;
            default:
                out.push_back(n);
                break;
        }
    }
    return out;
}

inline std::optional<std::string> extract_string_field(std::string_view json, std::string_view key) {
    const std::string needle = "\"" + std::string(key) + "\"";
    const auto pos = json.find(needle);
    if (pos == std::string_view::npos) {
        return std::nullopt;
    }
    auto colon = json.find(':', pos + needle.size());
    if (colon == std::string_view::npos) {
        return std::nullopt;
    }
    auto q1 = json.find('"', colon + 1);
    if (q1 == std::string_view::npos) {
        return std::nullopt;
    }
    auto q2 = q1 + 1;
    while (q2 < json.size()) {
        if (json[q2] == '"') {
            // Count preceding backslashes: odd => escaped quote.
            size_t bs = 0;
            size_t k = q2;
            while (k > q1 + 1 && json[k - 1] == '\\') {
                ++bs;
                --k;
            }
            if ((bs % 2) == 0) {
                break;
            }
        }
        ++q2;
    }
    if (q2 >= json.size()) {
        return std::nullopt;
    }
    return json_unescape(json.substr(q1 + 1, q2 - q1 - 1));
}

inline std::optional<bool> extract_bool_field(std::string_view json, std::string_view key) {
    const std::string needle = "\"" + std::string(key) + "\"";
    const auto pos = json.find(needle);
    if (pos == std::string_view::npos) {
        return std::nullopt;
    }
    auto colon = json.find(':', pos + needle.size());
    if (colon == std::string_view::npos) {
        return std::nullopt;
    }
    auto i = colon + 1;
    while (i < json.size() && (json[i] == ' ' || json[i] == '\t')) {
        ++i;
    }
    if (json.compare(i, 4, "true") == 0) {
        return true;
    }
    if (json.compare(i, 5, "false") == 0) {
        return false;
    }
    return std::nullopt;
}

inline std::optional<int64_t> extract_int_field(std::string_view json, std::string_view key) {
    const std::string needle = "\"" + std::string(key) + "\"";
    const auto pos = json.find(needle);
    if (pos == std::string_view::npos) {
        return std::nullopt;
    }
    auto colon = json.find(':', pos + needle.size());
    if (colon == std::string_view::npos) {
        return std::nullopt;
    }
    auto i = colon + 1;
    while (i < json.size() && (json[i] == ' ' || json[i] == '\t')) {
        ++i;
    }
    bool neg = false;
    if (i < json.size() && json[i] == '-') {
        neg = true;
        ++i;
    }
    if (i >= json.size() || json[i] < '0' || json[i] > '9') {
        return std::nullopt;
    }
    int64_t v = 0;
    while (i < json.size() && json[i] >= '0' && json[i] <= '9') {
        v = v * 10 + (json[i] - '0');
        ++i;
    }
    return neg ? -v : v;
}

}  // namespace lws::daemon
