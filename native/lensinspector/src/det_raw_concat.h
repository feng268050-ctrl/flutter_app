#pragma once

#include "rknn_runner.h"

#include <vector>

namespace rknn_det_raw {

/// Merge three raw P2/P3/P4 tensors [1,65,H,W] → row-major [65, N] (same as Python concat_p2p3p4).
bool ConcatDetRawP2P3P4(const std::vector<RKNNRunner::OutputTensor>& outputs,
                        std::vector<float>& merged,
                        int& dim0,
                        int& dim1);

}  // namespace rknn_det_raw
