#pragma once

#include "opencv_detect_codes.h"

#include <optional>
#include <string>
#include <vector>

namespace edgedrawing {

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

constexpr int kCodeSpotSizeRejected = opencv_detect::kFrameRejected;
constexpr int kCodeCircleRadiusRejected = opencv_detect::kFrameRejected;
constexpr int kMaxSpotDimensionPx = 30;
constexpr int kMinSpotDimensionPx = 10;
/// minEnclosingCircle radius must be >= this value or frame is rejected (code=-5).
constexpr int kMinEnclosingCircleRadiusPx = 300;

/** minEnclosingCircle on deburred mask; center is the EdgeDrawing base point. */
struct CircleFit {
    double base_x = 0.0;
    double base_y = 0.0;
    double radius = 0.0;
};

struct EdgeDrawingDetection {
    bool found = false;
    int reject_code = 0;
    std::string reason;
    Point2d center;
    int peak_x = 0;
    int peak_y = 0;
    int anchor_w = 0;
    int anchor_h = 0;
    std::string method = "ximgproc_edge_drawing";
    std::optional<LrDistance> lr;
    std::optional<CircleFit> circle_fit;
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

struct FrameResult {
    int code = 0;
    bool ok = false;
    std::string reason;
    double sat_ratio = 0.0;
    double mean_v = 0.0;
    std::optional<EdgeDrawingDetection> zero_point;
    std::optional<LrDistance> lr;
    std::optional<ZeroComparison> comparison;
    std::optional<CircleFit> circle_fit;
};

struct RoiConfig {
    Box center_box;
    Point2d fixed_center_xy;
    std::optional<Point2d> reference_zero_xy;
    int source_width = 0;
    int source_height = 0;
};

}  // namespace edgedrawing
