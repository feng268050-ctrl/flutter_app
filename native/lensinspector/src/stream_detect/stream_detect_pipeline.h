#pragma once

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

#include "detect_runner.h"
#include "frame_scheduler.h"
#include "rtsp_demux.h"
#include "stream_detect_config.h"

#include <opencv2/core.hpp>

namespace stream_detect {

class StreamDetectPipeline {
public:
    StreamDetectPipeline();
    ~StreamDetectPipeline();

    bool start(const std::string& rtspUrl, const SessionConfig& sessionConfig);
    void stop();
    bool isRunning() const { return running_.load(); }

    void setLaserOn(bool on);
    void setBurstMode(bool burst);
    void updateConfig(const SessionConfig& sessionConfig);
    void setZeroPointTargetMode(int mode);

    /** Snapshot of last URL used by start(); empty if never started. */
    std::string rtspUrl() const;

    int64_t framesSampled() const { return frames_sampled_.load(); }

private:
    void workerLoop();
    void onBgrFrame(const cv::Mat& bgr, int64_t decodeMs);
    SessionConfig copyConfig() const;
    void publishSessionStart();
    void publishSessionStop(const std::string& reason);
    void publishDetectResult(const DetectOutcome& outcome,
                             int width,
                             int height,
                             int64_t timestamp_ms,
                             int64_t frame_id);
    void publishCombinedFrame(const std::vector<DetectOutcome>& outcomes,
                              int width,
                              int height,
                              int64_t timestamp_ms,
                              int64_t frame_id);
    void publishPipelineState(const std::string& state, const std::string& detail);
    bool tryReconnectDemux();

    std::atomic<bool> running_{false};
    std::atomic<bool> stop_requested_{false};
    std::atomic<bool> laser_on_{false};
    std::atomic<int64_t> frames_sampled_{0};
    std::atomic<int64_t> frame_id_{0};
    std::atomic<int64_t> reconnect_count_{0};

    mutable std::mutex config_mu_;
    std::string rtsp_url_;
    SessionConfig config_;
    std::unique_ptr<std::thread> worker_;
    RtspDemux demux_;
    FrameScheduler scheduler_;
};

}  // namespace stream_detect
