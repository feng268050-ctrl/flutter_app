#include "frame_scheduler.h"

namespace stream_detect {

void FrameScheduler::reset() {
    burst_ = false;
    last_accept_ms_ = -1;
}

void FrameScheduler::setBurstMode(bool burst) {
    burst_ = burst;
}

bool FrameScheduler::tryAccept(int64_t nowMs) {
    const int64_t interval = burst_ ? kBurstIntervalMs : kNormalIntervalMs;
    if (last_accept_ms_ < 0 || nowMs - last_accept_ms_ >= interval) {
        last_accept_ms_ = nowMs;
        return true;
    }
    return false;
}

}  // namespace stream_detect
