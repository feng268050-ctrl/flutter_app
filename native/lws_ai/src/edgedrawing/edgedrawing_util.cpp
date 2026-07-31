#include "edgedrawing_util.h"

#include <cmath>

namespace edgedrawing {
namespace {

double round2(double v) {
    return std::round(v * 100.0) / 100.0;
}

}  // namespace

std::optional<ZeroComparison> compareZeroToReference(const std::optional<Point2d>& reference_xy,
                                                     const std::optional<Point2d>& detected_xy) {
    if (!reference_xy || !detected_xy) {
        return std::nullopt;
    }
    const double dx = detected_xy->x - reference_xy->x;
    const double dy = detected_xy->y - reference_xy->y;
    ZeroComparison cmp;
    cmp.reference_zero_xy = Point2d{round2(reference_xy->x), round2(reference_xy->y)};
    cmp.detected_zero_xy = Point2d{round2(detected_xy->x), round2(detected_xy->y)};
    cmp.offset.unit = "px";
    cmp.offset.dx_px = round2(dx);
    cmp.offset.dy_px = round2(dy);
    cmp.offset.distance_px = round2(std::hypot(dx, dy));
    return cmp;
}

}  // namespace edgedrawing
