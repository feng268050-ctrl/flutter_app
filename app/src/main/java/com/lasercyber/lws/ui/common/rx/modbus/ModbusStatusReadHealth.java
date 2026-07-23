package com.lasercyber.lws.ui.common.rx.modbus;

import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.common.config.ControlCardCommAlarmMode;
import com.lasercyber.lws.ui.common.config.DeviceModelConfig;

/**
 * Tracks recent device-status Modbus poll outcomes for C001 (controller ↔ tablet comm).
 */
public final class ModbusStatusReadHealth {

    private static final ModbusStatusReadHealth INSTANCE = new ModbusStatusReadHealth();
    private final ModbusSegmentReadHealth delegate = new ModbusSegmentReadHealth();

    private ModbusStatusReadHealth() {
    }

    public static ModbusStatusReadHealth getInstance() {
        return INSTANCE;
    }

    /**
     * @param success {@code true} when all {@code createDeviceStatus()} fields were read.
     */
    public synchronized void recordOutcome(boolean success) {
        delegate.recordOutcome(success);
    }

    public synchronized boolean isFault() {
        return isFault(DeviceModelConfig.getControlCardCommAlarmMode());
    }

    @VisibleForTesting
    synchronized boolean isFault(ControlCardCommAlarmMode mode) {
        return delegate.isFault(mode);
    }

    @VisibleForTesting
    synchronized void resetForTest() {
        delegate.resetForTest();
    }
}
