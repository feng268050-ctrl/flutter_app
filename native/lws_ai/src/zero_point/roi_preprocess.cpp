#include "roi_preprocess.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

namespace zero_point {

RoiCrop cropRoiBgr(const cv::Mat& bgr, const Box& center_box) {
    RoiCrop out;
    if (bgr.empty()) {
        return out;
    }
    const int frame_w = bgr.cols;
    const int frame_h = bgr.rows;
    out.x = std::max(0, std::min(center_box.x, frame_w - 1));
    out.y = std::max(0, std::min(center_box.y, frame_h - 1));
    const int bw = std::max(1, std::min(center_box.w, frame_w - out.x));
    const int bh = std::max(1, std::min(center_box.h, frame_h - out.y));
    out.roi_bgr = bgr(cv::Rect(out.x, out.y, bw, bh));
    return out;
}

void saveRoiStage(const std::string& dump_dir, const std::string& name, const cv::Mat& img) {
    if (dump_dir.empty() || img.empty()) {
        return;
    }
    cv::imwrite(dump_dir + "/" + name, img);
}

cv::Mat brightnessEnhanceRoi(const cv::Mat& roi_bgr) {
    cv::Mat hsv;
    cv::cvtColor(roi_bgr, hsv, cv::COLOR_BGR2HSV);
    std::vector<cv::Mat> channels;
    cv::split(hsv, channels);
    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(2.5, cv::Size(8, 8));
    clahe->apply(channels[2], channels[2]);
    cv::merge(channels, hsv);
    cv::Mat enhanced;
    cv::cvtColor(hsv, enhanced, cv::COLOR_HSV2BGR);
    enhanced.convertTo(enhanced, -1, 1.15, 12.0);
    return enhanced;
}

cv::Mat enhancedGrayRoi(const cv::Mat& roi_bgr) {
    const cv::Mat enhanced = brightnessEnhanceRoi(roi_bgr);
    cv::Mat gray;
    cv::cvtColor(enhanced, gray, cv::COLOR_BGR2GRAY);
    return gray;
}

}  // namespace zero_point
