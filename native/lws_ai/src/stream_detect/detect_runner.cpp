#include "detect_runner.h"

#if defined(ENABLE_EDGEDRAWING) && ENABLE_EDGEDRAWING
#include "edgedrawing_context.h"
#include "edgedrawing_json.h"
#endif
#include "opencv_detect_codes.h"
#include "opencv_stain_detect_session.h"
#include "opencv_stain_detect/opencv_stain_detect_analyzer.h"
#include "zero_point_context.h"
#include "zero_point_json.h"
#include "zero_point_types.h"

#include <mutex>
#include <string>

namespace stream_detect {
namespace {

std::mutex g_rknn_hook_mu;
RknnStreamInferFn g_rknn_stream_infer = nullptr;

std::string rknn_disabled_json(const char* reason) {
    return std::string("{\"ok\":false,\"code\":") +
           std::to_string(opencv_detect::kInvalidHandle) +
           ",\"message\":\"" + reason + "\"}";
}

}  // namespace

void setRknnStreamInferHook(RknnStreamInferFn fn) {
    std::lock_guard<std::mutex> lock(g_rknn_hook_mu);
    g_rknn_stream_infer = fn;
}

bool isFrameRejectedCode(int code) {
    return code == opencv_detect::kFrameRejected;
}

DetectOutcome runLensDetIfEnabled(const cv::Mat& bgr,
                                  const SessionConfig& sessionConfig,
                                  int64_t frame_id) {
    DetectOutcome out;
    out.module = "lens_det";
    if (!sessionConfig.lens_det_enabled || sessionConfig.opencv_stain_session_handle == 0) {
        out.ok = false;
        out.code = opencv_detect::kInvalidHandle;
        out.summary_json = opencv_stain_detect::summaryToJson(opencv_stain_detect::errorResult(
            opencv_detect::kInvalidHandle, opencv_detect::kReasonInvalidSessionHandle));
        return out;
    }
    auto* session = reinterpret_cast<opencv_stain_detect::Session*>(sessionConfig.opencv_stain_session_handle);
    const std::string frame_output_dir =
            sessionConfig.output_dir + "/frame_" + std::to_string(frame_id);
    opencv_stain_detect::Result native_result =
        opencv_stain_detect::analyzeOpencvStainDetectBgr(
            bgr, session->options(), frame_output_dir, &session->islandSlotSession());
    out.summary_json = opencv_stain_detect::summaryToJson(native_result);
    out.ok = native_result.ok;
    out.code = native_result.code;
    return out;
}

DetectOutcome runZeroPointIfEnabled(const cv::Mat& bgr,
                                    const SessionConfig& sessionConfig,
                                    int64_t /*frame_id*/) {
    DetectOutcome out;
    out.module = "zero_point";
    if (!sessionConfig.zero_point_enabled || sessionConfig.zero_point_handle == 0) {
        out.ok = false;
        out.code = opencv_detect::kInvalidHandle;
        out.summary_json = zero_point::errorJson(opencv_detect::kInvalidHandle,
                                                 opencv_detect::kReasonInvalidSessionHandle);
        return out;
    }
    auto* ctx = reinterpret_cast<zero_point::Context*>(sessionConfig.zero_point_handle);
    ctx->setDetectTargetMode(sessionConfig.zero_point_target_mode == 1
                                 ? zero_point::DetectTargetMode::Line
                                 : zero_point::DetectTargetMode::Point);
    const zero_point::FrameResult result = ctx->detectBgr(bgr);
    out.summary_json = zero_point::frameResultToJson(result, ctx->roi().reference_zero_xy);
    out.ok = result.ok;
    out.code = result.code;
    return out;
}

#if defined(ENABLE_EDGEDRAWING) && ENABLE_EDGEDRAWING
DetectOutcome runEdgeDrawingIfEnabled(const cv::Mat& bgr,
                                      const SessionConfig& sessionConfig,
                                      int64_t /*frame_id*/) {
    DetectOutcome out;
    out.module = "edgedrawing";
    if (!sessionConfig.edgedrawing_enabled || sessionConfig.edgedrawing_handle == 0) {
        out.ok = false;
        out.code = opencv_detect::kInvalidHandle;
        out.summary_json = edgedrawing::errorJson(opencv_detect::kInvalidHandle,
                                                  opencv_detect::kReasonInvalidSessionHandle);
        return out;
    }
    auto* ctx = reinterpret_cast<edgedrawing::Context*>(sessionConfig.edgedrawing_handle);
    const edgedrawing::FrameResult result = ctx->detectBgr(bgr);
    out.summary_json = edgedrawing::frameResultToJson(result);
    out.ok = result.ok;
    out.code = result.code;
    return out;
}
#endif

DetectOutcome runRknnStainIfEnabled(const cv::Mat& bgr,
                                    const SessionConfig& sessionConfig,
                                    int64_t /*frame_id*/) {
    DetectOutcome out;
    out.module = "rknn_stain";
    if (!sessionConfig.rknn_stream_enabled || sessionConfig.rknn_session_handle == 0) {
        out.ok = false;
        out.code = opencv_detect::kInvalidHandle;
        out.summary_json = rknn_disabled_json("rknn stream disabled");
        return out;
    }
    RknnStreamInferFn fn = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_rknn_hook_mu);
        fn = g_rknn_stream_infer;
    }
    if (!fn) {
        out.ok = false;
        out.code = opencv_detect::kInvalidHandle;
        out.summary_json = rknn_disabled_json("rknn stream hook not registered");
        return out;
    }
    fn(bgr, sessionConfig.rknn_session_handle, "live_infer",
       &out.summary_json, &out.code, &out.ok);
    return out;
}

std::vector<DetectOutcome> runEnabledDetectModules(const cv::Mat& bgr,
                                                   const SessionConfig& sessionConfig,
                                                   int64_t frame_id) {
    std::vector<DetectOutcome> outcomes;
    if (sessionConfig.lens_det_enabled) {
        outcomes.push_back(runLensDetIfEnabled(bgr, sessionConfig, frame_id));
    }
    if (sessionConfig.zero_point_enabled) {
        outcomes.push_back(runZeroPointIfEnabled(bgr, sessionConfig, frame_id));
    }
#if defined(ENABLE_RKNN_STAIN_STREAM) && ENABLE_RKNN_STAIN_STREAM
    if (sessionConfig.rknn_stream_enabled) {
        outcomes.push_back(runRknnStainIfEnabled(bgr, sessionConfig, frame_id));
    }
#endif
#if defined(ENABLE_EDGEDRAWING) && ENABLE_EDGEDRAWING
    if (sessionConfig.edgedrawing_enabled) {
        outcomes.push_back(runEdgeDrawingIfEnabled(bgr, sessionConfig, frame_id));
    }
#endif
    return outcomes;
}

}  // namespace stream_detect
