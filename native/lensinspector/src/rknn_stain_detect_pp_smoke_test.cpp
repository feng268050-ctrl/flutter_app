#include "rknn_stain_detect_pp.h"
#include <cmath>
#include <iostream>
#include <stdexcept>

static void require_eq(int got, int expected, const char* msg) {
    if (got != expected) throw std::runtime_error(msg);
}

static Detection box(float cx, float cy, float half = 20.0f) {
    return {cx - half, cy - half, cx + half, cy + half, 0.9f, 0};
}

int main() {
    RknnStainContaminationDetector::Config cfg;
    cfg.img_w = 1920;
    cfg.img_h = 1080;
    cfg.optical_center_x = 960;
    cfg.optical_center_y = 540;
    cfg.mask_center_x = 885;
    cfg.mask_center_y = 430;
    cfg.mask_radius_px = 280;

    RknnStainContaminationDetector::WindowConfig wc;
    wc.level2_min_frames = 1;
    wc.level1_min_frames = 1;
    wc.window_time_ms = 200;

    RknnStainContaminationDetector det(cfg, wc);

    require_eq(det.analyze_single_frame({}).frame_level, 0, "empty detections should be CLEAN");

    require_eq(det.analyze_single_frame({box(885, 430)}).frame_level, 2,
               "fixed mask center box inside mask should be L2");

    require_eq(det.analyze_single_frame({box(100, 100)}).frame_level, 1,
               "corner box outside mask should be L1");

    require_eq(det.analyze_single_frame({box(100, 100, 400)}).frame_level, 1,
               "large box outside mask must not auto-L2 from area");

    auto mixed = det.analyze_single_frame({box(100, 100), box(885, 430)});
    require_eq(mixed.frame_level, 2, "inside box should dominate mixed frame");

    det.reset();
    auto heavy = det.update({box(885, 430)});
    require_eq(heavy.level, 2, "single inside frame should aggregate to HEAVY");

    det.reset();
    auto slight = det.update({box(50, 50)});
    require_eq(slight.level, 1, "single outside frame should aggregate to SLIGHT");

    RknnStainContaminationDetector::WindowConfig wc2;
    wc2.level2_min_frames = 2;
    wc2.level1_min_frames = 2;
    wc2.window_time_ms = 200;
    RknnStainContaminationDetector window_det(cfg, wc2);
    window_det.reset();
    require_eq(window_det.update({box(885, 430)}).level, 0,
               "one inside frame should not reach HEAVY with level2_min_frames=2");
    require_eq(window_det.update({box(885, 430)}).level, 2,
               "two inside frames in window should reach HEAVY");

    window_det.reset();
    require_eq(window_det.update({box(50, 50)}).level, 0,
               "one outside frame should not reach SLIGHT with level1_min_frames=2");
    require_eq(window_det.update({box(50, 50)}).level, 1,
               "two outside-only frames should reach SLIGHT");

    std::cout << "rknn_stain_detect_pp_smoke_test passed\n";
    return 0;
}
