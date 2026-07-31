#pragma once

#include <vector>

namespace opencv_stain_detect {

/// Marks indices that belong to a native-ok run of length >= min_consecutive.
inline std::vector<bool> consecutiveOkEffectiveMask(const std::vector<bool>& native_ok,
                                                    int min_consecutive) {
    const int n = static_cast<int>(native_ok.size());
    std::vector<bool> mask(n, false);
    if (min_consecutive <= 1) {
        return native_ok;
    }
    int i = 0;
    while (i < n) {
        if (!native_ok[i]) {
            ++i;
            continue;
        }
        const int start = i;
        while (i < n && native_ok[i]) {
            ++i;
        }
        const int len = i - start;
        if (len >= min_consecutive) {
            for (int j = start; j < i; ++j) {
                mask[j] = true;
            }
        }
    }
    return mask;
}

}  // namespace opencv_stain_detect
