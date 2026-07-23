package com.lasercyber.lws.ui.common.ai.video;

import org.junit.Assert;
import org.junit.Test;

public class ProcessVideoAiSampleGridTest {

    private static final long INTERVAL_MS = 500L;

    @Test
    public void sampleGrid_skipsZeroMs_firstSampleAt500() {
        Assert.assertEquals(-1L, ProcessVideoAiSession.sampleMsForClockPosition(0L, INTERVAL_MS));
        Assert.assertEquals(-1L, ProcessVideoAiSession.sampleMsForClockPosition(499L, INTERVAL_MS));
        Assert.assertEquals(500L, ProcessVideoAiSession.sampleMsForClockPosition(500L, INTERVAL_MS));
        Assert.assertEquals(500L, ProcessVideoAiSession.sampleMsForClockPosition(999L, INTERVAL_MS));
        Assert.assertEquals(1000L, ProcessVideoAiSession.sampleMsForClockPosition(1000L, INTERVAL_MS));
        Assert.assertEquals(1000L, ProcessVideoAiSession.sampleMsForClockPosition(1499L, INTERVAL_MS));
    }

    @Test
    public void queuedInferSample_runsAfterPlaybackEnds_untilFinalized() {
        Assert.assertTrue(ProcessVideoAiSession.shouldRunQueuedInferSample(false));
        Assert.assertFalse(ProcessVideoAiSession.shouldRunQueuedInferSample(true));
    }
}
