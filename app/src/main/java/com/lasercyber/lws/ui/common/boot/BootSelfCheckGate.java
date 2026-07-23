package com.lasercyber.lws.ui.common.boot;

/**
 * Process-wide gate that suppresses overlapping async warn popups during boot self-check.
 */
public final class BootSelfCheckGate {

    private static volatile boolean active;

    private BootSelfCheckGate() {
    }

    public static boolean isActive() {
        return active;
    }

    public static synchronized void setActive(boolean value) {
        active = value;
    }

    /** Visible for unit tests. */
    static void resetForTest() {
        active = false;
    }
}
