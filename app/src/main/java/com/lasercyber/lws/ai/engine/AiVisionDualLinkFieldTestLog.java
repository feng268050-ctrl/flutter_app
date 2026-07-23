package com.lasercyber.lws.ai.engine;
import android.os.SystemClock;
import android.util.Log;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.common.config.CameraConfig;

/**
 * Structured logs for RK3566 AI Vision dual-link field test (Phase 3 / task 4.3).
 * Filter logcat with tag {@code AiVisionDualLink}.
 */
public final class AiVisionDualLinkFieldTestLog {

    public static final String TAG = "AiVisionDualLink";

    /** Overlay bus-to-UI apply within this window passes sync tolerance (spec: 100–300 ms). */
    public static final long OVERLAY_SYNC_PASS_MS = 300L;

    private static volatile long playbackFirstFrameMonoMs = -1L;
    private static volatile long detectSessionStartMonoMs = -1L;
    private static volatile long detectFirstSampleMonoMs = -1L;

    private AiVisionDualLinkFieldTestLog() {
    }

    public static void resetSession() {
        playbackFirstFrameMonoMs = -1L;
        detectSessionStartMonoMs = -1L;
        detectFirstSampleMonoMs = -1L;
    }

    public static void logPlaybackFirstFrame(
            long firstFrameMs,
            int decodeType,
            int width,
            int height,
            @NonNull String profile) {
        if (!isEnabled()) {
            return;
        }
        playbackFirstFrameMonoMs = SystemClock.elapsedRealtime();
        Log.i(TAG, "playback_first_frame firstFrameMs=" + firstFrameMs
                + " decodeType=" + decodeType
                + " size=" + width + "x" + height
                + " profile=" + profile
                + " monoMs=" + playbackFirstFrameMonoMs);
        logDualLinkGapIfReady();
    }

    public static void logDetectSessionStart(@NonNull String source, long samplingIntervalMs) {
        if (!isEnabled()) {
            return;
        }
        detectSessionStartMonoMs = SystemClock.elapsedRealtime();
        detectFirstSampleMonoMs = -1L;
        Log.i(TAG, "detect_session_start source=" + source
                + " samplingIntervalMs=" + samplingIntervalMs
                + " monoMs=" + detectSessionStartMonoMs);
    }

    public static void logDetectSample(long frameId, int width, int height) {
        if (!isEnabled()) {
            return;
        }
        long now = SystemClock.elapsedRealtime();
        if (detectFirstSampleMonoMs < 0L) {
            detectFirstSampleMonoMs = now;
            long sinceSession = detectSessionStartMonoMs >= 0L
                    ? now - detectSessionStartMonoMs
                    : -1L;
            Log.i(TAG, "detect_first_sample frameId=" + frameId
                    + " size=" + width + "x" + height
                    + " sinceSessionMs=" + sinceSession
                    + " monoMs=" + now);
            logDualLinkGapIfReady();
        }
    }

    public static void logOverlaySync(long frameId, long busToOverlayMs) {
        if (!isEnabled()) {
            return;
        }
        String syncVerdict = busToOverlayMs <= OVERLAY_SYNC_PASS_MS ? "pass" : "slow";
        Log.i(TAG, "overlay_sync frameId=" + frameId
                + " busToOverlayMs=" + busToOverlayMs
                + " verdict=" + syncVerdict);
    }

    private static void logDualLinkGapIfReady() {
        if (playbackFirstFrameMonoMs < 0L || detectFirstSampleMonoMs < 0L) {
            return;
        }
        long gapMs = Math.abs(detectFirstSampleMonoMs - playbackFirstFrameMonoMs);
        Log.i(TAG, "dual_link_first_sample_gap_ms=" + gapMs
                + " playbackMonoMs=" + playbackFirstFrameMonoMs
                + " detectMonoMs=" + detectFirstSampleMonoMs);
    }

    private static boolean isEnabled() {
        return CameraConfig.isAiVisionDualLinkFieldTestLoggingEnabled();
    }
}
