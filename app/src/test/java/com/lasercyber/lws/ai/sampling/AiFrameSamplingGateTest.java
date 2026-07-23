package com.lasercyber.lws.ai.sampling;
import com.lasercyber.lws.ai.sampling.AiFrameSamplingGate;
import com.lasercyber.lws.ai.sampling.AiFrameSamplingInterval;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class AiFrameSamplingGateTest {

    private static final long INTERVAL_MS = 500L;

    @Test
    public void firstFrameAfterReset_isAcceptedImmediately() {
        AiFrameSamplingGate gate = new AiFrameSamplingGate(INTERVAL_MS);
        assertTrue(gate.tryAccept(1000L));
    }

    @Test
    public void frameWithinInterval_isRejected() {
        AiFrameSamplingGate gate = new AiFrameSamplingGate(INTERVAL_MS);
        assertTrue(gate.tryAccept(1000L));
        assertFalse(gate.tryAccept(1200L));
        assertFalse(gate.tryAccept(1499L));
    }

    @Test
    public void frameAtIntervalBoundary_isAccepted() {
        AiFrameSamplingGate gate = new AiFrameSamplingGate(INTERVAL_MS);
        assertTrue(gate.tryAccept(1000L));
        assertTrue(gate.tryAccept(1500L));
    }

    @Test
    public void burstAfterInterval_acceptsEachBoundary() {
        AiFrameSamplingGate gate = new AiFrameSamplingGate(INTERVAL_MS);
        assertTrue(gate.tryAccept(0L));
        assertTrue(gate.tryAccept(500L));
        assertTrue(gate.tryAccept(1000L));
        assertFalse(gate.tryAccept(1001L));
    }

    @Test
    public void reset_allowsImmediateAccept() {
        AiFrameSamplingGate gate = new AiFrameSamplingGate(INTERVAL_MS);
        assertTrue(gate.tryAccept(1000L));
        assertFalse(gate.tryAccept(1100L));
        gate.reset();
        assertTrue(gate.tryAccept(1100L));
    }

    @Test
    public void profileConstructor_usesProfileInterval() {
        AiFrameSamplingGate liveWeld = new AiFrameSamplingGate(AiFrameSamplingInterval.LIVE_WELD);
        AiFrameSamplingGate live = new AiFrameSamplingGate(AiFrameSamplingInterval.AI_VISION_LIVE);
        AiFrameSamplingGate processVideo = new AiFrameSamplingGate(AiFrameSamplingInterval.AI_VISION_PROCESS_VIDEO);
        assertTrue(liveWeld.getSampleIntervalMs() == 500L);
        assertTrue(live.getSampleIntervalMs() == 500L);
        assertTrue(processVideo.getSampleIntervalMs() == 500L);
    }
}
