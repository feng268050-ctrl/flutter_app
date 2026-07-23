#pragma once

#include "daemon/daemon_ipc.h"
#include "stream_detect/stream_detect_config.h"
#include "stream_detect/stream_detect_pipeline.h"
#include "opencv_stain_detect_session.h"
#include "zero_point_context.h"
#include "central_scheduler.h"
#include "config.h"

#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

namespace lws::daemon {

/**
 * Owns OpenCV / zero-point / RKNN sessions and StreamDetectPipeline inside the daemon process.
 * Bit0 (state_.laser_on) gates sampling; assist flags update module enables.
 */
class StreamDetectController {
public:
    explicit StreamDetectController(DaemonState& state);
    ~StreamDetectController();

    StreamDetectController(const StreamDetectController&) = delete;
    StreamDetectController& operator=(const StreamDetectController&) = delete;

    /** Wire pipeline events into DaemonIpc evt queue. */
    void attach_event_sink(DaemonIpc& ipc);

    std::string handle_configure(const std::string& json_line, const std::string& id);
    std::string handle_start(const std::string& json_line, const std::string& id);
    std::string handle_stop(const std::string& id);
    std::string handle_burst_mode(const std::string& json_line, const std::string& id);
    std::string handle_zp_target_mode(const std::string& json_line, const std::string& id);
    std::string handle_offline_opencv_stain_nv12(const std::string& json_line, const std::string& id);
    std::string handle_offline_opencv_stain_jpg(const std::string& json_line, const std::string& id);
    std::string handle_offline_zero_point_nv12(const std::string& json_line, const std::string& id);
    void on_laser_or_assist_changed();

    void shutdown();

private:
    bool ensure_sessions_locked(std::string& err);
    void ensure_rknn_hook_locked();
    void apply_gates_locked();
    stream_detect::SessionConfig build_config_locked() const;
    static bool read_nv12_file(const std::string& path, int width, int height, std::vector<uint8_t>& out,
                               std::string& err);

    DaemonState& state_;
    std::mutex mu_;
    stream_detect::SessionConfig base_config_;
    std::string project_root_;
    std::string config_yaml_;
    std::string roi_json_;
    double zp_tolerance_px_{10.0};
    std::unique_ptr<opencv_stain_detect::Session> opencv_session_;
    std::unique_ptr<zero_point::Context> zp_context_;
    std::optional<AppConfig> rknn_app_config_;
    std::unique_ptr<CentralScheduler> rknn_scheduler_;
    std::unique_ptr<stream_detect::StreamDetectPipeline> pipeline_;
    std::string last_rtsp_url_;
    bool configured_{false};
    bool rknn_hook_registered_{false};

    /** Stop worker before destroying session objects held as int64_t in SessionConfig. */
    void stop_pipeline_for_session_rebind_locked();
    /** Restart pipeline after session rebind when it was running. */
    bool restart_pipeline_after_rebind_locked(std::string& err);
};

}  // namespace lws::daemon
