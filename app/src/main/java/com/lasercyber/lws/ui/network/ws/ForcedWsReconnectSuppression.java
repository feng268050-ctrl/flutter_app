package com.lasercyber.lws.ui.network.ws;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * In-memory only: after {@code command.disconnect}, blocks automatic WebSocket reconnect until this process exits.
 * App restart clears it so the device may connect again without rebooting the whole device.
 */
public final class ForcedWsReconnectSuppression {
    private static final AtomicBoolean SUPPRESS_RECONNECT = new AtomicBoolean(false);

    private ForcedWsReconnectSuppression() {
    }

    public static boolean isActive() {
        return SUPPRESS_RECONNECT.get();
    }

    public static void arm() {
        SUPPRESS_RECONNECT.set(true);
    }

    /** Reset (e.g. tests); normal flows rely on process death to clear. */
    public static void clear() {
        SUPPRESS_RECONNECT.set(false);
    }
}
