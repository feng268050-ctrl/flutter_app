package com.lasercyber.lws.ui.common.rx.modbus;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Ensures only one device status/data poll cycle runs at a time across timer ticks.
 */
public final class ModbusPollCycleGuard {

    private static final AtomicBoolean IN_FLIGHT = new AtomicBoolean(false);

    private ModbusPollCycleGuard() {
    }

    /**
     * @return {@code true} if this tick may start a new poll cycle
     */
    public static boolean tryBegin() {
        return IN_FLIGHT.compareAndSet(false, true);
    }

    public static void end() {
        IN_FLIGHT.set(false);
    }

    public static boolean isCycleInFlight() {
        return IN_FLIGHT.get();
    }
}
