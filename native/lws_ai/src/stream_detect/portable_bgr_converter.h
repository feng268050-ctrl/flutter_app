#pragma once

#include "iframe_converter.h"

namespace stream_detect {

class PortableBgrConverter final : public IFrameConverter {
public:
    bool toBgr(const DecodedFrame& frame, cv::Mat& bgr_out) override;
};

}  // namespace stream_detect
