package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.stain.LensDetConsecutiveOkFilter;

import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiTimeline;

import org.junit.Assert;
import org.junit.Test;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

public class LensDetConsecutiveOkFilterTest {

    @Test
    public void effectiveOkMask_whenMinIsOne_matchesNative() {
        boolean[] nativeOk = {true, true, true, false, true};
        boolean[] effective = LensDetConsecutiveOkFilter.effectiveOkMask(nativeOk, 1);
        Assert.assertArrayEquals(nativeOk, effective);
    }

    @Test
    public void effectiveOkMask_requiresFourWhenConfigured() {
        boolean[] nativeOk = {true, true, true, false, true, true, true, true, true};
        boolean[] effective = LensDetConsecutiveOkFilter.effectiveOkMask(nativeOk, 4);
        Assert.assertArrayEquals(
                new boolean[] {false, false, false, false, true, true, true, true, true},
                effective);
    }

    @Test
    public void liveGate_publishesOnFirstFrameWhenMinIsOne() {
        LensDetConsecutiveOkFilter.LiveGate gate = new LensDetConsecutiveOkFilter.LiveGate();
        Assert.assertTrue(gate.acceptNativeOk(true, 1));
        Assert.assertTrue(gate.acceptNativeOk(true, 1));
        Assert.assertFalse(gate.acceptNativeOk(false, 1));
        Assert.assertTrue(gate.acceptNativeOk(true, 1));
    }

    @Test
    public void liveGate_publishesFromFourthFrameWhenMinIsFour() {
        LensDetConsecutiveOkFilter.LiveGate gate = new LensDetConsecutiveOkFilter.LiveGate();
        Assert.assertFalse(gate.acceptNativeOk(true, 4));
        Assert.assertFalse(gate.acceptNativeOk(true, 4));
        Assert.assertFalse(gate.acceptNativeOk(true, 4));
        Assert.assertTrue(gate.acceptNativeOk(true, 4));
        Assert.assertTrue(gate.acceptNativeOk(true, 4));
        Assert.assertFalse(gate.acceptNativeOk(false, 4));
        Assert.assertFalse(gate.acceptNativeOk(true, 4));
    }

    @Test
    public void liveGate_blueFrameRequiresFourBeforePublish() {
        LensDetConsecutiveOkFilter.LiveGate gate = new LensDetConsecutiveOkFilter.LiveGate();
        Assert.assertFalse(gate.acceptNativeOk(true, "blue", 1, 4));
        Assert.assertFalse(gate.acceptNativeOk(true, "blue", 1, 4));
        Assert.assertFalse(gate.acceptNativeOk(true, "blue", 1, 4));
        Assert.assertTrue(gate.acceptNativeOk(true, "blue", 1, 4));
    }

    @Test
    public void liveGate_resetsStreakWhenFrameKindChanges() {
        LensDetConsecutiveOkFilter.LiveGate gate = new LensDetConsecutiveOkFilter.LiveGate();
        Assert.assertTrue(gate.acceptNativeOk(true, "red", 1, 4));
        Assert.assertFalse(gate.acceptNativeOk(true, "blue", 1, 4));
    }

    @Test
    public void filterTimelineFrames_clearsShortRuns() {
        List<ProcessVideoAiTimeline.Frame> frames = Arrays.asList(
                frameWithBox(500L),
                frameWithBox(1000L),
                frameWithBox(1500L),
                cleanFrame(2000L),
                frameWithBox(2500L),
                frameWithBox(3000L),
                frameWithBox(3500L),
                frameWithBox(4000L),
                cleanFrame(4500L));
        List<ProcessVideoAiTimeline.Frame> filtered = ProcessVideoAiTimeline.filterTimelineFrames(
                frames,
                4);
        Assert.assertFalse(filtered.get(0).hasDetection());
        Assert.assertFalse(filtered.get(1).hasDetection());
        Assert.assertFalse(filtered.get(2).hasDetection());
        Assert.assertFalse(filtered.get(3).hasDetection());
        Assert.assertTrue(filtered.get(4).hasDetection());
        Assert.assertTrue(filtered.get(5).hasDetection());
        Assert.assertTrue(filtered.get(6).hasDetection());
        Assert.assertTrue(filtered.get(7).hasDetection());
        Assert.assertFalse(filtered.get(8).hasDetection());
    }

    private static ProcessVideoAiTimeline.Frame frameWithBox(long timeMs) {
        return new ProcessVideoAiTimeline.Frame(
                timeMs,
                2,
                OpencvStainDetectResult.OVERLAY_STATUS,
                "",
                640,
                480,
                Collections.singletonList(
                        new ProcessVideoAiTimeline.Box(10f, 10f, 30f, 30f, 0, "contamination", 1.0)));
    }

    private static ProcessVideoAiTimeline.Frame cleanFrame(long timeMs) {
        return new ProcessVideoAiTimeline.Frame(
                timeMs,
                0,
                "CLEAN",
                "",
                640,
                480,
                Collections.emptyList());
    }
}
