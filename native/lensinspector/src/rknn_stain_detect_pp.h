#pragma once
#include "detection.h"
#include "config.h"
#include <string>
#include <vector>
#include <deque>

struct ContaminationResult {
    int         level;
    std::string status;
    std::string message;
};

struct FrameVerdict {
    int frame_level;
};

class RknnStainContaminationDetector {
public:
    struct Config {
        int img_w = 640;
        int img_h = 640;
        int optical_center_x = 320;
        int optical_center_y = 320;
        int mask_center_x = 0;
        int mask_center_y = 0;
        int mask_radius_px = 280;
    };

    struct WindowConfig {
        int window_time_ms            = 200;
        int fps                       = 30;
        int level2_min_frames         = 2;
        int level1_min_frames         = 2;
        int consecutive_frames_thresh = 2;
    };

    explicit RknnStainContaminationDetector(const Config& cfg);
    RknnStainContaminationDetector(const Config& cfg, const WindowConfig& wcfg);

    FrameVerdict        analyze_single_frame(const std::vector<Detection>& detections) const;
    ContaminationResult update(const std::vector<Detection>& detections);
    ContaminationResult current_result() const;
    void                reset();

private:
    ContaminationResult evaluate_window() const;

    Config  cfg_;
    int     mask_center_x_;
    int     mask_center_y_;
    int64_t mask_radius_sq_;

    int window_size_;
    int level2_min_frames_;
    int level1_min_frames_;
    int consecutive_frames_thresh_;

    std::deque<FrameVerdict> window_;
    ContaminationResult      last_result_{0, "CLEAN", "洁净"};
};
