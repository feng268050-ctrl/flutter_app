#include "zero_point_context.h"

#include "opencv_detect_codes.h"
#include "roi_config.h"

namespace zero_point {

Context::Context(std::string roi_json_path, double tolerance_px)
    : roi_json_path_(std::move(roi_json_path)),
      tolerance_px_(tolerance_px > 0.0 ? tolerance_px : 10.0) {}

void Context::ensureFrameSize(int width, int height) {
    if (roi_loaded_ && frame_width_ == width && frame_height_ == height) {
        return;
    }
    roi_ = loadRoiConfig(roi_json_path_, width, height);
    frame_width_ = width;
    frame_height_ = height;
    roi_loaded_ = true;
}

FrameResult Context::detectBgr(const cv::Mat& bgr) {
    if (bgr.empty()) {
        FrameResult err;
        err.code = opencv_detect::kInvalidInput;
        err.ok = false;
        err.reason = opencv_detect::kReasonEmptyImage;
        return err;
    }
    ensureFrameSize(bgr.cols, bgr.rows);
    return detectZeroPointFrame(bgr, roi_, tolerance_px_, std::string{}, detect_target_mode_);
}

}  // namespace zero_point
