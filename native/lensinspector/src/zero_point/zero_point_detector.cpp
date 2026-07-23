#include "zero_point_detector.h"

#include "brightest_in_box.h"
#include "brightest_line_in_box.h"
#include "opencv_detect_codes.h"
#include "red_frame_validator.h"
#include "roi_config.h"
#include "zero_point_json.h"
#include "zero_point_util.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/videoio.hpp>

#include <algorithm>
#include <cmath>
#include <cerrno>
#include <cstring>
#include <fstream>

#include "../fscompat.h"
#include <iomanip>
#include <sstream>
#include <sys/stat.h>
#include <sys/types.h>

namespace {

void exposureMetrics(const cv::Mat& bgr, const zero_point::Box& center_box, double& sat_ratio, double& mean_v) {
    sat_ratio = 0.0;
    mean_v = 0.0;
    if (bgr.empty()) {
        return;
    }
    const int frame_w = bgr.cols;
    const int frame_h = bgr.rows;
    int x = std::max(0, std::min(center_box.x, frame_w - 1));
    int y = std::max(0, std::min(center_box.y, frame_h - 1));
    int bw = std::max(1, std::min(center_box.w, frame_w - x));
    int bh = std::max(1, std::min(center_box.h, frame_h - y));
    const cv::Mat roi = bgr(cv::Rect(x, y, bw, bh));
    if (roi.empty()) {
        return;
    }
    cv::Mat hsv;
    cv::cvtColor(roi, hsv, cv::COLOR_BGR2HSV);
    std::vector<cv::Mat> channels;
    cv::split(hsv, channels);
    cv::Mat v = channels[2];
    cv::Mat saturated;
    cv::compare(v, 245, saturated, cv::CMP_GT);
    sat_ratio = static_cast<double>(cv::countNonZero(saturated)) /
                static_cast<double>(std::max(1, v.rows * v.cols));
    mean_v = cv::mean(v)[0];
}

std::string path_stem(const std::string& path) {
    std::string name = path;
    const std::string::size_type slash = name.find_last_of('/');
    if (slash != std::string::npos) {
        name = name.substr(slash + 1);
    }
    const std::string::size_type dot = name.find_last_of('.');
    if (dot != std::string::npos && dot != 0) {
        name = name.substr(0, dot);
    }
    return name;
}

bool mkdir_p(const std::string& dir) {
    if (dir.empty()) {
        return false;
    }
    std::string path = dir;
    while (path.size() > 1 && path.back() == '/') {
        path.pop_back();
    }
    std::string cur;
    cur.reserve(path.size());
    for (std::string::size_type i = 0; i < path.size(); ++i) {
        const char c = path[i];
        cur.push_back(c);
        if (c != '/' && i + 1 != path.size()) {
            continue;
        }
        if (cur.size() == 1 && cur[0] == '/') {
            continue;
        }
        if (::mkdir(cur.c_str(), 0755) != 0 && errno != EEXIST) {
            return false;
        }
    }
    if (::mkdir(cur.c_str(), 0755) != 0 && errno != EEXIST) {
        return false;
    }
    return true;
}

std::string join_path(const std::string& a, const std::string& b) {
    if (a.empty()) {
        return b;
    }
    if (a.back() == '/') {
        return a + b;
    }
    return a + "/" + b;
}

void drawReferenceCrosshairs(cv::Mat& vis, int ref_x, int ref_y, const cv::Scalar& color, int thickness = 2) {
    if (vis.empty()) {
        return;
    }
    const int w = vis.cols;
    const int h = vis.rows;
    cv::line(vis, cv::Point(0, ref_y), cv::Point(w - 1, ref_y), color, thickness, cv::LINE_AA);
    cv::line(vis, cv::Point(ref_x, 0), cv::Point(ref_x, h - 1), color, thickness, cv::LINE_AA);
}

void drawReferenceMarker(cv::Mat& vis, int ref_x, int ref_y) {
    constexpr int kAxisThickness = 1;
    constexpr int kRefCircleRadius = 8;
    constexpr int kRefCircleThickness = 2;
    const cv::Scalar axis_color(0, 255, 255);
    drawReferenceCrosshairs(vis, ref_x, ref_y, axis_color, kAxisThickness);
    cv::circle(vis, cv::Point(ref_x, ref_y), kRefCircleRadius, axis_color, kRefCircleThickness, cv::LINE_AA);
}

void drawDetectedMarker(cv::Mat& vis, int px, int py) {
    constexpr int kDetCircleRadius = 9;
    constexpr int kDetCircleThickness = 2;
    cv::circle(vis, cv::Point(px, py), kDetCircleRadius, cv::Scalar(0, 255, 0), kDetCircleThickness, cv::LINE_AA);
}

cv::Mat drawZeroOverlay(const cv::Mat& frame,
                        const zero_point::RoiConfig& roi,
                        const zero_point::FrameResult& result,
                        int frame_index) {
    cv::Mat vis = frame.clone();
    const zero_point::Box& box = roi.center_box;

    cv::rectangle(vis,
                  cv::Rect(box.x, box.y, box.w, box.h),
                  cv::Scalar(0, 255, 255),
                  2);
    if (roi.reference_zero_xy) {
        const int ref_x = static_cast<int>(std::lround(roi.reference_zero_xy->x));
        const int ref_y = static_cast<int>(std::lround(roi.reference_zero_xy->y));
        drawReferenceMarker(vis, ref_x, ref_y);
    }

    if (result.zero_point && result.zero_point->found) {
        const zero_point::BrightestDetection& det = *result.zero_point;
        drawDetectedMarker(vis, det.peak_x, det.peak_y);
        std::ostringstream caption;
        caption << "f=" << frame_index << " peak=(" << det.peak_x << "," << det.peak_y << ")";
        cv::putText(vis,
                    caption.str(),
                    cv::Point(30, std::max(30, vis.rows - 30)),
                    cv::FONT_HERSHEY_SIMPLEX,
                    0.8,
                    cv::Scalar(0, 255, 0),
                    2,
                    cv::LINE_AA);
    }

    return vis;
}

void writeRedGateSummary(const std::string& path, const opencv_detect::RedFrameValidation& red_gate) {
    std::ofstream out(path);
    if (!out) {
        return;
    }
    const char* verdict = "unknown";
    switch (red_gate.verdict) {
        case opencv_detect::RedFrameVerdict::ValidRed:
            verdict = "valid_red";
            break;
        case opencv_detect::RedFrameVerdict::Overexposed:
            verdict = "overexposed";
            break;
        case opencv_detect::RedFrameVerdict::InvalidNonRed:
            verdict = "invalid_non_red";
            break;
        case opencv_detect::RedFrameVerdict::NoValidRegion:
            verdict = "no_valid_region";
            break;
        case opencv_detect::RedFrameVerdict::EmptyRoi:
            verdict = "empty_roi";
            break;
    }
    out << "verdict=" << verdict << '\n';
    if (red_gate.reason_token != nullptr) {
        out << "reason=" << red_gate.reason_token << '\n';
    }
    out << "gray_mean=" << red_gate.metrics.gray_mean << '\n';
    out << "overexposed_ratio=" << red_gate.metrics.overexposed_ratio << '\n';
    out << "red_ratio=" << red_gate.metrics.red_ratio << '\n';
    out << "purple_ratio=" << red_gate.metrics.purple_ratio << '\n';
    out << "sat_mean=" << red_gate.metrics.sat_mean << '\n';
    out << "val_mean=" << red_gate.metrics.val_mean << '\n';
}

}  // namespace

namespace zero_point {

FrameResult detectZeroPointFrame(const cv::Mat& bgr,
                                 const RoiConfig& roi,
                                 double tolerance_px,
                                 const std::string& dump_stages_dir,
                                 DetectTargetMode target_mode) {
    FrameResult output;
    output.code = 0;
    output.ok = true;

    const bool dump_stages = !dump_stages_dir.empty();
    if (dump_stages) {
        fscompat::makedirs(dump_stages_dir);
        cv::imwrite(dump_stages_dir + "/00_input_bgr.jpg", bgr);
        cv::Mat roi_outline = bgr.clone();
        const zero_point::Box& box = roi.center_box;
        cv::rectangle(roi_outline,
                      cv::Rect(box.x, box.y, box.w, box.h),
                      cv::Scalar(0, 255, 255),
                      2);
        if (roi.reference_zero_xy) {
            const int ref_x = static_cast<int>(std::lround(roi.reference_zero_xy->x));
            const int ref_y = static_cast<int>(std::lround(roi.reference_zero_xy->y));
            drawReferenceMarker(roi_outline, ref_x, ref_y);
        }
        cv::imwrite(dump_stages_dir + "/04_roi_outline.jpg", roi_outline);
    }

    const opencv_detect::RedFrameValidation red_gate = opencv_detect::validateRedFrameMaskOnly(
        bgr, dump_stages ? dump_stages_dir : std::string{});
    if (dump_stages) {
        writeRedGateSummary(dump_stages_dir + "/00_red_gate.txt", red_gate);
    }
    if (red_gate.verdict != opencv_detect::RedFrameVerdict::ValidRed) {
        output.ok = false;
        output.code = opencv_detect::kFrameRejected;
        output.reason = red_gate.reason_token != nullptr ? red_gate.reason_token
                                                         : opencv_detect::kReasonInvalidNonRed;
        if (!dump_stages) {
            return output;
        }
    }

    exposureMetrics(bgr, roi.center_box, output.sat_ratio, output.mean_v);

    BrightestDetection detection = target_mode == DetectTargetMode::Line
                                       ? detectBrightestLineInBox(bgr, roi.center_box, dump_stages_dir)
                                       : detectBrightestPointInBox(bgr, roi.center_box, dump_stages_dir);
    if (!detection.found) {
        output.code = detection.reject_code != 0 ? detection.reject_code : opencv_detect::kDetectFailed;
        output.ok = false;
        output.reason = detection.reason.empty() ? opencv_detect::kReasonBlackBlobNotFound : detection.reason;
        if (dump_stages) {
            cv::imwrite(dump_stages_dir + "/11_detect_overlay.jpg",
                        drawZeroOverlay(bgr, roi, output, 1));
        }
        return output;
    }

    output.zero_point = detection;
    if (detection.lr) {
        output.lr = *detection.lr;
    }

    output.comparison = compareZeroToReference(roi.reference_zero_xy, detection.center);
    if (!output.comparison) {
        output.code = opencv_detect::kConfigError;
        output.ok = false;
        output.reason = opencv_detect::kReasonMissingReferenceZero;
        output.zero_point.reset();
        if (dump_stages) {
            cv::imwrite(dump_stages_dir + "/11_detect_overlay.jpg",
                        drawZeroOverlay(bgr, roi, output, 1));
        }
        return output;
    }
    if (red_gate.verdict != opencv_detect::RedFrameVerdict::ValidRed) {
        output.ok = false;
        output.code = opencv_detect::kFrameRejected;
        output.reason = red_gate.reason_token != nullptr ? red_gate.reason_token
                                                         : opencv_detect::kReasonInvalidNonRed;
        output.zero_point.reset();
        output.comparison.reset();
        if (dump_stages) {
            cv::imwrite(dump_stages_dir + "/11_detect_overlay.jpg",
                        drawZeroOverlay(bgr, roi, output, 1));
        }
        return output;
    }
    output.ok = true;
    output.code = 0;
    if (dump_stages) {
        cv::imwrite(dump_stages_dir + "/11_detect_overlay.jpg",
                    drawZeroOverlay(bgr, roi, output, 1));
    }
    (void)tolerance_px;
    return output;
}

VideoProcessResult processVideo(const std::string& video_path,
                                const std::string& roi_json_path,
                                const std::string& out_dir,
                                double tolerance_px) {
    VideoProcessResult result;
    result.video_path = video_path;

    cv::VideoCapture cap(video_path);
    if (!cap.isOpened()) {
        result.ok = false;
        return result;
    }

    const int frame_w = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_WIDTH));
    const int frame_h = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_HEIGHT));
    const RoiConfig roi = loadRoiConfig(roi_json_path, frame_w, frame_h);
    result.center_box = roi.center_box;
    result.fixed_center_xy = roi.fixed_center_xy;
    result.reference_zero_xy = roi.reference_zero_xy;
    result.visual_detection_box = roi.center_box;
    result.visual_detection_line_y_ratio = 0.0;

    (void)mkdir_p(out_dir);
    const std::string stem = path_stem(video_path);
    result.output_video_path = join_path(out_dir, stem + "_zero.mp4");
    result.output_json_path = join_path(out_dir, stem + "_zero_result.json");

    cv::VideoWriter writer;
    bool write_overlay = false;
    double fps = cap.get(cv::CAP_PROP_FPS);
    if (fps <= 1e-3 || !std::isfinite(fps)) {
        fps = 25.0;
    }
    if (frame_w > 0 && frame_h > 0) {
        write_overlay = writer.open(result.output_video_path,
                                    cv::VideoWriter::fourcc('m', 'p', '4', 'v'),
                                    fps,
                                    cv::Size(frame_w, frame_h));
        if (!write_overlay) {
            result.output_video_path.clear();
        }
    }

    std::vector<EventRecord> events;
    int frame_index = 0;

    cv::Mat frame;
    while (cap.read(frame)) {
        ++frame_index;
        const FrameResult frame_result = detectZeroPointFrame(frame, roi, tolerance_px);
        if (write_overlay) {
            writer.write(drawZeroOverlay(frame, roi, frame_result, frame_index));
        }
        if (!frame_result.ok || !frame_result.zero_point) {
            continue;
        }
        EventRecord record;
        record.frame_id = frame_index;
        record.best_frame_id = frame_index;
        record.lr = frame_result.lr;
        record.comparison = frame_result.comparison;
        EventSummary summary;
        summary.best_frame_id = frame_index;
        summary.best_peak_brightness = frame_result.zero_point->peak_brightness_v;
        summary.center_status = "ok";
        summary.final_result = "OK";
        record.summary = summary;
        events.push_back(std::move(record));
    }
    if (write_overlay) {
        writer.release();
    }

    result.events = std::move(events);
    result.ok = true;

    if (!events.empty() && events.back().comparison) {
        result.detected_zero_xy = events.back().comparison->detected_zero_xy;
        result.offset = events.back().comparison->offset;
    }

    writeVideoResultJson(result.output_json_path, result, roi_json_path);
    return result;
}

}  // namespace zero_point
