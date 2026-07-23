package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;
import androidx.annotation.VisibleForTesting;

/**
 * Reference-counted SSE stream for {@code GET /v1/monitor/stat}.
 */
public final class MonitorStatHttpPublisher {

    private static final MonitorStatHttpPublisher INSTANCE = new MonitorStatHttpPublisher();
    private final MonitorStatSseHub sseHub = new MonitorStatSseHub();

    private MonitorStatHttpPublisher() {
    }

    @NonNull
    public static MonitorStatHttpPublisher getInstance() {
        return INSTANCE;
    }

    @NonNull
    public MonitorStatSseHub.SseSubscriber acquire() {
        return sseHub.acquireSubscriber();
    }

    @VisibleForTesting
    static void resetForTest() {
        INSTANCE.sseHub.resetForTest();
    }
}
