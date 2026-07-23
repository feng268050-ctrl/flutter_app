package com.lasercyber.lws.ui.common.settings;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.After;
import org.junit.Test;

public class DangerousOperationsSettingsTest {

    @After
    public void tearDown() {
        DangerousOperationsSettings.resetForTest();
    }

    @Test
    public void defaultsDisabledWhenNoOverride() {
        assertFalse(DangerousOperationsSettings.isKeepLaserOnWhileAlarmed(null));
        assertFalse(DangerousOperationsSettings.isAllowWorkAfterCameraAlarm(null));
        assertFalse(DangerousOperationsSettings.isAllowWorkAfterGasAlarm(null));
        assertFalse(DangerousOperationsSettings.isAllowWorkAfterLensContamination(null));
        assertFalse(DangerousOperationsSettings.isAllowWorkAfterFeederAlarm(null));
    }

    @Test
    public void keepLaserOnWhileAlarmedOverride() {
        DangerousOperationsSettings.setOverridesForTest(null, null, null, true);
        assertTrue(DangerousOperationsSettings.isKeepLaserOnWhileAlarmed(null));
    }

    @Test
    public void overridesEnableBypass() {
        DangerousOperationsSettings.setOverridesForTest(true, true, true);
        assertTrue(DangerousOperationsSettings.isAllowWorkAfterCameraAlarm(null));
        assertTrue(DangerousOperationsSettings.isAllowWorkAfterGasAlarm(null));
        assertTrue(DangerousOperationsSettings.isAllowWorkAfterLensContamination(null));
    }

    @Test
    public void overridesCanBeIndependent() {
        DangerousOperationsSettings.setOverridesForTest(true, false, null);
        assertTrue(DangerousOperationsSettings.isAllowWorkAfterCameraAlarm(null));
        assertFalse(DangerousOperationsSettings.isAllowWorkAfterGasAlarm(null));
        assertFalse(DangerousOperationsSettings.isAllowWorkAfterLensContamination(null));
    }

    @Test
    public void feederOverrideIndependent() {
        DangerousOperationsSettings.setOverridesForTest(null, null, null, true, null);
        assertTrue(DangerousOperationsSettings.isAllowWorkAfterFeederAlarm(null));
        assertFalse(DangerousOperationsSettings.isAllowWorkAfterCameraAlarm(null));
    }
}
