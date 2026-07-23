package com.lasercyber.lws.ui.common.ai.video;

import org.junit.Assert;
import org.junit.Test;

import java.util.Collections;

public class ProcessVideoAiTimelineTest {

    @Test
    public void findFrameAt_doesNotHoldForwardWhenLaterSampleHasNoBox() {
        ProcessVideoAiTimeline timeline = new ProcessVideoAiTimeline("cache", 5000L, 200L);
        timeline.addFrame(new ProcessVideoAiTimeline.Frame(
                200L, 0, "STAIN_DETECT", "",
                640, 360,
                Collections.singletonList(new ProcessVideoAiTimeline.Box(
                        10f, 20f, 30f, 40f, 0, "contamination", 1.0))));
        timeline.addFrame(new ProcessVideoAiTimeline.Frame(
                400L, 0, "STAIN_DETECT", "",
                640, 360,
                Collections.emptyList()));

        ProcessVideoAiTimeline.Frame at400 = timeline.findFrameAt(400L);
        Assert.assertNotNull(at400);
        Assert.assertEquals(400L, at400.timeMs);
        Assert.assertFalse(at400.hasDetection());
        Assert.assertTrue(at400.toOverlayBoxes().isEmpty());
    }

    @Test
    public void findFrameAt_returnsSampleWithBoxesWhenPresent() {
        ProcessVideoAiTimeline timeline = new ProcessVideoAiTimeline("cache", 5000L, 200L);
        timeline.addFrame(new ProcessVideoAiTimeline.Frame(
                200L, 0, "STAIN_DETECT", "",
                640, 360,
                Collections.singletonList(new ProcessVideoAiTimeline.Box(
                        10f, 20f, 30f, 40f, 0, "contamination", 1.0))));

        ProcessVideoAiTimeline.Frame at200 = timeline.findFrameAt(200L);
        Assert.assertNotNull(at200);
        Assert.assertTrue(at200.hasDetection());
        Assert.assertEquals(1, at200.toOverlayBoxes().size());
    }

    @Test
    public void findFrameAt_usesStainDetectTargetOnSameFrame() {
        ProcessVideoAiTimeline.StainDetect stainDetect = new ProcessVideoAiTimeline.StainDetect(
                true, 0, 100.0, 200.0, "offline");
        ProcessVideoAiTimeline timeline = new ProcessVideoAiTimeline("cache", 5000L, 200L);
        timeline.addFrame(new ProcessVideoAiTimeline.Frame(
                200L, 0, "STAIN_DETECT", "", 640, 360,
                Collections.emptyList(), stainDetect));

        ProcessVideoAiTimeline.Frame at200 = timeline.findFrameAt(200L);
        Assert.assertNotNull(at200);
        Assert.assertTrue(at200.hasDetection());
    }

    @Test
    public void findTemporalSummaryFrame_skipsHoldForwardLookup() {
        ProcessVideoAiTimeline timeline = new ProcessVideoAiTimeline("cache", 5000L, 200L);
        timeline.addFrame(new ProcessVideoAiTimeline.Frame(
                200L, 0, "STAIN_DETECT", "",
                640, 360,
                Collections.singletonList(new ProcessVideoAiTimeline.Box(
                        10f, 20f, 30f, 40f, 0, "contamination", 1.0))));
        timeline.addFrame(new ProcessVideoAiTimeline.Frame(
                5000L, 2, "STAIN_DETECT", "",
                640, 360,
                Collections.singletonList(new ProcessVideoAiTimeline.Box(
                        50f, 60f, 70f, 80f, 0, "contamination", 1.0)),
                null,
                true));

        Assert.assertNotNull(timeline.findTemporalSummaryFrame());
        ProcessVideoAiTimeline.Frame at5000 = timeline.findFrameAt(5000L);
        Assert.assertNotNull(at5000);
        Assert.assertTrue(at5000.temporalSummary);
    }
}
