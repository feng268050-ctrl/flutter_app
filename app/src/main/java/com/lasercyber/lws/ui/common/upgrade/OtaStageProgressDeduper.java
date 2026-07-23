package com.lasercyber.lws.ui.common.upgrade;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

/**
 * Remembers the last successfully delivered {@code device.update_progress} percent per stage so the
 * same {@code (stage, progress)} pair is not sent twice over WS.
 */
public final class OtaStageProgressDeduper {

    private final Map<String, Integer> lastDeliveredByStage = new HashMap<>();

    public synchronized boolean alreadyDelivered(@NonNull String stage, int progress) {
        Integer last = lastDeliveredByStage.get(stage);
        return last != null && last == progress;
    }

    public synchronized void markDelivered(@NonNull String stage, int progress) {
        lastDeliveredByStage.put(stage, progress);
    }

    public synchronized void reset() {
        lastDeliveredByStage.clear();
    }
}
