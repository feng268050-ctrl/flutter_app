#pragma once

#include "zero_point_types.h"

#include <opencv2/core.hpp>

#include <string>

namespace zero_point {

struct RoiCrop {
    cv::Mat roi_bgr;
    int x = 0;
    int y = 0;
};

RoiCrop cropRoiBgr(const cv::Mat& bgr, const Box& center_box);

void saveRoiStage(const std::string& dump_dir, const std::string& name, const cv::Mat& img);

cv::Mat brightnessEnhanceRoi(const cv::Mat& roi_bgr);

cv::Mat enhancedGrayRoi(const cv::Mat& roi_bgr);

}  // namespace zero_point
