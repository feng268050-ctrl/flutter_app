#pragma once

#include "fixed_roi_pipeline.h"
#include "red_bright_region.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include <algorithm>
#include <cmath>
#include <cerrno>
#include <limits>
#include <optional>
#include <string>
#include <sys/stat.h>
#include <tuple>
#include <vector>

namespace opencv_stain_detect {
namespace fixed_roi_internal {

inline TwoLargestBlobs findTwoLargestBlobsImpl(const std::vector<RegionBlob>& blobs) {
    TwoLargestBlobs out;
    for (const RegionBlob& blob : blobs) {
        if (out.largest == nullptr || blob.area_px > out.largest->area_px) {
            out.second = out.largest;
            out.largest = &blob;
        } else if (out.second == nullptr || blob.area_px > out.second->area_px) {
            out.second = &blob;
        }
    }
    return out;
}

inline cv::Mat ellipsisKernel(int size) {
    const int safe = std::max(1, size);
    return cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(safe, safe));
}

inline cv::Mat brightnessEnhance(const cv::Mat& bgr, const FixedRoiParams& params) {
    cv::Mat hsv;
    cv::cvtColor(bgr, hsv, cv::COLOR_BGR2HSV);
    std::vector<cv::Mat> channels;
    cv::split(hsv, channels);
    cv::Ptr<cv::CLAHE> clahe =
        cv::createCLAHE(params.enhance_clahe_clip, cv::Size(8, 8));
    clahe->apply(channels[2], channels[2]);
    cv::merge(channels, hsv);
    cv::Mat merged;
    cv::cvtColor(hsv, merged, cv::COLOR_HSV2BGR);
    cv::Mat enhanced;
    cv::convertScaleAbs(merged, enhanced, params.enhance_alpha, params.enhance_beta);
    return enhanced;
}

inline cv::Mat applyGlobalGrayDenoise(const cv::Mat& gray, const FixedRoiParams& params) {
    if (params.gray_global_denoise_kernel <= 1) {
        return gray;
    }
    int kernel = params.gray_global_denoise_kernel;
    if (kernel % 2 == 0) {
        ++kernel;
    }
    cv::Mat denoised;
    cv::medianBlur(gray, denoised, kernel);
    return denoised;
}

inline cv::Mat maskToBgr(const cv::Mat& mask_u8, const cv::Scalar& color = cv::Scalar(0, 255, 0)) {
    cv::Mat vis = cv::Mat::zeros(mask_u8.rows, mask_u8.cols, CV_8UC3);
    for (int y = 0; y < mask_u8.rows; ++y) {
        const uchar* row = mask_u8.ptr<uchar>(y);
        cv::Vec3b* out = vis.ptr<cv::Vec3b>(y);
        for (int x = 0; x < mask_u8.cols; ++x) {
            if (row[x] > 0) {
                out[x] = cv::Vec3b(
                    static_cast<uchar>(color[0]),
                    static_cast<uchar>(color[1]),
                    static_cast<uchar>(color[2]));
            }
        }
    }
    return vis;
}

inline void mkdirRecursive(const std::string& dir) {
    if (dir.empty()) {
        return;
    }
    std::string path;
    path.reserve(dir.size());
    for (std::size_t i = 0; i < dir.size(); ++i) {
        const char c = dir[i];
        path.push_back(c);
        if (c == '/' && path.size() > 1) {
            if (::mkdir(path.c_str(), 0755) != 0 && errno != EEXIST) {
                // Best effort; parent may already exist.
            }
        }
    }
    if (::mkdir(dir.c_str(), 0755) != 0 && errno != EEXIST) {
        // Best effort for dump stages.
    }
}

inline void maybeSaveStage(const std::string& dump_dir,
                           int& step,
                           const std::string& name,
                           const cv::Mat& img) {
    if (dump_dir.empty()) {
        return;
    }
    mkdirRecursive(dump_dir);
    const std::string path =
        dump_dir + "/" + (step < 10 ? "0" : "") + std::to_string(step) + "_" + name;
    cv::imwrite(path, img);
    ++step;
}

inline int countComponents(const cv::Mat& mask_u8, int min_area) {
    cv::Mat labels;
    cv::Mat stats;
    cv::Mat centroids;
    const int num =
        cv::connectedComponentsWithStats(mask_u8, labels, stats, centroids, 8);
    int count = 0;
    for (int i = 1; i < num; ++i) {
        if (stats.at<int>(i, cv::CC_STAT_AREA) >= min_area) {
            ++count;
        }
    }
    return count;
}

inline cv::Mat applyRoiGlobalErode(const cv::Mat& opened, const FixedRoiParams& params) {
    if (params.global_erode_kernel <= 0) {
        return opened.clone();
    }
    cv::Mat eroded;
    cv::erode(opened, eroded, ellipsisKernel(params.global_erode_kernel));
    return eroded;
}

inline std::vector<RegionBlob> blobsFromMask(const cv::Mat& mask_u8, int min_area) {
    cv::Mat labels;
    cv::Mat stats;
    cv::Mat centroids;
    const int num =
        cv::connectedComponentsWithStats(mask_u8, labels, stats, centroids, 8);

    std::vector<RegionBlob> targets;
    for (int i = 1; i < num; ++i) {
        const int area = stats.at<int>(i, cv::CC_STAT_AREA);
        if (area < min_area) {
            continue;
        }
        RegionBlob blob;
        blob.x = stats.at<int>(i, cv::CC_STAT_LEFT);
        blob.y = stats.at<int>(i, cv::CC_STAT_TOP);
        blob.w = stats.at<int>(i, cv::CC_STAT_WIDTH);
        blob.h = stats.at<int>(i, cv::CC_STAT_HEIGHT);
        blob.area_px = area;
        blob.cx = centroids.at<double>(i, 0);
        blob.cy = centroids.at<double>(i, 1);
        targets.push_back(blob);
    }
    std::sort(targets.begin(), targets.end(), [](const RegionBlob& a, const RegionBlob& b) {
        return a.area_px > b.area_px;
    });
    return targets;
}

inline void drawBlobsOnRoi(cv::Mat& roi_bgr,
                           const std::vector<RegionBlob>& blobs,
                           const cv::Scalar& color) {
    for (const RegionBlob& blob : blobs) {
        cv::rectangle(roi_bgr,
                      cv::Point(blob.x, blob.y),
                      cv::Point(blob.x + blob.w - 1, blob.y + blob.h - 1),
                      color,
                      2);
        cv::circle(roi_bgr,
                   cv::Point(static_cast<int>(std::round(blob.cx)),
                             static_cast<int>(std::round(blob.cy))),
                   6,
                   color,
                   2);
    }
}

std::vector<RegionBlob> filterGlobalErodeTargets(const std::vector<RegionBlob>& blobs,
                                                  const FixedRoiParams& params,
                                                  int min_height_px);

int countStrictInvertQualifyingDarkBlobs(const cv::Mat& inverted_tight,
                                         const FixedRoiParams& params);

std::vector<RegionBlob> detectRedAboveBrightLine(const cv::Mat& roi_bgr,
                                                  const cv::Mat& gray,
                                                  const FixedRoiParams& params,
                                                  const std::string& dump_stages_dir,
                                                  int& step);

std::vector<RegionBlob> detectGlobalErodeSingleTarget(const cv::Mat& inverted_tight,
                                                       const FixedRoiParams& params,
                                                       const std::string& dump_stages_dir,
                                                       int& step);

}  // namespace fixed_roi_internal
}  // namespace opencv_stain_detect
