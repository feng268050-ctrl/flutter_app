#include "scan_v_channel_radial_adaptive.h"

#include "radial_scan_debug.h"

#include "opencv_detect_codes.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/ximgproc/edge_drawing.hpp>

#include <algorithm>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <limits>
#include <optional>
#include <sstream>

namespace edgedrawing {

namespace {

// Top-left OSD blackout (timestamp / device id), aligned with opencv_stain_detect config defaults.
constexpr bool kEnableOsdBlackout = false;
constexpr int kOsdMaskMaxWidth = 850;
constexpr int kOsdMaskMaxHeight = 140;

// HSV red/pink plasma: hue mask + V-channel bright mask → close → largest component → circle/ellipse.
// OpenCV H ∈ [0, 180]; red wraps at 0/180.
constexpr int kPinkHueMin = 130;
constexpr int kPinkHueMax = 175;
constexpr int kRedHueLowMax = 10;
constexpr int kRedHueHighMin = 170;
// Plan A: hue AND bright (excludes diffuse halo); moderate V gate + small guide dilate.
constexpr int kPinkRedSatMin = 50;
constexpr int kPinkRedValMin = 60;
constexpr int kBrightVMin = 220;

// ScanVChannelRadialAdaptive: Gaussian V → weighted centroid → radial scan → adaptive radius → EMA.
constexpr int kVSmoothKernel = 9;
constexpr double kVSmoothSigma = 2.0;
constexpr int kBrightWeightThreshold = 220;
constexpr int kScanVChannelRadialAdaptiveDirections = 360;
constexpr double kScanVChannelRadialAdaptiveRefDistancePx = 10.0;
constexpr int kScanVChannelRadialAdaptiveScanStartPx = 25;
constexpr double kScanVChannelRadialAdaptiveDropRatio = 0.60;
constexpr double kScanVChannelRadialAdaptiveSoftDropRatio = 0.55;
constexpr double kScanVChannelRadialAdaptiveSaturationRef = 240.0;
constexpr int kScanVChannelRadialAdaptiveGradientWindowPx = 10;
constexpr double kScanVChannelRadialAdaptiveMinGradient = 9.0;
constexpr double kScanVChannelRadialAdaptiveLogGradientScale = 120.0;
constexpr double kScanVChannelRadialAdaptiveMinLogGradient = 0.010;
constexpr double kScanVChannelRadialAdaptiveOuterGradientStartRatio = 0.35;
constexpr double kScanVChannelRadialAdaptiveMinRadiusMedianRatio = 0.50;
constexpr double kScanVChannelRadialAdaptiveTightRadiusMedianRatio = 0.75;
constexpr double kScanVChannelRadialAdaptiveMaxRadiusMedianRatio = 1.25;
constexpr double kScanVChannelRadialAdaptiveArcAsymmetryPx = 40.0;
constexpr int kPlasmaMaskOpenKernelSize = 5;
constexpr int kScanVChannelRadialAdaptiveMinValidRays = 24;
constexpr const char kScanVChannelRadialAdaptiveMethod[] = "RadialCircleFit";

constexpr int kMorphCloseKernelSize = 21;
// Large kernel removes vignette/low-frequency illumination; bright plasma stays above surround.
constexpr int kBgNormalizeBlurKernel = 301;
constexpr int kHighPassBlurKernel = 15;
constexpr int kPlasmaGuideDilateKernel = 5;
constexpr double kFusedNormalizedWeight = 0.6;
constexpr double kFusedHighpassWeight = 0.4;
constexpr int kEdgeMagnitudeThreshold = 18;
enum class GradientOperator { Sobel, Scharr };
constexpr GradientOperator kGradientOperator = GradientOperator::Scharr;
constexpr int kMinPinkPlasmaAreaPx = 800;
constexpr int kMinPinkCircleRadiusFloorPx = 80;
constexpr double kMinPinkCircleRadiusScale = 0.12;

int scaledMinPinkCircleRadiusPx(int frame_width, int frame_height) {
    const int dim = std::min(frame_width, frame_height);
    return std::max(kMinPinkCircleRadiusFloorPx,
                    static_cast<int>(std::lround(static_cast<double>(dim) * kMinPinkCircleRadiusScale)));
}

// Enhance + invert blob path (aligned with zero_point brightest_in_box).
constexpr int kBlackGrayThreshold = 80;
constexpr int kMinBlobAreaPx = 4;

// Denoise (Gaussian blur) then dilate binary mask to connect broken edges.
constexpr int kDenoiseBlurKernel = 5;
constexpr double kDenoiseBlurSigma = 1.5;
constexpr int kDilateKernelSize = 7;
constexpr int kDilateIterations = 2;
// Deburr: close internal holes then open to trim edge speckles.
constexpr int kDeburrCloseKernelSize = 9;
constexpr int kDeburrOpenKernelSize = 5;
// Circle fit on deburred mask: largest foreground contour + minEnclosingCircle.
// The circle center (cx, cy) is the EdgeDrawing base point anchor.

cv::ximgproc::EdgeDrawing::Params defaultEdgeDrawingParams() {
    cv::ximgproc::EdgeDrawing::Params params;
    params.EdgeDetectionOperator = cv::ximgproc::EdgeDrawing::PREWITT;
    params.GradientThresholdValue = 20;
    params.MinPathLength = 50;
    params.PFmode = false;
    params.MinLineLength = 10;
    params.NFAValidation = false;
    return params;
}

bool spotSizeOk(int w, int h) {
    return w >= kMinSpotDimensionPx && h >= kMinSpotDimensionPx && w <= kMaxSpotDimensionPx &&
           h <= kMaxSpotDimensionPx;
}

void rejectSpotSize(EdgeDrawingDetection& out, int w, int h) {
    out.found = false;
    out.reject_code = kCodeSpotSizeRejected;
    out.reason = (w < kMinSpotDimensionPx || h < kMinSpotDimensionPx)
                     ? opencv_detect::kReasonSpotSizeBelowMin
                     : opencv_detect::kReasonSpotSizeAboveMax;
}

void rejectCircleRadius(EdgeDrawingDetection& out) {
    out.found = false;
    out.reject_code = kCodeCircleRadiusRejected;
    out.reason = opencv_detect::kReasonCircleRadiusBelowMin;
}

double dist2ToTarget(const Point2d& p, const Point2d& target) {
    const double dx = p.x - target.x;
    const double dy = p.y - target.y;
    return dx * dx + dy * dy;
}

Point2d roiToFramePoint(int roi_x, int roi_y, const Point2d& roi_local) {
    return Point2d{static_cast<double>(roi_x) + roi_local.x, static_cast<double>(roi_y) + roi_local.y};
}

cv::Mat brightnessEnhanceBgr(const cv::Mat& bgr) {
    cv::Mat hsv;
    cv::cvtColor(bgr, hsv, cv::COLOR_BGR2HSV);
    std::vector<cv::Mat> channels;
    cv::split(hsv, channels);
    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(2.5, cv::Size(8, 8));
    clahe->apply(channels[2], channels[2]);
    cv::merge(channels, hsv);
    cv::Mat enhanced;
    cv::cvtColor(hsv, enhanced, cv::COLOR_HSV2BGR);
    enhanced.convertTo(enhanced, -1, 1.15, 12.0);
    return enhanced;
}

cv::Mat buildInvertedGray(const cv::Mat& bgr) {
    cv::Mat gray;
    cv::cvtColor(bgr, gray, cv::COLOR_BGR2GRAY);
    cv::Mat inverted;
    cv::bitwise_not(gray, inverted);
    return inverted;
}

cv::Mat denoiseGray(const cv::Mat& gray) {
    cv::Mat denoised;
    cv::GaussianBlur(gray,
                     denoised,
                     cv::Size(kDenoiseBlurKernel, kDenoiseBlurKernel),
                     kDenoiseBlurSigma);
    return denoised;
}

cv::Mat dilateThresholdMask(const cv::Mat& gray, int threshold_type) {
    cv::Mat binary;
    cv::threshold(gray, binary, kBlackGrayThreshold, 255, threshold_type);
    const cv::Mat kernel =
        cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(kDilateKernelSize, kDilateKernelSize));
    cv::Mat dilated;
    cv::dilate(binary, dilated, kernel, cv::Point(-1, -1), kDilateIterations);
    return dilated;
}

cv::Mat buildDilatedDarkRegionMask(const cv::Mat& enhanced_bgr) {
    cv::Mat gray;
    cv::cvtColor(enhanced_bgr, gray, cv::COLOR_BGR2GRAY);
    const cv::Mat denoised = denoiseGray(gray);
    // Dark circular interior -> white after BINARY_INV, then dilate to bridge gaps.
    return dilateThresholdMask(denoised, cv::THRESH_BINARY_INV);
}

cv::Mat deburrMask(const cv::Mat& mask) {
    const cv::Mat close_kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE,
                                                          cv::Size(kDeburrCloseKernelSize, kDeburrCloseKernelSize));
    cv::Mat closed;
    cv::morphologyEx(mask, closed, cv::MORPH_CLOSE, close_kernel);
    const cv::Mat open_kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE,
                                                          cv::Size(kDeburrOpenKernelSize, kDeburrOpenKernelSize));
    cv::Mat deburred;
    cv::morphologyEx(closed, deburred, cv::MORPH_OPEN, open_kernel);
    return deburred;
}

std::string fittedCircleToJson(const FittedCircle& circle, const char* method) {
    if (!circle.found) {
        return "{\"found\":false}";
    }
    std::ostringstream out;
    out << std::fixed << std::setprecision(2);
    out << "{\"found\":true"
        << ",\"method\":\"" << method << '"'
        << ",\"cx\":" << circle.cx
        << ",\"cy\":" << circle.cy
        << ",\"radius\":" << circle.radius
        << ",\"circularity\":" << circle.circularity
        << ",\"contour_area\":" << circle.contour_area;
    if (circle.has_ellipse) {
        out << ",\"ellipse\":{"
            << "\"cx\":" << circle.ellipse_cx
            << ",\"cy\":" << circle.ellipse_cy
            << ",\"axis_a\":" << circle.ellipse_axis_a
            << ",\"axis_b\":" << circle.ellipse_axis_b
            << ",\"angle_deg\":" << circle.ellipse_angle_deg
            << '}';
    }
    out << '}';
    return out.str();
}

cv::Mat foregroundMaskForContour(const cv::Mat& mask) {
    cv::Mat foreground;
    cv::threshold(mask, foreground, 127, 255, cv::THRESH_BINARY_INV);
    return foreground;
}

FittedCircle fitMinEnclosingCircle(const cv::Mat& mask) {
    FittedCircle result;
    if (mask.empty()) {
        return result;
    }
    const cv::Mat foreground = foregroundMaskForContour(mask);
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(foreground, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    if (contours.empty()) {
        return result;
    }

    const auto largest = std::max_element(contours.begin(),
                                          contours.end(),
                                          [](const std::vector<cv::Point>& a, const std::vector<cv::Point>& b) {
                                              return cv::contourArea(a) < cv::contourArea(b);
                                          });
    const double area = cv::contourArea(*largest);
    if (area < kMinBlobAreaPx) {
        return result;
    }

    cv::Point2f center;
    float radius = 0.0f;
    cv::minEnclosingCircle(*largest, center, radius);
    const double peri = cv::arcLength(*largest, true);
    result.found = true;
    result.cx = static_cast<double>(center.x);
    result.cy = static_cast<double>(center.y);
    result.radius = static_cast<double>(radius);
    result.contour_area = area;
    result.circularity = 4.0 * CV_PI * area / (peri * peri + 1e-6);
    return result;
}

void maskOutOsdRegion(cv::Mat& mask) {
    if (!kEnableOsdBlackout || mask.empty()) {
        return;
    }
    const int w = std::min(kOsdMaskMaxWidth, mask.cols);
    const int h = std::min(kOsdMaskMaxHeight, mask.rows);
    if (w > 0 && h > 0) {
        mask(cv::Rect(0, 0, w, h)).setTo(0);
    }
}

Box clampBoxToFrame(const Box& box, int frame_w, int frame_h) {
    const int x = std::max(0, std::min(box.x, frame_w - 1));
    const int y = std::max(0, std::min(box.y, frame_h - 1));
    const int bw = std::max(1, std::min(box.w, frame_w - x));
    const int bh = std::max(1, std::min(box.h, frame_h - y));
    return Box{x, y, bw, bh};
}

void applyRoiMask(cv::Mat& mask, const Box& box) {
    if (mask.empty()) {
        return;
    }
    cv::Mat roi_gate = cv::Mat::zeros(mask.size(), CV_8UC1);
    cv::rectangle(roi_gate, cv::Rect(box.x, box.y, box.w, box.h), cv::Scalar(255), cv::FILLED);
    cv::bitwise_and(mask, roi_gate, mask);
}

cv::Mat buildPinkRedHueMask(const cv::Mat& hsv) {
    const cv::Scalar lo(0, kPinkRedSatMin, kPinkRedValMin);
    cv::Mat pink;
    cv::inRange(hsv,
                cv::Scalar(kPinkHueMin, lo[1], lo[2]),
                cv::Scalar(kPinkHueMax, 255, 255),
                pink);
    cv::Mat red_lo;
    cv::inRange(hsv,
                cv::Scalar(0, lo[1], lo[2]),
                cv::Scalar(kRedHueLowMax, 255, 255),
                red_lo);
    cv::Mat red_hi;
    cv::inRange(hsv,
                cv::Scalar(kRedHueHighMin, lo[1], lo[2]),
                cv::Scalar(180, 255, 255),
                red_hi);
    cv::Mat hue_mask;
    cv::bitwise_or(pink, red_lo, hue_mask);
    cv::bitwise_or(hue_mask, red_hi, hue_mask);
    maskOutOsdRegion(hue_mask);
    return hue_mask;
}

cv::Mat buildBrightVMask(const cv::Mat& hsv) {
    std::vector<cv::Mat> channels;
    cv::split(hsv, channels);
    cv::Mat bright;
    cv::threshold(channels[2], bright, kBrightVMin, 255, cv::THRESH_BINARY);
    maskOutOsdRegion(bright);
    return bright;
}

cv::Mat dilatePlasmaGuideMask(const cv::Mat& binary) {
    const int kernel = kPlasmaGuideDilateKernel | 1;
    const cv::Mat element = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(kernel, kernel));
    cv::Mat dilated;
    cv::dilate(binary, dilated, element);
    return dilated;
}

cv::Mat morphCloseMask(const cv::Mat& mask) {
    const cv::Mat kernel = cv::getStructuringElement(
        cv::MORPH_ELLIPSE, cv::Size(kMorphCloseKernelSize, kMorphCloseKernelSize));
    cv::Mat closed;
    cv::morphologyEx(mask, closed, cv::MORPH_CLOSE, kernel);
    return closed;
}

cv::Mat extractHsvVChannel(const cv::Mat& hsv) {
    std::vector<cv::Mat> channels;
    cv::split(hsv, channels);
    return channels[2];
}

cv::Mat buildHsvBinaryMask(const cv::Mat& hsv) {
    cv::Mat hue_mask = buildPinkRedHueMask(hsv);
    cv::Mat bright_mask = buildBrightVMask(hsv);
    cv::Mat binary;
    cv::bitwise_and(hue_mask, bright_mask, binary);
    return binary;
}

cv::Mat toGray8(const cv::Mat& input) {
    if (input.channels() == 1) {
        return input;
    }
    cv::Mat gray;
    cv::cvtColor(input, gray, cv::COLOR_BGR2GRAY);
    return gray;
}

/** Subtract large-kernel blurred background and restore global mean (vignette flatten). */
cv::Mat normalizeBackground(const cv::Mat& gray) {
    const int kernel = kBgNormalizeBlurKernel | 1;
    cv::Mat background;
    cv::GaussianBlur(gray, background, cv::Size(kernel, kernel), 0.0);
    cv::Mat gray_f;
    cv::Mat bg_f;
    gray.convertTo(gray_f, CV_32F);
    background.convertTo(bg_f, CV_32F);
    const float mean_val = static_cast<float>(cv::mean(gray)[0]);
    cv::Mat flattened = gray_f - bg_f + mean_val;
    cv::Mat out;
    flattened.convertTo(out, CV_8U);
    return out;
}

/** High-pass: subtract low-frequency background from normalized image. */
cv::Mat highPassEnhance(const cv::Mat& gray) {
    const int kernel = kHighPassBlurKernel | 1;
    cv::Mat low_freq;
    cv::GaussianBlur(gray, low_freq, cv::Size(kernel, kernel), 0.0);
    cv::Mat high_pass;
    cv::subtract(gray, low_freq, high_pass, cv::noArray(), CV_16S);
    cv::Mat abs_high_pass;
    cv::convertScaleAbs(high_pass, abs_high_pass);
    return abs_high_pass;
}

cv::Mat computeGradientMagnitude(const cv::Mat& gray, GradientOperator op) {
    cv::Mat grad_x;
    cv::Mat grad_y;
    cv::Mat abs_grad_x;
    cv::Mat abs_grad_y;
    cv::Mat magnitude;
    if (op == GradientOperator::Scharr) {
        cv::Scharr(gray, grad_x, CV_16S, 1, 0);
        cv::Scharr(gray, grad_y, CV_16S, 0, 1);
    } else {
        cv::Sobel(gray, grad_x, CV_16S, 1, 0, 3);
        cv::Sobel(gray, grad_y, CV_16S, 0, 1, 3);
    }
    cv::convertScaleAbs(grad_x, abs_grad_x);
    cv::convertScaleAbs(grad_y, abs_grad_y);
    cv::addWeighted(abs_grad_x, 0.5, abs_grad_y, 0.5, 0, magnitude);
    return magnitude;
}

cv::Mat largestComponentMask(const cv::Mat& mask) {
    cv::Mat binary;
    cv::threshold(mask, binary, 127, 255, cv::THRESH_BINARY);
    cv::Mat labels;
    cv::Mat stats;
    cv::Mat centroids;
    const int num = cv::connectedComponentsWithStats(binary, labels, stats, centroids, 8);
    if (num <= 1) {
        return cv::Mat::zeros(mask.size(), CV_8UC1);
    }
    int best_label = 1;
    for (int label = 2; label < num; ++label) {
        if (stats.at<int>(label, cv::CC_STAT_AREA) > stats.at<int>(best_label, cv::CC_STAT_AREA)) {
            best_label = label;
        }
    }
    cv::Mat component;
    cv::compare(labels, best_label, component, cv::CMP_EQ);
    component.convertTo(component, CV_8UC1, 255);
    return component;
}

cv::Mat refinePlasmaBinaryMask(const cv::Mat& binary) {
    const cv::Mat largest = largestComponentMask(binary);
    const cv::Mat open_kernel = cv::getStructuringElement(
        cv::MORPH_ELLIPSE, cv::Size(kPlasmaMaskOpenKernelSize, kPlasmaMaskOpenKernelSize));
    cv::Mat opened;
    cv::morphologyEx(largest, opened, cv::MORPH_OPEN, open_kernel);
    return opened;
}

/** Largest connected component → minEnclosingCircle + fitEllipse. */
FittedCircle fitLargestComponentCircleOrEllipse(const cv::Mat& mask, int min_area_px) {
    FittedCircle result;
    if (mask.empty()) {
        return result;
    }
    cv::Mat binary;
    cv::threshold(mask, binary, 127, 255, cv::THRESH_BINARY);
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(binary, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    if (contours.empty()) {
        return result;
    }
    const auto largest = std::max_element(contours.begin(),
                                          contours.end(),
                                          [](const std::vector<cv::Point>& a, const std::vector<cv::Point>& b) {
                                              return cv::contourArea(a) < cv::contourArea(b);
                                          });
    const double area = cv::contourArea(*largest);
    if (area < static_cast<double>(min_area_px)) {
        return result;
    }

    cv::Point2f center;
    float radius = 0.0f;
    cv::minEnclosingCircle(*largest, center, radius);
    const double peri = cv::arcLength(*largest, true);
    result.found = true;
    result.cx = static_cast<double>(center.x);
    result.cy = static_cast<double>(center.y);
    result.radius = static_cast<double>(radius);
    result.contour_area = area;
    result.circularity = 4.0 * CV_PI * area / (peri * peri + 1e-6);

    if (largest->size() >= 5) {
        const cv::RotatedRect ellipse = cv::fitEllipse(*largest);
        result.has_ellipse = true;
        result.ellipse_cx = static_cast<double>(ellipse.center.x);
        result.ellipse_cy = static_cast<double>(ellipse.center.y);
        result.ellipse_axis_a = static_cast<double>(ellipse.size.width) * 0.5;
        result.ellipse_axis_b = static_cast<double>(ellipse.size.height) * 0.5;
        result.ellipse_angle_deg = static_cast<double>(ellipse.angle);
    }
    return result;
}

void collectPinkCircleCandidate(const FittedCircle& circle,
                                const Point2d& target,
                                std::vector<AnchorCandidate>& out) {
    if (!circle.found) {
        return;
    }
    AnchorCandidate cand;
    cand.center = Point2d{circle.cx, circle.cy};
    cand.w = std::max(1, static_cast<int>(std::lround(circle.radius * 2.0)));
    cand.h = cand.w;
    cand.dist2 = dist2ToTarget(cand.center, target);
    cand.priority = -1;
    out.push_back(cand);
}

/** Largest min-enclosing circle among EdgeDrawing edge contours (no mask preprocess). */
FittedCircle fitMinEnclosingCircleFromEdgeImage(const cv::Mat& edge_image) {
    FittedCircle result;
    if (edge_image.empty()) {
        return result;
    }
    cv::Mat binary;
    cv::threshold(edge_image, binary, 127, 255, cv::THRESH_BINARY);
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(binary, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    double best_radius = 0.0;
    for (const std::vector<cv::Point>& contour : contours) {
        const double area = cv::contourArea(contour);
        if (area < kMinBlobAreaPx) {
            continue;
        }
        cv::Point2f center;
        float radius = 0.0f;
        cv::minEnclosingCircle(contour, center, radius);
        if (static_cast<double>(radius) <= best_radius) {
            continue;
        }
        best_radius = static_cast<double>(radius);
        const double peri = cv::arcLength(contour, true);
        result.found = true;
        result.cx = static_cast<double>(center.x);
        result.cy = static_cast<double>(center.y);
        result.radius = best_radius;
        result.contour_area = area;
        result.circularity = 4.0 * CV_PI * area / (peri * peri + 1e-6);
    }
    return result;
}

bool findLargestBlobInRoi(const cv::Mat& roi_bgr,
                          cv::Rect& out_bounds,
                          int& out_peak_ix,
                          int& out_peak_iy) {
    const cv::Mat inverted = buildInvertedGray(roi_bgr);
    cv::Mat mask;
    cv::threshold(inverted, mask, kBlackGrayThreshold, 255, cv::THRESH_BINARY_INV);

    cv::Mat labels;
    cv::Mat stats;
    cv::Mat centroids;
    const int label_count =
        cv::connectedComponentsWithStats(mask, labels, stats, centroids, 8, CV_32S);
    if (label_count <= 1) {
        return false;
    }

    int best_label = -1;
    int best_area = 0;
    for (int label = 1; label < label_count; ++label) {
        const int area = stats.at<int>(label, cv::CC_STAT_AREA);
        if (area < kMinBlobAreaPx) {
            continue;
        }
        if (area > best_area) {
            best_area = area;
            best_label = label;
        }
    }
    if (best_label < 0) {
        return false;
    }

    out_bounds.x = stats.at<int>(best_label, cv::CC_STAT_LEFT);
    out_bounds.y = stats.at<int>(best_label, cv::CC_STAT_TOP);
    out_bounds.width = stats.at<int>(best_label, cv::CC_STAT_WIDTH);
    out_bounds.height = stats.at<int>(best_label, cv::CC_STAT_HEIGHT);
    out_peak_ix = out_bounds.x + out_bounds.width / 2;
    out_peak_iy = out_bounds.y + out_bounds.height / 2;
    return out_bounds.width > 0 && out_bounds.height > 0;
}

void collectLargestBlobCandidate(const cv::Mat& enhanced_bgr,
                                 const Box& valid_box,
                                 const Point2d& target,
                                 std::vector<AnchorCandidate>& out) {
    const int x = valid_box.x;
    const int y = valid_box.y;
    const int bw = valid_box.w;
    const int bh = valid_box.h;
    if (x < 0 || y < 0 || x + bw > enhanced_bgr.cols || y + bh > enhanced_bgr.rows) {
        return;
    }
    const cv::Mat roi = enhanced_bgr(cv::Rect(x, y, bw, bh));
    cv::Rect blob;
    int peak_ix = 0;
    int peak_iy = 0;
    if (!findLargestBlobInRoi(roi, blob, peak_ix, peak_iy)) {
        return;
    }

    const int blob_w = blob.width;
    const int blob_h = blob.height;
    if (!spotSizeOk(blob_w, blob_h)) {
        return;
    }

    AnchorCandidate cand;
    cand.center = Point2d{static_cast<double>(x + peak_ix), static_cast<double>(y + peak_iy)};
    cand.w = blob_w;
    cand.h = blob_h;
    cand.dist2 = dist2ToTarget(cand.center, target);
    cand.priority = 0;  // highest: enhance-invert largest blob
    out.push_back(cand);
}

void applyTopLeftOsdBlackout(cv::Mat& bgr, int max_width, int max_height) {
    if (bgr.empty() || max_width <= 0 || max_height <= 0) {
        return;
    }
    const int w = std::min(max_width, bgr.cols);
    const int h = std::min(max_height, bgr.rows);
    if (w <= 0 || h <= 0) {
        return;
    }
    bgr(cv::Rect(0, 0, w, h)).setTo(cv::Scalar(0, 0, 0));
}

bool pointInsideBox(double px, double py, const Box& box) {
    return px >= box.x && py >= box.y && px < box.x + box.w && py < box.y + box.h;
}

void collectEllipseCandidates(const cv::Mat& ellipses,
                              int roi_x,
                              int roi_y,
                              int roi_w,
                              int roi_h,
                              const Box& valid_box,
                              const Point2d& target,
                              std::vector<AnchorCandidate>& out) {
    if (ellipses.empty()) {
        return;
    }
    for (int i = 0; i < ellipses.rows; ++i) {
        if (ellipses.cols < 6) {
            continue;
        }
        const double cx = ellipses.at<double>(i, 0);
        const double cy = ellipses.at<double>(i, 1);
        const double v2 = ellipses.at<double>(i, 2);
        const double v3 = ellipses.at<double>(i, 3);
        const double v4 = ellipses.at<double>(i, 4);

        if (cx < 0 || cy < 0 || cx >= roi_w || cy >= roi_h) {
            continue;
        }

        int w = 0;
        int h = 0;
        if (std::abs(v2) < 1e-6) {
            // Circle branch (see OpenCV ed.py sample).
            const int radius = static_cast<int>(std::lround(v3 + v4));
            w = std::max(1, radius * 2);
            h = w;
        } else {
            w = std::max(1, static_cast<int>(std::lround(v2 + v3)));
            h = std::max(1, static_cast<int>(std::lround(v2 + v4)));
        }
        if (!spotSizeOk(w, h)) {
            continue;
        }

        AnchorCandidate cand;
        cand.center = roiToFramePoint(roi_x, roi_y, Point2d{cx, cy});
        if (!pointInsideBox(cand.center.x, cand.center.y, valid_box)) {
            continue;
        }
        cand.w = w;
        cand.h = h;
        cand.dist2 = dist2ToTarget(cand.center, target);
        cand.priority = 1;
        out.push_back(cand);
    }
}

void collectLineCandidates(const cv::Mat& lines,
                           int roi_x,
                           int roi_y,
                           int roi_w,
                           int roi_h,
                           const Box& valid_box,
                           const Point2d& target,
                           std::vector<AnchorCandidate>& out) {
    if (lines.empty()) {
        return;
    }
    for (int i = 0; i < lines.rows; ++i) {
        const float x1 = lines.at<float>(i, 0);
        const float y1 = lines.at<float>(i, 1);
        const float x2 = lines.at<float>(i, 2);
        const float y2 = lines.at<float>(i, 3);
        const double mx = (static_cast<double>(x1) + x2) * 0.5;
        const double my = (static_cast<double>(y1) + y2) * 0.5;
        if (mx < 0 || my < 0 || mx >= roi_w || my >= roi_h) {
            continue;
        }
        const int w = std::max(1, static_cast<int>(std::lround(std::abs(x2 - x1) + 1.0f)));
        const int h = std::max(1, static_cast<int>(std::lround(std::abs(y2 - y1) + 1.0f)));
        if (!spotSizeOk(w, h)) {
            continue;
        }
        AnchorCandidate cand;
        cand.center = roiToFramePoint(roi_x, roi_y, Point2d{mx, my});
        if (!pointInsideBox(cand.center.x, cand.center.y, valid_box)) {
            continue;
        }
        cand.w = w;
        cand.h = h;
        cand.dist2 = dist2ToTarget(cand.center, target);
        cand.priority = 2;
        out.push_back(cand);
    }
}

void collectSegmentCandidates(const std::vector<std::vector<cv::Point>>& segments,
                              int roi_x,
                              int roi_y,
                              int roi_w,
                              int roi_h,
                              const Box& valid_box,
                              const Point2d& target,
                              std::vector<AnchorCandidate>& out) {
    for (const auto& seg : segments) {
        if (seg.size() < 2) {
            continue;
        }
        double sum_x = 0.0;
        double sum_y = 0.0;
        int min_x = seg.front().x;
        int max_x = seg.front().x;
        int min_y = seg.front().y;
        int max_y = seg.front().y;
        for (const cv::Point& p : seg) {
            sum_x += p.x;
            sum_y += p.y;
            min_x = std::min(min_x, p.x);
            max_x = std::max(max_x, p.x);
            min_y = std::min(min_y, p.y);
            max_y = std::max(max_y, p.y);
        }
        const double mx = sum_x / static_cast<double>(seg.size());
        const double my = sum_y / static_cast<double>(seg.size());
        if (mx < 0 || my < 0 || mx >= roi_w || my >= roi_h) {
            continue;
        }
        const int w = std::max(1, max_x - min_x + 1);
        const int h = std::max(1, max_y - min_y + 1);
        if (!spotSizeOk(w, h)) {
            continue;
        }
        AnchorCandidate cand;
        cand.center = roiToFramePoint(roi_x, roi_y, Point2d{mx, my});
        if (!pointInsideBox(cand.center.x, cand.center.y, valid_box)) {
            continue;
        }
        cand.w = w;
        cand.h = h;
        cand.dist2 = dist2ToTarget(cand.center, target);
        cand.priority = 3;
        out.push_back(cand);
    }
}
std::optional<AnchorCandidate> pickBestCandidate(std::vector<AnchorCandidate>& candidates) {
    if (candidates.empty()) {
        return std::nullopt;
    }
    std::sort(candidates.begin(), candidates.end(), [](const AnchorCandidate& a, const AnchorCandidate& b) {
        if (a.priority != b.priority) {
            return a.priority < b.priority;
        }
        return a.dist2 < b.dist2;
    });
    return candidates.front();
}

cv::Mat smoothVChannel(const cv::Mat& v_channel) {
    const int kernel = kVSmoothKernel | 1;
    cv::Mat smoothed;
    cv::GaussianBlur(v_channel, smoothed, cv::Size(kernel, kernel), kVSmoothSigma);
    return smoothed;
}

double sampleVBilinear(const cv::Mat& v, double x, double y) {
    if (v.empty() || x < 0.0 || y < 0.0 || x >= static_cast<double>(v.cols - 1) ||
        y >= static_cast<double>(v.rows - 1)) {
        return 0.0;
    }
    const int x0 = static_cast<int>(std::floor(x));
    const int y0 = static_cast<int>(std::floor(y));
    const double fx = x - static_cast<double>(x0);
    const double fy = y - static_cast<double>(y0);
    const double v00 = static_cast<double>(v.at<uchar>(y0, x0));
    const double v10 = static_cast<double>(v.at<uchar>(y0, x0 + 1));
    const double v01 = static_cast<double>(v.at<uchar>(y0 + 1, x0));
    const double v11 = static_cast<double>(v.at<uchar>(y0 + 1, x0 + 1));
    const double top = v00 * (1.0 - fx) + v10 * fx;
    const double bottom = v01 * (1.0 - fx) + v11 * fx;
    return top * (1.0 - fy) + bottom * fy;
}

Point2d brightWeightedCentroid(const cv::Mat& v_smooth, const Box& box, int bright_threshold) {
    const cv::Rect roi_rect(box.x, box.y, box.w, box.h);
    const cv::Mat roi = v_smooth(roi_rect);
    double sum_w = 0.0;
    double sum_x = 0.0;
    double sum_y = 0.0;
    for (int row = 0; row < roi.rows; ++row) {
        for (int col = 0; col < roi.cols; ++col) {
            const double value = static_cast<double>(roi.at<uchar>(row, col));
            if (value < static_cast<double>(bright_threshold)) {
                continue;
            }
            const double delta = value - static_cast<double>(bright_threshold);
            const double weight = delta * delta;
            sum_w += weight;
            sum_x += static_cast<double>(box.x + col) * weight;
            sum_y += static_cast<double>(box.y + row) * weight;
        }
    }
    if (sum_w <= 1e-6) {
        return Point2d{
            box.x + box.w * 0.5,
            box.y + box.h * 0.5,
        };
    }
    return Point2d{sum_x / sum_w, sum_y / sum_w};
}

cv::Mat visualizeBrightnessWeights(const cv::Mat& v_smooth, const Box& box, int bright_threshold) {
    cv::Mat weight_map = cv::Mat::zeros(v_smooth.size(), CV_8UC1);
    const cv::Rect roi_rect(box.x, box.y, box.w, box.h);
    const cv::Mat roi = v_smooth(roi_rect);
    double max_weight = 0.0;
    for (int row = 0; row < roi.rows; ++row) {
        for (int col = 0; col < roi.cols; ++col) {
            const double value = static_cast<double>(roi.at<uchar>(row, col));
            const double delta = std::max(0.0, value - static_cast<double>(bright_threshold));
            const double weight = delta * delta;
            max_weight = std::max(max_weight, weight);
            weight_map.at<uchar>(box.y + row, box.x + col) =
                static_cast<uchar>(std::min(255.0, weight));
        }
    }
    if (max_weight > 1e-6) {
        weight_map.convertTo(weight_map, CV_8U, 255.0 / max_weight);
    }
    return weight_map;
}

int maxRadiusInBox(const Box& box, double cx, double cy, double cos_a, double sin_a) {
    int max_r = 1;
    for (int r = 1; r < 4096; ++r) {
        const double px = cx + static_cast<double>(r) * cos_a;
        const double py = cy + static_cast<double>(r) * sin_a;
        if (px < static_cast<double>(box.x) || px >= static_cast<double>(box.x + box.w) ||
            py < static_cast<double>(box.y) || py >= static_cast<double>(box.y + box.h)) {
            return std::max(1, r - 1);
        }
        max_r = r;
    }
    return max_r;
}

bool plasmaGuideAllows(const cv::Mat& plasma_guide, double x, double y) {
    if (plasma_guide.empty()) {
        return true;
    }
    const int px = static_cast<int>(std::lround(x));
    const int py = static_cast<int>(std::lround(y));
    if (px < 0 || py < 0 || px >= plasma_guide.cols || py >= plasma_guide.rows) {
        return false;
    }
    return plasma_guide.at<uchar>(py, px) > 0;
}

std::optional<double> findScanVChannelRadialEdgeDistance(const cv::Mat& v_smooth,
                                              const cv::Mat& plasma_guide,
                                              const Box& box,
                                              double cx,
                                              double cy,
                                              double angle_deg) {
    const double angle_rad = angle_deg * CV_PI / 180.0;
    const double cos_a = std::cos(angle_rad);
    const double sin_a = std::sin(angle_rad);
    const int max_r = maxRadiusInBox(box, cx, cy, cos_a, sin_a);
    if (max_r <= kScanVChannelRadialAdaptiveScanStartPx + 2) {
        return std::nullopt;
    }

    const double ref = sampleVBilinear(v_smooth,
                                       cx + cos_a * kScanVChannelRadialAdaptiveRefDistancePx,
                                       cy + sin_a * kScanVChannelRadialAdaptiveRefDistancePx);
    if (ref < 8.0) {
        return std::nullopt;
    }

    const double drop_ratio = ref >= kScanVChannelRadialAdaptiveSaturationRef ? kScanVChannelRadialAdaptiveSoftDropRatio : kScanVChannelRadialAdaptiveDropRatio;
    for (int r = kScanVChannelRadialAdaptiveScanStartPx; r < max_r; ++r) {
        const double value = sampleVBilinear(v_smooth,
                                             cx + cos_a * static_cast<double>(r),
                                             cy + sin_a * static_cast<double>(r));
        if (value < ref * drop_ratio) {
            const double edge_x = cx + cos_a * static_cast<double>(r);
            const double edge_y = cy + sin_a * static_cast<double>(r);
            if (plasmaGuideAllows(plasma_guide, edge_x, edge_y)) {
                return static_cast<double>(r);
            }
            break;
        }
    }

    const int gradient_start = std::max(
        kScanVChannelRadialAdaptiveScanStartPx,
        static_cast<int>(std::lround(static_cast<double>(max_r) * kScanVChannelRadialAdaptiveOuterGradientStartRatio)));
    double best_r = 0.0;
    double best_score = 0.0;
    for (int r = gradient_start; r < max_r - kScanVChannelRadialAdaptiveGradientWindowPx; ++r) {
        const double inner = sampleVBilinear(v_smooth,
                                             cx + cos_a * static_cast<double>(r - kScanVChannelRadialAdaptiveGradientWindowPx),
                                             cy + sin_a * static_cast<double>(r - kScanVChannelRadialAdaptiveGradientWindowPx));
        const double outer = sampleVBilinear(v_smooth,
                                             cx + cos_a * static_cast<double>(r + kScanVChannelRadialAdaptiveGradientWindowPx),
                                             cy + sin_a * static_cast<double>(r + kScanVChannelRadialAdaptiveGradientWindowPx));
        const double linear_gradient = inner - outer;
        const double log_gradient =
            std::log(inner + 1.0) - std::log(outer + 1.0);
        const double score =
            std::max(linear_gradient, log_gradient * kScanVChannelRadialAdaptiveLogGradientScale);
        if (score > best_score) {
            best_score = score;
            best_r = static_cast<double>(r);
        }
    }
    const double log_threshold = kScanVChannelRadialAdaptiveMinLogGradient * kScanVChannelRadialAdaptiveLogGradientScale;
    if (best_score < std::max(kScanVChannelRadialAdaptiveMinGradient, log_threshold)) {
        return std::nullopt;
    }
    const double edge_x = cx + cos_a * best_r;
    const double edge_y = cy + sin_a * best_r;
    if (!plasmaGuideAllows(plasma_guide, edge_x, edge_y)) {
        return std::nullopt;
    }
    return best_r;
}

double medianOf(std::vector<double> values) {
    if (values.empty()) {
        return 0.0;
    }
    const auto median_it = values.begin() + static_cast<int>(values.size()) / 2;
    std::nth_element(values.begin(), median_it, values.end());
    return *median_it;
}

bool radiusPassesTightBand(double radius, double median_radius) {
    return radius >= median_radius * kScanVChannelRadialAdaptiveTightRadiusMedianRatio &&
           radius <= median_radius * kScanVChannelRadialAdaptiveMaxRadiusMedianRatio;
}

bool fitScanVChannelRadialAdaptiveCircleFromCenter(const std::vector<cv::Point2d>& edge_points,
                                 double center_x,
                                 double center_y,
                                 double& radius,
                                 std::vector<cv::Point2d>& used_edge_points) {
    if (edge_points.size() < 3) {
        return false;
    }

    struct TaggedRadius {
        double radius = 0.0;
        bool top = false;
        bool left = false;
        cv::Point2d point;
    };
    std::vector<TaggedRadius> tagged;
    tagged.reserve(edge_points.size());
    for (const cv::Point2d& point : edge_points) {
        TaggedRadius entry;
        entry.point = point;
        entry.radius = std::hypot(point.x - center_x, point.y - center_y);
        entry.top = point.y < center_y;
        entry.left = point.x < center_x;
        tagged.push_back(entry);
    }

    std::vector<double> all_radii;
    std::vector<double> top_radii;
    std::vector<double> bottom_radii;
    std::vector<double> left_radii;
    std::vector<double> right_radii;
    all_radii.reserve(tagged.size());
    for (const TaggedRadius& entry : tagged) {
        all_radii.push_back(entry.radius);
        if (entry.top) {
            top_radii.push_back(entry.radius);
        } else {
            bottom_radii.push_back(entry.radius);
        }
        if (entry.left) {
            left_radii.push_back(entry.radius);
        } else {
            right_radii.push_back(entry.radius);
        }
    }

    const double median_all = medianOf(all_radii);
    const double median_top = top_radii.empty() ? median_all : medianOf(top_radii);
    const double median_bottom = bottom_radii.empty() ? median_all : medianOf(bottom_radii);
    const double median_left = left_radii.empty() ? median_all : medianOf(left_radii);
    const double median_right = right_radii.empty() ? median_all : medianOf(right_radii);

    const bool vertical_asymmetric = std::abs(median_top - median_bottom) > kScanVChannelRadialAdaptiveArcAsymmetryPx;
    const bool horizontal_asymmetric = std::abs(median_left - median_right) > kScanVChannelRadialAdaptiveArcAsymmetryPx;
    const bool asymmetric = vertical_asymmetric || horizontal_asymmetric;

    std::vector<double> pool;
    pool.reserve(tagged.size());
    if (!asymmetric) {
        for (const TaggedRadius& entry : tagged) {
            if (entry.radius >= median_all * kScanVChannelRadialAdaptiveMinRadiusMedianRatio) {
                pool.push_back(entry.radius);
            }
        }
    } else {
        const bool use_top = vertical_asymmetric && median_top >= median_bottom;
        const bool use_bottom = vertical_asymmetric && median_bottom > median_top;
        const bool use_left = horizontal_asymmetric && median_left >= median_right;
        const bool use_right = horizontal_asymmetric && median_right > median_left;
        for (const TaggedRadius& entry : tagged) {
            bool keep = false;
            if (use_top && entry.top) {
                keep = true;
            }
            if (use_bottom && !entry.top) {
                keep = true;
            }
            if (use_left && entry.left) {
                keep = true;
            }
            if (use_right && !entry.left) {
                keep = true;
            }
            if (!vertical_asymmetric && horizontal_asymmetric) {
                keep = (use_left && entry.left) || (use_right && !entry.left);
            }
            if (vertical_asymmetric && !horizontal_asymmetric) {
                keep = (use_top && entry.top) || (use_bottom && !entry.top);
            }
            if (keep && entry.radius >= median_all * kScanVChannelRadialAdaptiveMinRadiusMedianRatio) {
                pool.push_back(entry.radius);
            }
        }
        if (static_cast<int>(pool.size()) < kScanVChannelRadialAdaptiveMinValidRays) {
            for (const TaggedRadius& entry : tagged) {
                if (entry.radius >= median_all * kScanVChannelRadialAdaptiveMinRadiusMedianRatio) {
                    pool.push_back(entry.radius);
                }
            }
        }
    }

    const double pool_median = medianOf(pool);
    std::vector<double> pool_deviations;
    pool_deviations.reserve(pool.size());
    for (double value : pool) {
        pool_deviations.push_back(std::abs(value - pool_median));
    }
    const double pool_mad = medianOf(pool_deviations) + 1e-6;

    double sum_radius = 0.0;
    int count = 0;
    used_edge_points.clear();
    used_edge_points.reserve(tagged.size());
    for (const TaggedRadius& entry : tagged) {
        bool in_pool = false;
        for (double value : pool) {
            if (std::abs(value - entry.radius) < 0.5) {
                in_pool = true;
                break;
            }
        }
        if (!in_pool) {
            continue;
        }
        if (std::abs(entry.radius - pool_median) > 2.5 * pool_mad) {
            continue;
        }
        if (!radiusPassesTightBand(entry.radius, pool_median)) {
            continue;
        }
        sum_radius += entry.radius;
        ++count;
        used_edge_points.push_back(entry.point);
    }
    if (count < kScanVChannelRadialAdaptiveMinValidRays) {
        used_edge_points.clear();
        return false;
    }
    radius = sum_radius / static_cast<double>(count);
    return radius > 1.0;
}

bool fitCircleLeastSquares(const std::vector<cv::Point2d>& points, double& cx, double& cy, double& radius) {
    if (points.size() < 3) {
        return false;
    }
    const int n = static_cast<int>(points.size());
    cv::Mat design(n, 3, CV_64F);
    cv::Mat target(n, 1, CV_64F);
    for (int i = 0; i < n; ++i) {
        const double x = points[static_cast<size_t>(i)].x;
        const double y = points[static_cast<size_t>(i)].y;
        design.at<double>(i, 0) = x;
        design.at<double>(i, 1) = y;
        design.at<double>(i, 2) = 1.0;
        target.at<double>(i, 0) = x * x + y * y;
    }
    cv::Mat solution;
    if (!cv::solve(design, target, solution, cv::DECOMP_SVD)) {
        return false;
    }
    cx = solution.at<double>(0, 0) * 0.5;
    cy = solution.at<double>(1, 0) * 0.5;
    const double c = solution.at<double>(2, 0);
    const double radius_sq = c + cx * cx + cy * cy;
    if (radius_sq <= 1.0) {
        return false;
    }
    radius = std::sqrt(radius_sq);
    return std::isfinite(cx) && std::isfinite(cy) && std::isfinite(radius);
}

std::vector<cv::Point2d> filterScanVChannelRadialAdaptiveOutliers(const std::vector<cv::Point2d>& edge_points,
                                              double center_x,
                                              double center_y) {
    if (edge_points.empty()) {
        return {};
    }
    std::vector<double> radii;
    radii.reserve(edge_points.size());
    for (const cv::Point2d& point : edge_points) {
        radii.push_back(std::hypot(point.x - center_x, point.y - center_y));
    }
    std::vector<double> sorted = radii;
    const auto median_it = sorted.begin() + static_cast<int>(sorted.size()) / 2;
    std::nth_element(sorted.begin(), median_it, sorted.end());
    const double median = *median_it;
    std::vector<double> deviations;
    deviations.reserve(radii.size());
    for (double radius : radii) {
        deviations.push_back(std::abs(radius - median));
    }
    const auto mad_it = deviations.begin() + static_cast<int>(deviations.size()) / 2;
    std::nth_element(deviations.begin(), mad_it, deviations.end());
    const double mad = *mad_it + 1e-6;

    const double min_radius = median * kScanVChannelRadialAdaptiveMinRadiusMedianRatio;
    std::vector<cv::Point2d> filtered;
    filtered.reserve(edge_points.size());
    for (size_t i = 0; i < edge_points.size(); ++i) {
        if (radii[i] < min_radius) {
            continue;
        }
        if (std::abs(radii[i] - median) <= 2.5 * mad) {
            filtered.push_back(edge_points[i]);
        }
    }
    return filtered;
}

ScanVChannelRadialAdaptiveEstimate estimateScanVChannelRadialAdaptiveCircle(const cv::Mat& v_smooth,
                                                const Box& box,
                                                const cv::Mat& plasma_guide) {
    ScanVChannelRadialAdaptiveEstimate result;
    const Point2d weighted_center = brightWeightedCentroid(v_smooth, box, kBrightWeightThreshold);
    result.weighted_cx = weighted_center.x;
    result.weighted_cy = weighted_center.y;

    std::vector<cv::Point2d> edge_points;
    edge_points.reserve(static_cast<size_t>(kScanVChannelRadialAdaptiveDirections));
    for (int direction = 0; direction < kScanVChannelRadialAdaptiveDirections; ++direction) {
        const std::optional<double> edge_distance = findScanVChannelRadialEdgeDistance(
            v_smooth, plasma_guide, box, weighted_center.x, weighted_center.y, static_cast<double>(direction));
        if (!edge_distance) {
            continue;
        }
        const double angle_rad = static_cast<double>(direction) * CV_PI / 180.0;
        edge_points.emplace_back(weighted_center.x + std::cos(angle_rad) * *edge_distance,
                               weighted_center.y + std::sin(angle_rad) * *edge_distance);
    }
    result.valid_rays = static_cast<int>(edge_points.size());
    if (result.valid_rays < kScanVChannelRadialAdaptiveMinValidRays) {
        return result;
    }

    const std::vector<cv::Point2d> filtered =
        filterScanVChannelRadialAdaptiveOutliers(edge_points, weighted_center.x, weighted_center.y);
    if (static_cast<int>(filtered.size()) < kScanVChannelRadialAdaptiveMinValidRays) {
        return result;
    }

    std::vector<cv::Point2d> used_edge_points;
    double fit_radius = 0.0;
    if (!fitScanVChannelRadialAdaptiveCircleFromCenter(
            filtered, weighted_center.x, weighted_center.y, fit_radius, used_edge_points)) {
        return result;
    }

    result.found = true;
    result.cx = weighted_center.x;
    result.cy = weighted_center.y;
    result.radius = fit_radius;
    result.edge_points = used_edge_points.empty() ? filtered : used_edge_points;
    return result;
}

std::string scanVChannelRadialAdaptiveCircleToJson(const ScanVChannelRadialAdaptiveEstimate& raw,
                               double smooth_cx,
                               double smooth_cy,
                               double smooth_radius) {
    std::ostringstream out;
    out << std::fixed << std::setprecision(2);
    if (!raw.found) {
        out << "{\"found\":false"
            << ",\"valid_rays\":" << raw.valid_rays
            << ",\"weighted_cx\":" << raw.weighted_cx
            << ",\"weighted_cy\":" << raw.weighted_cy
            << '}';
        return out.str();
    }
    out << "{\"found\":true"
        << ",\"method\":\"" << kScanVChannelRadialAdaptiveMethod << '"'
        << ",\"valid_rays\":" << raw.valid_rays
        << ",\"weighted_cx\":" << raw.weighted_cx
        << ",\"weighted_cy\":" << raw.weighted_cy
        << ",\"raw_cx\":" << raw.cx
        << ",\"raw_cy\":" << raw.cy
        << ",\"raw_radius\":" << raw.radius
        << ",\"cx\":" << smooth_cx
        << ",\"cy\":" << smooth_cy
        << ",\"radius\":" << smooth_radius
        << '}';
    return out.str();
}
}  // namespace

void resetScanVChannelRadialAdaptiveTemporalSmoothing() {
    // No-op: App JNI path is stateless (one frame in, one JSON out).
}

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

EdgeDrawingDetection detectScanVChannelRadialAdaptiveInBox(const cv::Mat& bgr,
                                                           const Box& center_box,
                                                           const std::optional<Point2d>& reference_zero_xy,
                                                           const std::string& dump_stages_dir) {
    EdgeDrawingDetection out;
    out.method = kScanVChannelRadialAdaptiveMethod;
    if (bgr.empty()) {
        out.reason = "empty frame";
        return out;
    }

    const int frame_w = bgr.cols;
    const int frame_h = bgr.rows;
    const Box valid_box = clampBoxToFrame(center_box, frame_w, frame_h);

    saveStage(dump_stages_dir, "01_input_bgr.jpg", bgr);

    cv::Mat work = bgr.clone();

    const cv::Rect roi_rect(valid_box.x, valid_box.y, valid_box.w, valid_box.h);
    cv::Mat roi_outline = work.clone();
    cv::rectangle(roi_outline, roi_rect, cv::Scalar(0, 255, 255), 2);
    saveStage(dump_stages_dir, "02_roi_outline.jpg", roi_outline);
    saveStage(dump_stages_dir, "02_roi_bgr.jpg", work(roi_rect).clone());

    // V 通道 → 高斯平滑 → 亮区加权质心 → 径向扫描 → 亮度下降点 → 拟合圆 → 多帧平滑.
    cv::Mat hsv;
    cv::cvtColor(work, hsv, cv::COLOR_BGR2HSV);
    const cv::Mat v_channel = extractHsvVChannel(hsv);
    saveStage(dump_stages_dir, "02_hsv_v.jpg", v_channel);

    const cv::Mat v_smooth = smoothVChannel(v_channel);
    saveStage(dump_stages_dir, "03_v_gaussian.jpg", v_smooth);
    saveStage(dump_stages_dir,
              "04_brightness_weight.jpg",
              visualizeBrightnessWeights(v_smooth, valid_box, kBrightWeightThreshold));

    cv::Mat plasma_binary = refinePlasmaBinaryMask(buildHsvBinaryMask(hsv));
    applyRoiMask(plasma_binary, valid_box);
    saveStage(dump_stages_dir, "03_plasma_binary.png", plasma_binary);
    cv::Mat plasma_guide = dilatePlasmaGuideMask(plasma_binary);
    applyRoiMask(plasma_guide, valid_box);
    saveStage(dump_stages_dir, "03b_plasma_guide.png", plasma_guide);

    const ScanVChannelRadialAdaptiveEstimate raw_estimate =
        estimateScanVChannelRadialAdaptiveCircle(v_smooth, valid_box, plasma_guide);

    const double fit_cx = raw_estimate.cx;
    const double fit_cy = raw_estimate.cy;
    const double fit_radius = raw_estimate.radius;

    saveTextStage(dump_stages_dir,
                  "09_circle_fit.json",
                  scanVChannelRadialAdaptiveCircleToJson(raw_estimate, fit_cx, fit_cy, fit_radius));
    saveScanVChannelRadialAdaptiveDebugOverlay(
        work, raw_estimate, fit_cx, fit_cy, fit_radius, valid_box, dump_stages_dir);

    const int min_radius_px = scaledMinPinkCircleRadiusPx(valid_box.w, valid_box.h);
    if (!raw_estimate.found || fit_radius < static_cast<double>(min_radius_px)) {
        rejectCircleRadius(out);
        return out;
    }

    FittedCircle fitted_circle;
    fitted_circle.found = true;
    fitted_circle.cx = fit_cx;
    fitted_circle.cy = fit_cy;
    fitted_circle.radius = fit_radius;
    fitted_circle.circularity =
        static_cast<double>(raw_estimate.valid_rays) / static_cast<double>(kScanVChannelRadialAdaptiveDirections);
    saveFitOverlay(work, fitted_circle, dump_stages_dir);

    CircleFit circle_fit;
    circle_fit.base_x = fit_cx;
    circle_fit.base_y = fit_cy;
    circle_fit.radius = fit_radius;
    out.circle_fit = circle_fit;

    Point2d target{
        valid_box.x + valid_box.w * 0.5,
        valid_box.y + valid_box.h * 0.5,
    };
    if (reference_zero_xy) {
        target = *reference_zero_xy;
    }
    std::vector<AnchorCandidate> candidates;
    collectPinkCircleCandidate(fitted_circle, target, candidates);

    const std::optional<AnchorCandidate> best = pickBestCandidate(candidates);
    dumpCandidateOverlay(bgr, valid_box, reference_zero_xy, candidates, best, dump_stages_dir);

    if (!best) {
        out.reason = opencv_detect::kReasonEdgeNotFound;
        return out;
    }

    out.found = true;
    out.peak_x = static_cast<int>(std::lround(best->center.x));
    out.peak_y = static_cast<int>(std::lround(best->center.y));
    out.center = best->center;
    out.anchor_w = best->w;
    out.anchor_h = best->h;
    out.lr = calcLrDistanceToBox(valid_box, out.center);
    return out;
}

}  // namespace edgedrawing
