#include "rknn_stain_detect_pp.h"
#include <algorithm>
#include <cmath>

RknnStainContaminationDetector::RknnStainContaminationDetector(const Config& cfg)
    : RknnStainContaminationDetector(cfg, WindowConfig()) {}

RknnStainContaminationDetector::RknnStainContaminationDetector(const Config& cfg,
                                                     const WindowConfig& wcfg)
    : cfg_(cfg)
    , mask_center_x_(cfg_.mask_center_x != 0 ? cfg_.mask_center_x : 885)
    , mask_center_y_(cfg_.mask_center_y != 0 ? cfg_.mask_center_y : 430)
    , mask_radius_sq_(static_cast<int64_t>(cfg_.mask_radius_px) * cfg_.mask_radius_px)
    , level2_min_frames_(wcfg.level2_min_frames)
    , level1_min_frames_(wcfg.level1_min_frames)
    , consecutive_frames_thresh_(wcfg.consecutive_frames_thresh) {
    int fps = wcfg.fps > 0 ? wcfg.fps : 30;
    float frame_ms = 1000.0f / fps;
    window_size_ = std::max(1, static_cast<int>(std::round(wcfg.window_time_ms / frame_ms)));
}

void RknnStainContaminationDetector::reset() {
    window_.clear();
    last_result_ = {0, "CLEAN", "洁净"};
}

FrameVerdict
RknnStainContaminationDetector::analyze_single_frame(const std::vector<Detection>& dets) const {
    if (dets.empty())
        return {0};

    bool has_inside  = false;
    bool has_outside = false;

    for (const auto& d : dets) {
        int x1 = static_cast<int>(d.x1);
        int y1 = static_cast<int>(d.y1);
        int x2 = static_cast<int>(d.x2);
        int y2 = static_cast<int>(d.y2);
        int cx = (x1 + x2) >> 1;
        int cy = (y1 + y2) >> 1;

        int64_t dist_sq = static_cast<int64_t>(cx - mask_center_x_) * (cx - mask_center_x_)
                        + static_cast<int64_t>(cy - mask_center_y_) * (cy - mask_center_y_);

        if (dist_sq <= mask_radius_sq_)
            has_inside = true;
        else
            has_outside = true;
    }

    if (has_inside)
        return {2};
    if (has_outside)
        return {1};
    return {0};
}

ContaminationResult
RknnStainContaminationDetector::update(const std::vector<Detection>& detections) {
    FrameVerdict fv = analyze_single_frame(detections);

    window_.push_back(fv);
    if (static_cast<int>(window_.size()) > window_size_)
        window_.pop_front();

    last_result_ = evaluate_window();
    return last_result_;
}

ContaminationResult RknnStainContaminationDetector::current_result() const {
    return last_result_;
}

ContaminationResult
RknnStainContaminationDetector::evaluate_window() const {
    if (window_.empty())
        return {0, "CLEAN", "洁净"};

    int l2_count = 0, l1_count = 0;
    int max_consecutive_l2 = 0, cur_consecutive_l2 = 0;
    int max_consecutive_contaminated = 0, cur_consecutive_contaminated = 0;

    for (const auto& fv : window_) {
        if (fv.frame_level == 2) {
            l2_count++;
            cur_consecutive_l2++;
            max_consecutive_l2 = std::max(max_consecutive_l2, cur_consecutive_l2);
        } else {
            cur_consecutive_l2 = 0;
        }

        if (fv.frame_level == 1) {
            l1_count++;
        }

        if (fv.frame_level >= 1) {
            cur_consecutive_contaminated++;
            max_consecutive_contaminated = std::max(max_consecutive_contaminated,
                                                     cur_consecutive_contaminated);
        } else {
            cur_consecutive_contaminated = 0;
        }
    }

    if (l2_count >= level2_min_frames_)
        return {2, "HEAVY", "立即更换 (mask 内检出)"};

    if (max_consecutive_l2 >= consecutive_frames_thresh_)
        return {2, "HEAVY", "立即更换 (连续 mask 内检出)"};

    if (l1_count >= level1_min_frames_)
        return {1, "SLIGHT", "建议擦拭 (mask 外检出)"};

    if (max_consecutive_contaminated >= consecutive_frames_thresh_)
        return {1, "SLIGHT", "建议擦拭 (连续检出)"};

    return {0, "CLEAN", "洁净"};
}
