#include "yuv_convert.h"

#include <cstring>

#include <opencv2/imgproc.hpp>

namespace stream_detect {

bool i420ToNv12(const uint8_t* i420, int width, int height, std::vector<uint8_t>& nv12Out) {
    if (!i420 || width <= 0 || height <= 0 || (width % 2) != 0 || (height % 2) != 0) {
        return false;
    }
    const size_t ySize = static_cast<size_t>(width) * static_cast<size_t>(height);
    const size_t uvPlane = ySize / 4;
    nv12Out.resize(ySize + ySize / 2);
    memcpy(nv12Out.data(), i420, ySize);
    const uint8_t* u = i420 + ySize;
    const uint8_t* v = u + uvPlane;
    uint8_t* uvOut = nv12Out.data() + ySize;
    for (size_t i = 0; i < uvPlane; ++i) {
        uvOut[i * 2] = u[i];
        uvOut[i * 2 + 1] = v[i];
    }
    return true;
}

bool nv12ToBgr(const uint8_t* nv12, int width, int height, cv::Mat& bgrOut) {
    if (!nv12 || width <= 0 || height <= 0) {
        return false;
    }
    cv::Mat yuv(height + height / 2, width, CV_8UC1, const_cast<uint8_t*>(nv12));
    cv::cvtColor(yuv, bgrOut, cv::COLOR_YUV2BGR_NV12);
    return !bgrOut.empty();
}

}  // namespace stream_detect
