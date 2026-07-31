#pragma once

#include <opencv2/core.hpp>

#include <string>
#include <vector>

namespace stain_preprocess {

constexpr int kRoiX = 565;
constexpr int kRoiY = 110;
constexpr int kRoiSize = 700;

struct Output {
    cv::Mat rgb_u8;               ///< 640×640 RGB uint8, continuous
    std::vector<float> nchw_f32;  ///< 1×3×imgsz×imgsz RGB /255, empty if not built
};

bool PreprocessRoiResize(const cv::Mat& bgr, int imgsz, Output& out, std::string& err);
bool PreprocessLetterbox(const cv::Mat& bgr, int imgsz, Output& out, float& scale, int& pad_w, int& pad_h,
                         std::string& err);

}  // namespace stain_preprocess
