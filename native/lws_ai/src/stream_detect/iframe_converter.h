#pragma once

#include "decoded_frame.h"

#include <opencv2/core.hpp>

namespace stream_detect {

/** NV12 (stride-aware) → BGR for algorithm entry. */
class IFrameConverter {
public:
    virtual ~IFrameConverter() = default;
    virtual bool toBgr(const DecodedFrame& frame, cv::Mat& bgr_out) = 0;
};

}  // namespace stream_detect
