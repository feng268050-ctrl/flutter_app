#pragma once

#include "zero_point_types.h"

#include <opencv2/core.hpp>

#include <string>

namespace zero_point {

/// Single-frame zero-point detect (brightest peak in ROI). No temporal state.
/// When dump_stages_dir is non-empty, saves OpenCV intermediates under that directory.
FrameResult detectZeroPointFrame(const cv::Mat& bgr,
                                 const RoiConfig& roi,
                                 double tolerance_px,
                                 const std::string& dump_stages_dir = "",
                                 DetectTargetMode target_mode = DetectTargetMode::Point);

VideoProcessResult processVideo(const std::string& video_path,
                                const std::string& roi_json_path,
                                const std::string& out_dir,
                                double tolerance_px);

}  // namespace zero_point
