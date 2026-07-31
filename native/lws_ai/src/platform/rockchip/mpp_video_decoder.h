#pragma once

#include "ivideo_decoder.h"

namespace stream_detect {

/** Rockchip MPP hardware decoder (H.264 → NV12). Requires LWS_HAVE_ROCKCHIP_MPP. */
class MppVideoDecoder final : public IVideoDecoder {
public:
    MppVideoDecoder();
    ~MppVideoDecoder() override;

    const char* backendName() const override { return "mpp"; }
    bool configureAvc(const AvcCodecConfig& config) override;
    void release() override;
    bool queueAccessUnit(const uint8_t* data,
                         size_t size,
                         int64_t pts_us,
                         bool key_frame) override;
    bool tryReceiveFrame(DecodedFrame& out, int timeout_us) override;

    static bool isAvailable();

private:
    struct Impl;
    Impl* impl_;
};

}  // namespace stream_detect
