#include "ndk_media_codec_video_decoder.h"

#include "media_codec_decoder.h"

namespace stream_detect {

NdkMediaCodecVideoDecoder::NdkMediaCodecVideoDecoder()
    : impl_(std::make_unique<MediaCodecDecoder>()) {}

NdkMediaCodecVideoDecoder::~NdkMediaCodecVideoDecoder() {
    release();
}

bool NdkMediaCodecVideoDecoder::isAvailable() {
#ifdef __ANDROID__
    return true;
#else
    return false;
#endif
}

bool NdkMediaCodecVideoDecoder::configureAvc(const AvcCodecConfig& config) {
    if (!impl_) {
        return false;
    }
    return impl_->configureAvc(config.width, config.height, config.sps, config.pps);
}

void NdkMediaCodecVideoDecoder::release() {
    if (impl_) {
        impl_->release();
    }
}

bool NdkMediaCodecVideoDecoder::queueAccessUnit(const uint8_t* data,
                                                size_t size,
                                                int64_t pts_us,
                                                bool key_frame) {
    if (!impl_) {
        return false;
    }
    return impl_->queueAccessUnit(data, size, pts_us, key_frame);
}

bool NdkMediaCodecVideoDecoder::tryReceiveFrame(DecodedFrame& out, int timeout_us) {
    if (!impl_) {
        return false;
    }
    std::vector<uint8_t> nv12;
    int width = 0;
    int height = 0;
    int64_t pts = 0;
    if (!impl_->tryDequeueOutput(nv12, width, height, pts, timeout_us)) {
        return false;
    }
    out.data = std::move(nv12);
    out.width = width;
    out.height = height;
    out.stride = width;
    out.slice_height = height;
    out.format = PixelFormat::NV12;
    out.pts_us = pts;
    return true;
}

}  // namespace stream_detect
