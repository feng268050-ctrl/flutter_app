#include "roi_config.h"
#include "zero_point_detector.h"
#include "zero_point_json.h"

#include "red_frame_validator.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

namespace {

void printUsage(const char* argv0) {
    std::cerr
        << "Usage:\n"
        << "  " << argv0
        << " --video <path> --roi-json <path> --out-dir <dir> [--tolerance-px 10] [--mode point|line] [--no-red-gate]\n"
        << "  " << argv0
        << " --image-dir <dir> --roi-json <path> --out-dir <dir> [--tolerance-px 10] [--mode point|line] [--no-red-gate]\n"
        << "  " << argv0
        << " --image <path> --roi-json <path> --out-dir <dir> [--tolerance-px 10] [--mode point|line] [--no-red-gate]\n";
}

zero_point::DetectTargetMode parseTargetMode(const std::string& mode) {
    if (mode == "line") {
        return zero_point::DetectTargetMode::Line;
    }
    return zero_point::DetectTargetMode::Point;
}

bool hasImageExtension(const fs::path& path) {
    std::string ext = path.extension().string();
    std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".bmp";
}

void drawReferenceCrosshairs(cv::Mat& vis, int ref_x, int ref_y, const cv::Scalar& color, int thickness = 2) {
    if (vis.empty()) {
        return;
    }
    const int w = vis.cols;
    const int h = vis.rows;
    cv::line(vis, cv::Point(0, ref_y), cv::Point(w - 1, ref_y), color, thickness, cv::LINE_AA);
    cv::line(vis, cv::Point(ref_x, 0), cv::Point(ref_x, h - 1), color, thickness, cv::LINE_AA);
}

void drawReferenceMarker(cv::Mat& vis, int ref_x, int ref_y) {
    constexpr int kAxisThickness = 1;
    constexpr int kRefCircleRadius = 8;
    constexpr int kRefCircleThickness = 2;
    const cv::Scalar axis_color(0, 255, 255);
    drawReferenceCrosshairs(vis, ref_x, ref_y, axis_color, kAxisThickness);
    cv::circle(vis, cv::Point(ref_x, ref_y), kRefCircleRadius, axis_color, kRefCircleThickness, cv::LINE_AA);
}

void drawDetectedMarker(cv::Mat& vis, int px, int py) {
    constexpr int kDetCircleRadius = 9;
    constexpr int kDetCircleThickness = 2;
    cv::circle(vis, cv::Point(px, py), kDetCircleRadius, cv::Scalar(0, 255, 0), kDetCircleThickness, cv::LINE_AA);
}

cv::Mat drawOverlay(const cv::Mat& frame,
                    const zero_point::RoiConfig& roi,
                    const zero_point::FrameResult& result) {
    cv::Mat vis = frame.clone();
    const zero_point::Box& box = roi.center_box;

    cv::rectangle(vis,
                  cv::Rect(box.x, box.y, box.w, box.h),
                  cv::Scalar(0, 255, 255),
                  2);
    if (roi.reference_zero_xy) {
        const int ref_x = static_cast<int>(std::lround(roi.reference_zero_xy->x));
        const int ref_y = static_cast<int>(std::lround(roi.reference_zero_xy->y));
        drawReferenceMarker(vis, ref_x, ref_y);
    }

    std::ostringstream status;
    status << "ok=" << (result.ok ? "true" : "false") << " code=" << result.code;
    if (result.comparison) {
        status << " offset_x=" << result.comparison->offset.dx_px
               << " offset_y=" << result.comparison->offset.dy_px;
    } else if (!result.reason.empty()) {
        status << " " << result.reason;
    }
    cv::putText(vis,
                status.str(),
                cv::Point(30, 40),
                cv::FONT_HERSHEY_SIMPLEX,
                0.9,
                result.ok ? cv::Scalar(0, 255, 0) : cv::Scalar(0, 0, 255),
                2,
                cv::LINE_AA);

    if (result.zero_point && result.zero_point->found) {
        drawDetectedMarker(vis, result.zero_point->peak_x, result.zero_point->peak_y);
    }
    return vis;
}

int processImageDir(const std::string& image_dir,
                    const std::string& roi_json,
                    const std::string& out_dir,
                    double tolerance_px,
                    zero_point::DetectTargetMode target_mode) {
    std::vector<fs::path> images;
    for (const auto& entry : fs::directory_iterator(image_dir)) {
        if (!entry.is_regular_file()) {
            continue;
        }
        if (hasImageExtension(entry.path())) {
            images.push_back(entry.path());
        }
    }
    if (images.empty()) {
        std::cerr << "zero_point_infer: no images in " << image_dir << std::endl;
        return 1;
    }
    std::sort(images.begin(), images.end());

    fs::create_directories(out_dir);
    const std::string overlay_dir = (fs::path(out_dir) / "overlays").string();
    const std::string json_dir = (fs::path(out_dir) / "json").string();
    fs::create_directories(overlay_dir);
    fs::create_directories(json_dir);

    std::ostringstream summary;
    summary << std::fixed << std::setprecision(2);
    summary << "{\"image_dir\":\"" << image_dir << "\",\"roi_json\":\"" << roi_json
            << "\",\"frames\":[";

    bool first = true;
    int ok_count = 0;
    for (const fs::path& image_path : images) {
        cv::Mat bgr = cv::imread(image_path.string(), cv::IMREAD_COLOR);
        if (bgr.empty()) {
            std::cerr << "zero_point_infer: failed to read " << image_path << std::endl;
            continue;
        }
        const zero_point::RoiConfig roi =
            zero_point::loadRoiConfig(roi_json, bgr.cols, bgr.rows);
        const zero_point::FrameResult result =
            zero_point::detectZeroPointFrame(bgr, roi, tolerance_px, "", target_mode);

        const std::string stem = image_path.stem().string();
        const std::string frame_json =
            zero_point::frameResultToJson(result, roi.reference_zero_xy);
        {
            std::ofstream out((fs::path(json_dir) / (stem + ".json")).string());
            out << frame_json;
        }
        cv::imwrite((fs::path(overlay_dir) / (stem + "_overlay.jpg")).string(),
                    drawOverlay(bgr, roi, result));

        if (!first) {
            summary << ',';
        }
        first = false;
        summary << "{\"file\":\"" << image_path.filename().string() << "\",\"result\":"
                << frame_json << '}';
        if (result.ok) {
            ++ok_count;
        }
    }

    summary << "],\"ok_frames\":" << ok_count << ",\"total_frames\":" << images.size() << '}';
    {
        std::ofstream out((fs::path(out_dir) / "batch_summary.json").string());
        out << summary.str();
    }
    std::cout << summary.str() << std::endl;
    return ok_count > 0 ? 0 : 2;
}

int processSingleImage(const std::string& image_path,
                       const std::string& roi_json,
                       const std::string& out_dir,
                       double tolerance_px,
                       zero_point::DetectTargetMode target_mode) {
    cv::Mat bgr = cv::imread(image_path, cv::IMREAD_COLOR);
    if (bgr.empty()) {
        std::cerr << "zero_point_infer: failed to read " << image_path << std::endl;
        return 1;
    }

    fs::create_directories(out_dir);
    const zero_point::RoiConfig roi = zero_point::loadRoiConfig(roi_json, bgr.cols, bgr.rows);
    const std::string stages_dir = (fs::path(out_dir) / "stages").string();
    const zero_point::FrameResult result =
        zero_point::detectZeroPointFrame(bgr, roi, tolerance_px, stages_dir, target_mode);

    const fs::path image_file(image_path);
    const std::string stem = image_file.stem().string();
    const std::string frame_json = zero_point::frameResultToJson(result, roi.reference_zero_xy);
    {
        std::ofstream out((fs::path(out_dir) / (stem + ".json")).string());
        out << frame_json;
    }
    cv::imwrite((fs::path(out_dir) / (stem + "_overlay.jpg")).string(),
                drawOverlay(bgr, roi, result));
    std::cout << frame_json << std::endl;
    return result.ok ? 0 : 2;
}

}  // namespace

int main(int argc, char** argv) {
    std::string video;
    std::string image;
    std::string image_dir;
    std::string roi_json;
    std::string out_dir;
    double tolerance_px = 10.0;
    bool no_red_gate = false;
    std::string mode = "point";

    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--video" && i + 1 < argc) {
            video = argv[++i];
        } else if (arg == "--image" && i + 1 < argc) {
            image = argv[++i];
        } else if (arg == "--image-dir" && i + 1 < argc) {
            image_dir = argv[++i];
        } else if (arg == "--roi-json" && i + 1 < argc) {
            roi_json = argv[++i];
        } else if (arg == "--out-dir" && i + 1 < argc) {
            out_dir = argv[++i];
        } else if (arg == "--tolerance-px" && i + 1 < argc) {
            tolerance_px = std::stod(argv[++i]);
        } else if (arg == "--no-red-gate") {
            no_red_gate = true;
        } else if (arg == "--mode" && i + 1 < argc) {
            mode = argv[++i];
        } else if (arg == "--help" || arg == "-h") {
            printUsage(argv[0]);
            return 0;
        }
    }

    const int mode_count = static_cast<int>(!video.empty()) + static_cast<int>(!image.empty()) +
                           static_cast<int>(!image_dir.empty());
    if (roi_json.empty() || out_dir.empty() || mode_count != 1) {
        printUsage(argv[0]);
        return 1;
    }

    if (no_red_gate) {
        opencv_detect::setRedFrameGateEnabled(false);
    }

    const zero_point::DetectTargetMode target_mode = parseTargetMode(mode);

    try {
        if (!image.empty()) {
            return processSingleImage(image, roi_json, out_dir, tolerance_px, target_mode);
        }
        if (!image_dir.empty()) {
            return processImageDir(image_dir, roi_json, out_dir, tolerance_px, target_mode);
        }
        const zero_point::VideoProcessResult result =
            zero_point::processVideo(video, roi_json, out_dir, tolerance_px);
        std::cout << zero_point::videoResultToJson(result, roi_json) << std::endl;
        return result.ok ? 0 : 2;
    } catch (const std::exception& ex) {
        std::cerr << "zero_point_infer error: " << ex.what() << std::endl;
        return 1;
    }
}
