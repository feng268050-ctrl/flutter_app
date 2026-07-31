#pragma once

#include "stream_detect_config.h"

#include <opencv2/core.hpp>
#include <cstdint>
#include <string>
#include <vector>

namespace stream_detect {

struct DetectOutcome {
    std::string module;
    std::string summary_json;
    int code = 0;
    bool ok = false;
};

/**
 * Optional RKNN live infer hook (registered by libai JNI; null in daemon).
 * Returns JSON summary; sets *out_code / *out_ok.
 */
using RknnStreamInferFn = void (*)(const cv::Mat& bgr,
                                   int64_t rknn_session_handle,
                                   const char* source,
                                   std::string* out_summary_json,
                                   int* out_code,
                                   bool* out_ok);

void setRknnStreamInferHook(RknnStreamInferFn fn);

/** Run enabled detect modules on BGR frame; returns all module outcomes in order. */
std::vector<DetectOutcome> runEnabledDetectModules(const cv::Mat& bgr,
                                                   const SessionConfig& sessionConfig,
                                                   int64_t frame_id);

DetectOutcome runLensDetIfEnabled(const cv::Mat& bgr,
                                  const SessionConfig& sessionConfig,
                                  int64_t frame_id);

DetectOutcome runZeroPointIfEnabled(const cv::Mat& bgr,
                                    const SessionConfig& sessionConfig,
                                    int64_t frame_id);

DetectOutcome runEdgeDrawingIfEnabled(const cv::Mat& bgr,
                                      const SessionConfig& sessionConfig,
                                      int64_t frame_id);

DetectOutcome runRknnStainIfEnabled(const cv::Mat& bgr,
                                    const SessionConfig& sessionConfig,
                                    int64_t frame_id);

bool isFrameRejectedCode(int code);

}  // namespace stream_detect
