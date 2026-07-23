package com.lasercyber.lws.ui.common.upgrade;

import android.os.SystemClock;

import java.util.function.LongSupplier;

/**
 * Throttles OTA {@code device.update_progress} emits per stage.
 * <p>
 * Within a stage, post when either:
 * <ul>
 *   <li>progress reaches {@code lastPosted + 10} (relative to the last push, not decade
 *       buckets — e.g. after a 100&nbsp;ms push at 6%, the next step push is at 16%), or</li>
 *   <li>{@value #MIN_INTERVAL_MS}&nbsp;ms elapsed since the last push and progress increased, or</li>
 *   <li>{@code 100%} was not posted yet.</li>
 * </ul>
 */
public final class OtaWsProgressThrottler {

    static final int PERCENT_STEP = 10;
    static final long MIN_INTERVAL_MS = 100L;

    private final LongSupplier uptimeMillis;
    private int lastPostedPercent = -1;
    private long lastPostTimeMs = 0L;

    public OtaWsProgressThrottler() {
        this(SystemClock::uptimeMillis);
    }

    OtaWsProgressThrottler(LongSupplier uptimeMillis) {
        this.uptimeMillis = uptimeMillis;
    }

    public synchronized void reset() {
        lastPostedPercent = -1;
        lastPostTimeMs = 0L;
    }

    public synchronized void markPosted(int percent) {
        lastPostedPercent = percent;
        lastPostTimeMs = uptimeMillis.getAsLong();
    }

    public synchronized int getLastPostedPercent() {
        return lastPostedPercent;
    }

    /**
     * @return {@code true} when a WS progress event for {@code percent} should be sent now
     */
    public synchronized boolean shouldPost(int percent) {
        if (percent < lastPostedPercent) {
            return false;
        }
        if (percent == 100 && lastPostedPercent < 100) {
            return true;
        }
        if (lastPostedPercent < 0) {
            return true;
        }
        if (percent <= lastPostedPercent) {
            return false;
        }
        if (percent >= lastPostedPercent + PERCENT_STEP) {
            return true;
        }
        return uptimeMillis.getAsLong() - lastPostTimeMs >= MIN_INTERVAL_MS;
    }
}
