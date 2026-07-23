package com.lasercyber.lws.ui.network.http.local;

import org.junit.Assert;
import org.junit.Test;

public class LiveSseTimelineTest {

    @Test
    public void timelineMs_countsFromConnectionAnchor() {
        LiveSseTimeline timeline = new LiveSseTimeline(1_000_000L);
        Assert.assertEquals(0L, timeline.timelineMs(1_000_000L));
        Assert.assertEquals(2_000L, timeline.timelineMs(1_002_000L));
        Assert.assertEquals(500L, timeline.timelineMs(1_000_500L));
    }
}
