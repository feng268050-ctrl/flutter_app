#include "stain_worker_pool.h"

StainWorkerPool::StainWorkerPool() {
    worker_ = std::thread([this] { workerLoop(); });
}

StainWorkerPool::~StainWorkerPool() {
    shutdown();
}

void StainWorkerPool::submit(cv::Mat frame, Task task) {
    if (!task || stop_.load()) {
        return;
    }
    {
        std::lock_guard<std::mutex> lk(mtx_);
        if (stop_.load()) {
            return;
        }
        queue_.push(Job{std::move(frame), std::move(task)});
    }
    cv_.notify_one();
}

void StainWorkerPool::shutdown() {
    if (stop_.exchange(true)) {
        return;
    }
    cv_.notify_all();
    if (worker_.joinable()) {
        worker_.join();
    }
    std::lock_guard<std::mutex> lk(mtx_);
    while (!queue_.empty()) {
        queue_.pop();
    }
}

void StainWorkerPool::workerLoop() {
    for (;;) {
        Job job;
        {
            std::unique_lock<std::mutex> lk(mtx_);
            cv_.wait(lk, [this] { return stop_.load() || !queue_.empty(); });
            if (stop_.load() && queue_.empty()) {
                return;
            }
            job = std::move(queue_.front());
            queue_.pop();
        }
        if (job.task) {
            job.task(std::move(job.frame));
        }
    }
}
