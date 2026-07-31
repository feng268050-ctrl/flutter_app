#include "edgedrawing_detector.h"
#include "edgedrawing_json.h"

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
    std::cerr << "Usage:\n"
              << "  " << argv0
              << " --image <path> [--roi-json <path>] [--no-roi] [--tolerance-px 10] [--out-dir <dir>]\n"
              << "  " << argv0
              << " --image-dir <dir> --out-dir <dir> [--roi-json <path>] [--no-roi] [--tolerance-px 10]\n";
}

edgedrawing::RoiConfig resolveRoi(const cv::Mat& bgr,
                                  const std::string& roi_json,
                                  bool no_roi) {
    if (no_roi) {
        return edgedrawing::makeFullFrameRoiConfig(bgr.cols, bgr.rows);
    }
    if (!roi_json.empty()) {
        return edgedrawing::loadRoiConfig(roi_json, bgr.cols, bgr.rows);
    }
    return edgedrawing::makeFullFrameRoiConfig(bgr.cols, bgr.rows);
}

bool hasImageExtension(const fs::path& path) {
    std::string ext = path.extension().string();
    std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".bmp";
}

cv::Mat drawOverlay(const cv::Mat& frame,
                    const edgedrawing::RoiConfig& roi,
                    const edgedrawing::FrameResult& result) {
    cv::Mat vis = frame.clone();
    const edgedrawing::Box& box = roi.center_box;
    cv::rectangle(vis,
                  cv::Rect(box.x, box.y, box.w, box.h),
                  cv::Scalar(0, 255, 255),
                  2);

    if (result.circle_fit) {
        const int base_x = static_cast<int>(std::lround(result.circle_fit->base_x));
        const int base_y = static_cast<int>(std::lround(result.circle_fit->base_y));
        cv::drawMarker(vis,
                       cv::Point(base_x, base_y),
                       cv::Scalar(0, 255, 255),
                       cv::MARKER_CROSS,
                       18,
                       2);
        if (result.comparison) {
            const int shifted_x = static_cast<int>(std::lround(
                    result.circle_fit->base_x + result.comparison->offset.dx_px));
            const int shifted_y = static_cast<int>(std::lround(
                    result.circle_fit->base_y + result.comparison->offset.dy_px));
            cv::circle(vis, cv::Point(shifted_x, shifted_y), 7, cv::Scalar(0, 255, 0), -1);
            cv::line(vis, cv::Point(base_x, base_y), cv::Point(shifted_x, shifted_y),
                     cv::Scalar(0, 255, 255), 2);
        }
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
        const int px = result.zero_point->peak_x;
        const int py = result.zero_point->peak_y;
        cv::circle(vis, cv::Point(px, py), 7, cv::Scalar(0, 255, 0), -1);
        if (roi.reference_zero_xy) {
            const int ref_x = static_cast<int>(std::lround(roi.reference_zero_xy->x));
            const int ref_y = static_cast<int>(std::lround(roi.reference_zero_xy->y));
            cv::drawMarker(vis,
                           cv::Point(ref_x, ref_y),
                           cv::Scalar(255, 0, 255),
                           cv::MARKER_CROSS,
                           14,
                           2);
        }
    }
    return vis;
}

int processImageDir(const std::string& image_dir,
                    const std::string& roi_json,
                    const std::string& out_dir,
                    double tolerance_px,
                    bool no_roi) {
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
        std::cerr << "edgedrawing_infer: no images in " << image_dir << std::endl;
        return 1;
    }
    std::sort(images.begin(), images.end());

    fs::create_directories(out_dir);
    const std::string overlay_dir = (fs::path(out_dir) / "overlays").string();
    const std::string json_dir = (fs::path(out_dir) / "json").string();
    const std::string stages_root = (fs::path(out_dir) / "stages").string();
    fs::create_directories(overlay_dir);
    fs::create_directories(json_dir);
    fs::create_directories(stages_root);

    int ok_count = 0;
    for (const fs::path& image_path : images) {
        cv::Mat bgr = cv::imread(image_path.string(), cv::IMREAD_COLOR);
        if (bgr.empty()) {
            std::cerr << "edgedrawing_infer: failed to read " << image_path << std::endl;
            continue;
        }
        const std::string stem = image_path.stem().string();
        const std::string stages_dir = (fs::path(stages_root) / stem).string();
        const edgedrawing::RoiConfig roi = resolveRoi(bgr, roi_json, no_roi);
        const edgedrawing::FrameResult result =
            edgedrawing::detectEdgeDrawingFrame(bgr, roi, tolerance_px, stages_dir);

        const std::string frame_json = edgedrawing::frameResultToJson(result);
        {
            std::ofstream out((fs::path(json_dir) / (stem + ".json")).string());
            out << frame_json;
        }
        cv::imwrite((fs::path(overlay_dir) / (stem + "_overlay.jpg")).string(),
                    drawOverlay(bgr, roi, result));
        if (result.ok) {
            ++ok_count;
        }
        std::cout << image_path.filename().string() << " " << frame_json << std::endl;
    }
    return ok_count > 0 ? 0 : 2;
}

}  // namespace

int main(int argc, char** argv) {
    std::string image;
    std::string image_dir;
    std::string roi_json;
    std::string out_dir;
    double tolerance_px = 10.0;
    bool no_roi = false;

    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--image" && i + 1 < argc) {
            image = argv[++i];
        } else if (arg == "--image-dir" && i + 1 < argc) {
            image_dir = argv[++i];
        } else if (arg == "--roi-json" && i + 1 < argc) {
            roi_json = argv[++i];
        } else if (arg == "--out-dir" && i + 1 < argc) {
            out_dir = argv[++i];
        } else if (arg == "--tolerance-px" && i + 1 < argc) {
            tolerance_px = std::stod(argv[++i]);
        } else if (arg == "--no-roi") {
            no_roi = true;
        } else if (arg == "--help" || arg == "-h") {
            printUsage(argv[0]);
            return 0;
        }
    }

    if (!no_roi && roi_json.empty()) {
        std::cerr << "edgedrawing_infer: using full frame (pass --roi-json for a custom ROI)\n";
    }
    if (image.empty() && image_dir.empty()) {
        printUsage(argv[0]);
        return 1;
    }

    try {
        if (!image_dir.empty()) {
            if (out_dir.empty()) {
                std::cerr << "edgedrawing_infer: --out-dir required with --image-dir\n";
                return 1;
            }
            return processImageDir(image_dir, roi_json, out_dir, tolerance_px, no_roi);
        }

        cv::Mat bgr = cv::imread(image, cv::IMREAD_COLOR);
        if (bgr.empty()) {
            std::cerr << "edgedrawing_infer: failed to read " << image << std::endl;
            return 1;
        }
        const fs::path image_path(image);
        const std::string stem = image_path.stem().string();
        std::string stages_dir;
        if (!out_dir.empty()) {
            fs::create_directories(out_dir);
            stages_dir = (fs::path(out_dir) / "stages" / stem).string();
        }
        const edgedrawing::RoiConfig roi = resolveRoi(bgr, roi_json, no_roi);
        const edgedrawing::FrameResult result =
            edgedrawing::detectEdgeDrawingFrame(bgr, roi, tolerance_px, stages_dir);
        const std::string frame_json = edgedrawing::frameResultToJson(result);
        if (!out_dir.empty()) {
            const std::string json_dir = (fs::path(out_dir) / "json").string();
            const std::string overlay_dir = (fs::path(out_dir) / "overlays").string();
            fs::create_directories(json_dir);
            fs::create_directories(overlay_dir);
            {
                std::ofstream out((fs::path(json_dir) / (stem + ".json")).string());
                out << frame_json;
            }
            cv::imwrite((fs::path(overlay_dir) / (stem + "_overlay.jpg")).string(),
                        drawOverlay(bgr, roi, result));
        }
        std::cout << frame_json << std::endl;
        return result.ok ? 0 : 2;
    } catch (const std::exception& ex) {
        std::cerr << "edgedrawing_infer error: " << ex.what() << std::endl;
        return 1;
    }
}
