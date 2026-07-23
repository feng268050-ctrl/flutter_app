package com.lasercyber.lws.ui.common.ai.video;

import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;

import org.junit.Assert;
import org.junit.Test;

import java.io.File;
import java.util.Collections;

public class ProcessVideoAiTimelinePersistenceTest {

    @Test
    public void saveAndLoad_roundTripsFramesAndClassification() throws Exception {
        File file = File.createTempFile("timeline-", ".json");
        file.deleteOnExit();
        ProcessVideoAiTimeline timeline = new ProcessVideoAiTimeline("cache-1", 5000L, 200L);
        timeline.addFrame(new ProcessVideoAiTimeline.Frame(
                0L,
                1,
                "CLEAN",
                "ok",
                1280,
                720,
                Collections.singletonList(new ProcessVideoAiTimeline.Box(
                        10f, 20f, 30f, 40f, 2, "stain", 0.9))));
        ProcessVideoAiTimelinePersistence.save(file, timeline, "cls=wood 0.88");
        Assert.assertTrue(ProcessVideoAiTimelinePersistence.hasReplayData(file));
        ProcessVideoAiTimelinePersistence.LoadedTimeline loaded =
                ProcessVideoAiTimelinePersistence.load(file);
        Assert.assertNotNull(loaded);
        Assert.assertEquals("cls=wood 0.88", loaded.classificationLine);
        Assert.assertEquals(1, loaded.timeline.snapshotFrames().size());
        Assert.assertEquals("CLEAN", loaded.timeline.snapshotFrames().get(0).status);
    }

    @Test
    public void saveAndLoad_emptyFrames_isReplayable() throws Exception {
        File file = File.createTempFile("timeline-empty-", ".json");
        file.deleteOnExit();
        ProcessVideoAiTimeline timeline = new ProcessVideoAiTimeline("cache-empty", 5000L, 200L);
        ProcessVideoAiTimelinePersistence.save(file, timeline, null);
        Assert.assertTrue(ProcessVideoAiTimelinePersistence.hasReplayData(file));
        ProcessVideoAiTimelinePersistence.LoadedTimeline loaded =
                ProcessVideoAiTimelinePersistence.load(file);
        Assert.assertNotNull(loaded);
        Assert.assertTrue(loaded.timeline.snapshotFrames().isEmpty());
    }

    @Test
    public void saveAndLoad_roundTripsBoxes() throws Exception {
        File file = File.createTempFile("timeline-boxes-", ".json");
        file.deleteOnExit();
        ProcessVideoAiTimeline timeline = new ProcessVideoAiTimeline("cache-boxes", 5000L, 200L);
        timeline.addFrame(new ProcessVideoAiTimeline.Frame(
                500L,
                0,
                OpencvStainDetectResult.OVERLAY_STATUS,
                "",
                1920,
                1080,
                Collections.singletonList(new ProcessVideoAiTimeline.Box(
                        870f, 524f, 894f, 548f, 0, "contamination", 1.0))));
        ProcessVideoAiTimelinePersistence.save(file, timeline, null);
        ProcessVideoAiTimelinePersistence.LoadedTimeline loaded =
                ProcessVideoAiTimelinePersistence.load(file);
        Assert.assertNotNull(loaded);
        Assert.assertEquals(1, loaded.timeline.snapshotFrames().size());
        Assert.assertEquals(1, loaded.timeline.snapshotFrames().get(0).boxes.size());
        Assert.assertFalse(loaded.timeline.snapshotFrames().get(0).boxes.get(0).label.isEmpty());
    }

    @Test
    public void temporalSummaryFrame_isDiscoverable() {
        ProcessVideoAiTimeline timeline = new ProcessVideoAiTimeline("cache-summary", 5000L, 200L);
        timeline.addFrame(new ProcessVideoAiTimeline.Frame(
                5000L,
                2,
                OpencvStainDetectResult.OVERLAY_STATUS,
                "",
                640,
                360,
                Collections.singletonList(new ProcessVideoAiTimeline.Box(
                        10f, 20f, 30f, 40f, 0, "contamination", 1.0)),
                null,
                true));
        ProcessVideoAiTimeline.Frame summary = timeline.findTemporalSummaryFrame();
        Assert.assertNotNull(summary);
        Assert.assertTrue(summary.temporalSummary);
        Assert.assertEquals(5000L, summary.timeMs);
    }

    @Test
    public void frame_carriesStainDetectSnapshot() {
        ProcessVideoAiTimeline.StainDetect lensDet = new ProcessVideoAiTimeline.StainDetect(
                true, 0, 882.0, 536.0, StainDetectSource.OFFLINE);
        ProcessVideoAiTimeline.Frame frame = new ProcessVideoAiTimeline.Frame(
                500L,
                0,
                "CLEAN",
                "",
                1920,
                1080,
                Collections.emptyList(),
                lensDet);
        Assert.assertNotNull(frame.stainDetect);
        Assert.assertTrue(frame.stainDetect.hasTarget());
        Assert.assertEquals(882.0, frame.stainDetect.targetX, 0.01);
        Assert.assertEquals(StainDetectSource.OFFLINE, frame.stainDetect.source);
    }
}
