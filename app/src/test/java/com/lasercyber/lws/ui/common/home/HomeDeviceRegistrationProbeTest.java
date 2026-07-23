package com.lasercyber.lws.ui.common.home;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.After;
import org.junit.Test;

public class HomeDeviceRegistrationProbeTest {

    @After
    public void tearDown() {
        HomeDeviceRegistrationProbe.resetForTest();
    }

    @Test
    public void skipStateClearsBindGate() {
        HomeDeviceRegistrationProbe.setStateForTest(
                HomeDeviceRegistrationProbe.State.SKIP, false);
        assertTrue(HomeDeviceRegistrationProbe.isBindGateCleared());
    }

    @Test
    public void failedStateClearsBindGate() {
        HomeDeviceRegistrationProbe.setStateForTest(
                HomeDeviceRegistrationProbe.State.FAILED, false);
        assertTrue(HomeDeviceRegistrationProbe.isBindGateCleared());
    }

    @Test
    public void needBindBlocksUntilDismissed() {
        HomeDeviceRegistrationProbe.setStateForTest(
                HomeDeviceRegistrationProbe.State.NEED_BIND, false);
        assertFalse(HomeDeviceRegistrationProbe.isBindGateCleared());

        HomeDeviceRegistrationProbe.onBindPromptDismissed();
        assertTrue(HomeDeviceRegistrationProbe.isBindGateCleared());
    }

    @Test
    public void loadingStateDoesNotClearBindGate() {
        HomeDeviceRegistrationProbe.setStateForTest(
                HomeDeviceRegistrationProbe.State.LOADING, false);
        assertFalse(HomeDeviceRegistrationProbe.isBindGateCleared());
    }
}
