#include "red_frame_validator.h"

#include "opencv_detect_codes.h"

#include <opencv2/imgproc.hpp>

#include <iostream>
#include <stdexcept>
#include <string>

namespace {

void require(bool condition, const char* msg) {
    if (!condition) {
        throw std::runtime_error(msg);
    }
}

cv::Mat makeFrameWithCircle(const cv::Scalar& bgr, int radius) {
    cv::Mat frame(1080, 1920, CV_8UC3, cv::Scalar(0, 0, 0));
    cv::circle(frame, cv::Point(960, 540), radius, bgr, cv::FILLED, cv::LINE_AA);
    return frame;
}

cv::Mat makeFrameWithRedPurpleBlend(int radius) {
    cv::Mat frame(1080, 1920, CV_8UC3, cv::Scalar(0, 0, 0));
    cv::circle(frame, cv::Point(960, 540), radius, cv::Scalar(0, 0, 210), cv::FILLED, cv::LINE_AA);
    cv::circle(frame, cv::Point(960, 540), radius * 3 / 4, cv::Scalar(255, 0, 255), cv::FILLED, cv::LINE_AA);
    return frame;
}

void expectVerdict(opencv_detect::RedFrameVerdict expected,
                   const char* expected_reason,
                   const opencv_detect::RedFrameValidation& validation,
                   const char* label) {
    if (validation.verdict != expected) {
        throw std::runtime_error(std::string(label) + ": unexpected verdict");
    }
    if (expected_reason != nullptr) {
        require(validation.reason_token != nullptr, (std::string(label) + ": missing reason").c_str());
        require(std::string(validation.reason_token) == expected_reason,
                (std::string(label) + ": reason mismatch").c_str());
    }
}

}  // namespace

int main() {
    const cv::Mat red_frame = makeFrameWithCircle(cv::Scalar(0, 0, 210), 420);
    const opencv_detect::RedFrameValidation red = opencv_detect::validateRedFrame(red_frame);
    expectVerdict(opencv_detect::RedFrameVerdict::ValidRed, nullptr, red, "red");

    const cv::Mat purple_frame = makeFrameWithCircle(cv::Scalar(255, 0, 255), 420);
    const opencv_detect::RedFrameValidation purple = opencv_detect::validateRedFrame(purple_frame);
    expectVerdict(
        opencv_detect::RedFrameVerdict::InvalidNonRed,
        opencv_detect::kReasonInvalidNonRed,
        purple,
        "purple");

    const opencv_detect::RedFrameValidation purple_mask_only =
        opencv_detect::validateRedFrameMaskOnly(purple_frame);
    expectVerdict(opencv_detect::RedFrameVerdict::ValidRed, nullptr, purple_mask_only, "purple_mask_only");

    const cv::Mat red_purple_blend = makeFrameWithRedPurpleBlend(420);
    const opencv_detect::RedFrameValidation blend = opencv_detect::validateRedFrame(red_purple_blend);
    expectVerdict(
        opencv_detect::RedFrameVerdict::InvalidNonRed,
        opencv_detect::kReasonInvalidNonRed,
        blend,
        "red_purple_blend");

    const cv::Mat white_frame = makeFrameWithCircle(cv::Scalar(255, 255, 255), 420);
    const opencv_detect::RedFrameValidation white = opencv_detect::validateRedFrame(white_frame);
    expectVerdict(
        opencv_detect::RedFrameVerdict::Overexposed,
        opencv_detect::kReasonOverexposed,
        white,
        "white");

    const cv::Mat empty_frame;
    const opencv_detect::RedFrameValidation empty = opencv_detect::validateRedFrame(empty_frame);
    expectVerdict(
        opencv_detect::RedFrameVerdict::NoValidRegion,
        opencv_detect::kReasonNoValidRegion,
        empty,
        "empty");

    std::cout << "red_frame_validator_test passed\n";
    return 0;
}
