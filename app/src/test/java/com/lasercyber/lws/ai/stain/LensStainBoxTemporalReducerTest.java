package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.stain.LensStainBoxTemporalReducer;

import org.junit.Assert;
import org.junit.Test;

import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiTimeline;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class LensStainBoxTemporalReducerTest {

    private static ProcessVideoAiTimeline.Frame frame(
            int frameIndex, float x1, float y1, float x2, float y2) {
        long timeMs = (frameIndex + 1) * 200L;
        return new ProcessVideoAiTimeline.Frame(
                timeMs,
                0,
                OpencvStainDetectResult.OVERLAY_STATUS,
                "",
                640,
                360,
                Collections.singletonList(new ProcessVideoAiTimeline.Box(
                        x1, y1, x2, y2, 0, "contamination", 1.0)));
    }

    @Test
    public void reduce_emptyInput_returnsClean() {
        LensStainBoxTemporalReducer.Result result =
                LensStainBoxTemporalReducer.reduce(Collections.emptyList());
        Assert.assertFalse(result.hasContamination());
        Assert.assertTrue(result.boxes.isEmpty());
    }

    @Test
    public void reduce_singleFrame_discardsBox() {
        List<ProcessVideoAiTimeline.Frame> frames = Collections.singletonList(
                frame(0, 100f, 100f, 120f, 120f));
        LensStainBoxTemporalReducer.Result result = LensStainBoxTemporalReducer.reduce(frames);
        Assert.assertFalse(result.hasContamination());
    }

    @Test
    public void reduce_twoFrames_discardsBox() {
        List<ProcessVideoAiTimeline.Frame> frames = new ArrayList<>();
        frames.add(frame(0, 100f, 100f, 120f, 120f));
        frames.add(frame(1, 101f, 101f, 121f, 121f));
        LensStainBoxTemporalReducer.Result result = LensStainBoxTemporalReducer.reduce(frames);
        Assert.assertFalse(result.hasContamination());
    }

    @Test
    public void reduce_threeDistinctFrames_keepsCluster() {
        List<ProcessVideoAiTimeline.Frame> frames = new ArrayList<>();
        frames.add(frame(0, 100f, 100f, 120f, 120f));
        frames.add(frame(1, 102f, 102f, 122f, 122f));
        frames.add(frame(2, 104f, 104f, 124f, 124f));
        LensStainBoxTemporalReducer.Result result = LensStainBoxTemporalReducer.reduce(frames);
        Assert.assertTrue(result.hasContamination());
        Assert.assertEquals(1, result.boxes.size());
    }

    @Test
    public void reduce_sameFrameDuplicateCountsOnce() {
        List<ProcessVideoAiTimeline.Box> twoBoxes = new ArrayList<>();
        twoBoxes.add(new ProcessVideoAiTimeline.Box(
                100f, 100f, 120f, 120f, 0, "contamination", 1.0));
        twoBoxes.add(new ProcessVideoAiTimeline.Box(
                105f, 105f, 125f, 125f, 0, "contamination", 1.0));
        ProcessVideoAiTimeline.Frame multiBox = new ProcessVideoAiTimeline.Frame(
                200L, 0, OpencvStainDetectResult.OVERLAY_STATUS, "", 640, 360, twoBoxes);
        List<ProcessVideoAiTimeline.Frame> frames = new ArrayList<>();
        frames.add(multiBox);
        frames.add(frame(1, 102f, 102f, 122f, 122f));
        LensStainBoxTemporalReducer.Result result = LensStainBoxTemporalReducer.reduce(frames);
        Assert.assertFalse(result.hasContamination());
    }

    @Test
    public void reduce_toleranceMerge_withinTenPixels() {
        List<ProcessVideoAiTimeline.Frame> frames = new ArrayList<>();
        frames.add(frame(0, 100f, 100f, 120f, 120f));
        frames.add(frame(1, 118f, 118f, 138f, 138f));
        frames.add(frame(2, 109f, 109f, 129f, 129f));
        LensStainBoxTemporalReducer.Result result = LensStainBoxTemporalReducer.reduce(frames);
        Assert.assertTrue(result.hasContamination());
        Assert.assertEquals(1, result.boxes.size());
    }

    @Test
    public void expandedRectsIntersect_respectsTolerance() {
        Assert.assertTrue(LensStainBoxTemporalReducer.expandedRectsIntersect(
                100f, 100f, 120f, 120f,
                130f, 130f, 150f, 150f,
                LensStainBoxTemporalReducer.BOX_CLUSTER_TOLERANCE_PX));
        Assert.assertFalse(LensStainBoxTemporalReducer.expandedRectsIntersect(
                100f, 100f, 120f, 120f,
                200f, 200f, 220f, 220f,
                LensStainBoxTemporalReducer.BOX_CLUSTER_TOLERANCE_PX));
    }

    @Test
    public void reduce_skipsTemporalSummaryFrames() {
        List<ProcessVideoAiTimeline.Frame> frames = new ArrayList<>();
        frames.add(frame(0, 100f, 100f, 120f, 120f));
        frames.add(new ProcessVideoAiTimeline.Frame(
                5000L, 2, OpencvStainDetectResult.OVERLAY_STATUS, "", 640, 360,
                Collections.singletonList(new ProcessVideoAiTimeline.Box(
                        200f, 200f, 220f, 220f, 0, "contamination", 1.0)),
                null,
                true));
        LensStainBoxTemporalReducer.Result result = LensStainBoxTemporalReducer.reduce(frames);
        Assert.assertFalse(result.hasContamination());
    }
}
