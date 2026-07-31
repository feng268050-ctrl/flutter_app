#pragma once

#include "zero_point_types.h"

#include <opencv2/core.hpp>

#include <string>

namespace zero_point {

BrightestDetection detectBrightestLineInBox(const cv::Mat& bgr,
                                            const Box& center_box,
                                            const std::string& dump_stages_dir = "");

}  // namespace zero_point
