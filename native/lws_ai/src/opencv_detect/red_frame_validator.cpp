#include "red_frame_validator.h"

#include "opencv_detect_codes.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include <algorithm>

namespace opencv_detect {
namespace {

constexpr double kOverexposedRatioThreshold = 0.5;
constexpr double kGrayMeanMax = 230.0;
constexpr int kOverexposedGrayLevel = 245;
constexpr double kRedRatioMin = 0.4;
constexpr double kPurpleRatioMax = 0.70;
constexpr double kRedPurpleMargin = 0.08;
constexpr double kSatMeanMin = 120.0;
constexpr double kValMeanMin = 70.0;
constexpr double kPurplePlasmaRatioMin = 0.45;
constexpr double kPurplePlasmaRedRatioMax = 0.10;
constexpr double kBlueRatioMin = 0.40;
constexpr double kBlueFrameRedRatioMax = 0.15;
constexpr int kBlueHueLo = 85;
constexpr int kBlueHueHi = 130;
constexpr int kGrayMaskThreshold = 20;
constexpr int kErodeKernelSize = 21;

bool g_red_frame_gate_enabled = true;

struct RoiMaskResult {
    enum class Status {
        Ok,
        NoValidRegion,
        EmptyRoi,
    };

    Status status = Status::NoValidRegion;
    RedFrameMetrics metrics;
};

RedFrameValidation makeValidation(RedFrameVerdict verdict, const char* reason, const RedFrameMetrics& metrics) {
    RedFrameValidation out;
    out.verdict = verdict;
    out.reason_token = reason;
    out.metrics = metrics;
    return out;
}

double channelMean(const cv::Mat& channel, const cv::Mat& mask) {
    return cv::mean(channel, mask)[0];
}

double maskedFractionAbove(const cv::Mat& gray, const cv::Mat& mask, int threshold) {
    cv::Mat above;
    cv::compare(gray, threshold, above, cv::CMP_GT);
    cv::Mat combined;
    cv::bitwise_and(above, mask, combined);
    const int masked = cv::countNonZero(mask);
    if (masked <= 0) {
        return 0.0;
    }
    return static_cast<double>(cv::countNonZero(combined)) / static_cast<double>(masked);
}

double maskedHueRedRatio(const cv::Mat& hue, const cv::Mat& mask) {
    cv::Mat low_red;
    cv::Mat high_red;
    cv::compare(hue, 10, low_red, cv::CMP_LT);
    cv::compare(hue, 170, high_red, cv::CMP_GT);
    cv::Mat red_mask;
    cv::bitwise_or(low_red, high_red, red_mask);
    cv::Mat combined;
    cv::bitwise_and(red_mask, mask, combined);
    const int masked = cv::countNonZero(mask);
    if (masked <= 0) {
        return 0.0;
    }
    return static_cast<double>(cv::countNonZero(combined)) / static_cast<double>(masked);
}

double maskedHuePurpleRatio(const cv::Mat& hue, const cv::Mat& mask) {
    cv::Mat above;
    cv::Mat below;
    cv::compare(hue, 125, above, cv::CMP_GT);
    cv::compare(hue, 165, below, cv::CMP_LT);
    cv::Mat purple_mask;
    cv::bitwise_and(above, below, purple_mask);
    cv::Mat combined;
    cv::bitwise_and(purple_mask, mask, combined);
    const int masked = cv::countNonZero(mask);
    if (masked <= 0) {
        return 0.0;
    }
    return static_cast<double>(cv::countNonZero(combined)) / static_cast<double>(masked);
}

double maskedHueBlueRatio(const cv::Mat& hue, const cv::Mat& mask) {
    cv::Mat lo_ok;
    cv::Mat hi_ok;
    cv::compare(hue, kBlueHueLo, lo_ok, cv::CMP_GT);
    cv::compare(hue, kBlueHueHi, hi_ok, cv::CMP_LT);
    cv::Mat blue_mask;
    cv::bitwise_and(lo_ok, hi_ok, blue_mask);
    cv::Mat combined;
    cv::bitwise_and(blue_mask, mask, combined);
    const int masked = cv::countNonZero(mask);
    if (masked <= 0) {
        return 0.0;
    }
    return static_cast<double>(cv::countNonZero(combined)) / static_cast<double>(masked);
}

RoiMaskResult buildErodedRoiMask(const cv::Mat& bgr, const std::string& dump_stages_dir) {
    RoiMaskResult result;
    if (bgr.empty() || bgr.type() != CV_8UC3) {
        return result;
    }

    const bool dump_stages = !dump_stages_dir.empty();

    cv::Mat gray;
    cv::Mat hsv;
    cv::cvtColor(bgr, gray, cv::COLOR_BGR2GRAY);
    cv::cvtColor(bgr, hsv, cv::COLOR_BGR2HSV);
    if (dump_stages) {
        cv::imwrite(dump_stages_dir + "/01_gray.jpg", gray);
    }

    cv::Mat mask;
    cv::compare(gray, kGrayMaskThreshold, mask, cv::CMP_GT);
    if (dump_stages) {
        cv::imwrite(dump_stages_dir + "/02_gray_mask_gt20.jpg", mask);
    }

    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(mask, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    if (contours.empty()) {
        result.status = RoiMaskResult::Status::NoValidRegion;
        return result;
    }

    const auto max_it = std::max_element(
        contours.begin(),
        contours.end(),
        [](const std::vector<cv::Point>& a, const std::vector<cv::Point>& b) {
            return cv::contourArea(a) < cv::contourArea(b);
        });

    cv::Mat roi_mask = cv::Mat::zeros(gray.size(), CV_8UC1);
    cv::drawContours(
        roi_mask,
        contours,
        static_cast<int>(std::distance(contours.begin(), max_it)),
        cv::Scalar(255),
        cv::FILLED);

    const cv::Mat erode_kernel =
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(kErodeKernelSize, kErodeKernelSize));
    cv::erode(roi_mask, roi_mask, erode_kernel, cv::Point(-1, -1), 1);
    if (dump_stages) {
        cv::imwrite(dump_stages_dir + "/03_roi_mask_eroded.jpg", roi_mask);
    }

    if (cv::countNonZero(roi_mask) <= 0) {
        result.status = RoiMaskResult::Status::EmptyRoi;
        return result;
    }

    std::vector<cv::Mat> hsv_channels;
    cv::split(hsv, hsv_channels);

    result.metrics.gray_mean = channelMean(gray, roi_mask);
    result.metrics.sat_mean = channelMean(hsv_channels[1], roi_mask);
    result.metrics.val_mean = channelMean(hsv_channels[2], roi_mask);
    result.metrics.overexposed_ratio = maskedFractionAbove(gray, roi_mask, kOverexposedGrayLevel);
    result.metrics.red_ratio = maskedHueRedRatio(hsv_channels[0], roi_mask);
    result.metrics.purple_ratio = maskedHuePurpleRatio(hsv_channels[0], roi_mask);
    result.metrics.blue_ratio = maskedHueBlueRatio(hsv_channels[0], roi_mask);
    result.status = RoiMaskResult::Status::Ok;
    return result;
}

}  // namespace

void setRedFrameGateEnabled(bool enabled) {
    g_red_frame_gate_enabled = enabled;
}

bool isRedFrameGateEnabled() {
    return g_red_frame_gate_enabled;
}

RedFrameValidation validateRedFrameMaskOnly(const cv::Mat& bgr, const std::string& dump_stages_dir) {
    if (!g_red_frame_gate_enabled) {
        RedFrameValidation bypass;
        bypass.verdict = RedFrameVerdict::ValidRed;
        bypass.reason_token = nullptr;
        return bypass;
    }

    const RoiMaskResult built = buildErodedRoiMask(bgr, dump_stages_dir);
    switch (built.status) {
        case RoiMaskResult::Status::Ok:
            return makeValidation(RedFrameVerdict::ValidRed, nullptr, built.metrics);
        case RoiMaskResult::Status::EmptyRoi:
            return makeValidation(RedFrameVerdict::EmptyRoi, kReasonEmptyRoi, built.metrics);
        case RoiMaskResult::Status::NoValidRegion:
        default:
            return makeValidation(RedFrameVerdict::NoValidRegion, kReasonNoValidRegion, built.metrics);
    }
}

RedFrameValidation validateRedFrame(const cv::Mat& bgr, const std::string& dump_stages_dir) {
    if (!g_red_frame_gate_enabled) {
        RedFrameValidation bypass;
        bypass.verdict = RedFrameVerdict::ValidRed;
        bypass.reason_token = nullptr;
        return bypass;
    }

    const RoiMaskResult built = buildErodedRoiMask(bgr, dump_stages_dir);
    if (built.status == RoiMaskResult::Status::NoValidRegion) {
        return makeValidation(RedFrameVerdict::NoValidRegion, kReasonNoValidRegion, built.metrics);
    }
    if (built.status == RoiMaskResult::Status::EmptyRoi) {
        return makeValidation(RedFrameVerdict::EmptyRoi, kReasonEmptyRoi, built.metrics);
    }

    const RedFrameMetrics& metrics = built.metrics;

    if (metrics.overexposed_ratio > kOverexposedRatioThreshold || metrics.gray_mean > kGrayMeanMax) {
        return makeValidation(RedFrameVerdict::Overexposed, kReasonOverexposed, metrics);
    }

    if (metrics.purple_ratio > kPurpleRatioMax) {
        return makeValidation(RedFrameVerdict::InvalidNonRed, kReasonInvalidNonRed, metrics);
    }

    const bool red_dominates_purple =
        metrics.red_ratio > metrics.purple_ratio + kRedPurpleMargin;
    if (metrics.red_ratio > kRedRatioMin && metrics.sat_mean > kSatMeanMin && metrics.val_mean > kValMeanMin &&
        red_dominates_purple) {
        return makeValidation(RedFrameVerdict::ValidRed, nullptr, metrics);
    }

    const bool magenta_plasma_pool =
        metrics.purple_ratio >= kPurplePlasmaRatioMin && metrics.purple_ratio <= kPurpleRatioMax &&
        metrics.red_ratio < kPurplePlasmaRedRatioMax &&
        metrics.purple_ratio > metrics.red_ratio + kRedPurpleMargin &&
        metrics.sat_mean > kSatMeanMin && metrics.val_mean > kValMeanMin;
    if (magenta_plasma_pool) {
        return makeValidation(RedFrameVerdict::ValidRed, nullptr, metrics);
    }

    const bool blue_weld_frame =
        metrics.blue_ratio >= kBlueRatioMin && metrics.red_ratio < kBlueFrameRedRatioMax &&
        metrics.sat_mean > kSatMeanMin && metrics.val_mean > kValMeanMin;
    if (blue_weld_frame) {
        return makeValidation(RedFrameVerdict::ValidBlue, nullptr, metrics);
    }

    return makeValidation(RedFrameVerdict::InvalidNonRed, kReasonInvalidNonRed, metrics);
}

}  // namespace opencv_detect
