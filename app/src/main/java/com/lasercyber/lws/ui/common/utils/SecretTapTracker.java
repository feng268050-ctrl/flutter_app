package com.lasercyber.lws.ui.common.utils;

import android.os.SystemClock;

/**
 * Detects consecutive taps within a short window (e.g. hidden settings entry).
 */
public final class SecretTapTracker {

    private static final int REQUIRED_TAPS = 5;
    /** Max idle time between consecutive taps before the count resets. */
    private static final long TAP_WINDOW_MS = 5000L;

    private int tapCount;
    private long resetAfterElapsed;

    /** @return {@code true} when the required number of taps was reached */
    public boolean registerTap() {
        long now = SystemClock.elapsedRealtime();
        if (now > resetAfterElapsed) {
            tapCount = 0;
        }
        tapCount++;
        resetAfterElapsed = now + TAP_WINDOW_MS;
        if (tapCount >= REQUIRED_TAPS) {
            tapCount = 0;
            return true;
        }
        return false;
    }

    public void reset() {
        tapCount = 0;
        resetAfterElapsed = 0L;
    }
}
