#pragma once

#include "edgedrawing_types.h"

#include <optional>

namespace edgedrawing {

std::optional<ZeroComparison> compareZeroToReference(const std::optional<Point2d>& reference_xy,
                                                     const std::optional<Point2d>& detected_xy);

}  // namespace edgedrawing
