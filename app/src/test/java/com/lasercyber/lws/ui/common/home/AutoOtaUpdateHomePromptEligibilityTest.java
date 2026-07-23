package com.lasercyber.lws.ui.common.home;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.common.upgrade.AutoCheckOtaUpdateSettings;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

/**
 * Eligibility matrix for {@link AutoOtaUpdateHomePrompt} dependencies (settings + bind gate).
 */
public class AutoOtaUpdateHomePromptEligibilityTest {

    @Before
    public void setUp() {
        AutoCheckOtaUpdateSettings.resetForTest();
        HomeDeviceRegistrationProbe.resetForTest();
    }

    @After
    public void tearDown() {
        AutoCheckOtaUpdateSettings.resetForTest();
        HomeDeviceRegistrationProbe.resetForTest();
    }

    @Test
    public void disabledSettingBlocksAutoCheck() {
        AutoCheckOtaUpdateSettings.setEnabledOverrideForTest(false);
        HomeDeviceRegistrationProbe.setStateForTest(
                HomeDeviceRegistrationProbe.State.SKIP, false);
        assertFalse(AutoCheckOtaUpdateSettings.isEnabled(null));
    }

    @Test
    public void enabledSettingWithBoundUsersAllowsGate() {
        AutoCheckOtaUpdateSettings.setEnabledOverrideForTest(true);
        HomeDeviceRegistrationProbe.setStateForTest(
                HomeDeviceRegistrationProbe.State.SKIP, false);
        assertTrue(AutoCheckOtaUpdateSettings.isEnabled(null));
        assertTrue(HomeDeviceRegistrationProbe.isBindGateCleared());
    }

    @Test
    public void pendingBindBlocksUntilDismissed() {
        AutoCheckOtaUpdateSettings.setEnabledOverrideForTest(true);
        HomeDeviceRegistrationProbe.setStateForTest(
                HomeDeviceRegistrationProbe.State.NEED_BIND, false);
        assertFalse(HomeDeviceRegistrationProbe.isBindGateCleared());
    }

    @Test
    public void dismissedBindAllowsGate() {
        AutoCheckOtaUpdateSettings.setEnabledOverrideForTest(true);
        HomeDeviceRegistrationProbe.setStateForTest(
                HomeDeviceRegistrationProbe.State.NEED_BIND, true);
        assertTrue(HomeDeviceRegistrationProbe.isBindGateCleared());
    }
}
