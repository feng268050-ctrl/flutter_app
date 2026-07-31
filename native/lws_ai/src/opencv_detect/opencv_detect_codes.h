#pragma once

namespace opencv_detect {

constexpr int kOk = 0;
constexpr int kInvalidHandle = -1;
constexpr int kInvalidInput = -2;
constexpr int kDetectFailed = -3;
constexpr int kIoError = -4;
constexpr int kFrameRejected = -5;
constexpr int kConfigError = -6;

// Shared reason tokens (snake_case).
constexpr const char* kReasonInvalidDetectorHandle = "invalid_detector_handle";
constexpr const char* kReasonInvalidSessionHandle = "invalid_session_handle";
constexpr const char* kReasonEmptyImagePath = "empty_image_path";
constexpr const char* kReasonEmptyOutputDir = "empty_output_dir";
constexpr const char* kReasonInvalidI420Dimensions = "invalid_i420_dimensions";
constexpr const char* kReasonInvalidRgbDimensions = "invalid_rgb_frame_dimensions";
constexpr const char* kReasonInvalidRgbStride = "invalid_rgb_stride";
constexpr const char* kReasonInvalidDirectBuffer = "invalid_direct_buffer";
constexpr const char* kReasonEmptyImage = "empty_image";
constexpr const char* kReasonInvalidImageType = "invalid_image_type";
constexpr const char* kReasonFailedToReadImage = "failed_to_read_image";
constexpr const char* kReasonFailedToCreateOutputDir = "failed_to_create_output_dir";
constexpr const char* kReasonFailedToWriteTargetJson = "failed_to_write_target_json";

constexpr const char* kReasonBlackBlobNotFound = "black_blob_not_found";
constexpr const char* kReasonLineNotFound = "line_not_found";
constexpr const char* kReasonEdgeNotFound = "edge_not_found";
constexpr const char* kReasonSpotSizeBelowMin = "spot_size_below_min";
constexpr const char* kReasonSpotSizeAboveMax = "spot_size_above_max";
constexpr const char* kReasonCircleRadiusBelowMin = "circle_radius_below_min";
constexpr const char* kReasonMissingReferenceZero = "missing_reference_zero";

constexpr const char* kReasonSaturatedWhiteAreaExceedsLimit = "saturated_white_area_exceeds_limit";
constexpr const char* kReasonInsufficientRegionsAfterErode = "insufficient_regions_after_erode";
constexpr const char* kReasonTooManyRegionsAfterErode = "too_many_regions_after_erode";
constexpr const char* kReasonInsufficientConsecutiveOkFrames = "insufficient_consecutive_ok_frames";
constexpr const char* kReasonNoTargetAfterFilter = "no_target_after_filter";

constexpr const char* kReasonOverexposed = "overexposed";
constexpr const char* kReasonInvalidNonRed = "invalid_non_red";
/// strict_inverted stage shows exactly N dark blobs (lens wash / contamination pattern).
constexpr const char* kReasonStrictInvertDirtyContamination = "strict_invert_dirty_contamination";
constexpr const char* kReasonNoValidRegion = "no_valid_region";
constexpr const char* kReasonEmptyRoi = "empty_roi";

}  // namespace opencv_detect
