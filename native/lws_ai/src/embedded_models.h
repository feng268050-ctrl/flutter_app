#pragma once
#include <cstddef>
#include <cstdint>

// RKNN stain-detect model embedded via objcopy -I binary (see CMakeLists.txt).

extern "C" {
    extern const uint8_t _binary_v8_rknn_stain_det_i8_rknn_start[];
    extern const uint8_t _binary_v8_rknn_stain_det_i8_rknn_end[];
}

inline const uint8_t* rknn_stain_det_model_data() {
    return _binary_v8_rknn_stain_det_i8_rknn_start;
}
inline size_t rknn_stain_det_model_size() {
    return static_cast<size_t>(_binary_v8_rknn_stain_det_i8_rknn_end
                               - _binary_v8_rknn_stain_det_i8_rknn_start);
}
