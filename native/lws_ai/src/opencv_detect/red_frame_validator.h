#pragma once

#include <opencv2/core.hpp>

#include <string>

namespace opencv_detect {

struct RedFrameMetrics {
    double gray_mean = 0.0;
    double overexposed_ratio = 0.0;
    double red_ratio = 0.0;
    double purple_ratio = 0.0;
    double blue_ratio = 0.0;
    double sat_mean = 0.0;
    double val_mean = 0.0;
};

enum class RedFrameVerdict {
    ValidRed,
    ValidBlue,
    Overexposed,
    InvalidNonRed,
    NoValidRegion,
    EmptyRoi,
};

struct RedFrameValidation {
    RedFrameVerdict verdict = RedFrameVerdict::NoValidRegion;
    const char* reason_token = nullptr;
    RedFrameMetrics metrics;
};

/// Mask-only gate for zero_point: bright-region contour + erosion; no OSD crop or color reject.
RedFrameValidation validateRedFrameMaskOnly(const cv::Mat& bgr,
                                              const std::string& dump_stages_dir = "");

/// Full-frame red / overexposure gate for edgedrawing and lens_det.
/// When dump_stages_dir is non-empty, saves gray / mask intermediates under that directory.
RedFrameValidation validateRedFrame(const cv::Mat& bgr, const std::string& dump_stages_dir = "");

void setRedFrameGateEnabled(bool enabled);
bool isRedFrameGateEnabled();

}  // namespace opencv_detect
