#include "fixed_roi_internal.hpp"

namespace opencv_stain_detect {
namespace fixed_roi_internal {
namespace {

int findBrightestHorizontalLineRow(const cv::Mat& gray, int bright_gray_threshold) {
    if (gray.empty()) {
        return 0;
    }
    const int thresh = std::max(1, std::min(255, bright_gray_threshold));
    cv::Mat bright;
    cv::compare(gray, thresh, bright, cv::CMP_GE);
    int best_row = 0;
    int best_count = 0;
    for (int y = 0; y < gray.rows; ++y) {
        const int count = cv::countNonZero(bright.row(y));
        if (count > best_count) {
            best_count = count;
            best_row = y;
        }
    }
    if (best_count >= 8) {
        return best_row;
    }
    double best_mean = -1.0;
    int mean_row = 0;
    for (int y = 0; y < gray.rows; ++y) {
        const double mean = cv::mean(gray.row(y))[0];
        if (mean > best_mean) {
            best_mean = mean;
            mean_row = y;
        }
    }
    return mean_row;
}

std::vector<RegionBlob> filterRedBrightTargets(const std::vector<RegionBlob>& blobs,
                                                const FixedRoiParams& params,
                                                const cv::Mat& sat,
                                                const cv::Mat& val,
                                                const cv::Mat& mask_u8) {
    std::vector<RegionBlob> kept;
    kept.reserve(blobs.size());
    for (const RegionBlob& blob : blobs) {
        if (blob.w <= params.red_bright_target_min_width_px
            || blob.h <= params.red_bright_target_min_height_px) {
            continue;
        }
        if (!passesRedBrightPlasmaColorGate(sat, val, mask_u8, blob, params)) {
            continue;
        }
        kept.push_back(blob);
    }
    return kept;
}

}  // namespace

int countStrictInvertQualifyingDarkBlobs(const cv::Mat& inverted_tight,
                                         const FixedRoiParams& params) {
    const int dark_max = std::max(1, std::min(254, params.strict_invert_dark_max_value));
    cv::Mat dark;
    cv::compare(inverted_tight, dark_max, dark, cv::CMP_LT);

    cv::Mat labels;
    cv::Mat stats;
    cv::Mat centroids;
    const int num =
        cv::connectedComponentsWithStats(dark, labels, stats, centroids, 8);

    const int min_area = std::max(1, params.strict_invert_dark_min_area);
    const int min_w = std::max(1, params.strict_invert_dark_min_width);
    const int min_h = std::max(1, params.strict_invert_dark_min_height);
    const int max_h = std::max(min_h, params.strict_invert_dark_max_height);
    const double min_aspect = std::max(1.0, params.strict_invert_dark_min_aspect);

    int count = 0;
    for (int i = 1; i < num; ++i) {
        const int area = stats.at<int>(i, cv::CC_STAT_AREA);
        if (area < min_area) {
            continue;
        }
        const int w = stats.at<int>(i, cv::CC_STAT_WIDTH);
        const int h = stats.at<int>(i, cv::CC_STAT_HEIGHT);
        if (w < min_w || h < min_h || h > max_h) {
            continue;
        }
        const double aspect = static_cast<double>(w) / static_cast<double>(std::max(h, 1));
        if (aspect < min_aspect) {
            continue;
        }
        ++count;
    }
    return count;
}

std::vector<RegionBlob> detectRedAboveBrightLine(const cv::Mat& roi_bgr,
                                                  const cv::Mat& gray,
                                                  const FixedRoiParams& params,
                                                  const std::string& dump_stages_dir,
                                                  int& step) {
    std::vector<RegionBlob> empty;
    if (roi_bgr.empty() || gray.empty()) {
        return empty;
    }

    const int line_row = findBrightestHorizontalLineRow(gray, params.red_line_bright_gray_threshold);
    const int margin = std::max(0, params.red_line_margin_px);
    const int upper_h = std::max(0, std::min(gray.rows, line_row - margin));
    const int lower_y = std::max(0, std::min(gray.rows, line_row + 1 + margin));
    const int lower_h = gray.rows - lower_y;

    cv::Mat line_vis = roi_bgr.clone();
    cv::line(line_vis,
             cv::Point(0, line_row),
             cv::Point(roi_bgr.cols - 1, line_row),
             cv::Scalar(255, 255, 0),
             2);
    maybeSaveStage(dump_stages_dir,
                   step,
                   "bright_line_row_" + std::to_string(line_row) + ".jpg",
                   line_vis);

    const cv::Mat red_mask = buildRedBrightPlasmaMask(roi_bgr, params);
    maybeSaveStage(dump_stages_dir,
                   step,
                   "red_bright_plasma_mask.jpg",
                   maskToBgr(red_mask, cv::Scalar(0, 0, 255)));

    int red_above = 0;
    int red_below = 0;
    if (upper_h > 0) {
        red_above = cv::countNonZero(red_mask(cv::Rect(0, 0, red_mask.cols, upper_h)));
    }
    if (lower_h > 0) {
        red_below = cv::countNonZero(red_mask(cv::Rect(0, lower_y, red_mask.cols, lower_h)));
    }
    const double denom = static_cast<double>(red_above + red_below);
    const double above_frac = denom > 0.0 ? static_cast<double>(red_above) / denom : 0.0;

    cv::Mat upper_red = cv::Mat::zeros(red_mask.size(), CV_8UC1);
    if (upper_h > 0) {
        red_mask(cv::Rect(0, 0, red_mask.cols, upper_h))
            .copyTo(upper_red(cv::Rect(0, 0, red_mask.cols, upper_h)));
    }
    maybeSaveStage(
        dump_stages_dir,
        step,
        "red_above_line_frac_" + cv::format("%.2f", above_frac) + "_regions_pending.jpg",
        maskToBgr(upper_red, cv::Scalar(0, 0, 255)));

    if (params.red_above_min_fraction > 0.0 && above_frac < params.red_above_min_fraction) {
        return empty;
    }

    const std::vector<RegionBlob> raw_blobs =
        blobsFromMask(upper_red, params.min_blob_area);
    const std::vector<RegionBlob> filtered_blobs =
        filterGlobalErodeTargets(raw_blobs, params, params.red_above_min_target_height_px);

    cv::Mat hsv;
    cv::cvtColor(roi_bgr, hsv, cv::COLOR_BGR2HSV);
    std::vector<cv::Mat> hsv_channels;
    cv::split(hsv, hsv_channels);

    std::vector<RegionBlob> gated;
    gated.reserve(filtered_blobs.size());
    for (const RegionBlob& blob : filtered_blobs) {
        if (passesRedBrightPlasmaColorGate(
                hsv_channels[1], hsv_channels[2], red_mask, blob, params)) {
            gated.push_back(blob);
        }
    }
    maybeSaveStage(dump_stages_dir,
                   step,
                   "red_above_bright_line_regions_" + std::to_string(gated.size()) + ".jpg",
                   maskToBgr(upper_red, cv::Scalar(0, 0, 255)));
    return gated;
}

}  // namespace fixed_roi_internal
}  // namespace opencv_stain_detect
