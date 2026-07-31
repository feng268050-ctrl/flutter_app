#pragma once

#include "edgedrawing_types.h"

#include <opencv2/core.hpp>

#include <optional>
#include <string>
#include <vector>

namespace edgedrawing {

struct FittedCircle {
    bool found = false;
    double cx = 0.0;
    double cy = 0.0;
    double radius = 0.0;
    double circularity = 0.0;
    double contour_area = 0.0;
    bool has_ellipse = false;
    double ellipse_cx = 0.0;
    double ellipse_cy = 0.0;
    double ellipse_axis_a = 0.0;
    double ellipse_axis_b = 0.0;
    double ellipse_angle_deg = 0.0;
};

struct AnchorCandidate {
    Point2d center;
    int w = 0;
    int h = 0;
    double dist2 = 0.0;
    int priority = 0;  // lower = preferred (ellipse/circle before line before segment)
};

struct ScanVChannelRadialAdaptiveEstimate {
    bool found = false;
    double cx = 0.0;
    double cy = 0.0;
    double radius = 0.0;
    double weighted_cx = 0.0;
    double weighted_cy = 0.0;
    int valid_rays = 0;
    std::vector<cv::Point2d> edge_points;
};


void saveStage(const std::string& dump_dir, const std::string& name, const cv::Mat& img);

void saveTextStage(const std::string& dump_dir, const std::string& name, const std::string& text);

void saveFitOverlay(const cv::Mat& bgr,
                    const FittedCircle& fit,
                    const std::string& dump_dir);

cv::Mat grayToBgr(const cv::Mat& gray);

void drawSegments(cv::Mat& canvas, const std::vector<std::vector<cv::Point>>& segments);

void drawLines(cv::Mat& canvas, const cv::Mat& lines);

void drawEllipses(cv::Mat& canvas, const cv::Mat& ellipses);

void dumpCandidateOverlay(const cv::Mat& bgr,
                          const Box& valid_box,
                          const std::optional<Point2d>& reference_zero_xy,
                          const std::vector<AnchorCandidate>& candidates,
                          const std::optional<AnchorCandidate>& best,
                          const std::string& dump_dir);

void saveScanVChannelRadialAdaptiveDebugOverlay(const cv::Mat& bgr,
                                                const ScanVChannelRadialAdaptiveEstimate& estimate,
                                                double smooth_cx,
                                                double smooth_cy,
                                                double smooth_radius,
                                                const Box& box,
                                                const std::string& dump_dir);

}  // namespace edgedrawing
