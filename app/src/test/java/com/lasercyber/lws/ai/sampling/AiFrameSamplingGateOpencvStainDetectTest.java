package com.lasercyber.lws.ai.sampling;
import com.lasercyber.lws.ai.sampling.AiFrameSamplingGate;
import com.lasercyber.lws.ai.sampling.AiFrameSamplingInterval;

import org.junit.Assert;
import org.junit.Test;

public class AiFrameSamplingGateOpencvStainDetectTest {

    @Test
    public void lensDetLiveWeldGateIndependentFromRknnLiveWeldGate() {
        AiFrameSamplingGate rknn = new AiFrameSamplingGate(AiFrameSamplingInterval.LIVE_WELD);
        AiFrameSamplingGate lensDet = new AiFrameSamplingGate(AiFrameSamplingInterval.LIVE_WELD);

        Assert.assertTrue(rknn.tryAccept(1000L));
        Assert.assertFalse(rknn.tryAccept(1200L));
        Assert.assertTrue(lensDet.tryAccept(1000L));
        Assert.assertFalse(lensDet.tryAccept(1200L));
        Assert.assertTrue(lensDet.tryAccept(1500L));
    }

    @Test
    public void lensDetLiveGateIndependentFromRknnLiveGate() {
        AiFrameSamplingGate rknn = new AiFrameSamplingGate(AiFrameSamplingInterval.AI_VISION_LIVE);
        AiFrameSamplingGate lensDet = new AiFrameSamplingGate(AiFrameSamplingInterval.AI_VISION_LIVE);

        Assert.assertTrue(rknn.tryAccept(100L));
        Assert.assertTrue(lensDet.tryAccept(100L));
        Assert.assertFalse(rknn.tryAccept(400L));
        Assert.assertFalse(lensDet.tryAccept(400L));
    }
}
