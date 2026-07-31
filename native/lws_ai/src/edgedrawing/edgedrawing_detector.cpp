#include "edgedrawing_detector.h"

#include "scan_v_channel_radial_adaptive.h"
#include "edgedrawing_util.h"
#include "opencv_detect_codes.h"
#include "red_frame_validator.h"
#include "roi_config.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include <algorithm>
#include <cmath>
#include <fstream>

#include "../fscompat.h"

namespace edgedrawing {
namespace {

void exposureMetrics(const cv::Mat& bgr, const Box& center_box, double& sat_ratio, double& mean_v) {
    sat_ratio = 0.0;
    mean_v = 0.0;
    if (bgr.empty()) {
        return;
    }
    const int frame_w = bgr.cols;
    const int frame_h = bgr.rows;
    int x = std::max(0, std::min(center_box.x, frame_w - 1));
    int y = std::max(0, std::min(center_box.y, frame_h - 1));
    int bw = std::max(1, std::min(center_box.w, frame_w - x));
    int bh = std::max(1, std::min(center_box.h, frame_h - y));
    const cv::Mat roi = bgr(cv::Rect(x, y, bw, bh));
    if (roi.empty()) {
        return;
    }
    cv::Mat hsv;
    cv::cvtColor(roi, hsv, cv::COLOR_BGR2HSV);
    std::vector<cv::Mat> channels;
    cv::split(hsv, channels);
    cv::Mat v = channels[2];
    cv::Mat saturated;
    cv::compare(v, 245, saturated, cv::CMP_GT);
    sat_ratio = static_cast<double>(cv::countNonZero(saturated)) /
                static_cast<double>(std::max(1, v.rows * v.cols));
    mean_v = cv::mean(v)[0];
}

RoiConfig fromZeroPointRoi(const zero_point::RoiConfig& zp) {
    RoiConfig out;
    out.center_box = Box{zp.center_box.x, zp.center_box.y, zp.center_box.w, zp.center_box.h};
    out.fixed_center_xy = Point2d{zp.fixed_center_xy.x, zp.fixed_center_xy.y};
    if (zp.reference_zero_xy) {
        out.reference_zero_xy =
            Point2d{zp.reference_zero_xy->x, zp.reference_zero_xy->y};
    }
    out.source_width = zp.source_width;
    out.source_height = zp.source_height;
    return out;
}

}  // namespace

RoiConfig loadRoiConfig(const std::string& roi_json_path, int frame_width, int frame_height) {
    if (roi_json_path.empty()) {
        return makeFullFrameRoiConfig(frame_width, frame_height);
    }
    return fromZeroPointRoi(zero_point::loadRoiConfig(roi_json_path, frame_width, frame_height));
}

RoiConfig makeFullFrameRoiConfig(int frame_width, int frame_height) {
    RoiConfig roi;
    roi.source_width = frame_width;
    roi.source_height = frame_height;
    roi.center_box = Box{0, 0, frame_width, frame_height};
    roi.fixed_center_xy =
        Point2d{frame_width * 0.5, frame_height * 0.5};
    roi.reference_zero_xy = roi.fixed_center_xy;
    return roi;
}

RoiConfig makeCenteredSquareRoiConfig(int frame_width, int frame_height, int side_px) {
    const int side = std::max(1, std::min(side_px, std::min(frame_width, frame_height)));
    const int x = std::max(0, (frame_width - side) / 2);
    const int y = std::max(0, (frame_height - side) / 2);
    RoiConfig roi;
    roi.source_width = frame_width;
    roi.source_height = frame_height;
    roi.center_box = Box{x, y, side, side};
    roi.fixed_center_xy =
        Point2d{x + side * 0.5, y + side * 0.5};
    roi.reference_zero_xy = roi.fixed_center_xy;
    return roi;
}

namespace {

// Matches app/src/main/assets/edgedrawing_detect_roi.json (640×640 upper-center on 1920×1080).
constexpr int kPlasmaRoiSourceW = 1920;
constexpr int kPlasmaRoiSourceH = 1080;
constexpr int kPlasmaRoiX = 600;
constexpr int kPlasmaRoiY = 0;
constexpr int kPlasmaRoiW = 640;
constexpr int kPlasmaRoiH = 640;
constexpr double kPlasmaRefX = 924.47;
constexpr double kPlasmaRefY = 292.00;

Box scalePlasmaBoxToFrame(int frame_width, int frame_height) {
    if (frame_width <= 0 || frame_height <= 0) {
        return Box{0, 0, 0, 0};
    }
    if (frame_width == kPlasmaRoiSourceW && frame_height == kPlasmaRoiSourceH) {
        return Box{kPlasmaRoiX, kPlasmaRoiY, kPlasmaRoiW, kPlasmaRoiH};
    }
    const double sx = static_cast<double>(frame_width) / static_cast<double>(kPlasmaRoiSourceW);
    const double sy = static_cast<double>(frame_height) / static_cast<double>(kPlasmaRoiSourceH);
    return Box{
        static_cast<int>(std::lround(kPlasmaRoiX * sx)),
        static_cast<int>(std::lround(kPlasmaRoiY * sy)),
        static_cast<int>(std::lround(kPlasmaRoiW * sx)),
        static_cast<int>(std::lround(kPlasmaRoiH * sy)),
    };
}

Point2d scalePlasmaReferenceToFrame(int frame_width, int frame_height) {
    if (frame_width <= 0 || frame_height <= 0) {
        return Point2d{0.0, 0.0};
    }
    if (frame_width == kPlasmaRoiSourceW && frame_height == kPlasmaRoiSourceH) {
        return Point2d{kPlasmaRefX, kPlasmaRefY};
    }
    const double sx = static_cast<double>(frame_width) / static_cast<double>(kPlasmaRoiSourceW);
    const double sy = static_cast<double>(frame_height) / static_cast<double>(kPlasmaRoiSourceH);
    return Point2d{kPlasmaRefX * sx, kPlasmaRefY * sy};
}

}  // namespace

RoiConfig makePlasmaRoiConfig(int frame_width, int frame_height) {
    const Box box = scalePlasmaBoxToFrame(frame_width, frame_height);
    const Point2d ref = scalePlasmaReferenceToFrame(frame_width, frame_height);
    RoiConfig roi;
    roi.source_width = kPlasmaRoiSourceW;
    roi.source_height = kPlasmaRoiSourceH;
    roi.center_box = box;
    roi.fixed_center_xy = ref;
    roi.reference_zero_xy = ref;
    return roi;
}

namespace {

void writeRedGateSummary(const std::string& path, const opencv_detect::RedFrameValidation& red_gate) {
    std::ofstream out(path);
    if (!out) {
        return;
    }
    const char* verdict = "unknown";
    switch (red_gate.verdict) {
        case opencv_detect::RedFrameVerdict::ValidRed:
            verdict = "valid_red";
            break;
        case opencv_detect::RedFrameVerdict::Overexposed:
            verdict = "overexposed";
            break;
        case opencv_detect::RedFrameVerdict::InvalidNonRed:
            verdict = "invalid_non_red";
            break;
        case opencv_detect::RedFrameVerdict::NoValidRegion:
            verdict = "no_valid_region";
            break;
        case opencv_detect::RedFrameVerdict::EmptyRoi:
            verdict = "empty_roi";
            break;
    }
    out << "verdict=" << verdict << '\n';
    if (red_gate.reason_token != nullptr) {
        out << "reason=" << red_gate.reason_token << '\n';
    }
    out << "gray_mean=" << red_gate.metrics.gray_mean << '\n';
    out << "overexposed_ratio=" << red_gate.metrics.overexposed_ratio << '\n';
    out << "red_ratio=" << red_gate.metrics.red_ratio << '\n';
    out << "purple_ratio=" << red_gate.metrics.purple_ratio << '\n';
    out << "sat_mean=" << red_gate.metrics.sat_mean << '\n';
    out << "val_mean=" << red_gate.metrics.val_mean << '\n';
}

}  // namespace

FrameResult detectEdgeDrawingFrame(const cv::Mat& bgr,
                                   const RoiConfig& roi,
                                   double tolerance_px,
                                   const std::string& dump_stages_dir) {
    FrameResult output;
    output.code = 0;
    output.ok = true;

    const bool dump_stages = !dump_stages_dir.empty();
    if (dump_stages) {
        fscompat::makedirs(dump_stages_dir);
        cv::imwrite(dump_stages_dir + "/00_input_bgr.jpg", bgr);
    }

    const opencv_detect::RedFrameValidation red_gate = opencv_detect::validateRedFrame(bgr);
    if (dump_stages) {
        writeRedGateSummary(dump_stages_dir + "/00_red_gate.txt", red_gate);
    }
    if (red_gate.verdict != opencv_detect::RedFrameVerdict::ValidRed) {
        output.ok = false;
        output.code = opencv_detect::kFrameRejected;
        output.reason = red_gate.reason_token != nullptr ? red_gate.reason_token
                                                         : opencv_detect::kReasonInvalidNonRed;
        if (!dump_stages) {
            return output;
        }
    }

    exposureMetrics(bgr, roi.center_box, output.sat_ratio, output.mean_v);

    EdgeDrawingDetection detection = detectScanVChannelRadialAdaptiveInBox(
        bgr, roi.center_box, roi.reference_zero_xy, dump_stages_dir);
    if (detection.circle_fit) {
        output.circle_fit = detection.circle_fit;
    }
    if (!detection.found) {
        output.code = detection.reject_code != 0 ? detection.reject_code : opencv_detect::kDetectFailed;
        output.ok = false;
        output.reason = detection.reason.empty() ? opencv_detect::kReasonEdgeNotFound : detection.reason;
        return output;
    }

    output.zero_point = detection;
    if (detection.lr) {
        output.lr = *detection.lr;
    }

    output.comparison = compareZeroToReference(roi.reference_zero_xy, detection.center);
    if (!output.comparison) {
        output.code = opencv_detect::kConfigError;
        output.ok = false;
        output.reason = opencv_detect::kReasonMissingReferenceZero;
        output.zero_point.reset();
        return output;
    }
    if (red_gate.verdict != opencv_detect::RedFrameVerdict::ValidRed) {
        output.ok = false;
        output.code = opencv_detect::kFrameRejected;
        output.reason = red_gate.reason_token != nullptr ? red_gate.reason_token
                                                         : opencv_detect::kReasonInvalidNonRed;
        output.zero_point.reset();
        output.comparison.reset();
        return output;
    }
    output.ok = true;
    output.code = 0;
    (void)tolerance_px;
    return output;
}

}  // namespace edgedrawing
