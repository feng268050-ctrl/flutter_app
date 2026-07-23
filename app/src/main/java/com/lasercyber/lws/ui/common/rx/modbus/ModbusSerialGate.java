package com.lasercyber.lws.ui.common.rx.modbus;

import android.os.SystemClock;

import com.lasercyber.lws.ui.common.config.ModbusConfig;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Enforces {@link ModbusConfig#COMMAND_INTERVAL_MS} between Modbus command completions on the serial bus.
 */
public final class ModbusSerialGate {

    private static final ModbusSerialGate INSTANCE = new ModbusSerialGate();

    private final AtomicLong lastCommandEndMs = new AtomicLong(-1L);
    private final AtomicBoolean commandInFlight = new AtomicBoolean(false);
    private volatile long intervalMs = ModbusConfig.COMMAND_INTERVAL_MS;
    private volatile Clock clock = SystemClock::uptimeMillis;
    private volatile Sleeper sleeper = ms -> SystemClock.sleep(ms);

    @FunctionalInterface
    interface Clock {
        long uptimeMillis();
    }

    @FunctionalInterface
    interface Sleeper {
        void sleep(long ms);
    }

    public static ModbusSerialGate getInstance() {
        return INSTANCE;
    }

    static void resetForTest() {
        INSTANCE.lastCommandEndMs.set(-1L);
        INSTANCE.commandInFlight.set(false);
        INSTANCE.intervalMs = ModbusConfig.COMMAND_INTERVAL_MS;
        INSTANCE.clock = SystemClock::uptimeMillis;
        INSTANCE.sleeper = ms -> SystemClock.sleep(ms);
    }

    static void setClockForTest(Clock clock, Sleeper sleeper) {
        INSTANCE.clock = clock;
        INSTANCE.sleeper = sleeper;
    }

    public boolean isCommandInFlight() {
        return commandInFlight.get();
    }

    public void beginCommand() {
        commandInFlight.set(true);
    }

    public void endCommand() {
        commandInFlight.set(false);
    }

    /**
     * @return milliseconds slept to satisfy the command interval (0 if mock or already satisfied)
     */
    public long awaitBeforeCommand() {
        if (ModbusConfig.isMock()) {
            return 0L;
        }
        long lastEnd = lastCommandEndMs.get();
        if (lastEnd < 0L) {
            return 0L;
        }
        long elapsed = clock.uptimeMillis() - lastEnd;
        long waitMs = intervalMs - elapsed;
        if (waitMs > 0L) {
            sleeper.sleep(waitMs);
            ModbusPollDiagnostics.recordGateWait(waitMs);
            return waitMs;
        }
        return 0L;
    }

    public void markCommandEnd() {
        lastCommandEndMs.set(clock.uptimeMillis());
    }

    static void setCommandInFlightForTest(boolean inFlight) {
        INSTANCE.commandInFlight.set(inFlight);
    }
}
