#include "stain_infer_outcome.h"

#include "det_callback_json.h"

StainInferOutcome StainInferOutcome::error(int code, std::string message) {
    StainInferOutcome out;
    out.code = code;
    out.error_message = std::move(message);
    return out;
}

std::string stain_infer_outcome_to_json(const StainInferOutcome& outcome) {
    if (outcome.code != 0) {
        return build_offline_infer_json(outcome.code,
                                        outcome.error_message,
                                        nullptr,
                                        nullptr,
                                        0,
                                        0,
                                        0,
                                        0,
                                        outcome.source.empty() ? "offline_infer" : outcome.source.c_str());
    }
    ContaminationResult cr;
    cr.level = outcome.level;
    cr.status = outcome.status;
    cr.message = outcome.detail_message;
    const std::vector<Detection> boxes = outcome.boxes;
    return build_offline_infer_json(0,
                                    "",
                                    &cr,
                                    &boxes,
                                    outcome.boxes_cap,
                                    outcome.boxes_total,
                                    outcome.image_width,
                                    outcome.image_height,
                                    outcome.source.c_str());
}
