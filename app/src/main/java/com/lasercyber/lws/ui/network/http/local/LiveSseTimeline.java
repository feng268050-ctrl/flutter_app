package com.lasercyber.lws.ui.network.http.local;

/**
 * Per SSE connection: {@code timestampMs} for live camera inference is elapsed ms since the
 * connection was established ({@link android.os.SystemClock#elapsedRealtime()} at subscribe).
 */
final class LiveSseTimeline {

    private final long connectionAnchorElapsedMs;

    LiveSseTimeline(long connectionAnchorElapsedMs) {
        this.connectionAnchorElapsedMs = connectionAnchorElapsedMs;
    }

    /**
     * @param elapsedRealtimeMs {@link android.os.SystemClock#elapsedRealtime()} at publish time
     * @return non-negative ms since this SSE connection was acquired
     */
    long timelineMs(long elapsedRealtimeMs) {
        return Math.max(0L, elapsedRealtimeMs - connectionAnchorElapsedMs);
    }
}
