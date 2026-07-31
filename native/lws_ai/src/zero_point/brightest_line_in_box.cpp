#include "brightest_line_in_box.h"

#include "brightest_in_box.h"
#include "opencv_detect_codes.h"
#include "roi_preprocess.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include <algorithm>
#include <cmath>
#include <vector>

namespace zero_point {
namespace {

constexpr int kLineGrayMin = 250;
constexpr int kMinBrightPixelsPerRow = 15;
constexpr int kMaxBrightPixelsPerRow = 400;
constexpr int kMinLineSpanPx = 20;
constexpr int kMaxLineSpanPx = 450;
constexpr int kMinLineThicknessPx = 3;
constexpr int kMaxLineThicknessPx = 45;
constexpr int kMaxLineBandRows = 60;

cv::Mat largestComponentMask(const cv::Mat& binary_mask) {
    if (binary_mask.empty()) {
        return cv::Mat();
    }
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(binary_mask, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    if (contours.empty()) {
        return cv::Mat();
    }
    const auto max_it = std::max_element(
        contours.begin(),
        contours.end(),
        [](const std::vector<cv::Point>& a, const std::vector<cv::Point>& b) {
            return cv::contourArea(a) < cv::contourArea(b);
        });
    cv::Mat component = cv::Mat::zeros(binary_mask.size(), CV_8UC1);
    cv::drawContours(
        component,
        contours,
        static_cast<int>(std::distance(contours.begin(), max_it)),
        cv::Scalar(255),
        cv::FILLED);
    return component;
}

bool measureLineFromComponentMask(const cv::Mat& component_mask,
                                  int& out_peak_ix,
                                  int& out_peak_iy,
                                  int& out_span_x,
                                  int& out_thickness_px,
                                  const std::string& dump_stages_dir) {
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(component_mask, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    if (contours.empty()) {
        return false;
    }

    const auto max_it = std::max_element(
        contours.begin(),
        contours.end(),
        [](const std::vector<cv::Point>& a, const std::vector<cv::Point>& b) {
            return cv::contourArea(a) < cv::contourArea(b);
        });
    const std::vector<cv::Point>& contour = *max_it;
    if (contour.size() < 3) {
        return false;
    }

    const cv::RotatedRect rect = cv::minAreaRect(contour);
    const float long_edge = std::max(rect.size.width, rect.size.height);
    const float short_edge = std::min(rect.size.width, rect.size.height);
    out_span_x = static_cast<int>(std::lround(long_edge));
    out_thickness_px = static_cast<int>(std::lround(short_edge));
    if (out_span_x < kMinLineSpanPx || out_span_x > kMaxLineSpanPx) {
        return false;
    }
    if (out_thickness_px < kMinLineThicknessPx || out_thickness_px > kMaxLineThicknessPx) {
        return false;
    }

    out_peak_ix = static_cast<int>(std::lround(rect.center.x));
    out_peak_iy = static_cast<int>(std::lround(rect.center.y));

    if (!dump_stages_dir.empty()) {
        cv::Mat rect_vis;
        cv::cvtColor(component_mask, rect_vis, cv::COLOR_GRAY2BGR);
        cv::Point2f box_points[4];
        rect.points(box_points);
        for (int i = 0; i < 4; ++i) {
            cv::line(rect_vis,
                     box_points[i],
                     box_points[(i + 1) % 4],
                     cv::Scalar(0, 255, 0),
                     2,
                     cv::LINE_AA);
        }
        cv::circle(rect_vis,
                   rect.center,
                   4,
                   cv::Scalar(0, 0, 255),
                   cv::FILLED,
                   cv::LINE_AA);
        saveRoiStage(dump_stages_dir, "10_roi_line_min_rect.jpg", rect_vis);
    }
    return true;
}

struct RowSegment {
    int start = 0;
    int end = 0;
    int score = 0;
};

bool findBrightestHorizontalLine(const cv::Mat& gray,
                                 int& out_peak_ix,
                                 int& out_peak_iy,
                                 int& out_span_x,
                                 int& out_band_rows,
                                 const std::string& dump_stages_dir) {
    if (gray.empty() || gray.type() != CV_8UC1) {
        return false;
    }

    std::vector<int> bright_count(static_cast<std::size_t>(gray.rows), 0);
    for (int row = 0; row < gray.rows; ++row) {
        const uint8_t* ptr = gray.ptr<uint8_t>(row);
        int count = 0;
        for (int col = 0; col < gray.cols; ++col) {
            if (ptr[col] >= kLineGrayMin) {
                ++count;
            }
        }
        bright_count[static_cast<std::size_t>(row)] = count;
    }

    std::vector<RowSegment> segments;
    RowSegment current;
    bool in_segment = false;
    for (int row = 0; row < gray.rows; ++row) {
        const int count = bright_count[static_cast<std::size_t>(row)];
        const bool valid = count >= kMinBrightPixelsPerRow && count <= kMaxBrightPixelsPerRow;
        if (valid) {
            if (!in_segment) {
                current = RowSegment{row, row, count};
                in_segment = true;
            } else {
                current.end = row;
                current.score += count;
            }
        } else if (in_segment) {
            segments.push_back(current);
            in_segment = false;
        }
    }
    if (in_segment) {
        segments.push_back(current);
    }
    if (segments.empty()) {
        return false;
    }

    const auto best_it = std::max_element(
        segments.begin(),
        segments.end(),
        [](const RowSegment& a, const RowSegment& b) { return a.score < b.score; });
    const RowSegment best = *best_it;
    out_band_rows = best.end - best.start + 1;
    if (out_band_rows <= 0 || out_band_rows > kMaxLineBandRows) {
        return false;
    }

    cv::Mat line_mask = cv::Mat::zeros(gray.size(), CV_8UC1);
    for (int row = best.start; row <= best.end; ++row) {
        const uint8_t* ptr = gray.ptr<uint8_t>(row);
        uint8_t* mask_ptr = line_mask.ptr<uint8_t>(row);
        for (int col = 0; col < gray.cols; ++col) {
            if (ptr[col] >= kLineGrayMin) {
                mask_ptr[col] = 255;
            }
        }
    }
    if (cv::countNonZero(line_mask) <= 0) {
        return false;
    }

    const cv::Mat component_mask = largestComponentMask(line_mask);
    if (component_mask.empty() || cv::countNonZero(component_mask) <= 0) {
        return false;
    }
    saveRoiStage(dump_stages_dir, "09_roi_line_band_mask.jpg", line_mask);
    saveRoiStage(dump_stages_dir, "10_roi_line_mask.jpg", component_mask);

    int thickness_px = 0;
    if (!measureLineFromComponentMask(
            component_mask, out_peak_ix, out_peak_iy, out_span_x, thickness_px, dump_stages_dir)) {
        return false;
    }
    (void)thickness_px;
    return true;
}

}  // namespace

BrightestDetection detectBrightestLineInBox(const cv::Mat& bgr,
                                            const Box& center_box,
                                            const std::string& dump_stages_dir) {
    BrightestDetection out;
    out.method = "roi_enhance_bright_horizontal_line_min_rect";
    if (bgr.empty()) {
        out.reason = "empty frame";
        return out;
    }

    const RoiCrop crop = cropRoiBgr(bgr, center_box);
    saveRoiStage(dump_stages_dir, "05_roi_bgr.jpg", crop.roi_bgr);

    const cv::Mat enhanced = brightnessEnhanceRoi(crop.roi_bgr);
    saveRoiStage(dump_stages_dir, "06_roi_enhanced.jpg", enhanced);

    cv::Mat gray;
    cv::cvtColor(enhanced, gray, cv::COLOR_BGR2GRAY);
    saveRoiStage(dump_stages_dir, "07_roi_gray.jpg", gray);

    int ix = 0;
    int iy = 0;
    int span_x = 0;
    int band_rows = 0;
    if (!findBrightestHorizontalLine(gray, ix, iy, span_x, band_rows, dump_stages_dir)) {
        out.reason = opencv_detect::kReasonLineNotFound;
        return out;
    }

    out.found = true;
    out.peak_x = crop.x + ix;
    out.peak_y = crop.y + iy;
    out.center = Point2d{static_cast<double>(out.peak_x), static_cast<double>(out.peak_y)};
    out.peak_brightness_v = static_cast<double>(gray.at<uint8_t>(
        std::min(std::max(iy, 0), gray.rows - 1),
        std::min(std::max(ix, 0), gray.cols - 1)));
    out.peak_score = static_cast<double>(span_x * band_rows);
    out.lr = calcLrDistanceToBox(center_box, out.center);
    return out;
}

}  // namespace zero_point
