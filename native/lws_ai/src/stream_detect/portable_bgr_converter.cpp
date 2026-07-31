#include "portable_bgr_converter.h"

#include "yuv_convert.h"

namespace stream_detect {

bool PortableBgrConverter::toBgr(const DecodedFrame& frame, cv::Mat& bgr_out) {
    if (frame.format != PixelFormat::NV12 && frame.format != PixelFormat::Unknown) {
        return false;
    }
    if (frame.data.empty() || frame.width <= 0 || frame.height <= 0) {
        return false;
    }
    const int stride = frame.effectiveStride();
    const int slice_h = frame.effectiveSliceHeight();
    if (stride == frame.width && slice_h == frame.height) {
        return nv12ToBgr(frame.data.data(), frame.width, frame.height, bgr_out);
    }
    // Tight-pack stride-padded NV12 for OpenCV cvtColor.
    const size_t y_size = static_cast<size_t>(stride) * static_cast<size_t>(slice_h);
    const size_t uv_rows = static_cast<size_t>(slice_h) / 2;
    const size_t packed_y = static_cast<size_t>(frame.width) * static_cast<size_t>(frame.height);
    const size_t packed_uv = packed_y / 2;
    std::vector<uint8_t> packed(packed_y + packed_uv);
    for (int row = 0; row < frame.height; ++row) {
        memcpy(packed.data() + static_cast<size_t>(row) * frame.width,
               frame.data.data() + static_cast<size_t>(row) * stride,
               static_cast<size_t>(frame.width));
    }
    const uint8_t* src_uv = frame.data.data() + y_size;
    uint8_t* dst_uv = packed.data() + packed_y;
    for (size_t row = 0; row < uv_rows; ++row) {
        memcpy(dst_uv + row * frame.width,
               src_uv + row * stride,
               static_cast<size_t>(frame.width));
    }
    return nv12ToBgr(packed.data(), frame.width, frame.height, bgr_out);
}

}  // namespace stream_detect
