#include "daemon/daemon_ipc.h"
#include "daemon/daemon_stream_controller.h"

#include <android/log.h>

#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <string>

#include <signal.h>
#include <sys/prctl.h>
#include <sys/stat.h>
#include <unistd.h>

#define LOG_TAG "AiDaemon"
#define ALOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define ALOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

struct Options {
    std::string workdir;
    std::string sock_dir;
    std::string abstract_prefix;
    std::string config;
};

void print_usage(const char* argv0) {
    ALOGE("usage: %s --workdir PATH (--abstract PREFIX | --sock-dir PATH) [--config PATH]",
          argv0);
}

bool parse_args(int argc, char** argv, Options& out) {
    const char* env_work = std::getenv("LWS_AI_WORKDIR");
    const char* env_sock = std::getenv("LWS_AI_SOCK_DIR");
    const char* env_abs = std::getenv("LWS_AI_ABSTRACT");
    const char* env_cfg = std::getenv("LWS_AI_CONFIG");
    if (env_work) {
        out.workdir = env_work;
    }
    if (env_sock) {
        out.sock_dir = env_sock;
    }
    if (env_abs) {
        out.abstract_prefix = env_abs;
    }
    if (env_cfg) {
        out.config = env_cfg;
    }
    for (int i = 1; i < argc; ++i) {
        const char* a = argv[i];
        auto need = [&](std::string& dest) -> bool {
            if (i + 1 >= argc) {
                return false;
            }
            dest = argv[++i];
            return true;
        };
        if (std::strcmp(a, "--workdir") == 0) {
            if (!need(out.workdir)) {
                return false;
            }
        } else if (std::strcmp(a, "--sock-dir") == 0) {
            if (!need(out.sock_dir)) {
                return false;
            }
        } else if (std::strcmp(a, "--abstract") == 0) {
            if (!need(out.abstract_prefix)) {
                return false;
            }
        } else if (std::strcmp(a, "--config") == 0) {
            if (!need(out.config)) {
                return false;
            }
        } else if (std::strcmp(a, "--help") == 0 || std::strcmp(a, "-h") == 0) {
            print_usage(argv[0]);
            return false;
        } else {
            ALOGE("unknown arg: %s", a);
            return false;
        }
    }
    if (out.workdir.empty()) {
        return false;
    }
    return !out.abstract_prefix.empty() || !out.sock_dir.empty();
}

bool ensure_dir(const std::string& path) {
    if (::mkdir(path.c_str(), 0700) == 0 || errno == EEXIST) {
        return true;
    }
    ALOGE("mkdir %s failed errno=%d", path.c_str(), errno);
    return false;
}

/** Die with SIGTERM when Java/App parent exits so we do not orphan. */
void install_parent_death_signal() {
#if defined(__linux__)
    if (::prctl(PR_SET_PDEATHSIG, SIGTERM) != 0) {
        ALOGE("prctl(PR_SET_PDEATHSIG) failed errno=%d", errno);
        return;
    }
    // Race: parent may have already exited between fork and prctl.
    if (::getppid() == 1) {
        ALOGE("parent already gone after PR_SET_PDEATHSIG; exiting");
        std::_Exit(0);
    }
#endif
}

}  // namespace

int main(int argc, char** argv) {
    install_parent_death_signal();

    Options opt;
    if (!parse_args(argc, argv, opt)) {
        print_usage(argv[0]);
        return 2;
    }
    ALOGI("lws_ai_daemon start workdir=%s abstract=%s sock_dir=%s config=%s",
          opt.workdir.c_str(),
          opt.abstract_prefix.empty() ? "(none)" : opt.abstract_prefix.c_str(),
          opt.sock_dir.empty() ? "(none)" : opt.sock_dir.c_str(),
          opt.config.empty() ? "(none)" : opt.config.c_str());

    if (!ensure_dir(opt.workdir)) {
        return 1;
    }
    if (!opt.sock_dir.empty() && !ensure_dir(opt.sock_dir)) {
        return 1;
    }
    if (::chdir(opt.workdir.c_str()) != 0) {
        ALOGE("chdir %s failed errno=%d", opt.workdir.c_str(), errno);
        return 1;
    }

    std::string cmd_path;
    std::string evt_path;
    if (!opt.abstract_prefix.empty()) {
        cmd_path = "@" + opt.abstract_prefix + "_cmd";
        evt_path = "@" + opt.abstract_prefix + "_evt";
    } else {
        cmd_path = opt.sock_dir + "/cmd.sock";
        evt_path = opt.sock_dir + "/evt.sock";
    }

    lws::daemon::DaemonState state;
    lws::daemon::StreamDetectController stream_detect(state);
    lws::daemon::DaemonIpc ipc(cmd_path, evt_path, state, &stream_detect);
    stream_detect.attach_event_sink(ipc);
    if (!ipc.start()) {
        ALOGE("ipc start failed");
        return 1;
    }

    while (!state.shutdown_requested.load()) {
        ipc.poll_once(500);
    }

    ALOGI("shutting down");
    stream_detect.shutdown();
    ipc.stop();
    return 0;
}
