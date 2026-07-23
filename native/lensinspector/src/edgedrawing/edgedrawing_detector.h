#pragma once

#include "edgedrawing_types.h"

#include <opencv2/core.hpp>

#include <string>

namespace edgedrawing {

RoiConfig loadRoiConfig(const std::string& roi_json_path, int frame_width, int frame_height);

/** Full-frame ROI with reference at image center (no box_xywh clipping). */
RoiConfig makeFullFrameRoiConfig(int frame_width, int frame_height);

/** Centered square ROI; reference at box center. */
RoiConfig makeCenteredSquareRoiConfig(int frame_width, int frame_height, int side_px);

/** 640×640 upper-center ROI (1920×1080 reference: x=640, y=54). */
RoiConfig makePlasmaRoiConfig(int frame_width, int frame_height);

FrameResult detectEdgeDrawingFrame(const cv::Mat& bgr,
                                   const RoiConfig& roi,
                                   double tolerance_px,
                                   const std::string& dump_stages_dir = "");

}  // namespace edgedrawing
