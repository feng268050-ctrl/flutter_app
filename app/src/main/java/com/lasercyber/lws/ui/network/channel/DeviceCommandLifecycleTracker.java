package com.lasercyber.lws.ui.network.channel;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public final class DeviceCommandLifecycleTracker {
    private static final Map<String, CommandDispatchStatus> STATUS_MAP = new ConcurrentHashMap<>();
    private static final Map<String, Long> DISPATCHED_AT_MAP = new ConcurrentHashMap<>();

    private DeviceCommandLifecycleTracker() {
    }

    public static void markAccepted(String correlationId) {
        STATUS_MAP.put(correlationId, CommandDispatchStatus.ACCEPTED);
    }

    public static void markDispatched(String correlationId) {
        STATUS_MAP.put(correlationId, CommandDispatchStatus.DISPATCHED);
        DISPATCHED_AT_MAP.put(correlationId, System.currentTimeMillis());
    }

    public static void markAcknowledged(String correlationId) {
        STATUS_MAP.put(correlationId, CommandDispatchStatus.ACKNOWLEDGED);
    }

    public static void markFailed(String correlationId) {
        STATUS_MAP.put(correlationId, CommandDispatchStatus.FAILED);
    }

    public static void markTimeoutIfNeeded(String correlationId, int timeoutMs) {
        Long dispatchedAt = DISPATCHED_AT_MAP.get(correlationId);
        if (dispatchedAt == null) {
            return;
        }
        if (System.currentTimeMillis() - dispatchedAt >= timeoutMs
                && STATUS_MAP.get(correlationId) == CommandDispatchStatus.DISPATCHED) {
            STATUS_MAP.put(correlationId, CommandDispatchStatus.TIMEOUT);
        }
    }

    public static CommandDispatchStatus getStatus(String correlationId) {
        return STATUS_MAP.get(correlationId);
    }
}
