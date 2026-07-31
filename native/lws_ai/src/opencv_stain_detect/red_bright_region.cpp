#include "red_bright_region.h"

#include <opencv2/imgproc.hpp>

namespace opencv_stain_detect {
namespace {

cv::Mat ellipsisKernel(int size) {
    const int safe = std::max(1, size);
    return cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(safe, safe));
}

}  // namespace

cv::Mat buildRedBrightPlasmaMask(const cv::Mat& roi_bgr, const FixedRoiParams& params) {
    if (roi_bgr.empty()) {
        return cv::Mat();
    }

    cv::Mat hsv;
    cv::cvtColor(roi_bgr, hsv, cv::COLOR_BGR2HSV);
    std::vector<cv::Mat> channels;
    cv::split(hsv, channels);
    const cv::Mat& hue = channels[0];
    const cv::Mat& sat = channels[1];
    const cv::Mat& val = channels[2];

    cv::Mat sat_ok;
    cv::Mat val_ok;
    cv::compare(sat, params.red_bright_s_min, sat_ok, cv::CMP_GE);
    cv::compare(val, params.red_bright_v_min, val_ok, cv::CMP_GE);
    cv::Mat sv_ok;
    cv::bitwise_and(sat_ok, val_ok, sv_ok);

    cv::Mat red_lo;
    cv::Mat red_hi;
    cv::compare(hue, params.red_bright_red_hue_lo, red_lo, cv::CMP_LT);
    cv::compare(hue, params.red_bright_red_hue_hi, red_hi, cv::CMP_GT);
    cv::Mat red_hue;
    cv::bitwise_or(red_lo, red_hi, red_hue);

    cv::Mat mag_lo;
    cv::Mat mag_hi;
    cv::compare(hue, params.red_bright_magenta_hue_lo, mag_lo, cv::CMP_GT);
    cv::compare(hue, params.red_bright_magenta_hue_hi, mag_hi, cv::CMP_LT);
    cv::Mat magenta_hue;
    cv::bitwise_and(mag_lo, mag_hi, magenta_hue);

    cv::Mat hue_mask;
    cv::bitwise_or(red_hue, magenta_hue, hue_mask);

    cv::Mat mask;
    cv::bitwise_and(hue_mask, sv_ok, mask);

    const cv::Mat kernel = ellipsisKernel(params.red_bright_morph_kernel);
    cv::morphologyEx(mask, mask, cv::MORPH_OPEN, kernel);
    cv::morphologyEx(mask, mask, cv::MORPH_CLOSE, kernel);
    if (params.red_bright_dilate_iterations > 0) {
        cv::dilate(mask, mask, kernel, cv::Point(-1, -1), params.red_bright_dilate_iterations);
    }
    return mask;
}

bool passesRedBrightPlasmaColorGate(const cv::Mat& sat,
                                      const cv::Mat& val,
                                      const cv::Mat& mask_u8,
                                      const RegionBlob& blob,
                                      const FixedRoiParams& params) {
    if (sat.empty() || val.empty() || mask_u8.empty()) {
        return false;
    }
    const cv::Rect bounds(0, 0, mask_u8.cols, mask_u8.rows);
    cv::Rect roi(blob.x, blob.y, blob.w, blob.h);
    roi &= bounds;
    if (roi.width <= 0 || roi.height <= 0) {
        return false;
    }

    cv::Mat sat_roi = sat(roi);
    cv::Mat val_roi = val(roi);
    cv::Mat mask_roi = mask_u8(roi);
    cv::Mat active;
    cv::compare(mask_roi, 0, active, cv::CMP_GT);
    const int total = cv::countNonZero(active);
    if (total <= 0) {
        return false;
    }

    cv::Mat v200;
    cv::compare(val_roi, 200, v200, cv::CMP_GT);
    cv::bitwise_and(v200, active, v200);
    const double v200_fraction = static_cast<double>(cv::countNonZero(v200)) / static_cast<double>(total);

    if (params.red_bright_reject_v200_fraction_max > 0.0
        && v200_fraction > params.red_bright_reject_v200_fraction_max) {
        return false;
    }

    if (params.red_bright_reject_white_fraction_max > 0.0) {
        cv::Mat low_sat;
        cv::compare(sat_roi, 80, low_sat, cv::CMP_LT);
        cv::Mat bright;
        cv::compare(val_roi, 180, bright, cv::CMP_GT);
        cv::Mat white;
        cv::bitwise_and(low_sat, bright, white);
        cv::bitwise_and(white, active, white);
        const double white_fraction =
            static_cast<double>(cv::countNonZero(white)) / static_cast<double>(total);
        if (white_fraction > params.red_bright_reject_white_fraction_max) {
            return false;
        }
    }

    if (params.red_bright_reject_centroid_y_min_full > 0.0) {
        const double full_frame_cy = blob.cy + static_cast<double>(params.roi_y);
        if (full_frame_cy < params.red_bright_reject_centroid_y_min_full) {
            return false;
        }
    }
    return true;
}

}  // namespace opencv_stain_detect
