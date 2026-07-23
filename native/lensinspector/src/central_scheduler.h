#pragma once
#include "config.h"
#include "frame_ring_buffer.h"
#include "stain_worker_pool.h"
#include "model_manager.h"
#include "rknn_stain_detect_pp.h"
#include "stain_infer_outcome.h"
#include "fscompat.h"

#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/videoio.hpp>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <ctime>
#include <functional>
#include <mutex>
#include <queue>
#include <string>
#include <thread>
#include <vector>

// ─── Logging (routes to logcat on Android) ─────────────────────────

#ifdef __ANDROID__
#include <android/log.h>
#define LG_TAG "LensGuard"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN,  LG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LG_TAG, __VA_ARGS__)
#else
#define LOGI(...) std::printf(__VA_ARGS__)
#define LOGW(...) std::printf(__VA_ARGS__)
#define LOGE(...) std::fprintf(stderr, __VA_ARGS__)
#endif

// ─── Scheduler callback interface ──────────────────────────────────

struct SchedulerCallbacks {
    std::function<void(int state)>                                          on_state_changed;
    std::function<void(int level, const std::string&, const std::string&)>  on_check_result;
};

// ─── System state enum ─────────────────────────────────────────────

enum class SystemState { IDLE = 0, MONITORING = 1, LOCKED = 2 };

// ─── Check result (passed through the internal queue) ──────────────

struct CheckResult {
    ContaminationResult cr;
    cv::Mat             debug_frame;
    std::vector<Detection> detections;
    bool                preview = false;
    std::string         reason;
};

// ─── CentralScheduler ─────────────────────────────────────────────

class CentralScheduler {
public:
    explicit CentralScheduler(const AppConfig& cfg);
    void run();
    void stop();

    int  getState()      const { return static_cast<int>(state_); }
    int  getStainLevel() const { return last_stain_level_; }
    bool isLensDirty()   const { return flag_lens_dirty_; }
    std::string getLastClsResultJson() const;

    void setLaserOn(bool on) { laser_on_.store(on); }
    void setAiVisionPreviewClassificationEnabled(bool /*enabled*/) {}
    void setAiVisionPreviewDetectionEnabled(bool enabled) {
        ai_vision_preview_det_enabled_.store(enabled);
    }
    void pushFrame(const uint8_t* data, int len, int w, int h);
    void setDeviceContext(const std::string& sn, const std::string& station_id);
    void pushCameraParams(float exposure_time, float gain, float light_level, float fps);
    void pushFrameMeta(int64_t timestamp_ms, int64_t frame_id);
    void notifyModelSwitched(const std::string& model_version);
    int inferImageAndSave(const std::string& image_path, const std::string& output_path);
    /// Offline video: read input_path frame-by-frame, stain det + draw boxes, write output_path (e.g. .mp4).
    /// Return 0 on success; -1 params; -2 open/read input; -3 infer error; -4 writer failed; -5 no frames.
    int inferVideoAndSave(const std::string& input_path, const std::string& output_path);
    std::string inferImageToJson(const std::string& image_path);
    std::string inferImageToJsonFromBgr(const cv::Mat& bgr_image, const char* source = "offline_infer");

    StainInferOutcome inferImageFromBgr(const cv::Mat& bgr_image, const char* source = "offline_infer");
    StainInferOutcome inferImageFromPath(const std::string& image_path);
    StainInferOutcome inferNv12Frame(const uint8_t* data, int len, int w, int h);

    void setCallbacks(SchedulerCallbacks cb) {
        std::lock_guard<std::mutex> lk(cb_lock_);
        callbacks_ = std::move(cb);
    }

    std::atomic<bool> running{true};

private:
    void print_versions();
    void self_test();
    void trigger_check(const char* reason, bool preview = false);
    void worker_stain(cv::Mat frame, bool preview, std::string reason);
    void drain_check_queue();
    void handle_result(const CheckResult& res);
    void handle_preview_result(const CheckResult& res);
    void popup_lens_warning(int level);
    void save_debug_image(const cv::Mat& frame, const std::string& status);
    void cleanup_debug_images();

    void notify_state(int s);
    void notify_result(int lvl, const std::string& status, const std::string& msg);
    bool waitFrame(cv::Mat& out, int timeout_ms);
    void initFrameParams(int w, int h);

    const AppConfig& cfg_;

    ModelManager                      models_;
    RknnStainContaminationDetector         stain_logic_;

    SystemState state_            = SystemState::IDLE;
    bool        flag_lens_dirty_  = false;
    int         last_stain_level_ = 0;

    std::atomic<bool> laser_on_{false};
    bool              prev_laser_on_ = false;
    std::atomic<bool> ai_vision_preview_det_enabled_{false};

    std::mutex              frame_mtx_;
    std::condition_variable frame_cv_;
    cv::Mat                 frame_buf_;
    bool                    frame_ready_ = false;
#if defined(LWS_FRAME_RING_BUFFER) && LWS_FRAME_RING_BUFFER
    FrameRingBuffer         frame_ring_;
#endif
    int                     frame_w_ = 0;
    int                     frame_h_ = 0;
    bool                    frame_params_inited_ = false;
    int                     frame_logic_w_     = 0;
    int                     frame_logic_h_     = 0;

    StainWorkerPool         stain_worker_;
    std::atomic<bool> checking_{false};
    std::mutex frame_lock_;
    cv::Mat    latest_frame_;

    std::mutex              queue_lock_;
    std::queue<CheckResult> check_queue_;

    double last_check_mono_  = 0.0;
    double last_preview_check_mono_ = 0.0;
    double locked_mono_      = 0.0;
    bool   lens_warned_      = false;
    int    last_popup_level_ = 0;
    int    debug_save_count_ = 0;

    double last_clean_check_time_ = 0.0;
    std::atomic<bool> stain_interrupt_flag_{false};

    std::mutex         cb_lock_;
    SchedulerCallbacks callbacks_;
};
