#pragma once

#include "detection.h"

#include <cstddef>
#include <string>
#include <vector>

/// One-shot stain inference result for App JNI (no JSON round-trip on the hot path).
struct StainInferOutcome {
    int code = -1;
    std::string error_message;

    std::string source;
    int level = 0;
    std::string status;
    std::string detail_message;
    int image_width = 0;
    int image_height = 0;
    std::vector<Detection> boxes;
    std::size_t boxes_total = 0;
    int boxes_cap = 0;
    bool boxes_truncated = false;

    static StainInferOutcome error(int code, std::string message);
};

std::string stain_infer_outcome_to_json(const StainInferOutcome& outcome);
