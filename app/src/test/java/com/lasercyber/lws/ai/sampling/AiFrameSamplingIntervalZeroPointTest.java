package com.lasercyber.lws.ai.sampling;
import com.lasercyber.lws.ai.sampling.AiFrameSamplingGate;
import com.lasercyber.lws.ai.sampling.AiFrameSamplingInterval;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class AiFrameSamplingIntervalZeroPointTest {

    @Test
    public void zeroPointOnLaser_uses500msInterval() {
        assertEquals(500L, AiFrameSamplingInterval.ZERO_POINT_ON_LASER.getIntervalMs());
    }

    @Test
    public void zeroPointOnLaser_alignsWithLiveWeldAt500ms() {
        assertEquals(
                AiFrameSamplingInterval.LIVE_WELD.getIntervalMs(),
                AiFrameSamplingInterval.ZERO_POINT_ON_LASER.getIntervalMs());
        assertEquals(
                AiFrameSamplingInterval.AI_VISION_LIVE.getIntervalMs(),
                AiFrameSamplingInterval.ZERO_POINT_ON_LASER.getIntervalMs());

        AiFrameSamplingGate liveWeld = new AiFrameSamplingGate(AiFrameSamplingInterval.LIVE_WELD);
        AiFrameSamplingGate zeroPoint = new AiFrameSamplingGate(AiFrameSamplingInterval.ZERO_POINT_ON_LASER);
        assertTrue(liveWeld.tryAccept(1000L));
        assertFalse(liveWeld.tryAccept(1200L));
        assertTrue(zeroPoint.tryAccept(2000L));
        assertFalse(zeroPoint.tryAccept(2200L));
    }
}
