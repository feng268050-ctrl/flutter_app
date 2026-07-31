#include "daemon/daemon_stream_controller.h"
#include "daemon/json_util.h"
#include "stream_detect/stream_detect_event.h"
#include "stream_detect/yuv_convert.h"
#include "stream_detect/detect_runner.h"
#include "opencv_stain_detect/opencv_stain_detect_analyzer.h"
#include "stain_infer_outcome.h"
#include "zero_point_json.h"
#include "zero_point_types.h"

#include <android/log.h>
#include <opencv2/imgcodecs.hpp>

#include <fstream>
#include <sstream>
#include <utility>
#include <vector>

#define LOG_TAG "AiDaemon"
#define ALOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define ALOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define ALOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)

namespace lws::daemon {
namespace {

void daemon_rknn_stream_infer(const cv::Mat& bgr,
                              int64_t rknn_session_handle,
                              const char* source,
                              std::string* out_summary_json,
                              int* out_code,
                              bool* out_ok) {
    auto* scheduler = reinterpret_cast<CentralScheduler*>(rknn_session_handle);
    if (!scheduler) {
        *out_ok = false;
        *out_code = -1;
        *out_summary_json = stain_infer_outcome_to_json(
                StainInferOutcome::error(-1, "invalid rknn session handle"));
        return;
    }
    const StainInferOutcome result =
            scheduler->inferImageFromBgr(bgr, source != nullptr ? source : "live_infer");
    *out_summary_json = stain_infer_outcome_to_json(result);
    *out_ok = result.code == 0;
    *out_code = result.code;
}

std::string make_ack(std::string_view type, std::string_view id, bool ok,
                     std::string_view code = {}, std::string_view message = {},
                     std::string_view summary_json = {}) {
    std::ostringstream oss;
    oss << "{\"v\":1,\"type\":\"" << type << "\",\"id\":\"" << json_escape(id)
        << "\",\"ts_ms\":" << now_ms() << ",\"ok\":" << (ok ? "true" : "false");
    if (!code.empty()) {
        oss << ",\"code\":\"" << json_escape(code) << "\"";
    }
    if (!message.empty()) {
        oss << ",\"message\":\"" << json_escape(message) << "\"";
    }
    if (!summary_json.empty()) {
        oss << ",\"summary_json\":\"" << json_escape(summary_json) << "\"";
    }
    oss << "}\n";
    return oss.str();
}

}  // namespace

StreamDetectController::StreamDetectController(DaemonState& state) : state_(state) {
    project_root_ = ".";  // chdir'd to workdir by main
    config_yaml_ = "config.yaml";
    roi_json_ = "zero_point_roi.json";
    base_config_.output_dir = "opencv_stain_detect_out/live";
    base_config_.session_source = "live_stain_detect";
    base_config_.camera_type = 1;
    base_config_.lens_det_enabled = true;
    base_config_.zero_point_enabled = false;
    base_config_.rknn_stream_enabled = false;
}

StreamDetectController::~StreamDetectController() {
    shutdown();
}

void StreamDetectController::attach_event_sink(DaemonIpc& ipc) {
    stream_detect::setStreamDetectEventSink([&ipc](const std::string& json_line) {
        ipc.publish_event(json_line);
    });
}

void StreamDetectController::shutdown() {
    std::lock_guard<std::mutex> lock(mu_);
    if (pipeline_) {
        pipeline_->stop();
        pipeline_.reset();
    }
    opencv_session_.reset();
    zp_context_.reset();
    rknn_scheduler_.reset();
    rknn_app_config_.reset();
    stream_detect::clearStreamDetectEventSink();
}

void StreamDetectController::ensure_rknn_hook_locked() {
    if (rknn_hook_registered_) {
        return;
    }
    stream_detect::setRknnStreamInferHook(&daemon_rknn_stream_infer);
    rknn_hook_registered_ = true;
}

bool StreamDetectController::ensure_sessions_locked(std::string& err) {
    try {
        if (!opencv_session_) {
            opencv_session_ = std::make_unique<opencv_stain_detect::Session>(
                    config_yaml_, project_root_);
            ALOGI("created opencv stain session config=%s root=%s",
                  config_yaml_.c_str(), project_root_.c_str());
        }
        if (!zp_context_) {
            zp_context_ = std::make_unique<zero_point::Context>(roi_json_, zp_tolerance_px_);
            ALOGI("created zero_point context roi=%s", roi_json_.c_str());
        }
        if (base_config_.rknn_stream_enabled && !rknn_scheduler_) {
            try {
                ensure_rknn_hook_locked();
                rknn_app_config_ = load_config(config_yaml_, project_root_);
                rknn_scheduler_ = std::make_unique<CentralScheduler>(*rknn_app_config_);
                ALOGI("created rknn CentralScheduler");
            } catch (const std::exception& ex) {
                ALOGW("rknn session unavailable (OpenCV/ZP continue): %s", ex.what());
                rknn_scheduler_.reset();
                rknn_app_config_.reset();
            }
        } else if (!base_config_.rknn_stream_enabled && rknn_scheduler_) {
            ALOGI("tearing down rknn session (rknn_stream_enabled=false)");
            rknn_scheduler_.reset();
            rknn_app_config_.reset();
        }
        return true;
    } catch (const std::exception& ex) {
        err = ex.what();
        ALOGE("ensure_sessions failed: %s", ex.what());
        return false;
    }
}

stream_detect::SessionConfig StreamDetectController::build_config_locked() const {
    stream_detect::SessionConfig cfg = base_config_;
    cfg.lens_det_enabled =
            base_config_.lens_det_enabled && state_.lens_contamination_enabled.load();
    cfg.zero_point_enabled =
            base_config_.zero_point_enabled && state_.zero_point_offset_enabled.load();
    cfg.opencv_stain_session_handle =
            opencv_session_ ? reinterpret_cast<int64_t>(opencv_session_.get()) : 0;
    cfg.zero_point_handle =
            zp_context_ ? reinterpret_cast<int64_t>(zp_context_.get()) : 0;
    if (rknn_scheduler_) {
        cfg.rknn_session_handle = reinterpret_cast<int64_t>(rknn_scheduler_.get());
        cfg.rknn_stream_enabled = base_config_.rknn_stream_enabled;
    } else {
        cfg.rknn_session_handle = 0;
        cfg.rknn_stream_enabled = false;
    }
    cfg.edgedrawing_handle = 0;
    cfg.edgedrawing_enabled = false;
    return cfg;
}

void StreamDetectController::apply_gates_locked() {
    if (!pipeline_) {
        return;
    }
    pipeline_->setLaserOn(state_.laser_on.load());
    if (configured_) {
        pipeline_->updateConfig(build_config_locked());
    }
}

void StreamDetectController::stop_pipeline_for_session_rebind_locked() {
    if (!pipeline_ || !pipeline_->isRunning()) {
        return;
    }
    if (last_rtsp_url_.empty()) {
        last_rtsp_url_ = pipeline_->rtspUrl();
    }
    ALOGI("stopping pipeline before session rebind url=%s", last_rtsp_url_.c_str());
    pipeline_->setLaserOn(false);
    pipeline_->stop();
}

bool StreamDetectController::restart_pipeline_after_rebind_locked(std::string& err) {
    if (last_rtsp_url_.empty()) {
        return true;
    }
    if (!pipeline_) {
        pipeline_ = std::make_unique<stream_detect::StreamDetectPipeline>();
    }
    const auto cfg = build_config_locked();
    if (!pipeline_->start(last_rtsp_url_, cfg)) {
        err = "failed to restart StreamDetectPipeline after session rebind";
        return false;
    }
    pipeline_->setLaserOn(state_.laser_on.load());
    ALOGI("restarted pipeline after session rebind url=%s", last_rtsp_url_.c_str());
    return true;
}

void StreamDetectController::on_laser_or_assist_changed() {
    std::lock_guard<std::mutex> lock(mu_);
    apply_gates_locked();
}

std::string StreamDetectController::handle_configure(const std::string& json_line,
                                                     const std::string& id) {
    std::lock_guard<std::mutex> lock(mu_);
    bool need_opencv_rebind = false;
    bool need_zp_rebind = false;
    bool need_rknn_teardown = false;

    if (auto v = extract_string_field(json_line, "output_dir")) {
        base_config_.output_dir = *v;
    }
    if (auto v = extract_string_field(json_line, "session_source")) {
        base_config_.session_source = *v;
    }
    if (auto v = extract_string_field(json_line, "config_yaml")) {
        if (*v != config_yaml_) {
            config_yaml_ = *v;
            need_opencv_rebind = true;
            need_rknn_teardown = true;
        }
    }
    if (auto v = extract_string_field(json_line, "project_root")) {
        if (*v != project_root_) {
            project_root_ = *v;
            need_opencv_rebind = true;
            need_rknn_teardown = true;
        }
    }
    if (auto v = extract_string_field(json_line, "roi_json")) {
        if (*v != roi_json_) {
            roi_json_ = *v;
            need_zp_rebind = true;
        }
    }
    if (auto v = extract_int_field(json_line, "camera_type")) {
        base_config_.camera_type = static_cast<int>(*v);
    }
    if (auto v = extract_int_field(json_line, "zero_point_target_mode")) {
        base_config_.zero_point_target_mode = static_cast<int>(*v);
    }
    if (auto v = extract_bool_field(json_line, "lens_det_enabled")) {
        base_config_.lens_det_enabled = *v;
    }
    if (auto v = extract_bool_field(json_line, "zero_point_enabled")) {
        base_config_.zero_point_enabled = *v;
    }
    if (auto v = extract_bool_field(json_line, "rknn_stream_enabled")) {
        if (base_config_.rknn_stream_enabled && !*v) {
            need_rknn_teardown = true;
        }
        base_config_.rknn_stream_enabled = *v;
    }
    // Omitted field keeps existing base_config_.rknn_stream_enabled (default false).

    const bool was_running = pipeline_ && pipeline_->isRunning();
    const bool will_rebind = need_opencv_rebind || need_zp_rebind || need_rknn_teardown;
    if (will_rebind && was_running) {
        stop_pipeline_for_session_rebind_locked();
    }
    if (need_opencv_rebind) {
        opencv_session_.reset();
    }
    if (need_zp_rebind) {
        zp_context_.reset();
    }
    if (need_rknn_teardown) {
        rknn_scheduler_.reset();
        rknn_app_config_.reset();
    }

    std::string err;
    if (!ensure_sessions_locked(err)) {
        return make_ack("configure_session_ack", id, false, "session_error", err);
    }
    configured_ = true;
    if (will_rebind && was_running) {
        if (!restart_pipeline_after_rebind_locked(err)) {
            return make_ack("configure_session_ack", id, false, "restart_failed", err);
        }
    } else if (pipeline_ && pipeline_->isRunning()) {
        apply_gates_locked();
    }
    ALOGI("configure_session ok output_dir=%s source=%s lens=%d zp=%d rknn=%d rebind=%d",
          base_config_.output_dir.c_str(),
          base_config_.session_source.c_str(),
          base_config_.lens_det_enabled ? 1 : 0,
          base_config_.zero_point_enabled ? 1 : 0,
          rknn_scheduler_ ? 1 : 0,
          will_rebind ? 1 : 0);
    return make_ack("configure_session_ack", id, true);
}

std::string StreamDetectController::handle_start(const std::string& json_line,
                                                 const std::string& id) {
    std::lock_guard<std::mutex> lock(mu_);
    auto url = extract_string_field(json_line, "rtsp_url");
    if (!url || url->empty()) {
        return make_ack("stream_detect_start_ack", id, false, "bad_request", "missing rtsp_url");
    }
    std::string err;
    if (!ensure_sessions_locked(err)) {
        return make_ack("stream_detect_start_ack", id, false, "session_error", err);
    }
    configured_ = true;
    if (!pipeline_) {
        pipeline_ = std::make_unique<stream_detect::StreamDetectPipeline>();
    }
    if (pipeline_->isRunning()) {
        pipeline_->stop();
    }
    const auto cfg = build_config_locked();
    const bool ok = pipeline_->start(*url, cfg);
    if (!ok) {
        return make_ack("stream_detect_start_ack", id, false, "start_failed",
                        "StreamDetectPipeline::start returned false");
    }
    last_rtsp_url_ = *url;
    pipeline_->setLaserOn(state_.laser_on.load());
    ALOGI("stream_detect_start ok url=%s laser_on=%d",
          url->c_str(), state_.laser_on.load() ? 1 : 0);
    return make_ack("stream_detect_start_ack", id, true);
}

std::string StreamDetectController::handle_stop(const std::string& id) {
    std::lock_guard<std::mutex> lock(mu_);
    if (pipeline_) {
        pipeline_->setLaserOn(false);
        pipeline_->stop();
    }
    ALOGI("stream_detect_stop");
    return make_ack("stream_detect_stop_ack", id, true);
}

std::string StreamDetectController::handle_burst_mode(const std::string& json_line,
                                                      const std::string& id) {
    auto burst = extract_bool_field(json_line, "burst");
    if (!burst) {
        return make_ack("stream_detect_burst_mode_ack", id, false, "bad_request", "missing burst");
    }
    std::lock_guard<std::mutex> lock(mu_);
    if (pipeline_) {
        pipeline_->setBurstMode(*burst);
    }
    ALOGI("stream_detect_burst_mode burst=%d", *burst ? 1 : 0);
    return make_ack("stream_detect_burst_mode_ack", id, true);
}

std::string StreamDetectController::handle_zp_target_mode(const std::string& json_line,
                                                          const std::string& id) {
    auto mode = extract_int_field(json_line, "target_mode");
    if (!mode) {
        return make_ack("stream_detect_zp_target_mode_ack", id, false, "bad_request",
                        "missing target_mode");
    }
    std::lock_guard<std::mutex> lock(mu_);
    base_config_.zero_point_target_mode = static_cast<int>(*mode);
    if (pipeline_) {
        pipeline_->setZeroPointTargetMode(base_config_.zero_point_target_mode);
    }
    if (zp_context_) {
        zp_context_->setDetectTargetMode(
                *mode == 1 ? zero_point::DetectTargetMode::Line
                           : zero_point::DetectTargetMode::Point);
    }
    ALOGI("stream_detect_zp_target_mode mode=%d", static_cast<int>(*mode));
    return make_ack("stream_detect_zp_target_mode_ack", id, true);
}

bool StreamDetectController::read_nv12_file(const std::string& path, int width, int height,
                                           std::vector<uint8_t>& out, std::string& err) {
    if (width <= 0 || height <= 0) {
        err = "invalid dimensions";
        return false;
    }
    const size_t expected =
            static_cast<size_t>(width) * static_cast<size_t>(height) * 3U / 2U;
    std::ifstream in(path, std::ios::binary);
    if (!in) {
        err = "open failed: " + path;
        return false;
    }
    out.resize(expected);
    in.read(reinterpret_cast<char*>(out.data()), static_cast<std::streamsize>(expected));
    if (static_cast<size_t>(in.gcount()) != expected) {
        err = "short read expected=" + std::to_string(expected) + " got=" +
              std::to_string(in.gcount());
        return false;
    }
    return true;
}

std::string StreamDetectController::handle_offline_opencv_stain_nv12(const std::string& json_line,
                                                                    const std::string& id) {
    auto path = extract_string_field(json_line, "nv12_path");
    auto w = extract_int_field(json_line, "width");
    auto h = extract_int_field(json_line, "height");
    if (!path || !w || !h) {
        return make_ack("offline_infer_opencv_stain_nv12_ack", id, false, "bad_request",
                        "missing nv12_path/width/height");
    }
    std::string output_dir =
            extract_string_field(json_line, "output_dir").value_or("opencv_stain_detect_out/offline");

    // Ephemeral session: avoid sharing live Session state with StreamDetect pipeline threads.
    std::string yaml;
    std::string root;
    {
        std::lock_guard<std::mutex> lock(mu_);
        yaml = config_yaml_;
        root = project_root_;
    }
    std::string err;
    std::vector<uint8_t> nv12;
    if (!read_nv12_file(*path, static_cast<int>(*w), static_cast<int>(*h), nv12, err)) {
        return make_ack("offline_infer_opencv_stain_nv12_ack", id, false, "io_error", err);
    }
    cv::Mat bgr;
    if (!stream_detect::nv12ToBgr(nv12.data(), static_cast<int>(*w), static_cast<int>(*h), bgr)) {
        return make_ack("offline_infer_opencv_stain_nv12_ack", id, false, "convert_error",
                        "nv12ToBgr failed");
    }
    try {
        opencv_stain_detect::Session session(yaml, root);
        opencv_stain_detect::Result native_result = opencv_stain_detect::analyzeOpencvStainDetectBgr(
                bgr, session.options(), output_dir, &session.islandSlotSession());
        const std::string summary = opencv_stain_detect::summaryToJson(native_result);
        ALOGI("offline_infer_opencv_stain_nv12 ok=%d code=%d", native_result.ok ? 1 : 0,
              native_result.code);
        return make_ack("offline_infer_opencv_stain_nv12_ack", id, true, {}, {}, summary);
    } catch (const std::exception& ex) {
        return make_ack("offline_infer_opencv_stain_nv12_ack", id, false, "session_error", ex.what());
    }
}

std::string StreamDetectController::handle_offline_opencv_stain_jpg(const std::string& json_line,
                                                                   const std::string& id) {
    auto path = extract_string_field(json_line, "image_path");
    if (!path || path->empty()) {
        return make_ack("offline_infer_opencv_stain_jpg_ack", id, false, "bad_request",
                        "missing image_path");
    }
    std::string output_dir =
            extract_string_field(json_line, "output_dir").value_or("opencv_stain_detect_out/offline");

    std::string yaml;
    std::string root;
    {
        std::lock_guard<std::mutex> lock(mu_);
        yaml = config_yaml_;
        root = project_root_;
    }
    cv::Mat bgr = cv::imread(*path, cv::IMREAD_COLOR);
    if (bgr.empty()) {
        return make_ack("offline_infer_opencv_stain_jpg_ack", id, false, "io_error",
                        "failed to read image");
    }
    try {
        opencv_stain_detect::Session session(yaml, root);
        opencv_stain_detect::Result native_result = opencv_stain_detect::analyzeOpencvStainDetectBgr(
                bgr, session.options(), output_dir, &session.islandSlotSession());
        const std::string summary = opencv_stain_detect::summaryToJson(native_result);
        ALOGI("offline_infer_opencv_stain_jpg ok=%d code=%d", native_result.ok ? 1 : 0,
              native_result.code);
        return make_ack("offline_infer_opencv_stain_jpg_ack", id, true, {}, {}, summary);
    } catch (const std::exception& ex) {
        return make_ack("offline_infer_opencv_stain_jpg_ack", id, false, "session_error", ex.what());
    }
}

std::string StreamDetectController::handle_offline_rknn_stain_jpg(const std::string& json_line,
                                                                 const std::string& id) {
    auto path = extract_string_field(json_line, "image_path");
    if (!path || path->empty()) {
        return make_ack("offline_infer_rknn_stain_jpg_ack", id, false, "bad_request",
                        "missing image_path");
    }

    std::string yaml;
    std::string root;
    {
        std::lock_guard<std::mutex> lock(mu_);
        yaml = config_yaml_;
        root = project_root_;
    }
    try {
        // Ephemeral scheduler: loads embedded det RKNN via ModelManager (NPU path).
        const AppConfig cfg = load_config(yaml, root);
        CentralScheduler scheduler(cfg);
        const StainInferOutcome result = scheduler.inferImageFromPath(*path);
        const std::string summary = stain_infer_outcome_to_json(result);
        ALOGI("offline_infer_rknn_stain_jpg code=%d boxes=%zu", result.code, result.boxes.size());
        const bool ok = result.code == 0;
        if (ok) {
            return make_ack("offline_infer_rknn_stain_jpg_ack", id, true, {}, {}, summary);
        }
        return make_ack("offline_infer_rknn_stain_jpg_ack", id, false, "infer_error",
                        result.error_message.empty() ? summary : result.error_message, summary);
    } catch (const std::exception& ex) {
        return make_ack("offline_infer_rknn_stain_jpg_ack", id, false, "session_error", ex.what());
    }
}

std::string StreamDetectController::handle_offline_zero_point_nv12(const std::string& json_line,
                                                                  const std::string& id) {
    auto path = extract_string_field(json_line, "nv12_path");
    auto w = extract_int_field(json_line, "width");
    auto h = extract_int_field(json_line, "height");
    if (!path || !w || !h) {
        return make_ack("offline_infer_zero_point_nv12_ack", id, false, "bad_request",
                        "missing nv12_path/width/height");
    }
    const int target_mode =
            static_cast<int>(extract_int_field(json_line, "target_mode").value_or(0));

    std::string roi;
    double tol;
    {
        std::lock_guard<std::mutex> lock(mu_);
        roi = roi_json_;
        tol = zp_tolerance_px_;
    }
    std::string err;
    std::vector<uint8_t> nv12;
    if (!read_nv12_file(*path, static_cast<int>(*w), static_cast<int>(*h), nv12, err)) {
        return make_ack("offline_infer_zero_point_nv12_ack", id, false, "io_error", err);
    }
    cv::Mat bgr;
    if (!stream_detect::nv12ToBgr(nv12.data(), static_cast<int>(*w), static_cast<int>(*h), bgr)) {
        return make_ack("offline_infer_zero_point_nv12_ack", id, false, "convert_error",
                        "nv12ToBgr failed");
    }
    try {
        zero_point::Context ctx(roi, tol);
        ctx.setDetectTargetMode(target_mode == 1 ? zero_point::DetectTargetMode::Line
                                                 : zero_point::DetectTargetMode::Point);
        const zero_point::FrameResult result = ctx.detectBgr(bgr);
        const std::string summary =
                zero_point::frameResultToJson(result, ctx.roi().reference_zero_xy);
        ALOGI("offline_infer_zero_point_nv12 ok=%d code=%d", result.ok ? 1 : 0, result.code);
        return make_ack("offline_infer_zero_point_nv12_ack", id, true, {}, {}, summary);
    } catch (const std::exception& ex) {
        return make_ack("offline_infer_zero_point_nv12_ack", id, false, "session_error", ex.what());
    }
}

}  // namespace lws::daemon
