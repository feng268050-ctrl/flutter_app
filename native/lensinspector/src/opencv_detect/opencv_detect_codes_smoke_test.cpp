#include "opencv_detect_codes.h"
#include "opencv_detect_json.h"

#include "opencv_stain_detect/opencv_stain_detect_analyzer.h"
#include "zero_point_json.h"

#include <opencv2/core.hpp>

#include <cstdio>
#include <filesystem>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {

void require_contains(const std::string& haystack, const char* needle, const char* msg) {
    if (haystack.find(needle) == std::string::npos) {
        throw std::runtime_error(msg);
    }
}

}  // namespace

int main() {
    const std::string zp_fail = zero_point::errorJson(
        opencv_detect::kFrameRejected, opencv_detect::kReasonSpotSizeAboveMax);
    require_contains(zp_fail, "\"code\":-5", "zero_point code");
    require_contains(zp_fail, "\"reason\":\"spot_size_above_max\"", "zero_point reason");

    const std::string zp_frame = opencv_detect::zeroPointFailureJson(
        opencv_detect::kInvalidInput, opencv_detect::kReasonInvalidI420Dimensions);
    require_contains(zp_frame, "\"offset_x\":0", "zero_point offset_x");

    const std::string stain_overexposed = opencv_stain_detect::summaryToJson(
        opencv_stain_detect::errorResult(opencv_detect::kFrameRejected,
                                       opencv_detect::kReasonOverexposed));
    require_contains(stain_overexposed, "\"code\":-5", "lens_det overexposed code");
    require_contains(stain_overexposed, "\"reason\":\"overexposed\"", "lens_det overexposed reason");
    require_contains(stain_overexposed, "\"files\":[]", "lens_det files");

    const std::string stain_non_red = opencv_stain_detect::summaryToJson(
        opencv_stain_detect::errorResult(opencv_detect::kFrameRejected,
                                       opencv_detect::kReasonInvalidNonRed));
    require_contains(stain_non_red, "\"reason\":\"invalid_non_red\"", "lens_det invalid_non_red reason");

    const std::string stain_detect = opencv_stain_detect::summaryToJson(
        opencv_stain_detect::errorResult(opencv_detect::kDetectFailed,
                                       opencv_detect::kReasonNoTargetAfterFilter));
    require_contains(stain_detect, "\"code\":-3", "lens_det detect_failed code");

    const std::filesystem::path temp_dir =
        std::filesystem::temp_directory_path() / "opencv_stain_detect_failed_frame_test";
    std::error_code ec;
    std::filesystem::remove_all(temp_dir, ec);
    std::filesystem::create_directories(temp_dir, ec);
    const cv::Mat bgr(64, 64, CV_8UC3, cv::Scalar(10, 10, 200));
    const opencv_stain_detect::Result failed_frame =
        opencv_stain_detect::detectFailedWithInputFrame(
            bgr, temp_dir.string(), opencv_detect::kReasonNoTargetAfterFilter);
    const std::string failed_json = opencv_stain_detect::summaryToJson(failed_frame);
    require_contains(failed_json, "input_frame.jpg", "detect_failed files");
    if (!std::filesystem::is_regular_file(temp_dir / "input_frame.jpg")) {
        throw std::runtime_error("detect_failed input_frame.jpg missing");
    }
    std::filesystem::remove_all(temp_dir, ec);

    std::cout << "opencv_detect_codes_smoke_test passed\n";
    return 0;
}
