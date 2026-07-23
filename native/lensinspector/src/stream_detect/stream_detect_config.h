#pragma once

#include <cstdint>
#include <string>

namespace stream_detect {

struct SessionConfig {
    std::string output_dir;
    std::string session_source = "live_stain_detect";
    int64_t opencv_stain_session_handle = 0;
    int64_t rknn_session_handle = 0;
    int64_t zero_point_handle = 0;
    int64_t edgedrawing_handle = 0;
    int camera_type = 1;
    int zero_point_target_mode = 0;
    bool lens_det_enabled = true;
    bool zero_point_enabled = false;
    bool edgedrawing_enabled = false;
    bool rknn_stream_enabled = false;
};

}  // namespace stream_detect
