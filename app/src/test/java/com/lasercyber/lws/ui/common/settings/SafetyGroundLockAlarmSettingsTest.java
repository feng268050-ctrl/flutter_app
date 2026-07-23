package com.lasercyber.lws.ui.common.settings;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.After;
import org.junit.Test;

public class SafetyGroundLockAlarmSettingsTest {

    @After
    public void reset() {
        SafetyGroundLockAlarmSettings.resetForTest();
    }

    @Test
    public void disabledByDefault() {
        assertFalse(SafetyGroundLockAlarmSettings.isEnabled(null));
    }

    @Test
    public void enabledWhenOptedIn() {
        SafetyGroundLockAlarmSettings.setEnabledOverrideForTest(true);
        assertTrue(SafetyGroundLockAlarmSettings.isEnabled(null));
    }

    @Test
    public void disabledWhenOptedOut() {
        SafetyGroundLockAlarmSettings.setEnabledOverrideForTest(false);
        assertFalse(SafetyGroundLockAlarmSettings.isEnabled(null));
    }
}
