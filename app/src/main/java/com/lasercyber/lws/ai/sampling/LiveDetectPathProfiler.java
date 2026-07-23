package com.lasercyber.lws.ai.sampling;
import android.os.SystemClock;
import android.util.Log;

import androidx.annotation.NonNull;

/**
 * Optional timing logs for the Java-side live detect path baseline (Phase 0).
 * Enable via {@link com.lasercyber.lws.ui.common.config.CameraConfig#isLiveDetectPathProfilingEnabled()}.
 */
public final class LiveDetectPathProfiler {

    private static final String TAG = "LiveDetectPathProfiler";

    private LiveDetectPathProfiler() {
    }

    public static void logFrameAccepted(@NonNull String path, int width, int height) {
        if (!isEnabled()) {
            return;
        }
        Log.i(TAG, "frame_accept path=" + path + " size=" + width + "x" + height
                + " monoMs=" + SystemClock.elapsedRealtime());
    }

    public static void logDetectStarted(@NonNull String path, long frameMonoMs) {
        if (!isEnabled()) {
            return;
        }
        long queueMs = SystemClock.elapsedRealtime() - frameMonoMs;
        Log.i(TAG, "detect_start path=" + path + " queueMs=" + queueMs);
    }

    public static void logDetectFinished(@NonNull String path, long startMonoMs, boolean success) {
        if (!isEnabled()) {
            return;
        }
        long detectMs = SystemClock.elapsedRealtime() - startMonoMs;
        Log.i(TAG, "detect_done path=" + path + " detectMs=" + detectMs + " ok=" + success);
    }

    private static boolean isEnabled() {
        return com.lasercyber.lws.ui.common.config.CameraConfig.isLiveDetectPathProfilingEnabled();
    }
}
