package com.lasercyber.lws.ui.common.rx.modbus;

import java.util.concurrent.atomic.AtomicReference;

/**
 * When active, the serial bus is reserved for controller OTA:
 * <ul>
 *   <li>{@link Phase#TRANSFER} — OTA writes only (no reads, no normal writes)</li>
 *   <li>{@link Phase#AWAIT_CONFIRM} — poll {@code otaUpgradeCmd} until device reports success/fail</li>
 * </ul>
 */
public final class ModbusOtaExclusiveSession {

    public enum Phase {
        NONE,
        TRANSFER,
        AWAIT_CONFIRM
    }

    private static final AtomicReference<Phase> PHASE = new AtomicReference<>(Phase.NONE);

    private ModbusOtaExclusiveSession() {
    }

    public static Phase currentPhase() {
        return PHASE.get();
    }

    public static boolean isActive() {
        return PHASE.get() != Phase.NONE;
    }

    public static void beginTransfer() {
        PHASE.set(Phase.TRANSFER);
    }

    /** @deprecated use {@link #beginTransfer()} */
    @Deprecated
    public static void begin() {
        beginTransfer();
    }

    public static void beginAwaitConfirm() {
        PHASE.set(Phase.AWAIT_CONFIRM);
    }

    public static void end() {
        PHASE.set(Phase.NONE);
    }

    static void resetForTest() {
        PHASE.set(Phase.NONE);
    }

    /**
     * @return rejection reason, or {@code null} if allowed
     */
    public static IllegalStateException checkBlocked(ModbusTraffic traffic) {
        Phase phase = PHASE.get();
        if (phase == Phase.NONE) {
            return null;
        }
        if (phase == Phase.TRANSFER) {
            if (traffic == ModbusTraffic.OTA_WRITE) {
                return null;
            }
            return blocked();
        }
        if (phase == Phase.AWAIT_CONFIRM) {
            if (traffic == ModbusTraffic.OTA_STATUS_READ) {
                return null;
            }
            return blocked();
        }
        return blocked();
    }

    private static IllegalStateException blocked() {
        return new IllegalStateException("Modbus blocked: controller OTA exclusive session active");
    }
}
