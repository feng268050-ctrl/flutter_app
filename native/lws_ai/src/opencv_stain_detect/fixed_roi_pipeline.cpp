#include "fixed_roi_pipeline.h"
#include "fixed_roi_internal.hpp"

#include <algorithm>
#include <cmath>

namespace opencv_stain_detect {
namespace {
namespace detail = fixed_roi_internal;

bool blobMatchesIslandSlot(const RegionBlob& blob,
                           const GlobalErodeIslandSlot& slot,
                           int margin_px) {
    const int m = margin_px;
    return blob.cx >= slot.x - m && blob.cx <= slot.x + slot.w + m
        && blob.cy >= slot.y - m && blob.cy <= slot.y + slot.h + m;
}

std::vector<GlobalErodeIslandSlot> snapshotGlobalErodeIslandSlots(
    const std::vector<RegionBlob>& blobs,
    const FixedRoiParams& params) {
    if (blobs.size() < static_cast<std::size_t>(params.min_split_regions)) {
        return {};
    }
    const int largest_area = blobs[0].area_px;
    std::vector<GlobalErodeIslandSlot> slots;
    for (std::size_t i = 1; i < blobs.size(); ++i) {
        if (blobs[i].area_px < params.min_relative_area_vs_largest * largest_area) {
            GlobalErodeIslandSlot slot;
            slot.x = blobs[i].x;
            slot.y = blobs[i].y;
            slot.w = blobs[i].w;
            slot.h = blobs[i].h;
            slot.area_px = blobs[i].area_px;
            slot.cx = blobs[i].cx;
            slot.cy = blobs[i].cy;
            slots.push_back(slot);
        }
    }
    return slots;
}

int countEffectiveBlobs(const std::vector<RegionBlob>& blobs,
                        const std::vector<GlobalErodeIslandSlot>& island_slots,
                        int margin_px) {
    int count = 0;
    for (const RegionBlob& blob : blobs) {
        bool is_island = false;
        for (const GlobalErodeIslandSlot& slot : island_slots) {
            if (blobMatchesIslandSlot(blob, slot, margin_px)) {
                is_island = true;
                break;
            }
        }
        if (!is_island) {
            ++count;
        }
    }
    return count;
}

std::vector<RegionBlob> filterGlobalErodeIslands(
    const std::vector<RegionBlob>& blobs,
    const std::vector<GlobalErodeIslandSlot>& island_slots,
    int margin_px) {
    std::vector<RegionBlob> kept;
    for (const RegionBlob& blob : blobs) {
        bool is_island = false;
        for (const GlobalErodeIslandSlot& slot : island_slots) {
            if (blobMatchesIslandSlot(blob, slot, margin_px)) {
                is_island = true;
                break;
            }
        }
        if (!is_island) {
            kept.push_back(blob);
        }
    }
    return kept;
}

std::vector<RegionBlob> filterSmallBlobsWhenMultiSplit(
    const std::vector<RegionBlob>& blobs,
    const FixedRoiParams& params) {
    if (blobs.size() < static_cast<std::size_t>(params.min_split_regions)) {
        return blobs;
    }
    std::vector<RegionBlob> kept;
    kept.reserve(blobs.size());
    for (const RegionBlob& blob : blobs) {
        if (blob.w >= params.multi_blob_min_target_width_px
            && blob.h >= params.multi_blob_min_target_height_px) {
            kept.push_back(blob);
        }
    }
    return kept;
}

std::vector<RegionBlob> filterFarCentroidBlobsWhenMultiSplit(
    const std::vector<RegionBlob>& blobs,
    const FixedRoiParams& params) {
    if (blobs.size() < static_cast<std::size_t>(params.min_split_regions)) {
        return blobs;
    }
    if (params.multi_blob_max_centroid_dist_from_largest_px <= 0.0) {
        return blobs;
    }
    const TwoLargestBlobs top2 = detail::findTwoLargestBlobsImpl(blobs);
    if (top2.largest == nullptr || top2.second == nullptr) {
        return blobs;
    }
    const double dx = top2.second->cx - top2.largest->cx;
    const double dy = top2.second->cy - top2.largest->cy;
    if (std::hypot(dx, dy) <= params.multi_blob_max_centroid_dist_from_largest_px) {
        return blobs;
    }
    std::vector<RegionBlob> kept;
    kept.reserve(blobs.size());
    for (const RegionBlob& blob : blobs) {
        if (&blob == top2.second) {
            continue;
        }
        kept.push_back(blob);
    }
    return kept;
}

void drawIslandSlotsOnRoi(cv::Mat& roi_bgr,
                          const std::vector<GlobalErodeIslandSlot>& slots) {
    const cv::Scalar color(255, 128, 0);
    for (const GlobalErodeIslandSlot& slot : slots) {
        cv::rectangle(roi_bgr,
                      cv::Point(slot.x, slot.y),
                      cv::Point(slot.x + slot.w - 1, slot.y + slot.h - 1),
                      color,
                      2);
        cv::putText(roi_bgr,
                    "global_erode_island",
                    cv::Point(slot.x, std::max(slot.y - 4, 12)),
                    cv::FONT_HERSHEY_SIMPLEX,
                    0.4,
                    color,
                    1,
                    cv::LINE_AA);
    }
}

}  // namespace

void GlobalErodeIslandSlotSession::learn(const std::vector<GlobalErodeIslandSlot>& slots,
                                         const std::string& source_frame) {
    if (!slots_.empty() || slots.empty()) {
        return;
    }
    slots_ = slots;
    learned_from_ = source_frame;
}

void resolveFixedRoi(int image_width,
                     int image_height,
                     const FixedRoiParams& params,
                     int& out_x,
                     int& out_y,
                     int& out_w,
                     int& out_h) {
    out_w = std::min(params.roi_width, image_width);
    out_h = std::min(params.roi_height, image_height);
    out_x = std::max(0, std::min(params.roi_x, image_width - out_w));
    out_y = std::max(0, std::min(params.roi_y, image_height - out_h));
}

FixedRoiPipelineResult runFixedRoiTargetPipeline(const cv::Mat& bgr,
                                                 const FixedRoiParams& params,
                                                 LensDetFrameKind frame_kind,
                                                 const std::string& dump_stages_dir,
                                                 GlobalErodeIslandSlotSession* island_session,
                                                 const std::string& source_frame) {
    FixedRoiPipelineResult out;
    out.frame_kind = frame_kind;
    const int h = bgr.rows;
    const int w = bgr.cols;

    resolveFixedRoi(w, h, params, out.roi_x, out.roi_y, out.roi_width, out.roi_height);

    int step = 0;
    detail::maybeSaveStage(dump_stages_dir, step, "input_raw.jpg", bgr);

    cv::Mat roi_on_input = bgr.clone();
    cv::rectangle(roi_on_input,
                  cv::Point(out.roi_x, out.roi_y),
                  cv::Point(out.roi_x + out.roi_width - 1, out.roi_y + out.roi_height - 1),
                  cv::Scalar(0, 255, 255),
                  2);
    detail::maybeSaveStage(dump_stages_dir, step, "roi_box_on_input.jpg", roi_on_input);

    const cv::Mat roi_crop =
        bgr(cv::Rect(out.roi_x, out.roi_y, out.roi_width, out.roi_height)).clone();
    detail::maybeSaveStage(dump_stages_dir, step, "roi_crop.jpg", roi_crop);

    const cv::Mat enhanced = detail::brightnessEnhance(roi_crop, params);
    detail::maybeSaveStage(dump_stages_dir, step, "brightness_enhanced.jpg", enhanced);

    cv::Mat gray;
    cv::cvtColor(enhanced, gray, cv::COLOR_BGR2GRAY);
    detail::maybeSaveStage(dump_stages_dir, step, "grayscale.jpg", gray);

    const cv::Mat gray_denoised = detail::applyGlobalGrayDenoise(gray, params);
    if (params.gray_global_denoise_kernel > 1) {
        detail::maybeSaveStage(dump_stages_dir, step, "global_denoise.jpg", gray_denoised);
    }

    cv::Mat inverted;
    cv::bitwise_not(gray_denoised, inverted);
    detail::maybeSaveStage(dump_stages_dir, step, "bw_inverted.jpg", inverted);

    std::vector<RegionBlob> filtered_blobs;
    if (frame_kind == LensDetFrameKind::Blue) {
        out.strict_invert_dark_blob_count = 0;
        filtered_blobs =
            detail::detectGlobalErodeSingleTarget(inverted, params, dump_stages_dir, step);
    } else {
        cv::Mat inverted_tight = inverted.clone();
        if (params.strict_invert_thresh >= 0) {
            inverted_tight.setTo(255, inverted > params.strict_invert_thresh);
        }

        out.strict_invert_dark_blob_count =
            detail::countStrictInvertQualifyingDarkBlobs(inverted_tight, params);
        detail::maybeSaveStage(dump_stages_dir,
                                step,
                                "strict_inverted_dark_blobs_"
                                    + std::to_string(out.strict_invert_dark_blob_count) + ".jpg",
                                inverted_tight);

        filtered_blobs =
            detail::detectRedAboveBrightLine(enhanced, gray_denoised, params, dump_stages_dir, step);
    }
    const int target_n_comp = static_cast<int>(filtered_blobs.size());

    (void)island_session;
    (void)source_frame;
    out.island_slots_from_session = false;
    out.island_slots = {};
    out.erosion_count = 0;

    out.region_count_after_erode = target_n_comp;
    if (target_n_comp == 1) {
        out.targets = filtered_blobs;
    } else {
        out.targets.clear();
    }

    if (!dump_stages_dir.empty() && !out.targets.empty()) {
        cv::Mat target_vis = roi_crop.clone();
        detail::drawBlobsOnRoi(target_vis, out.targets, cv::Scalar(0, 255, 0));
        const char* target_stage_name = frame_kind == LensDetFrameKind::Blue
                                            ? "global_erode_target.jpg"
                                            : "red_above_line_target.jpg";
        detail::maybeSaveStage(dump_stages_dir, step, target_stage_name, target_vis);
    }

    return out;
}

TwoLargestBlobs findTwoLargestBlobs(const std::vector<RegionBlob>& blobs) {
    return detail::findTwoLargestBlobsImpl(blobs);
}

}  // namespace opencv_stain_detect
