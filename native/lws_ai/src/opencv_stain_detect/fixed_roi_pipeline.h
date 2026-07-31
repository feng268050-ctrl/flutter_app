#pragma once

#include <opencv2/core.hpp>

#include <string>
#include <vector>

namespace opencv_stain_detect {

enum class LensDetFrameKind {
    Red,
    Blue,
};

struct RegionBlob {
    int x = 0;
    int y = 0;
    int w = 0;
    int h = 0;
    int area_px = 0;
    double cx = 0.0;
    double cy = 0.0;
};

/** ROI-local coords captured once after global 9x9 erosion; reused downstream. */
struct GlobalErodeIslandSlot {
    int x = 0;
    int y = 0;
    int w = 0;
    int h = 0;
    int area_px = 0;
    double cx = 0.0;
    double cy = 0.0;
};

/** Learn island slots once per batch/session; reuse for remaining frames. */
class GlobalErodeIslandSlotSession {
public:
    bool hasSlots() const { return !slots_.empty(); }
    const std::vector<GlobalErodeIslandSlot>& slots() const { return slots_; }
    const std::string& learnedFrom() const { return learned_from_; }

    void learn(const std::vector<GlobalErodeIslandSlot>& slots, const std::string& source_frame);

private:
    std::vector<GlobalErodeIslandSlot> slots_;
    std::string learned_from_;
};

struct FixedRoiParams {
    int roi_x = 650;
    int roi_y = 100;
    int roi_width = 640;
    int roi_height = 640;

    double enhance_clahe_clip = 2.5;
    double enhance_alpha = 1.15;
    int enhance_beta = 12;
    int invert_thresh = 80;
    /// Method-1 tight mask: pixels above this on inverted gray are whitened before binarization.
    int strict_invert_thresh = 110;
    /// Reject frame when qualifying strict_inverted dash-blob count equals this (0=off). Default 2.
    int strict_invert_reject_dark_blob_count = 2;
    /// Pixel on inverted_tight below this counts as dark (tighter than 255 fringe).
    int strict_invert_dark_max_value = 200;
    /// Min connected area (px) for a strict_inverted dash blob.
    int strict_invert_dark_min_area = 900;
    /// Horizontal wash dashes (l01-l03): wide, short, high aspect.
    int strict_invert_dark_min_width = 75;
    int strict_invert_dark_min_height = 14;
    int strict_invert_dark_max_height = 28;
    double strict_invert_dark_min_aspect = 4.0;
    /// Median blur on full ROI grayscale before invert (0=off, odd 3/5/7).
    int gray_global_denoise_kernel = 5;

    int min_blob_area = 40;
    int open_kernel = 3;
    int global_erode_kernel = 9;
    /// Min area (px) for step-10 global-erode blobs to keep (drop smaller).
    int global_erode_min_target_area_px = 150;
    /// Min bbox height (px) for blue-frame global-erode blobs to keep.
    int global_erode_min_target_height_px = 65;
    /// Min bbox height (px) for red-frame above-line blobs to keep.
    int red_above_min_target_height_px = 40;
    /// When two targets remain and centroid distance exceeds this, drop the smaller one (0=off).
    double global_erode_reject_two_targets_centroid_dist_px = 300.0;

    /// Red-frame path: gray/V pixels >= this count toward brightest horizontal weld line.
    int red_line_bright_gray_threshold = 240;
    /// Rows within ±margin of the bright line are excluded from above/below red split.
    int red_line_margin_px = 4;
    /// Require red pixel fraction above the bright line >= this (0=off).
    double red_above_min_fraction = 0.5;
    /// Deprecated: use global_erode_min_target_area_px for step-10 filtering.
    int min_target_area_px = 150;
    /// Deprecated: dynamic elliptical erode loop replaced by red_bright_region split mask.
    int erode_max_iterations = 0;
    int erode_kernel = 3;

    /// HSV red/magenta bright plasma mask (replaces dynamic erode for region split).
    int red_bright_s_min = 75;
    int red_bright_v_min = 40;
    int red_bright_red_hue_lo = 12;
    int red_bright_red_hue_hi = 168;
    int red_bright_magenta_hue_lo = 118;
    int red_bright_magenta_hue_hi = 168;
    int red_bright_morph_kernel = 3;
    int red_bright_dilate_iterations = 4;
    /// Red bright blob must exceed these bbox dimensions to count as a detection target.
    int red_bright_target_min_width_px = 350;
    int red_bright_target_min_height_px = 225;
    /// Reject blob when this fraction of mask pixels inside bbox have V above 200 (purple/white glare).
    /// Calibrated: l001-l003 <= ~0.07, l006 ~0.33. 0 disables.
    double red_bright_reject_v200_fraction_max = 0.15;
    /// Reject blob when this fraction of mask pixels have S below 80 and V above 180. 0 disables.
    double red_bright_reject_white_fraction_max = 0.0;
    /// Reject blob when full-frame centroid y is below this (top ROI purple/white wash). 0 disables.
    double red_bright_reject_centroid_y_min_full = 400.0;

    int min_split_regions = 1;
    /// Reject when effective detection blobs (centroid targets, after global-island
    /// exclusion and multi-blob filters) exceed this count.
    int max_split_regions = 1;

    double min_relative_area_vs_largest = 0.08;
    double min_centroid_dist_from_largest_px = 75.0;
    /// Distance-transform neck width (2 * local DT min); cut when below this (Method A).
    double neck_split_max_width_px = 60.0;
    /// Do not cut when measured neck width is below this (noise / too thin).
    double neck_split_min_width_px = 10.0;
    int neck_cut_line_thickness_px = 5;
    /// When >= min_split_regions effective blobs, drop targets below this bbox (px).
    int multi_blob_min_target_width_px = 40;
    int multi_blob_min_target_height_px = 40;
    /// When >= min_split_regions blobs remain, drop blobs whose centroid is farther than this
    /// from the largest blob's centroid (px).
    double multi_blob_max_centroid_dist_from_largest_px = 120.0;
    int global_erode_island_slot_margin_px = 16;

    /// Halo spread analysis around each lens_det target bbox (uses red_bright targets).
    int halo_analysis_margin_px = 40;
    int halo_core_v_min = 250;
    int halo_halo_v_min = 180;
    int halo_halo_v_max = 250;
    /// 0=off. Reject target when fwhm_halo_w / analysis_window_w exceeds this.
    double halo_reject_fwhm_halo_w_frac_max = 0.0;
    /// 0=off. Reject target when halo_score exceeds this.
    double halo_reject_halo_score_max = 0.0;
};

struct FixedRoiPipelineResult {
    int roi_x = 0;
    int roi_y = 0;
    int roi_width = 0;
    int roi_height = 0;
    int erosion_count = 0;
    /// Dark connected components on strict_inverted (non-white pixels, area >= strict_invert_dark_min_area).
    int strict_invert_dark_blob_count = 0;
    /// Effective detection blobs with centroid after global-island and multi-blob filters.
    int region_count_after_erode = 0;
    LensDetFrameKind frame_kind = LensDetFrameKind::Red;
    /// Blobs remaining after global-erode island filter (before multi-blob filters).
    int region_count_after_global_filter = 0;
    bool neck_split_applied = false;
    std::vector<RegionBlob> targets;
    std::vector<GlobalErodeIslandSlot> island_slots;
    bool island_slots_from_session = false;
    bool has_halo_spread_metrics = false;
    double halo_spread_score = 0.0;
    double halo_spread_fwhm_w_px = 0.0;
    double halo_spread_fwhm_halo_w_px = 0.0;
    double halo_spread_area_v200 = 0.0;
};

/** Largest and second-largest blobs by area_px; nullptr when absent. */
struct TwoLargestBlobs {
    const RegionBlob* largest = nullptr;
    const RegionBlob* second = nullptr;
};

TwoLargestBlobs findTwoLargestBlobs(const std::vector<RegionBlob>& blobs);

void resolveFixedRoi(int image_width,
                     int image_height,
                     const FixedRoiParams& params,
                     int& out_x,
                     int& out_y,
                     int& out_w,
                     int& out_h);

FixedRoiPipelineResult runFixedRoiTargetPipeline(
    const cv::Mat& bgr,
    const FixedRoiParams& params,
    LensDetFrameKind frame_kind,
    const std::string& dump_stages_dir = "",
    GlobalErodeIslandSlotSession* island_session = nullptr,
    const std::string& source_frame = "");

}  // namespace opencv_stain_detect
