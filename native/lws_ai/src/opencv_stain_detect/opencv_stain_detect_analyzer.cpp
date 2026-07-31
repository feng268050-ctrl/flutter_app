#include "opencv_stain_detect_analyzer.h"

#include "fixed_roi_pipeline.h"
#include "opencv_detect_codes.h"
#include "red_frame_validator.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include <cerrno>
#include <cmath>
#include <fstream>
#include <optional>
#include <iomanip>
#include <sstream>
#include <sys/stat.h>

namespace opencv_stain_detect {
namespace {

std::string jsonEscape(const std::string& value) {
    std::ostringstream out;
    for (char c : value) {
        switch (c) {
            case '\\':
                out << "\\\\";
                break;
            case '"':
                out << "\\\"";
                break;
            case '\n':
                out << "\\n";
                break;
            case '\r':
                out << "\\r";
                break;
            case '\t':
                out << "\\t";
                break;
            default:
                out << c;
                break;
        }
    }
    return out.str();
}

FixedRoiParams makeFixedRoiParams(const Options& options) {
    FixedRoiParams params;
    params.roi_x = options.roi_x;
    params.roi_y = options.roi_y;
    params.roi_width = options.roi_width;
    params.roi_height = options.roi_height;
    params.enhance_clahe_clip = options.enhance_clahe_clip;
    params.enhance_alpha = options.enhance_alpha;
    params.enhance_beta = options.enhance_beta;
    params.invert_thresh = options.invert_thresh;
    params.strict_invert_thresh = options.strict_invert_thresh;
    params.strict_invert_reject_dark_blob_count = options.strict_invert_reject_dark_blob_count;
    params.strict_invert_dark_max_value = options.strict_invert_dark_max_value;
    params.strict_invert_dark_min_area = options.strict_invert_dark_min_area;
    params.strict_invert_dark_min_width = options.strict_invert_dark_min_width;
    params.strict_invert_dark_min_height = options.strict_invert_dark_min_height;
    params.strict_invert_dark_max_height = options.strict_invert_dark_max_height;
    params.strict_invert_dark_min_aspect = options.strict_invert_dark_min_aspect;
    params.gray_global_denoise_kernel = options.gray_global_denoise_kernel;
    params.min_blob_area = options.min_blob_area;
    params.min_target_area_px = options.min_target_area_px;
    params.global_erode_min_target_area_px = options.global_erode_min_target_area_px;
    params.global_erode_min_target_height_px = options.global_erode_min_target_height_px;
    params.red_above_min_target_height_px = options.red_above_min_target_height_px;
    params.global_erode_reject_two_targets_centroid_dist_px =
        options.global_erode_reject_two_targets_centroid_dist_px;
    params.red_line_bright_gray_threshold = options.red_line_bright_gray_threshold;
    params.red_line_margin_px = options.red_line_margin_px;
    params.red_above_min_fraction = options.red_above_min_fraction;
    params.open_kernel = options.open_kernel;
    params.global_erode_kernel = options.global_erode_kernel;
    params.erode_max_iterations = options.erode_max_iterations;
    params.erode_kernel = options.erode_kernel;
    params.red_bright_s_min = options.red_bright_s_min;
    params.red_bright_v_min = options.red_bright_v_min;
    params.red_bright_red_hue_lo = options.red_bright_red_hue_lo;
    params.red_bright_red_hue_hi = options.red_bright_red_hue_hi;
    params.red_bright_magenta_hue_lo = options.red_bright_magenta_hue_lo;
    params.red_bright_magenta_hue_hi = options.red_bright_magenta_hue_hi;
    params.red_bright_morph_kernel = options.red_bright_morph_kernel;
    params.red_bright_dilate_iterations = options.red_bright_dilate_iterations;
    params.red_bright_target_min_width_px = options.red_bright_target_min_width_px;
    params.red_bright_target_min_height_px = options.red_bright_target_min_height_px;
    params.red_bright_reject_v200_fraction_max = options.red_bright_reject_v200_fraction_max;
    params.red_bright_reject_white_fraction_max = options.red_bright_reject_white_fraction_max;
    params.red_bright_reject_centroid_y_min_full = options.red_bright_reject_centroid_y_min_full;
    params.halo_analysis_margin_px = options.halo_analysis_margin_px;
    params.halo_core_v_min = options.halo_core_v_min;
    params.halo_halo_v_min = options.halo_halo_v_min;
    params.halo_halo_v_max = options.halo_halo_v_max;
    params.halo_reject_fwhm_halo_w_frac_max = options.halo_reject_fwhm_halo_w_frac_max;
    params.halo_reject_halo_score_max = options.halo_reject_halo_score_max;
    params.min_split_regions = options.min_split_regions;
    params.max_split_regions = options.max_split_regions;
    params.min_relative_area_vs_largest = options.min_relative_area_vs_largest;
    params.min_centroid_dist_from_largest_px = options.min_centroid_dist_from_largest_px;
    params.neck_split_max_width_px = options.neck_split_max_width_px;
    params.neck_split_min_width_px = options.neck_split_min_width_px;
    params.neck_cut_line_thickness_px = options.neck_cut_line_thickness_px;
    params.global_erode_island_slot_margin_px = options.global_erode_island_slot_margin_px;
    params.multi_blob_min_target_width_px = options.multi_blob_min_target_width_px;
    params.multi_blob_min_target_height_px = options.multi_blob_min_target_height_px;
    params.multi_blob_max_centroid_dist_from_largest_px =
        options.multi_blob_max_centroid_dist_from_largest_px;
    return params;
}

bool mkdirOne(const std::string& dir) {
    if (dir.empty()) {
        return false;
    }
    if (::mkdir(dir.c_str(), 0755) != 0) {
        return errno == EEXIST;
    }
    return true;
}

bool writeTargetJsonFile(const std::string& path, const DetectedTarget& target) {
    std::ofstream out(path);
    if (!out) {
        return false;
    }
    out << targetToJson(target);
    return static_cast<bool>(out);
}

bool blobMeetsTargetCriteria(const RegionBlob& blob,
                             const Options& options,
                             bool multi_blob) {
    const int min_w = multi_blob ? options.multi_blob_min_target_width_px
                                 : options.min_target_width_px;
    const int min_h = multi_blob ? options.multi_blob_min_target_height_px
                                 : options.min_target_height_px;
    return blob.w >= min_w && blob.h >= min_h;
}

bool relativeSmallFar(const RegionBlob& blob,
                    const RegionBlob& largest,
                    const Options& options) {
    if (blob.area_px >= options.min_relative_area_vs_largest * largest.area_px) {
        return false;
    }
    const double dx = blob.cx - largest.cx;
    const double dy = blob.cy - largest.cy;
    return std::hypot(dx, dy) >= options.min_centroid_dist_from_largest_px;
}

std::optional<DetectedTarget> blobToTarget(const RegionBlob& blob,
                                           const FixedRoiPipelineResult& pipeline) {
    DetectedTarget target;
    target.name = "target";
    target.x = blob.cx + pipeline.roi_x;
    target.y = blob.cy + pipeline.roi_y;
    target.bbox_x = blob.x + pipeline.roi_x;
    target.bbox_y = blob.y + pipeline.roi_y;
    target.w = blob.w;
    target.h = blob.h;
    return target;
}

std::optional<DetectedTarget> pickMultiBlobTarget(const FixedRoiPipelineResult& pipeline,
                                                   const Options& options) {
    const std::vector<RegionBlob>& blobs = pipeline.targets;
    if (blobs.empty()) {
        return std::nullopt;
    }

    const double rcx = pipeline.roi_width / 2.0;
    const double rcy = pipeline.roi_height / 2.0;
    const RegionBlob* best = nullptr;
    double best_dist2 = 0.0;
    for (const RegionBlob& blob : blobs) {
        if (blob.w < options.min_target_width_px || blob.h < options.min_target_height_px) {
            continue;
        }
        const double dx = blob.cx - rcx;
        const double dy = blob.cy - rcy;
        const double dist2 = dx * dx + dy * dy;
        if (best == nullptr || dist2 < best_dist2) {
            best = &blob;
            best_dist2 = dist2;
        }
    }
    if (best == nullptr) {
        return std::nullopt;
    }
    return blobToTarget(*best, pipeline);
}

}  // namespace

Result errorResult(int code, const std::string& reason) {
    Result result;
    result.code = code;
    result.ok = false;
    result.reason = reason;
    return result;
}

Result detectFailedWithInputFrame(const cv::Mat& bgr,
                                  const std::string& output_dir,
                                  const std::string& reason) {
    Result result = errorResult(opencv_detect::kDetectFailed, reason);
    if (bgr.empty() || output_dir.empty()) {
        return result;
    }
    const std::string path = output_dir + "/input_frame.jpg";
    if (cv::imwrite(path, bgr)) {
        result.written_files.push_back(path);
    }
    return result;
}

std::string targetToJson(const DetectedTarget& target) {
    std::ostringstream out;
    out << std::fixed << std::setprecision(2);
    out << "{\"name\":\"" << jsonEscape(target.name) << "\""
        << ",\"x\":" << target.x << ",\"y\":" << target.y
        << ",\"bbox_x\":" << target.bbox_x << ",\"bbox_y\":" << target.bbox_y
        << ",\"w\":" << target.w << ",\"h\":" << target.h << '}';
    return out.str();
}

std::string summaryToJson(const Result& result) {
    std::ostringstream out;
    out << "{\"ok\":" << (result.ok ? "true" : "false");
    out << ",\"code\":" << result.code;
    if (!result.reason.empty()) {
        out << ",\"reason\":\"" << jsonEscape(result.reason) << '"';
    }
    if (!result.frame_kind.empty()) {
        out << ",\"frame_kind\":\"" << jsonEscape(result.frame_kind) << '"';
    }
    out << ",\"files\":[";
    for (std::size_t i = 0; i < result.written_files.size(); ++i) {
        if (i > 0) {
            out << ',';
        }
        out << '"' << jsonEscape(result.written_files[i]) << '"';
    }
    out << "]}";
    return out.str();
}

Result analyzeOpencvStainDetectBgr(const cv::Mat& bgr,
                                   const Options& options,
                                   const std::string& output_dir,
                                   GlobalErodeIslandSlotSession* island_session,
                                   const std::string& source_frame) {
    if (bgr.empty()) {
        return errorResult(opencv_detect::kInvalidInput, opencv_detect::kReasonEmptyImage);
    }
    if (bgr.type() != CV_8UC3) {
        return errorResult(opencv_detect::kInvalidInput, opencv_detect::kReasonInvalidImageType);
    }
    if (output_dir.empty()) {
        return errorResult(opencv_detect::kInvalidInput, opencv_detect::kReasonEmptyOutputDir);
    }
    if (!mkdirOne(output_dir)) {
        return errorResult(opencv_detect::kIoError, opencv_detect::kReasonFailedToCreateOutputDir);
    }

  // Red-frame gate dumps belong in dump_stages_dir (CLI --dump-stages), not output_dir.
    const opencv_detect::RedFrameValidation red_gate =
        opencv_detect::validateRedFrame(bgr, options.dump_stages_dir);
    if (red_gate.verdict != opencv_detect::RedFrameVerdict::ValidRed
        && red_gate.verdict != opencv_detect::RedFrameVerdict::ValidBlue) {
        return errorResult(
            opencv_detect::kFrameRejected,
            red_gate.reason_token != nullptr ? red_gate.reason_token
                                             : opencv_detect::kReasonInvalidNonRed);
    }

    const LensDetFrameKind frame_kind = red_gate.verdict == opencv_detect::RedFrameVerdict::ValidBlue
                                          ? LensDetFrameKind::Blue
                                          : LensDetFrameKind::Red;

    const FixedRoiPipelineResult pipeline = runFixedRoiTargetPipeline(
        bgr,
        makeFixedRoiParams(options),
        frame_kind,
        options.dump_stages_dir,
        island_session,
        source_frame);

    if (frame_kind == LensDetFrameKind::Red
        && options.strict_invert_reject_dark_blob_count > 0
        && pipeline.strict_invert_dark_blob_count
               == options.strict_invert_reject_dark_blob_count) {
        return errorResult(opencv_detect::kFrameRejected,
                           opencv_detect::kReasonStrictInvertDirtyContamination);
    }

    if (pipeline.region_count_after_erode < options.min_split_regions) {
        return detectFailedWithInputFrame(bgr, output_dir,
                                          opencv_detect::kReasonInsufficientRegionsAfterErode);
    }

    if (options.max_split_regions > 0
        && pipeline.region_count_after_erode > options.max_split_regions) {
        return detectFailedWithInputFrame(bgr, output_dir,
                                          opencv_detect::kReasonTooManyRegionsAfterErode);
    }

    if (pipeline.targets.empty()) {
        return detectFailedWithInputFrame(bgr, output_dir,
                                          opencv_detect::kReasonInsufficientRegionsAfterErode);
    }

    const std::optional<DetectedTarget> target = pickMultiBlobTarget(pipeline, options);
    if (!target) {
        return detectFailedWithInputFrame(bgr, output_dir,
                                          opencv_detect::kReasonNoTargetAfterFilter);
    }

    Result result;
    result.code = 0;
    result.ok = true;
    result.frame_kind = pipeline.frame_kind == LensDetFrameKind::Blue ? "blue" : "red";
    const std::string path = output_dir + "/target.json";
    if (!writeTargetJsonFile(path, *target)) {
        return errorResult(opencv_detect::kIoError, opencv_detect::kReasonFailedToWriteTargetJson);
    }
    result.written_files.push_back(path);
    return result;
}

void drawDebugOverlay(cv::Mat& bgr,
                      const cv::Mat& input_bgr,
                      const Options& options,
                      const std::vector<DetectedTarget>& targets) {
    if (bgr.empty()) {
        return;
    }
    int roi_x = 0;
    int roi_y = 0;
    int roi_w = 0;
    int roi_h = 0;
    resolveFixedRoi(input_bgr.cols, input_bgr.rows, makeFixedRoiParams(options),
                    roi_x, roi_y, roi_w, roi_h);
    cv::rectangle(bgr,
                  cv::Point(roi_x, roi_y),
                  cv::Point(roi_x + roi_w - 1, roi_y + roi_h - 1),
                  cv::Scalar(0, 255, 255),
                  3);
    for (const auto& target : targets) {
        if (target.w > 0 && target.h > 0) {
            cv::rectangle(bgr,
                          cv::Point(target.bbox_x, target.bbox_y),
                          cv::Point(target.bbox_x + target.w, target.bbox_y + target.h),
                          cv::Scalar(0, 255, 0),
                          2);
        }
        cv::circle(bgr,
                   cv::Point(static_cast<int>(std::round(target.x)),
                             static_cast<int>(std::round(target.y))),
                   8,
                   cv::Scalar(0, 255, 0),
                   2);
    }
}

}  // namespace opencv_stain_detect
