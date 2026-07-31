#pragma once

#include "ivideo_decoder.h"

#include <memory>
#include <string>

namespace stream_detect {

/** Prefer Rockchip MPP; fall back to transitional NdkMediaCodec on Android. */
std::unique_ptr<IVideoDecoder> createAvcVideoDecoder(const AvcCodecConfig& config,
                                                     std::string& chosen_backend);

}  // namespace stream_detect
