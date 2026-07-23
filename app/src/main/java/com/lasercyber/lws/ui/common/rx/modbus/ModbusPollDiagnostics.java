package com.lasercyber.lws.ui.common.rx.modbus;

import android.util.Log;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

/**
 * Throttled debug metrics for Modbus poll / gate timing.
 */
public final class ModbusPollDiagnostics {

    private static final String TAG = LogTAGConstant.RxModbusPollResults;
    private static final int LOG_EVERY_N = 20;

    private static int discardCount;
    private static int cycleCount;
    private static long lastGateWaitMs;
    private static long lastCycleMs;

    private ModbusPollDiagnostics() {
    }

    static void resetForTest() {
        discardCount = 0;
        cycleCount = 0;
        lastGateWaitMs = 0L;
        lastCycleMs = 0L;
    }

    public static void recordDiscard(String reason) {
        discardCount++;
        if (Log.isLoggable(TAG, Log.DEBUG) && discardCount % LOG_EVERY_N == 0) {
            Log.d(TAG, "poll tick discarded reason=" + reason + " totalDiscards=" + discardCount);
        }
    }

    public static void recordGateWait(long waitMs) {
        lastGateWaitMs = waitMs;
    }

    public static void recordCycleComplete(long cycleMs) {
        cycleCount++;
        lastCycleMs = cycleMs;
        if (Log.isLoggable(TAG, Log.DEBUG) && cycleCount % LOG_EVERY_N == 0) {
            Log.d(TAG, "poll cycleMs=" + cycleMs + " lastGateWaitMs=" + lastGateWaitMs
                    + " cycles=" + cycleCount);
        }
    }

    public static long getLastCycleMsForTest() {
        return lastCycleMs;
    }

    public static int getDiscardCountForTest() {
        return discardCount;
    }
}
