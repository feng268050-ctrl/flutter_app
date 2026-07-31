#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace stream_detect {

/** NdkMediaCodec OutputBuffer decoder (no Surface). */
class MediaCodecDecoder {
public:
    MediaCodecDecoder();
    ~MediaCodecDecoder();

    bool configure(const std::string& mime, int width, int height);
    bool configureAvc(int width,
                      int height,
                      const std::vector<uint8_t>& sps,
                      const std::vector<uint8_t>& pps);
    void release();

    bool queueNal(const uint8_t* data, size_t size, int64_t ptsUs);
    bool queueAccessUnit(const uint8_t* data, size_t size, int64_t ptsUs, bool keyFrame);

    bool dequeueOutput(std::vector<uint8_t>& nv12Out, int& width, int& height, int64_t& ptsUs);
    bool tryDequeueOutput(std::vector<uint8_t>& nv12Out,
                          int& width,
                          int& height,
                          int64_t& ptsUs,
                          int timeoutUs);

private:
    struct Impl;
    Impl* impl_;
};

}  // namespace stream_detect
