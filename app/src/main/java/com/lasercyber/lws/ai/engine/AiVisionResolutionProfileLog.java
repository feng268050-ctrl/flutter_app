package com.lasercyber.lws.ai.engine;
import android.util.Log;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.common.config.CameraConfig;

/**
 * Structured resolution / policy logs for {@code ai-vision-live-resolution-profile} (task 4.5).
 * Filter logcat: {@code AiVisionResolutionProfile}.
 */
public final class AiVisionResolutionProfileLog {

    public static final String TAG = "AiVisionResolutionProfile";

    private AiVisionResolutionProfileLog() {
    }

    public static void logDetectPolicy(
            @NonNull String weldNative,
            @NonNull String aiVisionNative,
            @NonNull String overlayPolicy) {
        if (!isEnabled()) {
            return;
        }
        Log.i(TAG, "detect_policy weldNative=" + weldNative
                + " aiVisionNative=" + aiVisionNative
                + " overlay=" + overlayPolicy);
    }

    public static void logLiveRtspPolicy(
            @NonNull String policy,
            int candidateCount,
            @NonNull String firstUrl) {
        if (!isEnabled()) {
            return;
        }
        Log.i(TAG, "live_rtsp_policy policy=" + policy
                + " candidates=" + candidateCount
                + " firstUrl=" + firstUrl);
    }

    public static void logPlaybackDecode(
            int width,
            int height,
            int decodeType,
            @NonNull String profile,
            @NonNull String url) {
        if (!isEnabled()) {
            return;
        }
        Log.i(TAG, "playback_decode size=" + width + "x" + height
                + " decodeType=" + decodeType
                + " profile=" + profile
                + " url=" + url);
    }

    public static void logNativeDetectDecode(
            long frameId,
            int width,
            int height) {
        if (!isEnabled()) {
            return;
        }
        Log.i(TAG, "native_detect_decode frameId=" + frameId
                + " size=" + width + "x" + height);
    }

    private static boolean isEnabled() {
        return CameraConfig.isAiVisionResolutionProfileLoggingEnabled();
    }
}
