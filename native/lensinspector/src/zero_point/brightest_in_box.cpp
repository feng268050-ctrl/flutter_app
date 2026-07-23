#include "brightest_in_box.h"

#include "opencv_detect_codes.h"
#include "roi_preprocess.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include <algorithm>
#include <string>

namespace zero_point {
namespace {

constexpr int kBlackGrayThreshold = 80;
constexpr int kMinBlobAreaPx = 4;

bool findBrightestPeakBlob(const cv::Mat& roi_bgr,
                           cv::Rect& out_bounds,
                           int& out_peak_ix,
                           int& out_peak_iy,
                           double& out_peak_brightness,
                           const std::string& dump_stages_dir) {
    cv::Mat raw_gray;
    cv::cvtColor(roi_bgr, raw_gray, cv::COLOR_BGR2GRAY);

    const cv::Mat enhanced = brightnessEnhanceRoi(roi_bgr);
    saveRoiStage(dump_stages_dir, "06_roi_enhanced.jpg", enhanced);

    cv::Mat gray;
    cv::cvtColor(enhanced, gray, cv::COLOR_BGR2GRAY);
    saveRoiStage(dump_stages_dir, "07_roi_gray.jpg", gray);

    cv::Mat inverted;
    cv::bitwise_not(gray, inverted);
    saveRoiStage(dump_stages_dir, "08_roi_inverted.jpg", inverted);

    cv::Mat mask;
    cv::threshold(inverted, mask, kBlackGrayThreshold, 255, cv::THRESH_BINARY_INV);
    saveRoiStage(dump_stages_dir, "09_roi_binary_thresh.jpg", mask);

    cv::Mat labels;
    cv::Mat stats;
    cv::Mat centroids;
    const int label_count = cv::connectedComponentsWithStats(mask, labels, stats, centroids, 8, CV_32S);
    if (label_count <= 1) {
        return false;
    }

    int best_label = -1;
    int best_area = 0;
    double best_peak_brightness = -1.0;
    int best_peak_ix = 0;
    int best_peak_iy = 0;
    for (int label = 1; label < label_count; ++label) {
        const int area = stats.at<int>(label, cv::CC_STAT_AREA);
        if (area < kMinBlobAreaPx) {
            continue;
        }
        const cv::Mat component = (labels == label);
        double min_val = 0.0;
        double max_val = 0.0;
        cv::Point min_loc;
        cv::Point max_loc;
        cv::minMaxLoc(raw_gray, &min_val, &max_val, &min_loc, &max_loc, component);
        const bool brighter = max_val > best_peak_brightness;
        const bool tie_break_larger_area = max_val == best_peak_brightness && area > best_area;
        if (brighter || tie_break_larger_area) {
            best_peak_brightness = max_val;
            best_area = area;
            best_label = label;
            best_peak_ix = max_loc.x;
            best_peak_iy = max_loc.y;
        }
    }
    if (best_label < 0) {
        return false;
    }

    out_bounds.x = stats.at<int>(best_label, cv::CC_STAT_LEFT);
    out_bounds.y = stats.at<int>(best_label, cv::CC_STAT_TOP);
    out_bounds.width = stats.at<int>(best_label, cv::CC_STAT_WIDTH);
    out_bounds.height = stats.at<int>(best_label, cv::CC_STAT_HEIGHT);
    if (!dump_stages_dir.empty()) {
        cv::Mat blob_mask = (labels == best_label);
        blob_mask.convertTo(blob_mask, CV_8UC1, 255);
        saveRoiStage(dump_stages_dir, "10_roi_blob_mask.jpg", blob_mask);
    }
    out_peak_ix = best_peak_ix;
    out_peak_iy = best_peak_iy;
    out_peak_brightness = best_peak_brightness;
    return out_bounds.width > 0 && out_bounds.height > 0;
}

}  // namespace

LrDistance calcLrDistanceToBox(const Box& center_box, const Point2d& point) {
    const double box_right = center_box.x + center_box.w;
    const double cx0 = center_box.x + center_box.w / 2.0;
    const double cy0 = center_box.y + center_box.h / 2.0;
    LrDistance lr;
    lr.left_dist_px = point.x - center_box.x;
    lr.right_dist_px = box_right - point.x;
    lr.offset_x_px = point.x - cx0;
    lr.point_xy = point;
    lr.fixed_center_xy = Point2d{cx0, cy0};
    return lr;
}

BrightestDetection detectBrightestPointInBox(const cv::Mat& bgr,
                                             const Box& center_box,
                                             const std::string& dump_stages_dir) {
    BrightestDetection out;
    out.method = "roi_enhance_invert_brightest_peak_blob";
    if (bgr.empty()) {
        out.reason = "empty frame";
        return out;
    }

    const RoiCrop crop = cropRoiBgr(bgr, center_box);
    saveRoiStage(dump_stages_dir, "05_roi_bgr.jpg", crop.roi_bgr);

    cv::Rect blob;
    int ix = 0;
    int iy = 0;
    double peak_brightness = 0.0;
    if (!findBrightestPeakBlob(crop.roi_bgr, blob, ix, iy, peak_brightness, dump_stages_dir)) {
        out.reason = opencv_detect::kReasonBlackBlobNotFound;
        return out;
    }

    const int blob_w = blob.width;
    const int blob_h = blob.height;
    if (blob_w > kMaxSpotDimensionPx || blob_h > kMaxSpotDimensionPx) {
        out.found = false;
        out.reject_code = kCodeSpotSizeRejected;
        out.reason = opencv_detect::kReasonSpotSizeAboveMax;
        return out;
    }

    out.found = true;
    out.peak_x = crop.x + ix;
    out.peak_y = crop.y + iy;
    out.center = Point2d{static_cast<double>(out.peak_x), static_cast<double>(out.peak_y)};
    out.peak_brightness_v = peak_brightness;
    out.peak_score = peak_brightness;
    out.lr = calcLrDistanceToBox(center_box, out.center);
    return out;
}

}  // namespace zero_point
