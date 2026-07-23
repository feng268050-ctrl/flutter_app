#include "det_raw_concat.h"

#include <algorithm>
#include <cstddef>
#include <vector>

namespace rknn_det_raw {

bool ConcatDetRawP2P3P4(const std::vector<RKNNRunner::OutputTensor>& outputs,
                        std::vector<float>& merged,
                        int& dim0,
                        int& dim1) {
    if (outputs.size() != 3U) {
        return false;
    }
    struct Level {
        int idx;
        int spatial;
    };
    std::vector<Level> levels;
    levels.reserve(3U);
    constexpr int kChannels = 65;
    for (int i = 0; i < 3; ++i) {
        const auto& t = outputs[static_cast<std::size_t>(i)];
        int h = 0;
        int w = 0;
        if (t.n_dims == 4U && t.shape.size() >= 4U &&
            static_cast<int>(t.shape[1]) == kChannels) {
            h = static_cast<int>(t.shape[2]);
            w = static_cast<int>(t.shape[3]);
        } else if (t.n_dims == 3U && t.shape.size() >= 3U &&
                   static_cast<int>(t.shape[0]) == kChannels) {
            h = static_cast<int>(t.shape[1]);
            w = static_cast<int>(t.shape[2]);
        } else {
            return false;
        }
        if (h < 1 || w < 1) {
            return false;
        }
        levels.push_back({i, h * w});
    }
    std::sort(levels.begin(), levels.end(),
              [](const Level& a, const Level& b) { return a.spatial > b.spatial; });

    int total_anchors = 0;
    for (const auto& lv : levels) {
        total_anchors += lv.spatial;
    }
    if (total_anchors < 1) {
        return false;
    }

    const std::size_t merged_size =
        static_cast<std::size_t>(kChannels) * static_cast<std::size_t>(total_anchors);
    static thread_local std::vector<float> merged_buf;
    if (merged_buf.size() != merged_size) {
        merged_buf.resize(merged_size);
    }
    merged_buf.assign(merged_size, 0.0F);
    float* merged_data = merged_buf.data();
    int anchor_offset = 0;
    for (const auto& lv : levels) {
        const auto& t = outputs[static_cast<std::size_t>(lv.idx)];
        const int spatial = lv.spatial;
        const std::size_t plane = static_cast<std::size_t>(spatial);
        for (int c = 0; c < kChannels; ++c) {
            const std::size_t src_base = static_cast<std::size_t>(c) * plane;
            const std::size_t dst_base =
                static_cast<std::size_t>(c) * static_cast<std::size_t>(total_anchors) +
                static_cast<std::size_t>(anchor_offset);
            for (int s = 0; s < spatial; ++s) {
                merged_data[dst_base + static_cast<std::size_t>(s)] =
                    t.data[src_base + static_cast<std::size_t>(s)];
            }
        }
        anchor_offset += spatial;
    }
    dim0 = kChannels;
    dim1 = total_anchors;
    merged = merged_buf;
    return true;
}

}  // namespace rknn_det_raw
