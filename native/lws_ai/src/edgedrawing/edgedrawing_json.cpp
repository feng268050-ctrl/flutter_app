#include "edgedrawing_json.h"

#include "opencv_detect_json.h"

#include <iomanip>
#include <sstream>

namespace edgedrawing {
namespace {

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

}  // namespace

std::string errorJson(int code, const std::string& reason) {
    return opencv_detect::zeroPointFailureJson(code, reason);
}

std::string frameResultToJson(const FrameResult& result) {
    std::ostringstream out;
    out << std::fixed << std::setprecision(2);
    double offset_x = 0.0;
    double offset_y = 0.0;
    if (result.ok && result.comparison) {
        offset_x = result.comparison->offset.dx_px;
        offset_y = result.comparison->offset.dy_px;
    }
    out << "{\"ok\":" << (result.ok ? "true" : "false")
        << ",\"code\":" << result.code;
    if (!result.ok && !result.reason.empty()) {
        out << ",\"reason\":\"" << jsonEscape(result.reason) << '"';
    }
    out << ",\"offset_x\":" << offset_x
        << ",\"offset_y\":" << offset_y;
    if (result.circle_fit) {
        out << ",\"base_x\":" << result.circle_fit->base_x
            << ",\"base_y\":" << result.circle_fit->base_y;
    }
    out << '}';
    return out.str();
}

}  // namespace edgedrawing
