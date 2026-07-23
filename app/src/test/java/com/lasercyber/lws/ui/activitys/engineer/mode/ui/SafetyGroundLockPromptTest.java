package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.DeviceStatus;

import org.junit.Test;

public class SafetyGroundLockPromptTest {

    @Test
    public void eligibleWhenAlarmEnabledAndInterlockOpen() {
        DeviceStatus status = gunOnLockOpen();
        assertTrue(SafetyGroundLockPrompt.isEligibleForPrompt(status, true, true));
    }

    @Test
    public void notEligibleWhenAlarmDisabled() {
        DeviceStatus status = gunOnLockOpen();
        assertFalse(SafetyGroundLockPrompt.isEligibleForPrompt(status, true, false));
    }

    @Test
    public void notEligibleWhenLaserEnableOff() {
        DeviceStatus status = gunOnLockOpen();
        assertFalse(SafetyGroundLockPrompt.isEligibleForPrompt(status, false, true));
    }

    @Test
    public void notEligibleWhenGunReleased() {
        DeviceStatus status = new DeviceStatus();
        status.setMachineStatusSeg1(0);
        assertFalse(SafetyGroundLockPrompt.isEligibleForPrompt(status, true, true));
    }

    @Test
    public void notEligibleWhenInterlockConducting() {
        DeviceStatus status = new DeviceStatus();
        status.setMachineStatusSeg1((1 << 9) | (1 << 5));
        assertFalse(SafetyGroundLockPrompt.isEligibleForPrompt(status, true, true));
    }

    private static DeviceStatus gunOnLockOpen() {
        DeviceStatus status = new DeviceStatus();
        status.setMachineStatusSeg1(1 << 9);
        return status;
    }
}
