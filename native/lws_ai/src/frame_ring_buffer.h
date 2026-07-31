#pragma once

#include <atomic>
#include <cstdint>
#include <mutex>

#include <opencv2/core.hpp>

/** Dual-slot BGR frame handoff: producer publishes, consumer takes latest without clone. */
class FrameRingBuffer {
public:
    void publish(cv::Mat bgr, int64_t pts_ms = 0);
    /** Returns false if no ready frame. `out` receives a ref-counted Mat (no deep copy). */
    bool consume(cv::Mat& out, int64_t& pts_ms);

private:
    struct Slot {
        cv::Mat bgr;
        int64_t pts_ms = 0;
        bool ready = false;
    };

    Slot slots_[2];
    std::atomic<int> write_idx_{0};
    std::mutex mtx_;
};
