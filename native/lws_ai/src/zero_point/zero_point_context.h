#pragma once

#include <opencv2/core.hpp>

#include "roi_config.h"
#include "zero_point_detector.h"
#include "zero_point_types.h"

#include <string>

namespace zero_point {

/// Holds ROI config loaded from JSON; each detect call is stateless per frame.
class Context {
public:
    Context(std::string roi_json_path, double tolerance_px);

    FrameResult detectBgr(const cv::Mat& bgr);

    void setDetectTargetMode(DetectTargetMode mode) { detect_target_mode_ = mode; }

    DetectTargetMode detectTargetMode() const { return detect_target_mode_; }

    const RoiConfig& roi() const { return roi_; }

private:
    void ensureFrameSize(int width, int height);

    std::string roi_json_path_;
    double tolerance_px_;
    int frame_width_ = 0;
    int frame_height_ = 0;
    bool roi_loaded_ = false;
    RoiConfig roi_;
    DetectTargetMode detect_target_mode_ = DetectTargetMode::Point;
};

}  // namespace zero_point
