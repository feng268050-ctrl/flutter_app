package com.lasercyber.lws.ui.network.http.local;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiTimeline;

import org.junit.Assert;
import org.junit.Test;

import java.util.Collections;

public class ProcessVideoAiReplayJsonTest {

    @Test
    public void replayData_emptyFrames_emitsEmptyArray() {
        ProcessVideoAiTimeline timeline = new ProcessVideoAiTimeline("cache", 1000L, 200L);
        String json = ProcessVideoAiReplayJson.replayData("vid-empty", 999L, timeline);
        JsonObject root = new JsonParser().parse(json).getAsJsonObject();
        Assert.assertEquals("vid-empty", root.get("videoId").getAsString());
        Assert.assertEquals(0, root.getAsJsonArray("frames").size());
    }

    @Test
    public void replayData_emitsVersionAndFrames() {
        ProcessVideoAiTimeline timeline = new ProcessVideoAiTimeline("cache", 1000L, 200L);
        timeline.addFrame(new ProcessVideoAiTimeline.Frame(
                0L,
                1,
                "OK",
                "frame0",
                640,
                480,
                Collections.emptyList()));
        timeline.addFrame(new ProcessVideoAiTimeline.Frame(
                200L,
                2,
                "WARN",
                "frame1",
                640,
                480,
                Collections.emptyList()));

        String json = ProcessVideoAiReplayJson.replayData("vid-1", 1234L, timeline);
        JsonObject root = new JsonParser().parse(json).getAsJsonObject();
        Assert.assertEquals(ProcessVideoAiReplayJson.REPLAY_VERSION, root.get("version").getAsString());
        Assert.assertEquals("vid-1", root.get("videoId").getAsString());
        Assert.assertEquals(1234L, root.get("generatedAtMs").getAsLong());

        JsonArray frames = root.getAsJsonArray("frames");
        Assert.assertEquals(2, frames.size());
        Assert.assertEquals(200L, frames.get(1).getAsJsonObject().get("timestampMs").getAsLong());
        Assert.assertFalse(frames.get(1).getAsJsonObject().has("streamTimeMs"));
        Assert.assertEquals("WARN", frames.get(1).getAsJsonObject().get("status").getAsString());
    }

    @Test
    public void replayFrame_matchesSseRunningShape() {
        ProcessVideoAiTimeline timeline = new ProcessVideoAiTimeline("cache", 1000L, 200L);
        timeline.addFrame(new ProcessVideoAiTimeline.Frame(
                500L,
                0,
                OpencvStainDetectResult.OVERLAY_STATUS,
                "",
                1920,
                1080,
                Collections.singletonList(new ProcessVideoAiTimeline.Box(
                        870f, 524f, 894f, 548f, 0, "contamination", 1.0))));

        JsonObject frame = ProcessVideoAiReplayJson.runningFrameObject(
                timeline.snapshotFrames().get(0));

        Assert.assertEquals(500L, frame.get("timestampMs").getAsLong());
        Assert.assertEquals(StainDetectSource.OFFLINE, frame.get("source").getAsString());
        Assert.assertFalse(frame.has("stainDetect"));
        Assert.assertEquals(1, frame.getAsJsonArray("boxes").size());
        Assert.assertEquals("contamination",
                frame.getAsJsonArray("boxes").get(0).getAsJsonObject().get("label").getAsString());
    }
}
