#include "config.h"
#include "fscompat.h"
#include "opencv_detect/red_frame_validator.h"
#include <cstdio>
#include <stdexcept>

#ifdef __ANDROID__
#include <android/log.h>
#define CFG_TAG "LensGuard"
#define CFG_LOGW(...) __android_log_print(ANDROID_LOG_WARN, CFG_TAG, __VA_ARGS__)
#else
#define CFG_LOGW(...) std::fprintf(stderr, __VA_ARGS__)
#endif
#if defined(__has_include) && __has_include(<yaml-cpp/yaml.h>)
#include <yaml-cpp/yaml.h>
#else
namespace YAML {
class Node {
public:
    Node operator[](const char*) const { return {}; }
    Node operator[](int) const { return {}; }
    template <typename T>
    T as(const T& fallback) const { return fallback; }
    explicit operator bool() const { return false; }
};

inline Node LoadFile(const std::string&) {
    throw std::runtime_error("yaml-cpp headers are unavailable in this build environment");
}
} // namespace YAML
#endif
#include <algorithm>
#include <cctype>

static std::string resolve_path(const std::string& raw, const std::string& root) {
    if (fscompat::is_absolute(raw)) return raw;
    return fscompat::join(root, raw);
}

AppConfig load_config(const std::string& yaml_path, const std::string& project_root) {
    if (!fscompat::exists(yaml_path))
        throw std::runtime_error("Config file missing: " + yaml_path);

    YAML::Node doc = YAML::LoadFile(yaml_path);
    AppConfig c{};
    c.project_root = project_root;

    if (doc["models"] && doc["models"]["det"]) {
        c.models.det_enabled = doc["models"]["det"]["enabled"].as<bool>(true);
    }

    if (doc["camera"]) {
        auto cam = doc["camera"];
        c.camera.optical_center_x = cam["optical_center_x"].as<int>(0);
        c.camera.optical_center_y = cam["optical_center_y"].as<int>(0);
    }

    auto a = doc["algorithm"];
    auto si = a["stain_input_size"];
    c.algorithm.stain_input_size = {si[0].as<int>(640), si[1].as<int>(640)};
    c.algorithm.stain_conf_thresh= a["stain_conf_thresh"].as<float>(0.25f);
    c.algorithm.stain_nms_thresh = a["stain_nms_thresh"].as<float>(0.35f);
    c.algorithm.stain_max_det    = a["stain_max_det"].as<int>(100);
    if (c.algorithm.stain_max_det < 0) {
        c.algorithm.stain_max_det = 0;
    }
    c.algorithm.stain_score_mode = a["stain_score_mode"].as<std::string>("logits");
    std::transform(c.algorithm.stain_score_mode.begin(), c.algorithm.stain_score_mode.end(),
                   c.algorithm.stain_score_mode.begin(),
                   [](unsigned char ch) { return static_cast<char>(std::tolower(ch)); });
    if (c.algorithm.stain_score_mode != "logits" &&
        c.algorithm.stain_score_mode != "probabilities") {
        c.algorithm.stain_score_mode = "logits";
    }
    c.algorithm.use_rknn_io_mem = a["use_rknn_io_mem"].as<bool>(true);

    if (doc["stain_detection"]) {
        auto sd = doc["stain_detection"];
        c.stain_detection.window_time_ms            = sd["window_time_ms"].as<int>(200);
        c.stain_detection.mask_center_x             = sd["mask_center_x"].as<int>(885);
        c.stain_detection.mask_center_y             = sd["mask_center_y"].as<int>(430);
        c.stain_detection.mask_radius_px            = sd["mask_radius_px"].as<int>(280);
        c.stain_detection.mask_ref_width            = sd["mask_ref_width"].as<int>(1920);
        c.stain_detection.mask_ref_height           = sd["mask_ref_height"].as<int>(1080);
        c.stain_detection.level2_min_frames         = sd["level2_min_frames"].as<int>(2);
        c.stain_detection.level1_min_frames         = sd["level1_min_frames"].as<int>(2);
        c.stain_detection.consecutive_frames_thresh = sd["consecutive_frames_thresh"].as<int>(2);
    }

    auto s = doc["scheduler"];
    c.scheduler.check_interval_sec           = s["check_interval_sec"].as<int>(8);
    c.scheduler.substream_infer_interval_sec =
        s["substream_infer_interval_sec"].as<double>(0.5);
    c.scheduler.locked_timeout_sec = s["locked_timeout_sec"].as<int>(300);
    c.scheduler.stain_valid_sec       = s["stain_valid_sec"].as<int>(600);

    if (s["check_interval_sec"] || s["substream_infer_interval_sec"]) {
        CFG_LOGW(
            "[CONFIG] scheduler.check_interval_sec / substream_infer_interval_sec are legacy keys; "
            "stain infer cadence is frame-driven (App nativeRknnStainDetectFromStream). "
            "Loaded values are not used for Periodic/Preview timing.\n");
        if (s["check_interval_sec"]) {
            CFG_LOGW("[CONFIG]   check_interval_sec=%d (ignored for infer timing)\n",
                     c.scheduler.check_interval_sec);
        }
        if (s["substream_infer_interval_sec"]) {
            CFG_LOGW("[CONFIG]   substream_infer_interval_sec=%.3f (ignored for infer timing)\n",
                     c.scheduler.substream_infer_interval_sec);
        }
    }

    auto d = doc["debug"];
    c.debug.debug_dir  = resolve_path(d["debug_dir"].as<std::string>("debug_data"), project_root);
    c.debug.max_images = d["max_images"].as<int>(200);

    YAML::Node opencv_stain_detect_node;
    if (doc["opencv_stain_detect"]) {
        opencv_stain_detect_node = doc["opencv_stain_detect"];
    } else if (doc["lens_det"]) {
        opencv_stain_detect_node = doc["lens_det"];
    } else if (doc["white_in_red"]) {
        opencv_stain_detect_node = doc["white_in_red"];
    }
    if (opencv_stain_detect_node) {
        auto w = opencv_stain_detect_node;
        if (w["osd_mask"]) {
            c.opencv_stain_detect.osd_max_width = w["osd_mask"]["max_width"].as<int>(850);
            c.opencv_stain_detect.osd_max_height = w["osd_mask"]["max_height"].as<int>(140);
        }
        if (w["min_consecutive_ok_frames"]) {
            c.opencv_stain_detect.min_consecutive_ok_frames = w["min_consecutive_ok_frames"].as<int>(1);
        }
        if (w["blue_min_consecutive_ok_frames"]) {
            c.opencv_stain_detect.blue_min_consecutive_ok_frames =
                w["blue_min_consecutive_ok_frames"].as<int>(1);
        }
        if (w["fixed_roi"]) {
            auto fr = w["fixed_roi"];
            c.opencv_stain_detect.roi_x = fr["x"].as<int>(650);
            c.opencv_stain_detect.roi_y = fr["y"].as<int>(100);
            c.opencv_stain_detect.roi_width = fr["width"].as<int>(640);
            c.opencv_stain_detect.roi_height = fr["height"].as<int>(640);
        }
        if (w["preprocess"]) {
            auto pp = w["preprocess"];
            c.opencv_stain_detect.enhance_clahe_clip = pp["enhance_clahe_clip"].as<double>(2.5);
            c.opencv_stain_detect.enhance_alpha = pp["enhance_alpha"].as<double>(1.15);
            c.opencv_stain_detect.enhance_beta = pp["enhance_beta"].as<int>(12);
            c.opencv_stain_detect.invert_thresh = pp["invert_thresh"].as<int>(80);
            c.opencv_stain_detect.strict_invert_thresh = pp["strict_invert_thresh"].as<int>(110);
            if (pp["strict_invert_dirty_reject"]) {
                auto sir = pp["strict_invert_dirty_reject"];
                if (sir["enabled"] && !sir["enabled"].as<bool>(true)) {
                    c.opencv_stain_detect.strict_invert_reject_dark_blob_count = 0;
                } else {
                    c.opencv_stain_detect.strict_invert_reject_dark_blob_count =
                        sir["reject_dark_blob_count"].as<int>(2);
                }
                c.opencv_stain_detect.strict_invert_dark_min_area =
                    sir["dark_min_area"].as<int>(900);
                c.opencv_stain_detect.strict_invert_dark_max_value =
                    sir["dark_max_value"].as<int>(200);
                c.opencv_stain_detect.strict_invert_dark_min_width =
                    sir["dark_min_width"].as<int>(75);
                c.opencv_stain_detect.strict_invert_dark_min_height =
                    sir["dark_min_height"].as<int>(14);
                c.opencv_stain_detect.strict_invert_dark_max_height =
                    sir["dark_max_height"].as<int>(28);
                c.opencv_stain_detect.strict_invert_dark_min_aspect =
                    sir["dark_min_aspect"].as<double>(4.0);
            } else {
                c.opencv_stain_detect.strict_invert_reject_dark_blob_count =
                    pp["strict_invert_reject_dark_blob_count"].as<int>(2);
                c.opencv_stain_detect.strict_invert_dark_max_value =
                    pp["strict_invert_dark_max_value"].as<int>(200);
                c.opencv_stain_detect.strict_invert_dark_min_area =
                    pp["strict_invert_dark_min_area"].as<int>(900);
                c.opencv_stain_detect.strict_invert_dark_min_width =
                    pp["strict_invert_dark_min_width"].as<int>(75);
                c.opencv_stain_detect.strict_invert_dark_min_height =
                    pp["strict_invert_dark_min_height"].as<int>(14);
                c.opencv_stain_detect.strict_invert_dark_max_height =
                    pp["strict_invert_dark_max_height"].as<int>(28);
                c.opencv_stain_detect.strict_invert_dark_min_aspect =
                    pp["strict_invert_dark_min_aspect"].as<double>(4.0);
            }
            c.opencv_stain_detect.gray_global_denoise_kernel =
                pp["gray_global_denoise_kernel"].as<int>(5);
            c.opencv_stain_detect.min_blob_area = pp["min_blob_area"].as<int>(40);
            c.opencv_stain_detect.open_kernel = pp["open_kernel"].as<int>(3);
            c.opencv_stain_detect.global_erode_kernel = pp["global_erode_kernel"].as<int>(9);
            c.opencv_stain_detect.erode_max_iterations = pp["erode_max_iterations"].as<int>(0);
            c.opencv_stain_detect.erode_kernel = pp["erode_kernel"].as<int>(3);
            if (pp["red_bright_region"]) {
                auto rb = pp["red_bright_region"];
                c.opencv_stain_detect.red_bright_s_min = rb["s_min"].as<int>(75);
                c.opencv_stain_detect.red_bright_v_min = rb["v_min"].as<int>(40);
                c.opencv_stain_detect.red_bright_red_hue_lo = rb["red_hue_lo"].as<int>(12);
                c.opencv_stain_detect.red_bright_red_hue_hi = rb["red_hue_hi"].as<int>(168);
                c.opencv_stain_detect.red_bright_magenta_hue_lo = rb["magenta_hue_lo"].as<int>(118);
                c.opencv_stain_detect.red_bright_magenta_hue_hi = rb["magenta_hue_hi"].as<int>(168);
                c.opencv_stain_detect.red_bright_morph_kernel = rb["morph_kernel"].as<int>(3);
                c.opencv_stain_detect.red_bright_dilate_iterations = rb["dilate_iterations"].as<int>(4);
                c.opencv_stain_detect.red_bright_target_min_width_px =
                    rb["target_min_width_px"].as<int>(350);
                c.opencv_stain_detect.red_bright_target_min_height_px =
                    rb["target_min_height_px"].as<int>(225);
                c.opencv_stain_detect.red_bright_reject_v200_fraction_max =
                    rb["reject_v200_fraction_max"].as<double>(0.15);
                c.opencv_stain_detect.red_bright_reject_white_fraction_max =
                    rb["reject_white_fraction_max"].as<double>(0.0);
                c.opencv_stain_detect.red_bright_reject_centroid_y_min_full =
                    rb["reject_centroid_y_min_full"].as<double>(400.0);
            }
            if (pp["halo_spread_gate"]) {
                auto hg = pp["halo_spread_gate"];
                if (hg["enabled"].as<bool>(false)) {
                    c.opencv_stain_detect.halo_analysis_margin_px =
                        hg["analysis_margin_px"].as<int>(40);
                    c.opencv_stain_detect.halo_core_v_min = hg["core_v_min"].as<int>(250);
                    c.opencv_stain_detect.halo_halo_v_min = hg["halo_v_min"].as<int>(180);
                    c.opencv_stain_detect.halo_halo_v_max = hg["halo_v_max"].as<int>(250);
                    c.opencv_stain_detect.halo_reject_fwhm_halo_w_frac_max =
                        hg["reject_fwhm_halo_w_frac_max"].as<double>(0.82);
                    c.opencv_stain_detect.halo_reject_halo_score_max =
                        hg["reject_halo_score_max"].as<double>(0.0);
                }
            }
            c.opencv_stain_detect.min_split_regions = pp["min_split_regions"].as<int>(1);
            c.opencv_stain_detect.max_split_regions = pp["max_split_regions"].as<int>(1);
            c.opencv_stain_detect.min_target_area_px = pp["min_target_area_px"].as<int>(150);
            c.opencv_stain_detect.global_erode_min_target_area_px =
                pp["global_erode_min_target_area_px"].as<int>(150);
            c.opencv_stain_detect.global_erode_min_target_height_px =
                pp["global_erode_min_target_height_px"].as<int>(65);
            c.opencv_stain_detect.red_above_min_target_height_px =
                pp["red_above_min_target_height_px"].as<int>(40);
            c.opencv_stain_detect.global_erode_reject_two_targets_centroid_dist_px =
                pp["global_erode_reject_two_targets_centroid_dist_px"].as<double>(300.0);
            if (pp["red_above_line"]) {
                auto ral = pp["red_above_line"];
                c.opencv_stain_detect.red_line_bright_gray_threshold =
                    ral["bright_gray_threshold"].as<int>(240);
                c.opencv_stain_detect.red_line_margin_px = ral["line_margin_px"].as<int>(4);
                c.opencv_stain_detect.red_above_min_fraction =
                    ral["min_above_fraction"].as<double>(0.5);
            }
            c.opencv_stain_detect.min_target_width_px = pp["min_target_width_px"].as<int>(15);
            c.opencv_stain_detect.min_target_height_px = pp["min_target_height_px"].as<int>(15);
            c.opencv_stain_detect.max_saturated_white_area_px =
                pp["max_saturated_white_area_px"].as<int>(800 * 800);
            c.opencv_stain_detect.min_relative_area_vs_largest =
                pp["min_relative_area_vs_largest"].as<double>(0.08);
            c.opencv_stain_detect.min_centroid_dist_from_largest_px =
                pp["min_centroid_dist_from_largest_px"].as<double>(75.0);
            c.opencv_stain_detect.neck_split_max_width_px =
                pp["neck_split_max_width_px"].as<double>(60.0);
            c.opencv_stain_detect.neck_split_min_width_px =
                pp["neck_split_min_width_px"].as<double>(10.0);
            c.opencv_stain_detect.neck_cut_line_thickness_px =
                pp["neck_cut_line_thickness_px"].as<int>(5);
            c.opencv_stain_detect.multi_blob_min_target_width_px =
                pp["multi_blob_min_target_width_px"].as<int>(40);
            c.opencv_stain_detect.multi_blob_min_target_height_px =
                pp["multi_blob_min_target_height_px"].as<int>(40);
            c.opencv_stain_detect.multi_blob_max_centroid_dist_from_largest_px =
                pp["multi_blob_max_centroid_dist_from_largest_px"].as<double>(120.0);
            c.opencv_stain_detect.global_erode_island_slot_margin_px =
                pp["global_erode_island_slot_margin_px"].as<int>(16);
        } else if (w["valid_region"]) {
            // Legacy keys: morphology/target thresholds only; bright_* and ref_* are ignored.
            auto vr = w["valid_region"];
            c.opencv_stain_detect.min_blob_area = vr["min_blob_area"].as<int>(40);
            c.opencv_stain_detect.open_kernel = vr["open_kernel"].as<int>(3);
            c.opencv_stain_detect.global_erode_kernel = vr["global_erode_kernel"].as<int>(9);
            c.opencv_stain_detect.erode_max_iterations = vr["erode_max_iterations"].as<int>(4);
            c.opencv_stain_detect.erode_kernel = vr["erode_kernel"].as<int>(3);
            c.opencv_stain_detect.min_split_regions = vr["min_split_regions"].as<int>(2);
            c.opencv_stain_detect.max_split_regions = vr["max_split_regions"].as<int>(4);
            c.opencv_stain_detect.min_target_area_px = vr["min_target_area_px"].as<int>(800);
            c.opencv_stain_detect.min_target_width_px = vr["min_target_width_px"].as<int>(15);
            c.opencv_stain_detect.min_target_height_px = vr["min_target_height_px"].as<int>(15);
        }
    }

    if (doc["opencv_detect"]) {
        const YAML::Node od = doc["opencv_detect"];
        c.opencv_detect.enable_red_frame_gate =
            od["enable_red_frame_gate"].as<bool>(true);
    }

    return c;
}

void apply_opencv_detect_red_frame_gate(const std::string& yaml_path, const std::string& project_root) {
    if (!fscompat::exists(yaml_path)) {
        return;
    }
    try {
        const AppConfig config = load_config(yaml_path, project_root);
        opencv_detect::setRedFrameGateEnabled(config.opencv_detect.enable_red_frame_gate);
    } catch (const std::exception& ex) {
        CFG_LOGW("[CONFIG] apply_opencv_detect_red_frame_gate failed: %s\n", ex.what());
    }
}

void apply_opencv_detect_red_frame_gate_near(const std::string& nearby_file_path) {
    if (nearby_file_path.empty()) {
        return;
    }
    const std::string parent = fscompat::parent_path(nearby_file_path);
    const std::string config_path = fscompat::join(parent, "config.yaml");
    apply_opencv_detect_red_frame_gate(config_path, parent);
}
