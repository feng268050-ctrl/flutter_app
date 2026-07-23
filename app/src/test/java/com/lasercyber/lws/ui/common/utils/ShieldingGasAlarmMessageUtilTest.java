package com.lasercyber.lws.ui.common.utils;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.DeviceStatus;

import org.junit.Test;

public class ShieldingGasAlarmMessageUtilTest {

    @Test
    public void hasActiveAlarm_falseWhenNoBits() {
        DeviceStatus status = new DeviceStatus();
        status.setControlCardAlarmSeg1(0);
        assertFalse(ShieldingGasAlarmMessageUtil.hasActiveAlarm(status));
        assertFalse(ShieldingGasAlarmMessageUtil.hasActiveAlarm(null));
    }

    @Test
    public void hasActiveAlarm_trueForEachBit() {
        for (int bit = 0; bit < 4; bit++) {
            DeviceStatus status = new DeviceStatus();
            status.setControlCardAlarmSeg1(1 << bit);
            assertTrue(ShieldingGasAlarmMessageUtil.hasActiveAlarm(status));
        }
    }

}
