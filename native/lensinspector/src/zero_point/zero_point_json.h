#pragma once

#include "zero_point_types.h"

#include <string>

namespace zero_point {

std::string frameResultToJson(const FrameResult& result,
                                const std::optional<Point2d>& reference_zero_xy = std::nullopt);

std::string errorJson(int code, const std::string& reason);

void writeVideoResultJson(const std::string& path,
                          const VideoProcessResult& result,
                          const std::string& roi_json_path);

std::string videoResultToJson(const VideoProcessResult& result, const std::string& roi_json_path);

}  // namespace zero_point
