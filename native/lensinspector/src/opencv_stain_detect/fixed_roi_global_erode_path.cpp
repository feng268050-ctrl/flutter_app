#include "fixed_roi_internal.hpp"

namespace opencv_stain_detect {
namespace fixed_roi_internal {
namespace {

struct NeckSplitAttempt {
    cv::Mat mask;
    bool applied = false;
    double neck_width_px = 0.0;
    cv::Point neck_center{-1, -1};
    cv::Point peak_a;
    cv::Point peak_b;
    double across_x = 0.0;
    double across_y = 0.0;
    cv::Point cut_a;
    cv::Point cut_b;
};

double measureMaskWidthAlong(const cv::Mat& mask_u8,
                             const cv::Point& center,
                             double dir_x,
                             double dir_y) {
    auto extent_one_way = [&](int sign) {
        int steps = 0;
        for (int s = 1; s < std::max(mask_u8.cols, mask_u8.rows); ++s) {
            const int x = center.x + sign * static_cast<int>(std::lround(dir_x * static_cast<double>(s)));
            const int y = center.y + sign * static_cast<int>(std::lround(dir_y * static_cast<double>(s)));
            if (x < 0 || y < 0 || x >= mask_u8.cols || y >= mask_u8.rows) {
                break;
            }
            if (mask_u8.at<uchar>(y, x) == 0) {
                break;
            }
            ++steps;
        }
        return steps;
    };
    return static_cast<double>(extent_one_way(-1) + extent_one_way(1) + 1);
}

void buildAcrossUnitFromPeaks(const cv::Point& peak_a,
                              const cv::Point& peak_b,
                              double& across_x,
                              double& across_y) {
    const double bridge_x = static_cast<double>(peak_b.x - peak_a.x);
    const double bridge_y = static_cast<double>(peak_b.y - peak_a.y);
    const double bridge_len = std::hypot(bridge_x, bridge_y);
    if (bridge_len < 1e-3) {
        across_x = 0.0;
        across_y = 1.0;
        return;
    }
    // Shortest neck width is across the bridge axis (perpendicular to lobe-to-lobe chord).
    across_x = -bridge_y / bridge_len;
    across_y = bridge_x / bridge_len;
}

std::pair<cv::Point, cv::Point> cutSegmentAcrossNeck(const cv::Point& center,
                                                     double across_x,
                                                     double across_y,
                                                     int image_span) {
    const double span = static_cast<double>(std::max(image_span, 1));
    return {
        cv::Point(static_cast<int>(std::lround(center.x - across_x * span)),
                  static_cast<int>(std::lround(center.y - across_y * span))),
        cv::Point(static_cast<int>(std::lround(center.x + across_x * span)),
                  static_cast<int>(std::lround(center.y + across_y * span))),
    };
}

bool isDtLocalMaximum(const cv::Mat& dist, int x, int y, int radius, float center) {
    for (int dy = -radius; dy <= radius; ++dy) {
        for (int dx = -radius; dx <= radius; ++dx) {
            if (dx == 0 && dy == 0) {
                continue;
            }
            const int nx = x + dx;
            const int ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= dist.cols || ny >= dist.rows) {
                continue;
            }
            if (dist.at<float>(ny, nx) > center + 1e-3f) {
                return false;
            }
        }
    }
    return true;
}

std::vector<cv::Point> collectRegionalDtPeaks(const cv::Mat& dist,
                                               const cv::Mat& mask_u8,
                                               int radius,
                                               float min_dt) {
    std::vector<std::tuple<float, cv::Point>> peaks;
    for (int y = radius; y < dist.rows - radius; ++y) {
        const float* row = dist.ptr<float>(y);
        const uchar* mask_row = mask_u8.ptr<uchar>(y);
        for (int x = radius; x < dist.cols - radius; ++x) {
            if (mask_row[x] == 0) {
                continue;
            }
            const float center = row[x];
            if (center < min_dt) {
                continue;
            }
            if (!isDtLocalMaximum(dist, x, y, radius, center)) {
                continue;
            }
            peaks.emplace_back(center, cv::Point(x, y));
        }
    }
    std::sort(peaks.begin(),
              peaks.end(),
              [](const auto& a, const auto& b) { return std::get<0>(a) > std::get<0>(b); });

    std::vector<cv::Point> kept;
    constexpr double kMinPeakSeparationPx = 32.0;
    for (const auto& [value, pt] : peaks) {
        (void)value;
        bool too_close = false;
        for (const cv::Point& other : kept) {
            const double dx = static_cast<double>(pt.x - other.x);
            const double dy = static_cast<double>(pt.y - other.y);
            if (std::hypot(dx, dy) < kMinPeakSeparationPx) {
                too_close = true;
                break;
            }
        }
        if (!too_close) {
            kept.push_back(pt);
        }
        if (kept.size() >= 2U) {
            break;
        }
    }
    return kept;
}

std::optional<NeckSplitAttempt> measureNeckBetweenPeaks(const cv::Mat& mask_u8,
                                                        const cv::Point& peak_a,
                                                        const cv::Point& peak_b) {
    double across_x = 0.0;
    double across_y = 0.0;
    buildAcrossUnitFromPeaks(peak_a, peak_b, across_x, across_y);

    constexpr int kSamples = 200;
    double best_width = std::numeric_limits<double>::max();
    cv::Point best_pt(-1, -1);
    for (int i = 0; i < kSamples; ++i) {
        const double t = static_cast<double>(i) / static_cast<double>(kSamples - 1);
        const int x = static_cast<int>(std::lround(peak_a.x + (peak_b.x - peak_a.x) * t));
        const int y = static_cast<int>(std::lround(peak_a.y + (peak_b.y - peak_a.y) * t));
        if (x < 0 || y < 0 || x >= mask_u8.cols || y >= mask_u8.rows) {
            continue;
        }
        if (mask_u8.at<uchar>(y, x) == 0) {
            continue;
        }
        const double width_px = measureMaskWidthAlong(mask_u8, cv::Point(x, y), across_x, across_y);
        if (width_px < best_width) {
            best_width = width_px;
            best_pt = cv::Point(x, y);
        }
    }
    if (best_pt.x < 0 || best_width >= std::numeric_limits<double>::max()) {
        return std::nullopt;
    }

    NeckSplitAttempt attempt;
    attempt.neck_center = best_pt;
    attempt.peak_a = peak_a;
    attempt.peak_b = peak_b;
    attempt.across_x = across_x;
    attempt.across_y = across_y;
    attempt.neck_width_px = best_width;
    return attempt;
}

std::optional<std::pair<cv::Point, cv::Point>> collectLobeCentroidPeaks(const cv::Mat& mask_u8,
                                                                         int min_pixels_per_lobe) {
    int y_min = mask_u8.rows;
    int y_max = -1;
    for (int y = 0; y < mask_u8.rows; ++y) {
        const uchar* row = mask_u8.ptr<uchar>(y);
        for (int x = 0; x < mask_u8.cols; ++x) {
            if (row[x] > 0) {
                y_min = std::min(y_min, y);
                y_max = std::max(y_max, y);
            }
        }
    }
    if (y_max < y_min) {
        return std::nullopt;
    }

    const int height = y_max - y_min + 1;
    if (height < 8) {
        return std::nullopt;
    }

    const int margin = std::max(1, static_cast<int>(std::lround(height * 0.12)));
    const int scan_y0 = y_min + margin;
    const int scan_y1 = y_max - margin;
    if (scan_y1 <= scan_y0) {
        return std::nullopt;
    }

    int neck_y = scan_y0;
    int neck_w = std::numeric_limits<int>::max();
    for (int y = scan_y0; y <= scan_y1; ++y) {
        const uchar* row = mask_u8.ptr<uchar>(y);
        int x_left = -1;
        int x_right = -1;
        for (int x = 0; x < mask_u8.cols; ++x) {
            if (row[x] > 0) {
                if (x_left < 0) {
                    x_left = x;
                }
                x_right = x;
            }
        }
        if (x_left < 0) {
            continue;
        }
        const int w = x_right - x_left + 1;
        if (w < neck_w) {
            neck_w = w;
            neck_y = y;
        }
    }

    double upper_x = 0.0;
    double upper_y = 0.0;
    int upper_n = 0;
    double lower_x = 0.0;
    double lower_y = 0.0;
    int lower_n = 0;
    for (int y = 0; y < mask_u8.rows; ++y) {
        const uchar* row = mask_u8.ptr<uchar>(y);
        for (int x = 0; x < mask_u8.cols; ++x) {
            if (row[x] == 0) {
                continue;
            }
            if (y < neck_y) {
                upper_x += x;
                upper_y += y;
                ++upper_n;
            } else if (y > neck_y) {
                lower_x += x;
                lower_y += y;
                ++lower_n;
            }
        }
    }
    if (upper_n < min_pixels_per_lobe || lower_n < min_pixels_per_lobe) {
        return std::nullopt;
    }

    const cv::Point upper(static_cast<int>(std::lround(upper_x / upper_n)),
                          static_cast<int>(std::lround(upper_y / upper_n)));
    const cv::Point lower(static_cast<int>(std::lround(lower_x / lower_n)),
                          static_cast<int>(std::lround(lower_y / lower_n)));
    if (std::hypot(static_cast<double>(upper.x - lower.x),
                   static_cast<double>(upper.y - lower.y)) < 20.0) {
        return std::nullopt;
    }
    return std::make_pair(upper, lower);
}

std::optional<NeckSplitAttempt> measureNeckByDistanceTransform(const cv::Mat& mask_u8,
                                                                const FixedRoiParams& params) {
    if (mask_u8.empty() || cv::countNonZero(mask_u8) == 0) {
        return std::nullopt;
    }
    if (params.neck_split_max_width_px <= 0.0) {
        return std::nullopt;
    }

    cv::Mat dist;
    cv::distanceTransform(mask_u8, dist, cv::DIST_L2, 5);

    std::vector<cv::Point> peaks = collectRegionalDtPeaks(dist, mask_u8, 10, 8.0f);
    if (peaks.size() < 2U) {
        const std::optional<std::pair<cv::Point, cv::Point>> fallback =
            collectLobeCentroidPeaks(mask_u8, params.min_blob_area);
        if (!fallback.has_value()) {
            return std::nullopt;
        }
        peaks = {fallback->first, fallback->second};
    }

    return measureNeckBetweenPeaks(mask_u8, peaks[0], peaks[1]);
}

NeckSplitAttempt tryNeckSplitByDistanceTransform(const cv::Mat& mask_u8,
                                                  const FixedRoiParams& params,
                                                  const std::string& dump_stages_dir,
                                                  int& step) {
    NeckSplitAttempt result;
    result.mask = mask_u8.clone();

    const std::optional<NeckSplitAttempt> measured = measureNeckByDistanceTransform(mask_u8, params);
    if (!measured.has_value()) {
        return result;
    }

    result.neck_center = measured->neck_center;
    result.neck_width_px = measured->neck_width_px;
    result.peak_a = measured->peak_a;
    result.peak_b = measured->peak_b;
    result.across_x = measured->across_x;
    result.across_y = measured->across_y;
    if (result.neck_width_px >= params.neck_split_max_width_px
        || result.neck_width_px < params.neck_split_min_width_px
        || result.neck_center.x < 0) {
        return result;
    }

    std::tie(result.cut_a, result.cut_b) = cutSegmentAcrossNeck(
        result.neck_center,
        result.across_x,
        result.across_y,
        std::max(mask_u8.cols, mask_u8.rows));

    const int thickness = std::max(3, params.neck_cut_line_thickness_px);
    cv::line(result.mask,
             result.cut_a,
             result.cut_b,
             cv::Scalar(0),
             thickness,
             cv::LINE_8);

    result.applied = true;

    if (!dump_stages_dir.empty()) {
        cv::Mat dist;
        cv::distanceTransform(mask_u8, dist, cv::DIST_L2, 5);
        cv::Mat dist_vis;
        cv::normalize(dist, dist_vis, 0, 255, cv::NORM_MINMAX, CV_8U);
        cv::Mat dist_bgr;
        cv::cvtColor(dist_vis, dist_bgr, cv::COLOR_GRAY2BGR);
        cv::circle(dist_bgr, result.neck_center, 6, cv::Scalar(0, 0, 255), 2);
        cv::line(dist_bgr, result.peak_a, result.peak_b, cv::Scalar(255, 128, 0), 1, cv::LINE_AA);
        cv::line(dist_bgr, result.cut_a, result.cut_b, cv::Scalar(0, 255, 0), 2, cv::LINE_AA);
        maybeSaveStage(dump_stages_dir, step, "neck_distance_transform.jpg", dist_bgr);

        cv::Mat cut_vis = maskToBgr(mask_u8, cv::Scalar(0, 255, 255));
        cv::line(cut_vis, result.cut_a, result.cut_b, cv::Scalar(0, 0, 255), 2, cv::LINE_AA);
        cv::circle(cut_vis, result.neck_center, 6, cv::Scalar(0, 255, 0), 2);
        maybeSaveStage(
            dump_stages_dir,
            step,
            "neck_cut_width_" + std::to_string(static_cast<int>(std::round(result.neck_width_px)))
                + ".jpg",
            cut_vis);

        const int regions_after_cut = countComponents(result.mask, params.min_blob_area);
        maybeSaveStage(
            dump_stages_dir,
            step,
            "split_after_neck_cut_regions_" + std::to_string(regions_after_cut) + ".jpg",
            maskToBgr(result.mask, cv::Scalar(0, 255, 255)));
    }

    return result;
}

}  // namespace

std::vector<RegionBlob> filterGlobalErodeTargets(const std::vector<RegionBlob>& blobs,
                                                  const FixedRoiParams& params,
                                                  int min_height_px) {
    std::vector<RegionBlob> kept;
    kept.reserve(blobs.size());
    const int min_area = std::max(1, params.global_erode_min_target_area_px);
    const int min_h = std::max(1, min_height_px);
    for (const RegionBlob& blob : blobs) {
        if (blob.area_px >= min_area && blob.h >= min_h) {
            kept.push_back(blob);
        }
    }
    const double dist_thresh = params.global_erode_reject_two_targets_centroid_dist_px;
    if (dist_thresh > 0.0 && kept.size() > 1) {
        bool changed = true;
        while (changed && kept.size() > 1) {
            changed = false;
            for (std::size_t i = 0; i < kept.size() && !changed; ++i) {
                for (std::size_t j = i + 1; j < kept.size() && !changed; ++j) {
                    const double dx = kept[i].cx - kept[j].cx;
                    const double dy = kept[i].cy - kept[j].cy;
                    if (std::hypot(dx, dy) > dist_thresh) {
                        const std::size_t drop =
                            kept[i].area_px <= kept[j].area_px ? i : j;
                        kept.erase(kept.begin() + static_cast<std::ptrdiff_t>(drop));
                        changed = true;
                    }
                }
            }
        }
    }
    return kept;
}

std::vector<RegionBlob> detectGlobalErodeSingleTarget(const cv::Mat& inverted_tight,
                                                       const FixedRoiParams& params,
                                                       const std::string& dump_stages_dir,
                                                       int& step) {
    cv::Mat binary;
    cv::threshold(inverted_tight, binary, params.invert_thresh, 255, cv::THRESH_BINARY_INV);
    maybeSaveStage(dump_stages_dir, step, "binary_thresh_inv.jpg", maskToBgr(binary));

    cv::Mat opened;
    cv::morphologyEx(binary, opened, cv::MORPH_OPEN, ellipsisKernel(params.open_kernel));
    maybeSaveStage(dump_stages_dir, step, "morph_open_denoise.jpg", maskToBgr(opened));

    const cv::Mat roi_global_eroded = applyRoiGlobalErode(opened, params);
    const std::vector<RegionBlob> raw_blobs =
        blobsFromMask(roi_global_eroded, params.min_blob_area);
    const std::vector<RegionBlob> filtered_blobs =
        filterGlobalErodeTargets(raw_blobs, params, params.global_erode_min_target_height_px);
    maybeSaveStage(dump_stages_dir,
                   step,
                   "roi_global_erode_" + std::to_string(params.global_erode_kernel) + "x"
                       + std::to_string(params.global_erode_kernel) + "_regions_"
                       + std::to_string(filtered_blobs.size()) + ".jpg",
                   maskToBgr(roi_global_eroded, cv::Scalar(0, 255, 255)));
    return filtered_blobs;
}

}  // namespace fixed_roi_internal
}  // namespace opencv_stain_detect
