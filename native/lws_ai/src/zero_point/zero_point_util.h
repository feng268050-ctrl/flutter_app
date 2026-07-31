#pragma once

#include "zero_point_types.h"

#include <optional>

namespace zero_point {

std::optional<Point2d> pointFromDetection(const std::optional<BrightestDetection>& det);

std::optional<ZeroComparison> compareZeroToReference(const std::optional<Point2d>& reference_xy,
                                                     const std::optional<Point2d>& detected_xy);

}  // namespace zero_point
