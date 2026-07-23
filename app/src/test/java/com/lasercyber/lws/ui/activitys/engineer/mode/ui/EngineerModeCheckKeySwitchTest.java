package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.config.ModbusConfig;

import org.junit.After;
import org.junit.Test;

public class EngineerModeCheckKeySwitchTest {

    @After
    public void tearDown() {
        ModbusConfig.resetForTest();
    }

    @Test
    public void emulator_skipsKeySwitchWhenOff() {
        ModbusConfig.setMockOverrideForTest(true);
        DeviceStatus status = healthyStatus();
        assertTrue(EngineerModeCheck.checkWorkStatus(null, status));
    }

    @Test
    public void nonEmulator_blocksWhenKeySwitchOff() {
        ModbusConfig.setMockOverrideForTest(false);
        DeviceStatus status = healthyStatus();
        assertTrue(EngineerModeCheck.isKeySwitchPreflightBlocking(status));
    }

    @Test
    public void nonEmulator_passesWhenKeySwitchOn() {
        ModbusConfig.setMockOverrideForTest(false);
        DeviceStatus status = healthyStatus();
        status.setMachineStatusSeg1(1 << 6);
        assertFalse(EngineerModeCheck.isKeySwitchPreflightBlocking(status));
    }

    private static DeviceStatus healthyStatus() {
        DeviceStatus status = new DeviceStatus();
        status.setMachineStatusSeg1(0);
        status.setControlCardAlarmSeg1(0);
        return status;
    }
}
