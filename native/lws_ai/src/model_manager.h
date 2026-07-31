#pragma once
#include "config.h"
#include "detection.h"
#include <opencv2/core.hpp>
#include <memory>
#include <string>
#include <vector>

class RKNNRunner;

class ModelManager {
public:
    explicit ModelManager(const AppConfig& cfg);
    ~ModelManager();

    std::vector<Detection> infer_stain(const cv::Mat& img_bgr);

    bool isDetEnabled() const { return det_enabled_; }

    void release();

private:
    std::unique_ptr<RKNNRunner> stain_runner_;
    const AppConfig& cfg_;
    bool det_enabled_ = true;
};
