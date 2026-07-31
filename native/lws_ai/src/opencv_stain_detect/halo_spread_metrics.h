#pragma once

#include "fixed_roi_pipeline.h"

#include <opencv2/core.hpp>

namespace opencv_stain_detect {

struct HaloSpreadParams {
    /// Saturated core: V >= core_v_min.
    int core_v_min = 250;
    /// Halo ring: halo_v_min <= V < halo_v_max.
    int halo_v_min = 180;
    int halo_v_max = 250;
    /// Expand lens_det target bbox by this margin for halo analysis window.
    int analysis_margin_px = 40;
    /// Reject target when fwhm_halo_w / window_w exceeds this (0=off).
    double reject_fwhm_halo_w_frac_max = 0.0;
    /// Reject target when halo_score exceeds this (0=off).
    double reject_halo_score_max = 0.0;
};

struct HaloSpreadMetrics {
    int window_x = 0;
    int window_y = 0;
    int window_w = 0;
    int window_h = 0;
    double peak_v = 0.0;
    double fwhm_w_px = 0.0;
    double fwhm_h_px = 0.0;
    double fwhm_w_halo_px = 0.0;
    double fwhm_h_halo_px = 0.0;
    double area_frac_v200 = 0.0;
    double core_area_frac = 0.0;
    double halo_area_frac = 0.0;
    double halo_to_core_ratio = 0.0;
    double radial_r50_px = 0.0;
    double halo_score = 0.0;
};

/// Measure halo spread in ROI-local coords around a lens_det RegionBlob target.
HaloSpreadMetrics computeHaloSpreadMetrics(const cv::Mat& roi_bgr,
                                           const RegionBlob& target,
                                           const HaloSpreadParams& params);

bool passesHaloSpreadGate(const HaloSpreadMetrics& metrics,
                          const HaloSpreadParams& params);

void drawHaloAnalysisWindow(cv::Mat& roi_bgr, const HaloSpreadMetrics& metrics);

}  // namespace opencv_stain_detect
