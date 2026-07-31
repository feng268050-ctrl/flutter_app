#pragma once

#include "ivideo_decoder.h"

#include <memory>

namespace stream_detect {

class MediaCodecDecoder;

/** Transitional Android NdkMediaCodec backend (platform/android only). */
class NdkMediaCodecVideoDecoder final : public IVideoDecoder {
public:
    NdkMediaCodecVideoDecoder();
    ~NdkMediaCodecVideoDecoder() override;

    const char* backendName() const override { return "ndk_mediacodec"; }
    bool configureAvc(const AvcCodecConfig& config) override;
    void release() override;
    bool queueAccessUnit(const uint8_t* data,
                         size_t size,
                         int64_t pts_us,
                         bool key_frame) override;
    bool tryReceiveFrame(DecodedFrame& out, int timeout_us) override;

    static bool isAvailable();

private:
    std::unique_ptr<MediaCodecDecoder> impl_;
};

}  // namespace stream_detect
