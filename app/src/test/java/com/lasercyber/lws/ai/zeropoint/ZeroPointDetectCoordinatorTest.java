package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectCoordinator;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class ZeroPointDetectCoordinatorTest {

    @Test
    public void shouldStartTask_onlyOnLaserEnableRisingEdge() {
        assertFalse(ZeroPointDetectCoordinator.shouldStartTaskOnLaserEnableRisingEdge(null, true));
        assertFalse(ZeroPointDetectCoordinator.shouldStartTaskOnLaserEnableRisingEdge(true, true));
        assertFalse(ZeroPointDetectCoordinator.shouldStartTaskOnLaserEnableRisingEdge(true, false));
        assertTrue(ZeroPointDetectCoordinator.shouldStartTaskOnLaserEnableRisingEdge(false, true));
    }

    @Test
    public void roundActive_reflectsActiveEventId() {
        ZeroPointDetectCoordinator coordinator = ZeroPointDetectCoordinator.getInstance();
        assertFalse(coordinator.isRoundActive());
        coordinator.activateRoundForTest();
        try {
            assertTrue(coordinator.isRoundActive());
        } finally {
            coordinator.deactivateRoundForTest();
        }
    }
}
