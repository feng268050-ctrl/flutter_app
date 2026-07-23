#pragma once

#include "edgedrawing_detector.h"
#include "edgedrawing_types.h"

#include <opencv2/core.hpp>

#include <string>

namespace edgedrawing {

class Context {
public:
    Context(std::string roi_json_path, double tolerance_px);

    FrameResult detectBgr(const cv::Mat& bgr);

    const RoiConfig& roi() const { return roi_; }

private:
    void ensureFrameSize(int width, int height);

    std::string roi_json_path_;
    double tolerance_px_;
    int frame_width_ = 0;
    int frame_height_ = 0;
    bool roi_loaded_ = false;
    RoiConfig roi_;
};

}  // namespace edgedrawing
