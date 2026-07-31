#pragma once

#include "zero_point_types.h"

#include <opencv2/core.hpp>

#include <string>

namespace zero_point {

LrDistance calcLrDistanceToBox(const Box& center_box, const Point2d& point);

BrightestDetection detectBrightestPointInBox(const cv::Mat& bgr,
                                             const Box& center_box,
                                             const std::string& dump_stages_dir = "");

}  // namespace zero_point
