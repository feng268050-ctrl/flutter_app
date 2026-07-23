package com.lasercyber.lws.ai.sampling;
import com.lasercyber.lws.ai.engine.AiManager;
import com.lasercyber.lws.ai.sampling.AiFrameSamplingInterval;
import android.os.SystemClock;

/**
 * Time-based gate: at most one frame per {@code sampleIntervalMs} on a monotonic clock.
 */
public final class AiFrameSamplingGate {

    private final long sampleIntervalMs;
    private long lastAcceptElapsedMs;

    public AiFrameSamplingGate(long sampleIntervalMs) {
        this.sampleIntervalMs = Math.max(1L, sampleIntervalMs);
    }

    public AiFrameSamplingGate(AiFrameSamplingInterval interval) {
        this(interval.getIntervalMs());
    }

    public long getSampleIntervalMs() {
        return sampleIntervalMs;
    }

    /**
     * @param monotonicMs typically {@link SystemClock#elapsedRealtime()}
     * @return true if this frame should enter the AiManager stream push path
     */
    public boolean tryAccept(long monotonicMs) {
        long last = lastAcceptElapsedMs;
        if (last > 0 && monotonicMs - last < sampleIntervalMs) {
            return false;
        }
        lastAcceptElapsedMs = monotonicMs;
        return true;
    }

    public boolean tryAcceptNow() {
        return tryAccept(SystemClock.elapsedRealtime());
    }

    public void reset() {
        lastAcceptElapsedMs = 0L;
    }
}
