package com.lasercyber.lws.ai.zeropoint;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * Holds the latest weld zero-point offset that raised the settings reminder.
 */
public final class ZeroPointPendingCorrectionStore {

    private static final long MAX_PENDING_AGE_MS = 10 * 60 * 1000L;
    private static final ZeroPointPendingCorrectionStore INSTANCE =
            new ZeroPointPendingCorrectionStore();

    @Nullable
    private PendingCorrection pendingCorrection;

    private ZeroPointPendingCorrectionStore() {
    }

    public static ZeroPointPendingCorrectionStore getInstance() {
        return INSTANCE;
    }

    public synchronized void setWeldResult(long eventId,
                                                 int validSamples,
                                                 double meanOffsetX,
                                                 double meanOffsetY) {
        if (validSamples <= 0) {
            pendingCorrection = null;
            return;
        }
        pendingCorrection = new PendingCorrection(
                "weld_json",
                eventId,
                validSamples,
                meanOffsetX,
                meanOffsetY,
                System.currentTimeMillis());
    }

    @Nullable
    public synchronized PendingCorrection consumeLatest() {
        return consumeLatest(System.currentTimeMillis());
    }

    public synchronized boolean hasFreshPending() {
        if (pendingCorrection == null) {
            return false;
        }
        if (pendingCorrection.isExpired(System.currentTimeMillis())) {
            pendingCorrection = null;
            return false;
        }
        return true;
    }

    public synchronized void clear() {
        pendingCorrection = null;
    }

    @Nullable
    public synchronized PendingCorrection consumeLatest(long nowMs) {
        PendingCorrection result = pendingCorrection;
        if (result == null) {
            return null;
        }
        pendingCorrection = null;
        if (result.isExpired(nowMs)) {
            return null;
        }
        return result;
    }

    @Nullable
    public synchronized PendingCorrection peekForTest() {
        return pendingCorrection;
    }

    public static final class PendingCorrection {
        @NonNull
        public final String stageName;
        public final long eventId;
        public final int validSamples;
        public final double meanOffsetX;
        public final double meanOffsetY;
        public final long createdAtMs;

        private PendingCorrection(@NonNull String stageName,
                                  long eventId,
                                  int validSamples,
                                  double meanOffsetX,
                                  double meanOffsetY,
                                  long createdAtMs) {
            this.stageName = stageName;
            this.eventId = eventId;
            this.validSamples = validSamples;
            this.meanOffsetX = meanOffsetX;
            this.meanOffsetY = meanOffsetY;
            this.createdAtMs = createdAtMs;
        }

        boolean isExpired(long nowMs) {
            return nowMs - createdAtMs > MAX_PENDING_AGE_MS;
        }
    }
}
