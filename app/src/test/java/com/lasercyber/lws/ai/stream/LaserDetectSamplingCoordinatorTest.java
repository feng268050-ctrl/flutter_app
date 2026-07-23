package com.lasercyber.lws.ai.stream;
import com.lasercyber.lws.ai.model.OpencvDetectCodes;
import com.lasercyber.lws.ai.sampling.AiFrameSamplingInterval;
import com.lasercyber.lws.ai.stream.LaserDetectSamplingCoordinator;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectCoordinator;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Before;
import org.junit.Test;

public class LaserDetectSamplingCoordinatorTest {

    private LaserDetectSamplingCoordinator coordinator;

    @Before
    public void setUp() {
        coordinator = LaserDetectSamplingCoordinator.getInstance();
        coordinator.onLaserOff();
    }

    @Test
    public void frameRejected_entersBurstMode() {
        coordinator.reportDetectResult(
                LaserDetectSamplingCoordinator.Module.ZERO_POINT,
                false,
                OpencvDetectCodes.FRAME_REJECTED.code(),
                OpencvDetectCodes.REASON_SPOT_SIZE_ABOVE_MAX);
        assertTrue(coordinator.isBurstMode());
    }

    @Test
    public void burstExits_whenAllActiveModulesReturnOk() {
        ZeroPointDetectCoordinator.getInstance().activateRoundForTest();
        try {
            coordinator.reportDetectResult(
                    LaserDetectSamplingCoordinator.Module.LENS_DET,
                    false,
                    OpencvDetectCodes.FRAME_REJECTED.code(),
                    OpencvDetectCodes.REASON_SATURATED_WHITE_AREA_EXCEEDS_LIMIT);
            assertTrue(coordinator.isBurstMode());

            coordinator.reportDetectResult(
                    LaserDetectSamplingCoordinator.Module.LENS_DET,
                    true,
                    OpencvDetectCodes.OK.code(),
                    "");
            assertTrue(coordinator.isBurstMode());

            coordinator.reportDetectResult(
                    LaserDetectSamplingCoordinator.Module.ZERO_POINT,
                    true,
                    OpencvDetectCodes.OK.code(),
                    "");
            assertFalse(coordinator.isBurstMode());
        } finally {
            ZeroPointDetectCoordinator.getInstance().deactivateRoundForTest();
        }
    }

    @Test
    public void laserOff_resetsBurstMode() {
        coordinator.reportDetectResult(
                LaserDetectSamplingCoordinator.Module.ZERO_POINT,
                false,
                OpencvDetectCodes.FRAME_REJECTED.code(),
                OpencvDetectCodes.REASON_SPOT_SIZE_ABOVE_MAX);
        coordinator.onLaserOff();
        assertFalse(coordinator.isBurstMode());
    }

    @Test
    public void intervalConstants_liveWeld500_burst100() {
        assertEquals(500L, AiFrameSamplingInterval.LIVE_WELD.getIntervalMs());
        assertEquals(100L, AiFrameSamplingInterval.FRAME_REJECTED_BURST.getIntervalMs());
    }
}
