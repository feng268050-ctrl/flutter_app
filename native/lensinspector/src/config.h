#pragma once
#include <string>
#include <array>

struct CameraConfig {
    int optical_center_x;
    int optical_center_y;
};

struct AlgorithmConfig {
    std::array<int, 2> stain_input_size;
    float stain_conf_thresh;
    float stain_nms_thresh;
    /// Max boxes after NMS for JSON/callbacks; 0 = no cap (not recommended on device).
    int stain_max_det = 100;
    std::string stain_score_mode = "logits";  // "logits" or "probabilities"
    bool use_rknn_io_mem = true;
};

struct StainDetectionConfig {
    int window_time_ms            = 200;
    /// Mask circle center @ mask_ref_width×mask_ref_height (训练对齐 885,430 @ 1920×1080)
    int mask_center_x             = 885;
    int mask_center_y             = 430;
    int mask_radius_px            = 280;
    int mask_ref_width            = 1920;
    int mask_ref_height           = 1080;
    int level2_min_frames         = 2;
    int level1_min_frames         = 2;
    int consecutive_frames_thresh = 2;
};

struct SchedulerConfig {
    /// Legacy config; kept for backward compatibility (current scheduler is frame-driven).
    int    check_interval_sec          = 8;
    /// Legacy config; kept for backward compatibility (current scheduler is frame-driven).
    double substream_infer_interval_sec = 0.5;
    int    locked_timeout_sec          = 300;
    int    stain_valid_sec             = 600;
};

struct DebugConfig {
    std::string debug_dir;
    int max_images;
};

struct OpencvStainDetectConfig {
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
    int max_saturated_white_area_px = 800 * 800;
    double min_relative_area_vs_largest = 0.08;
    double min_centroid_dist_from_largest_px = 75.0;
    double neck_split_max_width_px = 60.0;
    double neck_split_min_width_px = 10.0;
    int neck_cut_line_thickness_px = 5;
    int multi_blob_min_target_width_px = 40;
    int multi_blob_min_target_height_px = 40;
    double multi_blob_max_centroid_dist_from_largest_px = 120.0;
    int global_erode_island_slot_margin_px = 16;
    /// Native per-frame ok must appear in a run of at least this many consecutive ok frames.
    int min_consecutive_ok_frames = 1;
    int blue_min_consecutive_ok_frames = 1;
};

struct ModelsConfig {
    bool det_enabled = true;
};

struct OpencvDetectConfig {
    /// When false, skip validateRedFrame for zero_point / lens_det / edgedrawing.
    bool enable_red_frame_gate = true;
};

struct AppConfig {
    ModelsConfig        models;
    CameraConfig        camera;
    AlgorithmConfig     algorithm;
    StainDetectionConfig stain_detection;
    SchedulerConfig     scheduler;
    DebugConfig         debug;
    OpencvDetectConfig  opencv_detect;
    OpencvStainDetectConfig       opencv_stain_detect;
    std::string         project_root;
};

AppConfig load_config(const std::string& yaml_path, const std::string& project_root);

/// Apply `opencv_detect.enable_red_frame_gate` from config.yaml (no-op if file missing).
void apply_opencv_detect_red_frame_gate(const std::string& yaml_path, const std::string& project_root);

/// Load `config.yaml` from the parent directory of `nearby_file_path`, if present.
void apply_opencv_detect_red_frame_gate_near(const std::string& nearby_file_path);
