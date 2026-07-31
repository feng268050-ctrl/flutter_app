#pragma once

#include "decoded_frame.h"

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace stream_detect {

struct AvcCodecConfig {
    int width = 0;
    int height = 0;
    std::vector<uint8_t> sps;
    std::vector<uint8_t> pps;
};

/** OS-agnostic H.264 access-unit decoder (MPP, transitional Ndk, etc.). */
class IVideoDecoder {
public:
    virtual ~IVideoDecoder() = default;

    virtual const char* backendName() const = 0;
    virtual bool configureAvc(const AvcCodecConfig& config) = 0;
    virtual void release() = 0;
    virtual bool queueAccessUnit(const uint8_t* data,
                                 size_t size,
                                 int64_t pts_us,
                                 bool key_frame) = 0;
    virtual bool tryReceiveFrame(DecodedFrame& out, int timeout_us) = 0;
};

}  // namespace stream_detect
