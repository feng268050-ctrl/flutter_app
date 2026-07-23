package com.lasercyber.lws.ai.sampling;
import com.lasercyber.lws.ai.sampling.LiveInferGraceCoordinator;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class LiveInferGraceCoordinatorTest {

    @Test
    public void isLiveInferActive_laserEnableActive_alwaysTrue() {
        assertTrue(LiveInferGraceCoordinator.isLiveInferActive(true, 5000L, 0L));
        assertTrue(LiveInferGraceCoordinator.isLiveInferActive(true, 5000L, 8000L));
    }

    @Test
    public void isLiveInferActive_graceWindow_extendsAfterLaserEnableOff() {
        long graceEnd = 8000L;
        assertTrue(LiveInferGraceCoordinator.isLiveInferActive(false, 5000L, graceEnd));
        assertTrue(LiveInferGraceCoordinator.isLiveInferActive(false, 7999L, graceEnd));
        assertFalse(LiveInferGraceCoordinator.isLiveInferActive(false, 8000L, graceEnd));
    }

    @Test
    public void isLiveInferActive_noGrace_endsImmediatelyWhenLaserEnableOff() {
        assertFalse(LiveInferGraceCoordinator.isLiveInferActive(false, 1000L, 0L));
    }

    @Test
    public void defaultGrace_is3Seconds() {
        assertTrue(LiveInferGraceCoordinator.DEFAULT_GRACE_AFTER_LASER_OFF_MS == 3000L);
    }
}
