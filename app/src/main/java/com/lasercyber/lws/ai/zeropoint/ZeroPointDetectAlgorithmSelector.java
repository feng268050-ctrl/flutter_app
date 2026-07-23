package com.lasercyber.lws.ai.zeropoint;
import android.util.Log;

/**
 * Laser-on zero-point detect always uses {@code zero_point} in {@code StreamDetectPipeline}.
 */
public final class ZeroPointDetectAlgorithmSelector {

    private static final String TAG = "ZeroPointAlgorithm";

    public static final int FRAMES_PER_DETECT_ROUND = 10;

    private ZeroPointDetectAlgorithmSelector() {
    }

    public static void logActiveAlgorithmOnce() {
        Log.i(TAG, "laser_zero_detect algorithm=ZERO_POINT weld_mode_routing=true");
    }
}
