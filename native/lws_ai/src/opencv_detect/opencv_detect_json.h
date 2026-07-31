#pragma once

#include <string>

namespace opencv_detect {

std::string jsonEscape(const std::string& value);

/** lens_det-style summary failure: ok, code, reason, files[]. */
std::string summaryFailureJson(int code, const std::string& reason);

/** zero_point frame failure: ok, code, reason, offset_x/y zeroed. */
std::string zeroPointFailureJson(int code, const std::string& reason);

}  // namespace opencv_detect
