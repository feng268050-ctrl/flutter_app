#pragma once

#include "fixed_roi_pipeline.h"

#include <opencv2/core.hpp>

#include <string>
#include <vector>

namespace opencv_stain_detect {

struct Options {
    int osd_max_width = 850;
    int osd_max_height = 140;

    int roi_x = 650;
    int roi_y = 100;
    int roi_width = 640;
    int roi_height = 640;

    double enhance_clahe_clip = 2.5;
    double enhance_alpha = 1.15;
    int enhance_beta = 12;
    int invert_thresh = 80;
    int strict_invert_thresh = 110;
    int strict_invert_reject_dark_blob_count = 2;
    int strict_invert_dark_max_value = 200;
    int strict_invert_dark_min_area = 900;
    int strict_invert_dark_min_width = 75;
    int strict_invert_dark_min_height = 14;
    int strict_invert_dark_max_height = 28;
    double strict_invert_dark_min_aspect = 4.0;
    int gray_global_denoise_kernel = 5;

    int min_blob_area = 40;
    int open_kernel = 3;
    int global_erode_kernel = 9;
    int erode_max_iterations = 0;
    int erode_kernel = 3;
    int min_split_regions = 1;
    int max_split_regions = 1;
    int min_target_area_px = 150;
    int global_erode_min_target_area_px = 150;
    int global_erode_min_target_height_px = 65;
    int red_above_min_target_height_px = 40;
    double global_erode_reject_two_targets_centroid_dist_px = 300.0;
    int red_line_bright_gray_threshold = 240;
    int red_line_margin_px = 4;
    double red_above_min_fraction = 0.5;
    int min_target_width_px = 15;
    int min_target_height_px = 15;
    double min_relative_area_vs_largest = 0.08;
    double min_centroid_dist_from_largest_px = 75.0;
    double neck_split_max_width_px = 60.0;
    double neck_split_min_width_px = 10.0;
    int neck_cut_line_thickness_px = 5;
    int multi_blob_min_target_width_px = 40;
    int multi_blob_min_target_height_px = 40;
    double multi_blob_max_centroid_dist_from_largest_px = 120.0;
    int global_erode_island_slot_margin_px = 16;

    int red_bright_s_min = 75;
    int red_bright_v_min = 40;
    int red_bright_red_hue_lo = 12;
    int red_bright_red_hue_hi = 168;
    int red_bright_magenta_hue_lo = 118;
    int red_bright_magenta_hue_hi = 168;
    int red_bright_morph_kernel = 3;
    int red_bright_dilate_iterations = 4;
    int red_bright_target_min_width_px = 350;
    int red_bright_target_min_height_px = 225;
    double red_bright_reject_v200_fraction_max = 0.15;
    double red_bright_reject_white_fraction_max = 0.0;
    double red_bright_reject_centroid_y_min_full = 400.0;
    int halo_analysis_margin_px = 40;
    int halo_core_v_min = 250;
    int halo_halo_v_min = 180;
    int halo_halo_v_max = 250;
    double halo_reject_fwhm_halo_w_frac_max = 0.0;
    double halo_reject_halo_score_max = 0.0;

    /// Deprecated: superseded by shared red-frame gate.
    int max_saturated_white_area_px = 800 * 800;

    /// When non-empty, pipeline writes numbered stage images under this directory.
    std::string dump_stages_dir;
};

struct DetectedTarget {
    std::string name;
    double x = 0.0;
    double y = 0.0;
    int bbox_x = 0;
    int bbox_y = 0;
    int w = 0;
    int h = 0;
};

struct Result {
    int code = 0;
    bool ok = false;
    std::string reason;
    std::string frame_kind = "red";
    std::vector<std::string> written_files;
};

Result analyzeOpencvStainDetectBgr(const cv::Mat& bgr,
                                   const Options& options,
                                   const std::string& output_dir,
                                   GlobalErodeIslandSlotSession* island_session = nullptr,
                                   const std::string& source_frame = "");
Result errorResult(int code, const std::string& reason);
Result detectFailedWithInputFrame(const cv::Mat& bgr,
                                   const std::string& output_dir,
                                   const std::string& reason);

std::string targetToJson(const DetectedTarget& target);
std::string summaryToJson(const Result& result);

void drawDebugOverlay(cv::Mat& bgr,
                      const cv::Mat& input_bgr,
                      const Options& options,
                      const std::vector<DetectedTarget>& targets);

}  // namespace opencv_stain_detect
