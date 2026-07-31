#pragma once

#include <opencv2/core.hpp>

#include <atomic>
#include <condition_variable>
#include <functional>
#include <mutex>
#include <queue>
#include <thread>

/** Single background worker for stain checks; joinable shutdown (no detach). */
class StainWorkerPool {
public:
    using Task = std::function<void(cv::Mat frame)>;

    StainWorkerPool();
    ~StainWorkerPool();

    StainWorkerPool(const StainWorkerPool&) = delete;
    StainWorkerPool& operator=(const StainWorkerPool&) = delete;

    void submit(cv::Mat frame, Task task);
    void shutdown();

private:
    struct Job {
        cv::Mat frame;
        Task task;
    };

    void workerLoop();

    std::thread worker_;
    std::mutex mtx_;
    std::condition_variable cv_;
    std::queue<Job> queue_;
    std::atomic<bool> stop_{false};
};
