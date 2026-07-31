#pragma once

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace lws::daemon {

struct DaemonState {
    std::atomic<bool> laser_on{false};
    std::atomic<bool> lens_contamination_enabled{true};
    std::atomic<bool> zero_point_offset_enabled{true};
    std::atomic<bool> shutdown_requested{false};
};

class StreamDetectController;

/**
 * Dual AF_UNIX SOCK_STREAM servers: cmd (req/resp) and evt (publish).
 * Paths may be filesystem paths or abstract names prefixed with '@'.
 * JSON Lines framing protocol v1.
 */
class DaemonIpc {
public:
    DaemonIpc(std::string cmd_path, std::string evt_path, DaemonState& state,
              StreamDetectController* stream_detect = nullptr);
    ~DaemonIpc();

    DaemonIpc(const DaemonIpc&) = delete;
    DaemonIpc& operator=(const DaemonIpc&) = delete;

    bool start();
    void stop();

    /** Poll once; handles accepts, cmd lines. Heartbeat runs on a side thread. */
    void poll_once(int timeout_ms);

    void publish_event(const std::string& json_line);

    bool is_running() const { return running_; }

private:
    static constexpr int kMaxEvtQueue = 64;
    static constexpr int64_t kHeartbeatIntervalMs = 2000;

    static bool is_abstract(const std::string& path) {
        return !path.empty() && path[0] == '@';
    }

    bool listen_socket(const std::string& path, int& out_fd);
    void unlink_path(const std::string& path);
    void accept_cmd();
    void accept_evt();
    void service_cmd_client();
    void flush_evt();
    void maybe_heartbeat();
    void heartbeat_loop();
    std::string handle_cmd(const std::string& line);
    void enqueue_evt(std::string line);
    void close_fd(int& fd);

    std::string cmd_path_;
    std::string evt_path_;
    DaemonState& state_;
    StreamDetectController* stream_detect_{nullptr};

    int cmd_listen_{-1};
    int evt_listen_{-1};
    int cmd_client_{-1};
    int evt_client_{-1};
    bool running_{false};

    std::string cmd_buf_;
    std::mutex evt_mu_;
    std::mutex evt_client_mu_;  // accept/replace/write evt_client_
    std::vector<std::string> evt_queue_;
    int64_t last_heartbeat_ms_{0};

    std::atomic<bool> heartbeat_stop_{true};
    std::thread heartbeat_thread_;
};

}  // namespace lws::daemon
