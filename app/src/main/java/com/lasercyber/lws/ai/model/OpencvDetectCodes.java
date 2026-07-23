package com.lasercyber.lws.ai.model;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * Unified native OpenCV detect result codes shared by zero_point and lens_det JNI.
 */
public enum OpencvDetectCodes {
    OK(0),
    INVALID_HANDLE(-1),
    INVALID_INPUT(-2),
    DETECT_FAILED(-3),
    IO_ERROR(-4),
    FRAME_REJECTED(-5),
    CONFIG_ERROR(-6);

    public static final String REASON_SPOT_SIZE_BELOW_MIN = "spot_size_below_min";
    public static final String REASON_SPOT_SIZE_ABOVE_MAX = "spot_size_above_max";
    public static final String REASON_CIRCLE_RADIUS_BELOW_MIN = "circle_radius_below_min";
    public static final String REASON_BLACK_BLOB_NOT_FOUND = "black_blob_not_found";
    public static final String REASON_LINE_NOT_FOUND = "line_not_found";
    public static final String REASON_MISSING_REFERENCE_ZERO = "missing_reference_zero";
    public static final String REASON_SATURATED_WHITE_AREA_EXCEEDS_LIMIT = "saturated_white_area_exceeds_limit";
    public static final String REASON_INSUFFICIENT_REGIONS_AFTER_ERODE = "insufficient_regions_after_erode";
    public static final String REASON_TOO_MANY_REGIONS_AFTER_ERODE = "too_many_regions_after_erode";
    public static final String REASON_INSUFFICIENT_CONSECUTIVE_OK_FRAMES = "insufficient_consecutive_ok_frames";
    public static final String REASON_NO_TARGET_AFTER_FILTER = "no_target_after_filter";
    public static final String REASON_OVEREXPOSED = "overexposed";
    public static final String REASON_INVALID_NON_RED = "invalid_non_red";
    public static final String REASON_NO_VALID_REGION = "no_valid_region";
    public static final String REASON_EMPTY_ROI = "empty_roi";

    private final int code;

    OpencvDetectCodes(int code) {
        this.code = code;
    }

    public int code() {
        return code;
    }

    @NonNull
    public static OpencvDetectCodes fromCode(int code) {
        for (OpencvDetectCodes value : values()) {
            if (value.code == code) {
                return value;
            }
        }
        return INVALID_HANDLE;
    }

    public boolean isFrameRejected() {
        return this == FRAME_REJECTED;
    }

    public boolean isSpotSizeRejection(@Nullable String reason) {
        return isFrameRejected()
                && reason != null
                && (REASON_SPOT_SIZE_BELOW_MIN.equals(reason) || REASON_SPOT_SIZE_ABOVE_MAX.equals(reason));
    }

    public boolean isCircleRadiusRejection(@Nullable String reason) {
        return isFrameRejected() && REASON_CIRCLE_RADIUS_BELOW_MIN.equals(reason);
    }

    public boolean isSaturationRejection(@Nullable String reason) {
        return isFrameRejected()
                && (REASON_SATURATED_WHITE_AREA_EXCEEDS_LIMIT.equals(reason)
                || REASON_OVEREXPOSED.equals(reason));
    }

    public boolean isRedFrameGateRejection(@Nullable String reason) {
        return isFrameRejected()
                && reason != null
                && (REASON_OVEREXPOSED.equals(reason)
                || REASON_INVALID_NON_RED.equals(reason)
                || REASON_NO_VALID_REGION.equals(reason)
                || REASON_EMPTY_ROI.equals(reason));
    }
}
