#pragma once

#include "edgedrawing_types.h"

#include <opencv2/core.hpp>

#include <optional>
#include <string>

namespace edgedrawing {

void resetScanVChannelRadialAdaptiveTemporalSmoothing();

LrDistance calcLrDistanceToBox(const Box& center_box, const Point2d& point);

EdgeDrawingDetection detectScanVChannelRadialAdaptiveInBox(
    const cv::Mat& bgr,
    const Box& center_box,
    const std::optional<Point2d>& reference_zero_xy = std::nullopt,
    const std::string& dump_stages_dir = "");

}  // namespace edgedrawing
