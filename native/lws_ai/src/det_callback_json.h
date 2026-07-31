#pragma once

#include "detection.h"
#include "json_escape.h"
#include "rknn_stain_detect_pp.h"

void cap_detections(std::vector<Detection>& detections, int max_det);

void append_det_boxes_json(std::ostringstream& os,
                           const std::vector<Detection>& detections,
                           int max_det,
                           std::size_t total_before_cap);

/// English human-readable fields for JSON consumed by App {@code LensGuardInferenceResult}.
ContaminationResult contamination_result_for_json(const ContaminationResult& result);

std::string build_preview_det_json(const ContaminationResult& result,
                                   const std::vector<Detection>& detections,
                                   int max_det,
                                   std::size_t total_before_cap,
                                   int image_width,
                                   int image_height);

std::string build_offline_infer_json(int code,
                                     const std::string& message,
                                     const ContaminationResult* result,
                                     const std::vector<Detection>* detections,
                                     int max_det,
                                     std::size_t total_before_cap,
                                     int image_width,
                                     int image_height,
                                     const char* source = "offline_infer");
