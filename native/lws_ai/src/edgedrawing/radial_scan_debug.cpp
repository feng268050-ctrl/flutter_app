#include "radial_scan_debug.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include <cerrno>
#include <cmath>
#include <fstream>
#include <sys/stat.h>

namespace edgedrawing {

namespace {

// Top-left OSD blackout (timestamp / device id), aligned with opencv_stain_detect config defaults.
constexpr bool kEnableOsdBlackout = false;
constexpr int kOsdMaskMaxWidth = 850;
constexpr int kOsdMaskMaxHeight = 140;

void mkdirRecursive(const std::string& dir) {
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
                // best effort
            }
        }
    }
    if (::mkdir(dir.c_str(), 0755) != 0 && errno != EEXIST) {
        // best effort
    }
}

}  // namespace

void saveStage(const std::string& dump_dir, const std::string& name, const cv::Mat& img) {
    if (dump_dir.empty() || img.empty()) {
        return;
    }
    mkdirRecursive(dump_dir);
    cv::imwrite(dump_dir + "/" + name, img);
}

void saveTextStage(const std::string& dump_dir, const std::string& name, const std::string& text) {
    if (dump_dir.empty() || text.empty()) {
        return;
    }
    mkdirRecursive(dump_dir);
    std::ofstream out(dump_dir + "/" + name);
    out << text;
}

void saveFitOverlay(const cv::Mat& bgr,
                    const FittedCircle& fit,
                    const std::string& dump_dir) {
    if (bgr.empty() || !fit.found) {
        return;
    }
    cv::Mat vis = bgr.clone();
    const int cx = static_cast<int>(std::lround(fit.cx));
    const int cy = static_cast<int>(std::lround(fit.cy));
    const int radius = std::max(1, static_cast<int>(std::lround(fit.radius)));
    cv::circle(vis, cv::Point(cx, cy), radius, cv::Scalar(0, 255, 255), 2);
    cv::drawMarker(vis, cv::Point(cx, cy), cv::Scalar(0, 255, 255), cv::MARKER_CROSS, 14, 2);
    if (fit.has_ellipse) {
        cv::ellipse(vis,
                    cv::Point(static_cast<int>(std::lround(fit.ellipse_cx)),
                              static_cast<int>(std::lround(fit.ellipse_cy))),
                    cv::Size(std::max(1, static_cast<int>(std::lround(fit.ellipse_axis_a))),
                             std::max(1, static_cast<int>(std::lround(fit.ellipse_axis_b)))),
                    fit.ellipse_angle_deg,
                    0,
                    360,
                    cv::Scalar(0, 255, 0),
                    2,
                    cv::LINE_AA);
    }
    saveStage(dump_dir, "09_fit_overlay.jpg", vis);
}

cv::Mat grayToBgr(const cv::Mat& gray) {
    cv::Mat bgr;
    if (gray.channels() == 1) {
        cv::cvtColor(gray, bgr, cv::COLOR_GRAY2BGR);
    } else {
        bgr = gray.clone();
    }
    return bgr;
}

void drawSegments(cv::Mat& canvas, const std::vector<std::vector<cv::Point>>& segments) {
    for (const auto& seg : segments) {
        if (seg.size() < 2) {
            continue;
        }
        const cv::Scalar color(static_cast<int>(seg[0].x * 37 % 256),
                               static_cast<int>(seg[0].y * 59 % 256),
                               static_cast<int>((seg[0].x + seg[0].y) * 17 % 256));
        cv::polylines(canvas, seg, false, color, 1, cv::LINE_8);
    }
}

void drawLines(cv::Mat& canvas, const cv::Mat& lines) {
    if (lines.empty()) {
        return;
    }
    for (int i = 0; i < lines.rows; ++i) {
        const int x1 = static_cast<int>(lines.at<float>(i, 0));
        const int y1 = static_cast<int>(lines.at<float>(i, 1));
        const int x2 = static_cast<int>(lines.at<float>(i, 2));
        const int y2 = static_cast<int>(lines.at<float>(i, 3));
        cv::line(canvas, cv::Point(x1, y1), cv::Point(x2, y2), cv::Scalar(0, 0, 255), 1, cv::LINE_AA);
    }
}

void drawEllipses(cv::Mat& canvas, const cv::Mat& ellipses) {
    if (ellipses.empty()) {
        return;
    }
    for (int i = 0; i < ellipses.rows; ++i) {
        if (ellipses.cols < 6) {
            continue;
        }
        const int cx = static_cast<int>(std::lround(ellipses.at<double>(i, 0)));
        const int cy = static_cast<int>(std::lround(ellipses.at<double>(i, 1)));
        const double v2 = ellipses.at<double>(i, 2);
        const double v3 = ellipses.at<double>(i, 3);
        const double v4 = ellipses.at<double>(i, 4);
        const double angle = ellipses.at<double>(i, 5);
        cv::Scalar color(0, 0, 255);
        if (std::abs(v2) < 1e-6) {
            color = cv::Scalar(0, 255, 0);
            const int radius = static_cast<int>(std::lround(v3 + v4));
            cv::circle(canvas, cv::Point(cx, cy), std::max(1, radius), color, 2, cv::LINE_AA);
        } else {
            const int axis_a = std::max(1, static_cast<int>(std::lround(v2 + v3)));
            const int axis_b = std::max(1, static_cast<int>(std::lround(v2 + v4)));
            cv::ellipse(canvas,
                        cv::Point(cx, cy),
                        cv::Size(axis_a, axis_b),
                        angle,
                        0,
                        360,
                        color,
                        2,
                        cv::LINE_AA);
        }
    }
}

void dumpCandidateOverlay(const cv::Mat& bgr,
                          const Box& valid_box,
                          const std::optional<Point2d>& reference_zero_xy,
                          const std::vector<AnchorCandidate>& candidates,
                          const std::optional<AnchorCandidate>& best,
                          const std::string& dump_dir) {
    cv::Mat vis = bgr.clone();
    if (kEnableOsdBlackout) {
        cv::rectangle(vis,
                      cv::Rect(0, 0, kOsdMaskMaxWidth, kOsdMaskMaxHeight),
                      cv::Scalar(64, 64, 64),
                      2);
        cv::putText(vis,
                    "OSD",
                    cv::Point(10, 30),
                    cv::FONT_HERSHEY_SIMPLEX,
                    1.0,
                    cv::Scalar(128, 128, 128),
                    2,
                    cv::LINE_AA);
    }
    if (reference_zero_xy) {
        const int ref_x = static_cast<int>(std::lround(reference_zero_xy->x));
        const int ref_y = static_cast<int>(std::lround(reference_zero_xy->y));
        cv::drawMarker(vis,
                       cv::Point(ref_x, ref_y),
                       cv::Scalar(255, 0, 255),
                       cv::MARKER_CROSS,
                       16,
                       2);
    }
    cv::rectangle(vis,
                  cv::Rect(valid_box.x, valid_box.y, valid_box.w, valid_box.h),
                  cv::Scalar(0, 255, 255),
                  2);
    for (const AnchorCandidate& cand : candidates) {
        const int px = static_cast<int>(std::lround(cand.center.x));
        const int py = static_cast<int>(std::lround(cand.center.y));
        cv::circle(vis, cv::Point(px, py), 5, cv::Scalar(255, 128, 0), 1);
    }
    if (best) {
        const int px = static_cast<int>(std::lround(best->center.x));
        const int py = static_cast<int>(std::lround(best->center.y));
        cv::circle(vis, cv::Point(px, py), 9, cv::Scalar(0, 255, 0), 2);
        cv::circle(vis, cv::Point(px, py), 4, cv::Scalar(0, 255, 0), -1);
    }
    saveStage(dump_dir, "20_candidates.jpg", vis);
}

void saveScanVChannelRadialAdaptiveDebugOverlay(const cv::Mat& bgr,
                                                const ScanVChannelRadialAdaptiveEstimate& estimate,
                            double smooth_cx,
                            double smooth_cy,
                            double smooth_radius,
                            const Box& box,
                            const std::string& dump_dir) {
    if (bgr.empty()) {
        return;
    }
    cv::Mat vis = bgr.clone();
    cv::rectangle(vis,
                    cv::Rect(box.x, box.y, box.w, box.h),
                    cv::Scalar(0, 255, 255),
                    2);
    const int weighted_x = static_cast<int>(std::lround(estimate.weighted_cx));
    const int weighted_y = static_cast<int>(std::lround(estimate.weighted_cy));
    cv::drawMarker(vis,
                   cv::Point(weighted_x, weighted_y),
                   cv::Scalar(255, 128, 0),
                   cv::MARKER_CROSS,
                   14,
                   2);
    for (const cv::Point2d& point : estimate.edge_points) {
        cv::circle(vis,
                   cv::Point(static_cast<int>(std::lround(point.x)), static_cast<int>(std::lround(point.y))),
                   2,
                   cv::Scalar(0, 165, 255),
                   -1);
    }
    const int fit_x = static_cast<int>(std::lround(smooth_cx));
    const int fit_y = static_cast<int>(std::lround(smooth_cy));
    const int fit_radius = std::max(1, static_cast<int>(std::lround(smooth_radius)));
    cv::circle(vis, cv::Point(fit_x, fit_y), fit_radius, cv::Scalar(0, 255, 255), 2);
    cv::drawMarker(vis, cv::Point(fit_x, fit_y), cv::Scalar(0, 255, 255), cv::MARKER_CROSS, 14, 2);
    saveStage(dump_dir, "06_scan_v_channel_radial_adaptive_overlay.jpg", vis);
}

}  // namespace edgedrawing
