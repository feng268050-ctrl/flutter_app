#include "opencv_stain_detect_analyzer.h"
#include "consecutive_ok_filter.h"
#include "red_frame_validator.h"

#include <opencv2/imgcodecs.hpp>

#include <algorithm>
#include <chrono>
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

struct BatchFrameRecord {
    fs::path image_path;
    std::string stem;
    cv::Mat bgr;
    opencv_stain_detect::Result native_result;
    double infer_ms = 0.0;
    std::string per_frame_out;
};

void printUsage(const char* argv0) {
    std::cerr << "Usage:\n"
              << "  " << argv0 << " <image-path> <output-dir> [--dump-stages <dir>]\n"
              << "      [--erode-kernel N] [--erode-max-iterations N]\n"
              << "  " << argv0 << " --image-dir <dir> --out-dir <dir> [--dump-stages]\n"
              << "      [--erode-kernel N] [--erode-max-iterations N]\n"
              << "      [--min-consecutive-ok-frames N] [--no-red-gate]\n";
}

bool hasImageExtension(const fs::path& path) {
    std::string ext = path.extension().string();
    std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".bmp";
}

opencv_stain_detect::Options makeOptions(bool dump_stages,
                                         const std::string& dump_root,
                                         const std::string& stem,
                                         int erode_kernel,
                                         int erode_max_iterations) {
    opencv_stain_detect::Options options;
    options.erode_kernel = erode_kernel;
    options.erode_max_iterations = erode_max_iterations;
    if (dump_stages) {
        if (!stem.empty()) {
            options.dump_stages_dir = (fs::path(dump_root) / stem).string();
        } else {
            options.dump_stages_dir = dump_root;
        }
    }
    return options;
}

opencv_stain_detect::Result effectiveResultForBatch(const opencv_stain_detect::Result& native_result,
                                                    bool effective_ok) {
    if (!native_result.ok || effective_ok) {
        return native_result;
    }
    return opencv_stain_detect::errorResult(-3, "insufficient_consecutive_ok_frames");
}

int processSingleImage(const std::string& image_path,
                       const std::string& output_dir,
                       bool dump_stages,
                       const std::string& dump_root,
                       int erode_kernel,
                       int erode_max_iterations) {
    const cv::Mat bgr = cv::imread(image_path, cv::IMREAD_COLOR);
    if (bgr.empty()) {
        std::cerr << "Failed to read image: " << image_path << '\n';
        return 1;
    }

    const fs::path stem = fs::path(image_path).stem();
    opencv_stain_detect::Options options =
        makeOptions(dump_stages, dump_root, stem.string(), erode_kernel, erode_max_iterations);
    const auto t0 = std::chrono::steady_clock::now();
    const opencv_stain_detect::Result result = opencv_stain_detect::analyzeOpencvStainDetectBgr(bgr, options, output_dir);
    const double infer_ms = std::chrono::duration<double, std::milli>(
                                    std::chrono::steady_clock::now() - t0)
                                    .count();
    std::cerr << "opencv_stain_detect_infer: " << image_path << " infer_ms=" << std::fixed
              << std::setprecision(2) << infer_ms << " ok=" << (result.ok ? 1 : 0) << '\n';
    std::cout << opencv_stain_detect::summaryToJson(result) << '\n';
    return result.ok ? 0 : 1;
}

void writeBatchArtifacts(const BatchFrameRecord& record,
                         bool dump_stages,
                         const std::string& stages_dir,
                         const std::string& overlay_dir,
                         const std::string& json_dir,
                         const opencv_stain_detect::Result& effective_result) {
    const std::string frame_json = opencv_stain_detect::summaryToJson(effective_result);
    {
        std::ofstream out((fs::path(json_dir) / (record.stem + ".json")).string());
        out << frame_json;
    }

    cv::Mat vis = record.bgr.clone();
    std::vector<opencv_stain_detect::DetectedTarget> targets;
    if (effective_result.ok) {
        std::ifstream target_in(record.per_frame_out + "/target.json");
        if (target_in) {
            std::ostringstream payload;
            payload << target_in.rdbuf();
            const std::string json = payload.str();
            opencv_stain_detect::DetectedTarget target;
            target.name = "target";
            const auto x_pos = json.find("\"x\":");
            const auto y_pos = json.find("\"y\":");
            if (x_pos != std::string::npos && y_pos != std::string::npos) {
                target.x = std::stod(json.substr(x_pos + 4));
                target.y = std::stod(json.substr(y_pos + 4));
                targets.push_back(target);
            }
        }
    }
    opencv_stain_detect::Options overlay_options;
    if (dump_stages) {
        overlay_options.dump_stages_dir = (fs::path(stages_dir) / record.stem).string();
    }
    opencv_stain_detect::drawDebugOverlay(vis, record.bgr, overlay_options, targets);
    cv::imwrite((fs::path(overlay_dir) / (record.stem + "_overlay.jpg")).string(), vis);
}

int processImageDir(const std::string& image_dir,
                    const std::string& out_dir,
                    bool dump_stages,
                    int erode_kernel,
                    int erode_max_iterations,
                    int min_consecutive_ok_frames) {
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
        std::cerr << "opencv_stain_detect_infer: no images in " << image_dir << std::endl;
        return 1;
    }
    std::sort(images.begin(), images.end());

    fs::create_directories(out_dir);
    const std::string overlay_dir = (fs::path(out_dir) / "overlays").string();
    const std::string json_dir = (fs::path(out_dir) / "json").string();
    const std::string stages_dir = (fs::path(out_dir) / "stages").string();
    fs::create_directories(overlay_dir);
    fs::create_directories(json_dir);
    if (dump_stages) {
        fs::create_directories(stages_dir);
    }

    std::vector<BatchFrameRecord> records;
    records.reserve(images.size());
    opencv_stain_detect::GlobalErodeIslandSlotSession island_session;
    const auto batch_t0 = std::chrono::steady_clock::now();
    for (const fs::path& image_path : images) {
        const cv::Mat bgr = cv::imread(image_path.string(), cv::IMREAD_COLOR);
        if (bgr.empty()) {
            std::cerr << "opencv_stain_detect_infer: failed to read " << image_path << std::endl;
            continue;
        }

        const std::string stem = image_path.stem().string();
        const std::string per_frame_out = (fs::path(json_dir) / stem).string();
        opencv_stain_detect::Options options =
            makeOptions(dump_stages, stages_dir, stem, erode_kernel, erode_max_iterations);
        const auto frame_t0 = std::chrono::steady_clock::now();
        const opencv_stain_detect::Result result = opencv_stain_detect::analyzeOpencvStainDetectBgr(
            bgr, options, per_frame_out, &island_session, stem);
        const double infer_ms = std::chrono::duration<double, std::milli>(
                                        std::chrono::steady_clock::now() - frame_t0)
                                        .count();
        if (island_session.hasSlots() && island_session.learnedFrom() == stem) {
            std::cerr << "opencv_stain_detect_infer: island slots learned from " << stem
                      << " count=" << island_session.slots().size()
                      << " (reused for remaining frames)\n";
        }
        std::cerr << "opencv_stain_detect_infer: " << image_path.filename().string() << " infer_ms="
                  << std::fixed << std::setprecision(2) << infer_ms << " native_ok="
                  << (result.ok ? 1 : 0) << '\n';

        BatchFrameRecord record;
        record.image_path = image_path;
        record.stem = stem;
        record.bgr = bgr;
        record.native_result = result;
        record.infer_ms = infer_ms;
        record.per_frame_out = per_frame_out;
        records.push_back(std::move(record));
    }

    std::vector<bool> native_ok;
    native_ok.reserve(records.size());
    for (const BatchFrameRecord& record : records) {
        native_ok.push_back(record.native_result.ok);
    }
    const std::vector<bool> effective_mask =
        opencv_stain_detect::consecutiveOkEffectiveMask(native_ok, min_consecutive_ok_frames);

    std::ostringstream summary;
    summary << std::fixed << std::setprecision(2);
    summary << "{\"image_dir\":\"" << image_dir << "\",\"min_consecutive_ok_frames\":"
            << min_consecutive_ok_frames << ",\"frames\":[";

    bool first = true;
    int ok_count = 0;
    double total_infer_ms = 0.0;
    for (std::size_t i = 0; i < records.size(); ++i) {
        const BatchFrameRecord& record = records[i];
        total_infer_ms += record.infer_ms;
        const opencv_stain_detect::Result effective_result =
            effectiveResultForBatch(record.native_result, effective_mask[i]);
        writeBatchArtifacts(record, dump_stages, stages_dir, overlay_dir, json_dir, effective_result);
        if (effective_result.ok) {
            ++ok_count;
        }
        if (!first) {
            summary << ',';
        }
        first = false;
        summary << "{\"file\":\"" << record.image_path.filename().string() << "\",\"infer_ms\":"
                << record.infer_ms << ",\"native_ok\":" << (record.native_result.ok ? "true" : "false")
                << ",\"result\":" << opencv_stain_detect::summaryToJson(effective_result) << '}';
        if (record.native_result.ok != effective_result.ok) {
            std::cerr << "opencv_stain_detect_infer: " << record.image_path.filename().string()
                      << " effective_ok=" << (effective_result.ok ? 1 : 0)
                      << " reason=insufficient_consecutive_ok_frames\n";
        }
    }

    const double batch_wall_ms = std::chrono::duration<double, std::milli>(
                                         std::chrono::steady_clock::now() - batch_t0)
                                         .count();
    summary << "],\"ok_frames\":" << ok_count << ",\"total_frames\":" << records.size()
            << ",\"total_infer_ms\":" << total_infer_ms << ",\"batch_wall_ms\":" << batch_wall_ms
            << '}';
    {
        std::ofstream out((fs::path(out_dir) / "batch_summary.json").string());
        out << summary.str();
    }
    std::cerr << "opencv_stain_detect_infer: batch total_infer_ms=" << std::fixed << std::setprecision(2)
              << total_infer_ms << " batch_wall_ms=" << batch_wall_ms << " frames="
              << records.size() << " ok=" << ok_count << " min_consecutive_ok_frames="
              << min_consecutive_ok_frames << '\n';
    std::cout << summary.str() << std::endl;
    return ok_count > 0 ? 0 : 2;
}

}  // namespace

int main(int argc, char** argv) {
    bool dump_stages = false;
    std::string dump_root;
    int erode_kernel = 3;
    int erode_max_iterations = 4;
    int min_consecutive_ok_frames = 1;
    bool no_red_gate = false;
    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--no-red-gate") {
            no_red_gate = true;
        } else if (arg == "--dump-stages") {
            dump_stages = true;
            if (i + 1 < argc && argv[i + 1][0] != '-') {
                dump_root = argv[++i];
            }
        } else if (arg == "--erode-kernel" && i + 1 < argc) {
            erode_kernel = std::stoi(argv[++i]);
        } else if (arg == "--erode-max-iterations" && i + 1 < argc) {
            erode_max_iterations = std::stoi(argv[++i]);
        } else if (arg == "--min-consecutive-ok-frames" && i + 1 < argc) {
            min_consecutive_ok_frames = std::stoi(argv[++i]);
        }
    }

    if (argc >= 3 && argv[1][0] != '-') {
        const std::string image_path = argv[1];
        const std::string output_dir = argv[2];
        if (no_red_gate) {
            opencv_detect::setRedFrameGateEnabled(false);
        }
        if (dump_stages && dump_root.empty()) {
            dump_root = (fs::path(output_dir) / "stages").string();
        }
        return processSingleImage(
            image_path, output_dir, dump_stages, dump_root, erode_kernel, erode_max_iterations);
    }

    std::string image_dir;
    std::string out_dir;
    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--image-dir" && i + 1 < argc) {
            image_dir = argv[++i];
        } else if (arg == "--out-dir" && i + 1 < argc) {
            out_dir = argv[++i];
        } else if (arg == "--help" || arg == "-h") {
            printUsage(argv[0]);
            return 0;
        }
    }

    if (image_dir.empty() || out_dir.empty()) {
        printUsage(argv[0]);
        return 2;
    }

    if (no_red_gate) {
        opencv_detect::setRedFrameGateEnabled(false);
    }

    try {
        return processImageDir(image_dir,
                               out_dir,
                               dump_stages,
                               erode_kernel,
                               erode_max_iterations,
                               min_consecutive_ok_frames);
    } catch (const std::exception& ex) {
        std::cerr << "opencv_stain_detect_infer error: " << ex.what() << std::endl;
        return 1;
    }
}
