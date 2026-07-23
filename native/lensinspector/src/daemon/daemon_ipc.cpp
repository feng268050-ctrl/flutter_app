#include "daemon/daemon_ipc.h"
#include "daemon/daemon_stream_controller.h"
#include "daemon/json_util.h"

#include <android/log.h>

#include <cerrno>
#include <cstring>
#include <cstddef>
#include <chrono>
#include <poll.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

#include <sstream>
#include <thread>

#define LOG_TAG "AiDaemon"
#define ALOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define ALOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define ALOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace lws::daemon {
namespace {

constexpr size_t kMaxLineBytes = 64 * 1024;

std::string make_ack(std::string_view type, std::string_view id, bool ok,
                     std::string_view code = {}, std::string_view message = {}) {
    std::ostringstream oss;
    oss << "{\"v\":1,\"type\":\"" << type << "\",\"id\":\"" << json_escape(id)
        << "\",\"ts_ms\":" << now_ms() << ",\"ok\":" << (ok ? "true" : "false");
    if (!code.empty()) {
        oss << ",\"code\":\"" << json_escape(code) << "\"";
    }
    if (!message.empty()) {
        oss << ",\"message\":\"" << json_escape(message) << "\"";
    }
    oss << "}\n";
    return oss.str();
}

std::string make_event(std::string_view type) {
    std::ostringstream oss;
    oss << "{\"v\":1,\"type\":\"" << type << "\",\"ts_ms\":" << now_ms() << "}\n";
    return oss.str();
}

}  // namespace

DaemonIpc::DaemonIpc(std::string cmd_path, std::string evt_path, DaemonState& state,
                     StreamDetectController* stream_detect)
    : cmd_path_(std::move(cmd_path)),
      evt_path_(std::move(evt_path)),
      state_(state),
      stream_detect_(stream_detect) {}

DaemonIpc::~DaemonIpc() {
    stop();
}

void DaemonIpc::heartbeat_loop() {
    while (!heartbeat_stop_.load()) {
        maybe_heartbeat();
        flush_evt();
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }
}

void DaemonIpc::close_fd(int& fd) {
    if (fd >= 0) {
        ::close(fd);
        fd = -1;
    }
}

void DaemonIpc::unlink_path(const std::string& path) {
    if (::unlink(path.c_str()) == 0) {
        ALOGI("unlinked stale %s", path.c_str());
    }
}

bool DaemonIpc::listen_socket(const std::string& path, int& out_fd) {
    unlink_path(path);
    int fd = ::socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) {
        ALOGE("socket failed errno=%d", errno);
        return false;
    }
    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    socklen_t addr_len = 0;
    if (!path.empty() && path[0] == '@') {
        // Abstract namespace: store name after leading NUL (path arg uses '@' prefix).
        const std::string name = path.substr(1);
        if (name.size() >= sizeof(addr.sun_path) - 1) {
            ALOGE("abstract name too long: %s", name.c_str());
            ::close(fd);
            return false;
        }
        addr.sun_path[0] = '\0';
        std::memcpy(addr.sun_path + 1, name.c_str(), name.size());
        addr_len = static_cast<socklen_t>(offsetof(sockaddr_un, sun_path) + 1 + name.size());
    } else {
        if (path.size() >= sizeof(addr.sun_path)) {
            ALOGE("socket path too long: %s", path.c_str());
            ::close(fd);
            return false;
        }
        std::strncpy(addr.sun_path, path.c_str(), sizeof(addr.sun_path) - 1);
        addr_len = static_cast<socklen_t>(sizeof(addr));
    }
    if (::bind(fd, reinterpret_cast<sockaddr*>(&addr), addr_len) != 0) {
        ALOGE("bind %s failed errno=%d", path.c_str(), errno);
        ::close(fd);
        return false;
    }
    if (::listen(fd, 2) != 0) {
        ALOGE("listen %s failed errno=%d", path.c_str(), errno);
        ::close(fd);
        if (path.empty() || path[0] != '@') {
            unlink_path(path);
        }
        return false;
    }
    out_fd = fd;
    ALOGI("listening %s", path.c_str());
    return true;
}

bool DaemonIpc::start() {
    if (running_) {
        return true;
    }
    if (!listen_socket(cmd_path_, cmd_listen_) || !listen_socket(evt_path_, evt_listen_)) {
        stop();
        return false;
    }
    running_ = true;
    last_heartbeat_ms_ = now_ms();
    enqueue_evt(make_event("daemon_ready"));
    heartbeat_stop_.store(false);
    if (heartbeat_thread_.joinable()) {
        heartbeat_stop_.store(true);
        heartbeat_thread_.join();
        heartbeat_stop_.store(false);
    }
    heartbeat_thread_ = std::thread([this] { heartbeat_loop(); });
    ALOGI("daemon_ready published (heartbeat thread running)");
    return true;
}

void DaemonIpc::stop() {
    heartbeat_stop_.store(true);
    if (heartbeat_thread_.joinable()) {
        heartbeat_thread_.join();
    }
    running_ = false;
    close_fd(cmd_client_);
    {
        std::lock_guard<std::mutex> client_lock(evt_client_mu_);
        close_fd(evt_client_);
    }
    close_fd(cmd_listen_);
    close_fd(evt_listen_);
    if (!is_abstract(cmd_path_)) {
        unlink_path(cmd_path_);
    }
    if (!is_abstract(evt_path_)) {
        unlink_path(evt_path_);
    }
    std::lock_guard<std::mutex> lock(evt_mu_);
    evt_queue_.clear();
}

void DaemonIpc::enqueue_evt(std::string line) {
    std::lock_guard<std::mutex> lock(evt_mu_);
    if (evt_queue_.size() >= static_cast<size_t>(kMaxEvtQueue)) {
        // Drop oldest non-critical: keep newest, prefer dropping heartbeats already coalesced.
        evt_queue_.erase(evt_queue_.begin());
    }
    evt_queue_.push_back(std::move(line));
}

void DaemonIpc::publish_event(const std::string& json_line) {
    std::string line = json_line;
    if (line.empty() || line.back() != '\n') {
        line.push_back('\n');
    }
    enqueue_evt(std::move(line));
}

void DaemonIpc::accept_cmd() {
    if (cmd_client_ >= 0) {
        // Single cmd client: replace.
        close_fd(cmd_client_);
        cmd_buf_.clear();
    }
    int fd = ::accept4(cmd_listen_, nullptr, nullptr, SOCK_CLOEXEC);
    if (fd < 0) {
        ALOGW("accept cmd failed errno=%d", errno);
        return;
    }
    cmd_client_ = fd;
    ALOGI("cmd client connected");
}

void DaemonIpc::accept_evt() {
    std::lock_guard<std::mutex> client_lock(evt_client_mu_);
    if (evt_client_ >= 0) {
        close_fd(evt_client_);
    }
    int fd = ::accept4(evt_listen_, nullptr, nullptr, SOCK_CLOEXEC);
    if (fd < 0) {
        ALOGW("accept evt failed errno=%d", errno);
        return;
    }
    evt_client_ = fd;
    ALOGI("evt client connected");
    // Re-announce readiness for late subscribers.
    enqueue_evt(make_event("daemon_ready"));
}

void DaemonIpc::flush_evt() {
    std::vector<std::string> batch;
    {
        std::lock_guard<std::mutex> lock(evt_mu_);
        batch.swap(evt_queue_);
    }
    if (batch.empty()) {
        return;
    }
    std::lock_guard<std::mutex> client_lock(evt_client_mu_);
    if (evt_client_ < 0) {
        return;
    }
    for (const auto& line : batch) {
        size_t off = 0;
        while (off < line.size()) {
            ssize_t n = ::write(evt_client_, line.data() + off, line.size() - off);
            if (n < 0) {
                if (errno == EINTR) {
                    continue;
                }
                ALOGW("evt write failed errno=%d; dropping client", errno);
                close_fd(evt_client_);
                return;
            }
            off += static_cast<size_t>(n);
        }
    }
}

std::string DaemonIpc::handle_cmd(const std::string& line) {
    auto type = extract_string_field(line, "type");
    auto id = extract_string_field(line, "id").value_or("");
    if (!type) {
        return make_ack("error", id, false, "bad_request", "missing type");
    }
    if (*type == "ping") {
        return make_ack("ping_ack", id, true);
    }
    if (*type == "laser_state") {
        auto laser = extract_bool_field(line, "laser_on");
        if (!laser) {
            return make_ack("laser_state_ack", id, false, "bad_request", "missing laser_on");
        }
        state_.laser_on.store(*laser);
        if (stream_detect_) {
            stream_detect_->on_laser_or_assist_changed();
        }
        ALOGI("laser_state laser_on=%d", *laser ? 1 : 0);
        return make_ack("laser_state_ack", id, true);
    }
    if (*type == "ai_assist_config") {
        auto lens = extract_bool_field(line, "lens_contamination_enabled");
        auto zp = extract_bool_field(line, "zero_point_offset_enabled");
        if (!lens || !zp) {
            return make_ack("ai_assist_config_ack", id, false, "bad_request",
                            "missing assist flags");
        }
        state_.lens_contamination_enabled.store(*lens);
        state_.zero_point_offset_enabled.store(*zp);
        if (stream_detect_) {
            stream_detect_->on_laser_or_assist_changed();
        }
        ALOGI("ai_assist_config lens=%d zero_point=%d", *lens ? 1 : 0, *zp ? 1 : 0);
        return make_ack("ai_assist_config_ack", id, true);
    }
    if (*type == "shutdown") {
        state_.shutdown_requested.store(true);
        ALOGI("shutdown requested");
        return make_ack("shutdown_ack", id, true);
    }
    if (*type == "configure_session") {
        if (!stream_detect_) {
            return make_ack("error", id, false, "not_available", "stream detect not linked");
        }
        return stream_detect_->handle_configure(line, id);
    }
    if (*type == "stream_detect_start") {
        if (!stream_detect_) {
            return make_ack("error", id, false, "not_available", "stream detect not linked");
        }
        return stream_detect_->handle_start(line, id);
    }
    if (*type == "stream_detect_stop") {
        if (!stream_detect_) {
            return make_ack("error", id, false, "not_available", "stream detect not linked");
        }
        return stream_detect_->handle_stop(id);
    }
    if (*type == "stream_detect_burst_mode") {
        if (!stream_detect_) {
            return make_ack("error", id, false, "not_available", "stream detect not linked");
        }
        return stream_detect_->handle_burst_mode(line, id);
    }
    if (*type == "stream_detect_zp_target_mode") {
        if (!stream_detect_) {
            return make_ack("error", id, false, "not_available", "stream detect not linked");
        }
        return stream_detect_->handle_zp_target_mode(line, id);
    }
    if (*type == "offline_infer_opencv_stain_nv12") {
        if (!stream_detect_) {
            return make_ack("error", id, false, "not_available", "stream detect not linked");
        }
        return stream_detect_->handle_offline_opencv_stain_nv12(line, id);
    }
    if (*type == "offline_infer_opencv_stain_jpg") {
        if (!stream_detect_) {
            return make_ack("error", id, false, "not_available", "stream detect not linked");
        }
        return stream_detect_->handle_offline_opencv_stain_jpg(line, id);
    }
    if (*type == "offline_infer_zero_point_nv12") {
        if (!stream_detect_) {
            return make_ack("error", id, false, "not_available", "stream detect not linked");
        }
        return stream_detect_->handle_offline_zero_point_nv12(line, id);
    }
    if (type->rfind("offline_infer_", 0) == 0) {
        return make_ack("error", id, false, "not_implemented",
                        "offline infer type not wired yet");
    }
    return make_ack("error", id, false, "unknown_type", *type);
}

void DaemonIpc::service_cmd_client() {
    if (cmd_client_ < 0) {
        return;
    }
    char buf[4096];
    ssize_t n = ::read(cmd_client_, buf, sizeof(buf));
    if (n == 0) {
        ALOGI("cmd client closed");
        close_fd(cmd_client_);
        cmd_buf_.clear();
        return;
    }
    if (n < 0) {
        if (errno == EINTR) {
            return;
        }
        ALOGW("cmd read failed errno=%d", errno);
        close_fd(cmd_client_);
        cmd_buf_.clear();
        return;
    }
    cmd_buf_.append(buf, static_cast<size_t>(n));
    if (cmd_buf_.size() > kMaxLineBytes) {
        ALOGW("cmd line too large; disconnect");
        close_fd(cmd_client_);
        cmd_buf_.clear();
        return;
    }
    size_t start = 0;
    while (true) {
        auto nl = cmd_buf_.find('\n', start);
        if (nl == std::string::npos) {
            break;
        }
        std::string line = cmd_buf_.substr(start, nl - start);
        start = nl + 1;
        if (line.empty()) {
            continue;
        }
        std::string resp = handle_cmd(line);
        size_t off = 0;
        while (off < resp.size() && cmd_client_ >= 0) {
            ssize_t w = ::write(cmd_client_, resp.data() + off, resp.size() - off);
            if (w < 0) {
                if (errno == EINTR) {
                    continue;
                }
                ALOGW("cmd write failed errno=%d", errno);
                close_fd(cmd_client_);
                cmd_buf_.clear();
                return;
            }
            off += static_cast<size_t>(w);
        }
    }
    if (start > 0) {
        cmd_buf_.erase(0, start);
    }
}

void DaemonIpc::maybe_heartbeat() {
    const int64_t now = now_ms();
    if (now - last_heartbeat_ms_ < kHeartbeatIntervalMs) {
        return;
    }
    last_heartbeat_ms_ = now;
    enqueue_evt(make_event("heartbeat"));
}

void DaemonIpc::poll_once(int timeout_ms) {
    if (!running_) {
        return;
    }
    pollfd fds[3];
    nfds_t nfds = 0;
    int idx_cmd_listen = -1;
    int idx_evt_listen = -1;
    int idx_cmd_client = -1;
    auto add = [&](int fd, short events) -> int {
        if (fd < 0) {
            return -1;
        }
        const int index = static_cast<int>(nfds);
        fds[nfds].fd = fd;
        fds[nfds].events = events;
        fds[nfds].revents = 0;
        ++nfds;
        return index;
    };
    idx_cmd_listen = add(cmd_listen_, POLLIN);
    idx_evt_listen = add(evt_listen_, POLLIN);
    idx_cmd_client = add(cmd_client_, POLLIN);
    const int rc = ::poll(fds, nfds, timeout_ms);
    if (rc < 0) {
        if (errno != EINTR) {
            ALOGW("poll failed errno=%d", errno);
        }
        return;
    }
    auto revents = [&](int index) -> short {
        return index >= 0 ? fds[index].revents : static_cast<short>(0);
    };
    if (revents(idx_cmd_listen) & POLLIN) {
        accept_cmd();
    }
    if (revents(idx_evt_listen) & POLLIN) {
        accept_evt();
    }
    if (revents(idx_cmd_client) & (POLLIN | POLLHUP | POLLERR)) {
        service_cmd_client();
    }
    // Heartbeat + evt flush run on heartbeat_thread_ so long offline cmds do not stall them.
    flush_evt();
}

}  // namespace lws::daemon
