#pragma once

#include <cstdint>

namespace stream_detect {

/** Time-based gate aligned with AiFrameSamplingInterval (500ms normal, 100ms burst). */
class FrameScheduler {
public:
    static constexpr int64_t kNormalIntervalMs = 500;
    static constexpr int64_t kBurstIntervalMs = 100;

    void reset();
    void setBurstMode(bool burst);
    bool tryAccept(int64_t nowMs);

private:
    bool burst_ = false;
    int64_t last_accept_ms_ = -1;
};

}  // namespace stream_detect
