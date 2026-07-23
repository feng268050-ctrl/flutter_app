#pragma once

#include "zero_point_types.h"

#include <string>

namespace zero_point {

RoiConfig loadRoiConfig(const std::string& roi_json_path, int frame_width, int frame_height);

Box scaleBoxToFrame(const Box& box, int source_width, int source_height, int frame_width, int frame_height);

std::optional<Point2d> scaleReferenceZero(const Point2d& ref,
                                          int source_width,
                                          int source_height,
                                          int frame_width,
                                          int frame_height);

}  // namespace zero_point
