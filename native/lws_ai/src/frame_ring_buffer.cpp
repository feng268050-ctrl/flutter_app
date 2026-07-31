#include "frame_ring_buffer.h"

void FrameRingBuffer::publish(cv::Mat bgr, int64_t pts_ms) {
    std::lock_guard<std::mutex> lk(mtx_);
    const int next = 1 - write_idx_.load(std::memory_order_relaxed);
    slots_[next].bgr = std::move(bgr);
    slots_[next].pts_ms = pts_ms;
    slots_[next].ready = true;
    write_idx_.store(next, std::memory_order_release);
}

bool FrameRingBuffer::consume(cv::Mat& out, int64_t& pts_ms) {
    std::lock_guard<std::mutex> lk(mtx_);
    const int idx = write_idx_.load(std::memory_order_acquire);
    if (!slots_[idx].ready || slots_[idx].bgr.empty()) {
        return false;
    }
    out = slots_[idx].bgr;
    pts_ms = slots_[idx].pts_ms;
    return true;
}
