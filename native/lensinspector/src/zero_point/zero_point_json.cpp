#include "zero_point_json.h"

#include "opencv_detect_json.h"
#include "zero_point_util.h"

#include <fstream>
#include <iomanip>
#include <sstream>

namespace zero_point {
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

void appendPoint2(std::ostringstream& out, const Point2d& p) {
    out << std::fixed << std::setprecision(2);
    out << '[' << p.x << ',' << p.y << ']';
}

void appendBox(std::ostringstream& out, const Box& box) {
    out << '[' << box.x << ',' << box.y << ',' << box.w << ',' << box.h << ']';
}

void appendOffset(std::ostringstream& out, const OffsetPx& offset) {
    out << std::fixed << std::setprecision(2);
    out << "{\"unit\":\"px\""
        << ",\"dx_px\":" << offset.dx_px << ",\"dy_px\":" << offset.dy_px
        << ",\"distance_px\":" << offset.distance_px << '}';
}

void appendLr(std::ostringstream& out, const LrDistance& lr) {
    out << std::fixed << std::setprecision(2);
    out << '{';
    out << "\"left_dist_px\":" << lr.left_dist_px;
    out << ",\"right_dist_px\":" << lr.right_dist_px;
    out << ",\"offset_x_px\":" << lr.offset_x_px;
    out << ",\"point_xy\":";
    appendPoint2(out, lr.point_xy);
    out << ",\"fixed_center_xy\":";
    appendPoint2(out, lr.fixed_center_xy);
    out << '}';
}

void appendBrightest(std::ostringstream& out, const BrightestDetection& det) {
    out << '{';
    out << "\"found\":true";
    out << ",\"center\":{\"x\":" << det.center.x << ",\"y\":" << det.center.y << '}';
    out << ",\"peak_xy\":[" << det.peak_x << ',' << det.peak_y << ']';
    out << ",\"peak_brightness_v\":" << det.peak_brightness_v;
    out << ",\"peak_score\":" << det.peak_score;
    out << ",\"method\":\"" << jsonEscape(det.method) << '"';
    if (det.lr) {
        out << ",\"lr\":";
        appendLr(out, *det.lr);
    }
    out << '}';
}

void appendComparison(std::ostringstream& out, const ZeroComparison& cmp) {
    out << "\"reference_zero_xy\":";
    appendPoint2(out, cmp.reference_zero_xy);
    out << ",\"detected_zero_xy\":";
    appendPoint2(out, cmp.detected_zero_xy);
    out << ",\"offset\":";
    appendOffset(out, cmp.offset);
}

void appendEvent(std::ostringstream& out, const EventRecord& event) {
    out << '{';
    out << "\"frame_id\":" << event.frame_id;
    out << ",\"best_frame_id\":" << event.best_frame_id;
    if (event.summary) {
        out << ",\"summary\":{";
        out << "\"final_result\":\"" << jsonEscape(event.summary->final_result) << '"';
        out << ",\"center_status\":\"" << jsonEscape(event.summary->center_status) << '"';
        out << ",\"best_frame_id\":" << event.summary->best_frame_id;
        out << ",\"best_peak_brightness\":" << event.summary->best_peak_brightness;
        out << '}';
    }
    if (event.lr) {
        out << ",\"lr\":";
        appendLr(out, *event.lr);
    }
    if (event.calibration) {
        out << ",\"calibration\":{";
        out << "\"left_dist_px\":" << event.calibration->left_dist_px;
        out << ",\"right_dist_px\":" << event.calibration->right_dist_px;
        out << ",\"center_offset_x_px\":" << event.calibration->center_offset_x_px;
        out << ",\"center_status\":\"" << jsonEscape(event.calibration->center_status) << '"';
        out << ",\"passed\":" << (event.calibration->passed ? "true" : "false");
        out << ",\"tolerance_px\":" << event.calibration->tolerance_px;
        out << '}';
    }
    if (event.comparison) {
        out << ',';
        appendComparison(out, *event.comparison);
    } else if (event.comparison.has_value() == false) {
        if (!event.comparison) {
            // no comparison block
        }
    }
    out << '}';
}

}  // namespace

std::string errorJson(int code, const std::string& reason) {
    return opencv_detect::zeroPointFailureJson(code, reason);
}

std::string frameResultToJson(const FrameResult& result,
                              const std::optional<Point2d>& /*reference_zero_xy*/) {
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
        << ",\"offset_y\":" << offset_y << '}';
    return out.str();
}

std::string videoResultToJson(const VideoProcessResult& result, const std::string& roi_json_path) {
    std::ostringstream out;
    out << std::fixed << std::setprecision(2);
    out << '{';
    out << "\"ok\":" << (result.ok ? "true" : "false");
    out << ",\"video\":\"" << jsonEscape(result.video_path) << '"';
    out << ",\"center_box_xywh\":[" << result.center_box.x << ',' << result.center_box.y << ','
        << result.center_box.w << ',' << result.center_box.h << ']';
    out << ",\"fixed_center_xy\":";
    appendPoint2(out, result.fixed_center_xy);
    out << ",\"visual_detection_box_xywh\":";
    appendBox(out, result.visual_detection_box);
    out << ",\"visual_detection_line_y_ratio\":" << result.visual_detection_line_y_ratio;
    if (result.reference_zero_xy) {
        out << ",\"reference_zero_xy\":";
        appendPoint2(out, *result.reference_zero_xy);
    } else {
        out << ",\"reference_zero_xy\":null";
    }
    out << ",\"roi_json\":\"" << jsonEscape(roi_json_path) << '"';
    if (!result.output_video_path.empty()) {
        out << ",\"output_video\":\"" << jsonEscape(result.output_video_path) << '"';
    }
    if (!result.output_json_path.empty()) {
        out << ",\"output_json\":\"" << jsonEscape(result.output_json_path) << '"';
    }
    out << ",\"event_count\":" << result.events.size();
    out << ",\"events\":[";
    for (std::size_t i = 0; i < result.events.size(); ++i) {
        if (i > 0) {
            out << ',';
        }
        appendEvent(out, result.events[i]);
    }
    out << ']';
    if (result.detected_zero_xy && result.offset) {
        out << ",\"detected_zero_xy\":";
        appendPoint2(out, *result.detected_zero_xy);
        out << ",\"offset\":";
        appendOffset(out, *result.offset);
    }
    out << '}';
    return out.str();
}

void writeVideoResultJson(const std::string& path,
                          const VideoProcessResult& result,
                          const std::string& roi_json_path) {
    std::ofstream out(path);
    out << videoResultToJson(result, roi_json_path);
}

}  // namespace zero_point
