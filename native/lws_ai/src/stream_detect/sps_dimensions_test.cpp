#include "rtsp_util.h"
#include "sps_dimensions.h"

#include <iostream>
#include <vector>

namespace {

bool expectDimensions(const std::vector<uint8_t>& sps, int expectedW, int expectedH) {
    int width = 0;
    int height = 0;
    if (!stream_detect::parseH264SpsDimensions(sps, width, height)) {
        std::cerr << "parseH264SpsDimensions failed\n";
        return false;
    }
    if (width != expectedW || height != expectedH) {
        std::cerr << "expected " << expectedW << "x" << expectedH << " got " << width << "x" << height
                  << '\n';
        return false;
    }
    return true;
}

}  // namespace

int main() {
    // 1920x1080 High profile SPS from a typical IPC PR1 stream (base64 from SDP sprop-parameter-sets).
    const std::string spsB64 =
        "Z0LAH5aNrUQvFCl5ZXZ0aOhrNX1BlTnJxd3dlT0FXZGVWdlMzUXdlcmVmc"
        "V9wS1NXN0hITjBleG42eXBRZ29BQUJZQ0FsZUAB";
    std::vector<uint8_t> sps;
    if (!stream_detect::base64Decode(spsB64, sps) || sps.empty()) {
        std::cerr << "base64Decode failed\n";
        return 1;
    }
    if (!expectDimensions(sps, 1920, 1080)) {
        return 1;
    }

    // Legacy parser mis-read this bitstream as 208x32; clamp must upgrade to 1920x1080.
    int width = 208;
    int height = 32;
    stream_detect::clampPlausibleVideoDimensions(width, height);
    if (width != 1920 || height != 1080) {
        std::cerr << "clampPlausibleVideoDimensions failed\n";
        return 1;
    }

    std::cout << "sps_dimensions_test passed\n";
    return 0;
}
