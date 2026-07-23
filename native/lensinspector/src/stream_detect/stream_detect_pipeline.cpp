#include "json_escape.h"
#include "stream_detect_constants.h"
#include "stream_detect_pipeline.h"
#include "detect_runner.h"
#include "stream_detect_event.h"

#ifdef __ANDROID__
#include <android/log.h>
#define SD_LOGI(...) __android_log_print(ANDROID_LOG_INFO, "StreamDetect", __VA_ARGS__)
#define SD_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "StreamDetect", __VA_ARGS__)
#else
#include <cstdio>
#define SD_LOGI(...) std::fprintf(stderr, __VA_ARGS__)
#define SD_LOGE(...) std::fprintf(stderr, __VA_ARGS__)
#endif

#include <chrono>
#include <sstream>
#include <vector>
#include <algorithm>

namespace stream_detect {

namespace {

int64_t nowEpochMs() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
               std::chrono::system_clock::now().time_since_epoch())
        .count();
}

}  // namespace

StreamDetectPipeline::StreamDetectPipeline() = default;

StreamDetectPipeline::~StreamDetectPipeline() {
    stop();
}

bool StreamDetectPipeline::start(const std::string& rtspUrl, const SessionConfig& sessionConfig) {
    if (running_.load()) {
        updateConfig(sessionConfig);
        return true;
    }
    if (rtspUrl.empty()) {
        return false;
    }
    if (!demux_.open(rtspUrl)) {
        SD_LOGE("pipeline start failed url=%s", rtspUrl.c_str());
        publishPipelineState("error", "rtsp_open_failed");
        return false;
    }
    {
        std::lock_guard<std::mutex> lock(config_mu_);
        rtsp_url_ = rtspUrl;
        config_ = sessionConfig;
    }
    stop_requested_.store(false);
    running_.store(true);
    frame_id_.store(0);
    scheduler_.reset();
    publishSessionStart();
    worker_ = std::make_unique<std::thread>(&StreamDetectPipeline::workerLoop, this);
    SD_LOGI("pipeline started url=%s", rtspUrl.c_str());
    return true;
}

void StreamDetectPipeline::stop() {
    if (!running_.load()) {
        return;
    }
    stop_requested_.store(true);
    if (worker_ && worker_->joinable()) {
        worker_->join();
    }
    worker_.reset();
    demux_.close();
    scheduler_.reset();
    publishSessionStop("release");
    running_.store(false);
    SD_LOGI("pipeline stopped");
}

void StreamDetectPipeline::setLaserOn(bool on) {
    laser_on_.store(on);
    if (!on) {
        scheduler_.reset();
        scheduler_.setBurstMode(false);
    }
}

void StreamDetectPipeline::setBurstMode(bool burst) {
    scheduler_.setBurstMode(burst);
}

void StreamDetectPipeline::updateConfig(const SessionConfig& sessionConfig) {
    std::lock_guard<std::mutex> lock(config_mu_);
    config_ = sessionConfig;
}

void StreamDetectPipeline::setZeroPointTargetMode(int mode) {
    std::lock_guard<std::mutex> lock(config_mu_);
    config_.zero_point_target_mode = mode;
}

std::string StreamDetectPipeline::rtspUrl() const {
    std::lock_guard<std::mutex> lock(config_mu_);
    return rtsp_url_;
}

SessionConfig StreamDetectPipeline::copyConfig() const {
    std::lock_guard<std::mutex> lock(config_mu_);
    return config_;
}

void StreamDetectPipeline::workerLoop() {
    cv::Mat bgr;
    int consecutiveReadFailures = 0;
    int reconnectBackoffMs = kReconnectBackoffInitialMs;
    while (!stop_requested_.load()) {
        const auto decodeStart = std::chrono::steady_clock::now();
        if (!demux_.readBgrFrame(bgr)) {
            ++consecutiveReadFailures;
            if (consecutiveReadFailures >= 30 && !rtspUrl().empty()) {
                if (tryReconnectDemux()) {
                    consecutiveReadFailures = 0;
                    reconnectBackoffMs = kReconnectBackoffInitialMs;
                } else {
                    reconnectBackoffMs = std::min(reconnectBackoffMs * 2, kReconnectBackoffMaxMs);
                    std::this_thread::sleep_for(std::chrono::milliseconds(reconnectBackoffMs));
                }
            } else {
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
            continue;
        }
        consecutiveReadFailures = 0;
        reconnectBackoffMs = kReconnectBackoffInitialMs;
        const auto decodeEnd = std::chrono::steady_clock::now();
        const int64_t decodeMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                                     decodeEnd - decodeStart)
                                     .count();
        onBgrFrame(bgr, decodeMs);
    }
}

void StreamDetectPipeline::onBgrFrame(const cv::Mat& bgr, int64_t decodeMs) {
    if (!laser_on_.load() || bgr.empty()) {
        return;
    }
    const int64_t nowMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                              std::chrono::steady_clock::now().time_since_epoch())
                              .count();
    if (!scheduler_.tryAccept(nowMs)) {
        return;
    }
    const int64_t fid = frame_id_.fetch_add(1) + 1;
    frames_sampled_.fetch_add(1);

    // Snapshot config so cmd-thread updateConfig cannot tear handles mid-detect.
    const SessionConfig frameConfig = copyConfig();
    const auto detectStart = std::chrono::steady_clock::now();
    const std::vector<DetectOutcome> outcomes = runEnabledDetectModules(bgr, frameConfig, fid);
    const int64_t detectMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                                 std::chrono::steady_clock::now() - detectStart)
                                 .count();
    const int64_t ts = nowEpochMs();
    DetectOutcome primaryLensDet;
    bool hasLensDet = false;
    publishCombinedFrame(outcomes, bgr.cols, bgr.rows, ts, fid);
    for (const DetectOutcome& outcome : outcomes) {
        if (outcome.module == "lens_det") {
            primaryLensDet = outcome;
            hasLensDet = true;
        }
        SD_LOGI("sampled frame_id=%lld module=%s %dx%d code=%d ok=%d decode_ms=%lld detect_ms=%lld e2e_ms=%lld",
                static_cast<long long>(fid),
                outcome.module.c_str(),
                bgr.cols,
                bgr.rows,
                outcome.code,
                outcome.ok ? 1 : 0,
                static_cast<long long>(decodeMs),
                static_cast<long long>(detectMs),
                static_cast<long long>(decodeMs + detectMs));
    }

    if (hasLensDet) {
        if (isFrameRejectedCode(primaryLensDet.code)) {
            scheduler_.setBurstMode(true);
        } else if (primaryLensDet.ok && primaryLensDet.code == 0) {
            scheduler_.setBurstMode(false);
        }
    }
}

void StreamDetectPipeline::publishSessionStart() {
    const SessionConfig cfg = copyConfig();
    std::ostringstream oss;
    oss << "{\"type\":\"session_start\",\"source\":\"" << cfg.session_source << "\","
        << "\"samplingIntervalMs\":500,\"timestampMs\":" << nowEpochMs() << "}";
    publishStreamDetectEvent(oss.str());
}

void StreamDetectPipeline::publishSessionStop(const std::string& reason) {
    std::ostringstream oss;
    oss << "{\"type\":\"session_stop\",\"reason\":\"" << reason << "\",\"timestampMs\":"
        << nowEpochMs() << "}";
    publishStreamDetectEvent(oss.str());
}

void StreamDetectPipeline::publishPipelineState(const std::string& state, const std::string& detail) {
    std::ostringstream oss;
    oss << "{\"type\":\"pipeline_state\",\"state\":\"" << state << "\",\"detail\":\"" << detail
        << "\",\"timestampMs\":" << nowEpochMs() << "}";
    publishStreamDetectEvent(oss.str());
}

void StreamDetectPipeline::publishDetectResult(const DetectOutcome& outcome,
                                               int width,
                                               int height,
                                               int64_t timestamp_ms,
                                               int64_t frame_id) {
    std::ostringstream oss;
    oss << "{\"type\":\"detect_result\",\"module\":\"" << outcome.module << "\","
        << "\"timestampMs\":" << timestamp_ms << ",\"frameId\":" << frame_id << ","
        << "\"imageWidth\":" << width << ",\"imageHeight\":" << height << ",\"code\":"
        << outcome.code << ",\"ok\":" << (outcome.ok ? "true" : "false") << ",\"summaryJson\":\""
        << json_escape(outcome.summary_json) << "\"}";
    publishStreamDetectEvent(oss.str());
}

void StreamDetectPipeline::publishCombinedFrame(const std::vector<DetectOutcome>& outcomes,
                                                int width,
                                                int height,
                                                int64_t timestamp_ms,
                                                int64_t frame_id) {
    if (outcomes.empty()) {
        return;
    }
    std::ostringstream oss;
    oss << "{\"type\":\"combined_frame\",\"timestampMs\":" << timestamp_ms
        << ",\"frame_pts_ms\":" << timestamp_ms << ",\"frameId\":" << frame_id
        << ",\"imageWidth\":" << width << ",\"imageHeight\":" << height << ",\"modules\":{";
    bool first = true;
    for (const DetectOutcome& outcome : outcomes) {
        if (!first) {
            oss << ',';
        }
        first = false;
        oss << "\"" << outcome.module << "\":{"
            << "\"code\":" << outcome.code << ",\"ok\":" << (outcome.ok ? "true" : "false")
            << ",\"summaryJson\":\"" << json_escape(outcome.summary_json) << "\"}";
    }
    oss << "}}";
    publishStreamDetectEvent(oss.str());
}

bool StreamDetectPipeline::tryReconnectDemux() {
    const std::string url = rtspUrl();
    if (url.empty()) {
        return false;
    }
    SD_LOGI("rtsp reconnect attempt url=%s count=%lld",
            url.c_str(),
            static_cast<long long>(reconnect_count_.load() + 1));
    publishPipelineState("reconnecting", "rtsp_read_failed");
    if (!demux_.reopen()) {
        publishPipelineState("error", "rtsp_reopen_failed");
        return false;
    }
    reconnect_count_.fetch_add(1);
    publishPipelineState("running", "rtsp_reconnected");
    return true;
}

}  // namespace stream_detect
