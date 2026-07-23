#pragma once

#include <cstddef>
#include <cstdint>
#include <vector>

namespace stream_detect {

/** Parse H.264 SPS (with 1-byte NAL header) into display width/height. */
bool parseH264SpsDimensions(const std::vector<uint8_t>& sps, int& width, int& height);

/** Reject implausible SDP dimensions before decoder configure. */
bool isPlausibleVideoDimensions(int width, int height);

/** Clamp implausible dimensions to a safe default (1920x1080). */
void clampPlausibleVideoDimensions(int& width, int& height);

}  // namespace stream_detect
