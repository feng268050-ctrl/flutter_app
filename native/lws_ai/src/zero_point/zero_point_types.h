#pragma once

#include "opencv_detect_codes.h"

#include <optional>
#include <string>
#include <vector>

namespace zero_point {

enum class DetectTargetMode {
    Point,
    Line,
};

struct Box {
    int x = 0;
    int y = 0;
    int w = 0;
    int h = 0;
};

struct Point2d {
    double x = 0.0;
    double y = 0.0;
};

struct LrDistance {
    double left_dist_px = 0.0;
    double right_dist_px = 0.0;
    double offset_x_px = 0.0;
    Point2d point_xy;
    Point2d fixed_center_xy;
};

/// Native frame error: bright blob size above kMaxSpotDimensionPx on width or height.
constexpr int kCodeSpotSizeRejected = opencv_detect::kFrameRejected;
constexpr int kMaxSpotDimensionPx = 30;

struct BrightestDetection {
    bool found = false;
    /// When found is false, non-zero reject_code is returned as JNI code (e.g. kCodeSpotSizeRejected).
    int reject_code = 0;
    std::string reason;
    Point2d center;
    int peak_x = 0;
    int peak_y = 0;
    double peak_brightness_v = 0.0;
    double peak_score = 0.0;
    std::string method = "brightest_peak_2d";
    std::optional<LrDistance> lr;
};

struct OffsetPx {
    std::string unit = "px";
    double dx_px = 0.0;
    double dy_px = 0.0;
    double distance_px = 0.0;
};

struct ZeroComparison {
    Point2d reference_zero_xy;
    Point2d detected_zero_xy;
    OffsetPx offset;
};

struct EventSummary {
    std::string final_result;
    std::string center_status;
    int best_frame_id = 0;
    double best_peak_brightness = 0.0;
};

struct CalibrationGate {
    double left_dist_px = 0.0;
    double right_dist_px = 0.0;
    double center_offset_x_px = 0.0;
    std::string center_status;
    bool passed = false;
    double tolerance_px = 10.0;
};

/// Per-frame detect result (stateless; App owns temporal logic).
struct FrameResult {
    int code = 0;
    bool ok = false;
    std::string reason;
    double sat_ratio = 0.0;
    double mean_v = 0.0;
    std::optional<BrightestDetection> zero_point;
    std::optional<LrDistance> lr;
    std::optional<CalibrationGate> calibration;
    std::optional<ZeroComparison> comparison;
};

struct EventRecord {
    int frame_id = 0;
    int best_frame_id = 0;
    std::optional<EventSummary> summary;
    std::optional<LrDistance> lr;
    std::optional<CalibrationGate> calibration;
    std::optional<ZeroComparison> comparison;
};

struct RoiConfig {
    Box center_box;
    Point2d fixed_center_xy;
    std::optional<Point2d> reference_zero_xy;
    int source_width = 0;
    int source_height = 0;
};

struct VideoProcessResult {
    bool ok = false;
    std::string video_path;
    Box center_box;
    Point2d fixed_center_xy;
    std::optional<Point2d> reference_zero_xy;
    Box visual_detection_box;
    double visual_detection_line_y_ratio = 0.0;
    std::vector<EventRecord> events;
    std::optional<Point2d> detected_zero_xy;
    std::optional<OffsetPx> offset;
    std::string output_video_path;
    std::string output_json_path;
};

}  // namespace zero_point
