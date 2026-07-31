#pragma once

#include "fixed_roi_pipeline.h"

#include <opencv2/core.hpp>

namespace opencv_stain_detect {

/** HSV red/magenta bright plasma mask inside ROI (hue + S/V gates, morph + dilate). */
cv::Mat buildRedBrightPlasmaMask(const cv::Mat& roi_bgr, const FixedRoiParams& params);

/** Drop purple/white highlight blobs that pass size gate but are mostly overexposed (V>200 / low-S bright). */
bool passesRedBrightPlasmaColorGate(const cv::Mat& sat,
                                      const cv::Mat& val,
                                      const cv::Mat& mask_u8,
                                      const RegionBlob& blob,
                                      const FixedRoiParams& params);

}  // namespace opencv_stain_detect
