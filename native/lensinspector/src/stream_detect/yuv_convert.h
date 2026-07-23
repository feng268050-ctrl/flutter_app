#pragma once

#include <opencv2/core.hpp>
#include <vector>

namespace stream_detect {

/** NV12 (Y + interleaved UV) to BGR cv::Mat for OpenCV detect entry. */
bool nv12ToBgr(const uint8_t* nv12, int width, int height, cv::Mat& bgrOut);

/** I420 planar to NV12 buffer (for soft-decode fallback). */
bool i420ToNv12(const uint8_t* i420, int width, int height, std::vector<uint8_t>& nv12Out);

}  // namespace stream_detect
