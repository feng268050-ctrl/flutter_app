package com.lasercyber.lws.ui.network.http.local;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;

import org.junit.Assert;
import org.junit.Test;

public class AiInferenceSseJsonTest {

    @Test
    public void runningData_usesPublisherTimestampOnly() {
        AiStainDetectResult result = new AiStainDetectResult(
                true,
                0,
                1,
                "MILD",
                "test",
                1920,
                1080,
                null,
                StainDetectSource.OFFLINE,
                9_999_999L);
        String json = AiInferenceSseJson.runningData(result, 500L, "session-1");
        JsonObject root = new JsonParser().parse(json).getAsJsonObject();
        Assert.assertEquals(500L, root.get("timestampMs").getAsLong());
        Assert.assertEquals("session-1", root.get("sessionId").getAsString());
        Assert.assertFalse(root.has("streamTimeMs"));
        Assert.assertEquals("MILD", root.get("status").getAsString());
        Assert.assertTrue(root.get("success").getAsBoolean());
    }

    @Test
    public void idleData_includesInferenceActive() {
        String json = AiInferenceSseJson.idleData(0L, true);
        JsonObject root = new JsonParser().parse(json).getAsJsonObject();
        Assert.assertEquals(0L, root.get("timestampMs").getAsLong());
        Assert.assertTrue(root.get("inferenceActive").getAsBoolean());
    }

    @Test
    public void startData_includesSessionFields() {
        String json = AiInferenceSseJson.startData(
                "sid", 0L, StainDetectSource.OFFLINE, 500L, 1920, 1080);
        JsonObject root = new JsonParser().parse(json).getAsJsonObject();
        Assert.assertEquals("sid", root.get("sessionId").getAsString());
        Assert.assertEquals(StainDetectSource.OFFLINE, root.get("source").getAsString());
        Assert.assertEquals(500L, root.get("samplingIntervalMs").getAsLong());
    }

    @Test
    public void runningData_omitsStainDetectSnapshot() {
        AiStainDetectResult stain = new AiStainDetectResult(
                true, 0, 0, "STAIN_DETECT", "", 1920, 1080, null, StainDetectSource.OFFLINE, 0L);
        String json = AiInferenceSseJson.runningData(stain, 500L, "sid");
        JsonObject root = new JsonParser().parse(json).getAsJsonObject();
        Assert.assertFalse(root.has("stainDetect"));
    }

    @Test
    public void stopData_includesReason() {
        String json = AiInferenceSseJson.stopData("sid", 1200L, "session_complete");
        JsonObject root = new JsonParser().parse(json).getAsJsonObject();
        Assert.assertEquals("session_complete", root.get("reason").getAsString());
        Assert.assertEquals(1200L, root.get("timestampMs").getAsLong());
    }
}
