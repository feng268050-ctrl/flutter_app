#pragma once

#include <cstdint>
#include <vector>

namespace stream_detect {

enum class PixelFormat { NV12, NV21, Unknown };

/** Stride-aware decoded YUV frame; product contract is NV12 for detect. */
struct DecodedFrame {
    std::vector<uint8_t> data;
    int width = 0;
    int height = 0;
    int stride = 0;
    int slice_height = 0;
    PixelFormat format = PixelFormat::Unknown;
    int64_t pts_us = 0;

    int effectiveStride() const { return stride > 0 ? stride : width; }
    int effectiveSliceHeight() const { return slice_height > 0 ? slice_height : height; }
};

}  // namespace stream_detect
