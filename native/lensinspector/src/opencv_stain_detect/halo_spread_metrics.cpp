#include "halo_spread_metrics.h"

#include <opencv2/imgproc.hpp>

#include <algorithm>
#include <cmath>
#include <vector>

namespace opencv_stain_detect {
namespace {

double fwhm1d(const cv::Mat& row_or_col) {
    double peak = 0.0;
    cv::minMaxLoc(row_or_col, nullptr, &peak);
    if (peak <= 1.0) {
        return 0.0;
    }
    const double half = peak * 0.5;
    int first = -1;
    int last = -1;
    const int n = row_or_col.rows == 1 ? row_or_col.cols : row_or_col.rows;
    for (int i = 0; i < n; ++i) {
        const float v = row_or_col.rows == 1 ? row_or_col.at<float>(0, i)
                                             : row_or_col.at<float>(i, 0);
        if (v >= half) {
            if (first < 0) {
                first = i;
            }
            last = i;
        }
    }
    if (first < 0 || last < 0) {
        return 0.0;
    }
    return static_cast<double>(last - first + 1);
}

cv::Rect expandBlobWindow(const cv::Size& roi_size,
                          const RegionBlob& blob,
                          int margin_px) {
    const int x = std::max(0, blob.x - margin_px);
    const int y = std::max(0, blob.y - margin_px);
    const int right = std::min(roi_size.width, blob.x + blob.w + margin_px);
    const int bottom = std::min(roi_size.height, blob.y + blob.h + margin_px);
    return cv::Rect(x, y, std::max(1, right - x), std::max(1, bottom - y));
}

double radialRadiusAtFraction(const cv::Mat& v,
                              int cx,
                              int cy,
                              double fraction) {
    const int max_r = std::min({cx, cy, v.cols - 1 - cx, v.rows - 1 - cy});
    if (max_r <= 0) {
        return 0.0;
    }
    std::vector<double> radial(static_cast<std::size_t>(max_r) + 1, 0.0);
    double peak = 0.0;
    for (int r = 0; r <= max_r; ++r) {
        double sum = 0.0;
        int count = 0;
        for (int y = 0; y < v.rows; ++y) {
            for (int x = 0; x < v.cols; ++x) {
                const double dist = std::hypot(static_cast<double>(x - cx),
                                               static_cast<double>(y - cy));
                if (dist >= r - 0.5 && dist < r + 0.5) {
                    sum += v.at<uchar>(y, x);
                    ++count;
                }
            }
        }
        radial[static_cast<std::size_t>(r)] = count > 0 ? sum / static_cast<double>(count) : 0.0;
        peak = std::max(peak, radial[static_cast<std::size_t>(r)]);
    }
    if (peak <= 0.0) {
        return 0.0;
    }
    const double target = peak * fraction;
    for (int r = max_r; r >= 0; --r) {
        if (radial[static_cast<std::size_t>(r)] >= target) {
            return static_cast<double>(r);
        }
    }
    return 0.0;
}

}  // namespace

HaloSpreadMetrics computeHaloSpreadMetrics(const cv::Mat& roi_bgr,
                                           const RegionBlob& target,
                                           const HaloSpreadParams& params) {
    HaloSpreadMetrics out;
    if (roi_bgr.empty()) {
        return out;
    }

    const cv::Rect window =
        expandBlobWindow(roi_bgr.size(), target, params.analysis_margin_px);
    out.window_x = window.x;
    out.window_y = window.y;
    out.window_w = window.width;
    out.window_h = window.height;

    const cv::Mat crop = roi_bgr(window);
    cv::Mat hsv;
    cv::cvtColor(crop, hsv, cv::COLOR_BGR2HSV);
    cv::Mat v_u8;
    cv::extractChannel(hsv, v_u8, 2);
    cv::Mat v;
    v_u8.convertTo(v, CV_32F);

    double peak = 0.0;
    cv::minMaxLoc(v, nullptr, &peak);
    out.peak_v = peak;

    cv::Mat peak_mask;
    cv::compare(v, peak, peak_mask, cv::CMP_EQ);
    cv::Moments m = cv::moments(peak_mask, true);
    int cx = m.m00 > 0.0 ? static_cast<int>(m.m10 / m.m00) : crop.cols / 2;
    int cy = m.m00 > 0.0 ? static_cast<int>(m.m01 / m.m00) : crop.rows / 2;
    cx = std::clamp(cx, 0, crop.cols - 1);
    cy = std::clamp(cy, 0, crop.rows - 1);

    const cv::Mat row = v.row(cy);
    const cv::Mat col = v.col(cx);
    out.fwhm_w_px = fwhm1d(row);
    out.fwhm_h_px = fwhm1d(col);

    cv::Mat halo_only = v.clone();
    halo_only.setTo(0, v >= static_cast<float>(params.core_v_min));
    const cv::Mat halo_row = halo_only.row(cy);
    const cv::Mat halo_col = halo_only.col(cx);
    out.fwhm_w_halo_px = fwhm1d(halo_row);
    out.fwhm_h_halo_px = fwhm1d(halo_col);

    const int total_px = crop.rows * crop.cols;
    int core_px = 0;
    int halo_px = 0;
    int v200_px = 0;
    for (int y = 0; y < crop.rows; ++y) {
        for (int x = 0; x < crop.cols; ++x) {
            const float val = v.at<float>(y, x);
            if (val >= 200.0f) {
                ++v200_px;
            }
            if (val >= static_cast<float>(params.core_v_min)) {
                ++core_px;
            } else if (val >= static_cast<float>(params.halo_v_min)
                       && val < static_cast<float>(params.halo_v_max)) {
                ++halo_px;
            }
        }
    }
    out.area_frac_v200 = static_cast<double>(v200_px) / static_cast<double>(total_px);
    out.core_area_frac = static_cast<double>(core_px) / static_cast<double>(total_px);
    out.halo_area_frac = static_cast<double>(halo_px) / static_cast<double>(total_px);
    out.halo_to_core_ratio =
        out.core_area_frac > 1e-6 ? out.halo_area_frac / out.core_area_frac : 0.0;

    out.radial_r50_px = radialRadiusAtFraction(v_u8, cx, cy, 0.5);
    out.halo_score = 0.30 * (out.fwhm_w_halo_px / std::max(window.width, 1))
                   + 0.30 * (out.fwhm_h_halo_px / std::max(window.height, 1))
                   + 0.25 * out.area_frac_v200
                   + 0.15 * (out.radial_r50_px / std::max(window.width / 2, 1));
    return out;
}

bool passesHaloSpreadGate(const HaloSpreadMetrics& metrics,
                          const HaloSpreadParams& params) {
    if (params.reject_fwhm_halo_w_frac_max > 0.0 && metrics.window_w > 0) {
        const double frac = metrics.fwhm_w_halo_px / static_cast<double>(metrics.window_w);
        if (frac > params.reject_fwhm_halo_w_frac_max) {
            return false;
        }
    }
    if (params.reject_halo_score_max > 0.0
        && metrics.halo_score > params.reject_halo_score_max) {
        return false;
    }
    return true;
}

void drawHaloAnalysisWindow(cv::Mat& roi_bgr, const HaloSpreadMetrics& metrics) {
    if (roi_bgr.empty()) {
        return;
    }
    const cv::Rect window(metrics.window_x,
                          metrics.window_y,
                          metrics.window_w,
                          metrics.window_h);
    cv::rectangle(roi_bgr, window, cv::Scalar(255, 128, 0), 2);
    const std::string label = "halo_score=" + cv::format("%.3f", metrics.halo_score)
                            + " fwhm_halo_w=" + cv::format("%.0f", metrics.fwhm_w_halo_px);
    cv::putText(roi_bgr,
                label,
                cv::Point(window.x, std::max(window.y - 6, 14)),
                cv::FONT_HERSHEY_SIMPLEX,
                0.45,
                cv::Scalar(255, 128, 0),
                1,
                cv::LINE_AA);
}

}  // namespace opencv_stain_detect
