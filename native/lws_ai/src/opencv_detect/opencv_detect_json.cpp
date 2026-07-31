#include "opencv_detect_json.h"

#include <iomanip>
#include <sstream>

namespace opencv_detect {

std::string jsonEscape(const std::string& value) {
    std::ostringstream out;
    for (char c : value) {
        switch (c) {
            case '\\':
                out << "\\\\";
                break;
            case '"':
                out << "\\\"";
                break;
            case '\n':
                out << "\\n";
                break;
            case '\r':
                out << "\\r";
                break;
            case '\t':
                out << "\\t";
                break;
            default:
                out << c;
                break;
        }
    }
    return out.str();
}

std::string summaryFailureJson(int code, const std::string& reason) {
    std::ostringstream out;
    out << "{\"ok\":false,\"code\":" << code;
    if (!reason.empty()) {
        out << ",\"reason\":\"" << jsonEscape(reason) << '"';
    }
    out << ",\"files\":[]}";
    return out.str();
}

std::string zeroPointFailureJson(int code, const std::string& reason) {
    std::ostringstream out;
    out << std::fixed << std::setprecision(2);
    out << "{\"ok\":false,\"code\":" << code;
    if (!reason.empty()) {
        out << ",\"reason\":\"" << jsonEscape(reason) << '"';
    }
    out << ",\"offset_x\":0,\"offset_y\":0}";
    return out.str();
}

}  // namespace opencv_detect
