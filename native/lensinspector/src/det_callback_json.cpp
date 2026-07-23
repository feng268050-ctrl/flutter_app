#include "det_callback_json.h"

#include "json_escape.h"

#include <algorithm>
#include <cmath>
#include <iomanip>
#include <sstream>

namespace {

float finite_or_zero(float value) {
    return std::isfinite(value) ? value : 0.0f;
}

float max_detection_confidence(const std::vector<Detection>& detections) {
    float best = 0.0f;
    for (const auto& d : detections) {
        if (std::isfinite(d.conf)) {
            best = std::max(best, d.conf);
        }
    }
    return best;
}

void sort_detections_by_score(std::vector<Detection>& detections) {
    std::sort(detections.begin(), detections.end(),
              [](const Detection& a, const Detection& b) { return a.conf > b.conf; });
}

}  // namespace

ContaminationResult contamination_result_for_json(const ContaminationResult& result) {
    ContaminationResult out = result;
    switch (result.level) {
        case 2:
            if (result.message.find("连续") != std::string::npos) {
                out.message = "Replace now (consecutive inside mask)";
            } else {
                out.message = "Replace now (inside mask)";
            }
            break;
        case 1:
            if (result.message.find("连续") != std::string::npos) {
                out.message = "Slight — wipe recommended (consecutive detection)";
            } else {
                out.message = "Slight — wipe recommended (outside mask)";
            }
            break;
        default:
            out.message = "Clean";
            break;
    }
    return out;
}

void cap_detections(std::vector<Detection>& detections, int max_det) {
    if (max_det <= 0) {
        return;
    }
    sort_detections_by_score(detections);
    if (static_cast<int>(detections.size()) > max_det) {
        detections.resize(static_cast<std::size_t>(max_det));
    }
}

void append_det_boxes_json(std::ostringstream& os,
                           const std::vector<Detection>& detections,
                           int max_det,
                           std::size_t total_before_cap) {
    os << ",\"boxes\":[";
    const std::size_t n = detections.size();
    for (std::size_t i = 0; i < n; ++i) {
        const auto& d = detections[i];
        if (i > 0) os << ',';
        os << "{\"x1\":" << finite_or_zero(d.x1)
           << ",\"y1\":" << finite_or_zero(d.y1)
           << ",\"x2\":" << finite_or_zero(d.x2)
           << ",\"y2\":" << finite_or_zero(d.y2)
           << ",\"classId\":" << d.cls_id
           << ",\"label\":\"cls=" << d.cls_id << "\""
           << ",\"score\":" << finite_or_zero(d.conf)
           << ",\"confidence\":" << finite_or_zero(d.conf)
           << '}';
    }
    os << ']';
    if (max_det > 0 && total_before_cap > n) {
        os << ",\"boxesTruncated\":true"
           << ",\"boxesTotal\":" << total_before_cap;
    }
}

std::string build_preview_det_json(const ContaminationResult& result,
                                   const std::vector<Detection>& detections,
                                   int max_det,
                                   std::size_t total_before_cap,
                                   int image_width,
                                   int image_height) {
    const ContaminationResult display = contamination_result_for_json(result);
    std::ostringstream os;
    os << std::fixed << std::setprecision(2);
    os << "{\"code\":0"
       << ",\"source\":\"preview_det\""
       << ",\"level\":" << display.level
       << ",\"status\":\"" << json_escape(display.status) << "\""
       << ",\"message\":\"" << json_escape(display.message) << "\"";
    if (image_width > 0 && image_height > 0) {
        os << ",\"imageWidth\":" << image_width << ",\"imageHeight\":" << image_height;
    }
    os << ",\"maxConfidence\":" << finite_or_zero(max_detection_confidence(detections));
    append_det_boxes_json(os, detections, max_det, total_before_cap);
    os << '}';
    return os.str();
}

std::string build_offline_infer_json(int code,
                                     const std::string& message,
                                     const ContaminationResult* result,
                                     const std::vector<Detection>* detections,
                                     int max_det,
                                     std::size_t total_before_cap,
                                     int image_width,
                                     int image_height,
                                     const char* source) {
    std::ostringstream os;
    os << std::fixed << std::setprecision(2);
    os << "{\"code\":" << code;
    if (code == 0 && result && detections) {
        const ContaminationResult display = contamination_result_for_json(*result);
        const char* src = (source && source[0] != '\0') ? source : "offline_infer";
        os << ",\"source\":\"" << json_escape(src) << "\""
           << ",\"level\":" << display.level
           << ",\"status\":\"" << json_escape(display.status) << "\""
           << ",\"message\":\"" << json_escape(display.message) << "\"";
        if (image_width > 0 && image_height > 0) {
            os << ",\"imageWidth\":" << image_width << ",\"imageHeight\":" << image_height;
        }
        os << ",\"maxConfidence\":" << finite_or_zero(max_detection_confidence(*detections));
        append_det_boxes_json(os, *detections, max_det, total_before_cap);
    } else if (!message.empty()) {
        os << ",\"message\":\"" << json_escape(message) << "\"";
    }
    os << '}';
    return os.str();
}
