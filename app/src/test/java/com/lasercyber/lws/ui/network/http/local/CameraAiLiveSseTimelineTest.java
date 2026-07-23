package com.lasercyber.lws.ui.network.http.local;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;

import org.junit.After;
import org.junit.Assert;
import org.junit.Test;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;

/**
 * Live camera SSE timeline: per-connection {@code timestampMs} from SSE subscribe time.
 */
public class CameraAiLiveSseTimelineTest {

    @After
    public void tearDown() {
        CameraAiHttpPublisher.resetForTest();
    }

    @Test
    public void acquire_firstEventIsIdle() throws Exception {
        AiInferenceSseHub hub = AiInferenceSseHub.forLiveCamera("test");
        AiInferenceSseHub.SseSubscriber sub = hub.acquireSubscriberAt(1_000_000L);
        InputStream body = sub.getInputStream();
        JsonObject idle = readFirstEvent(body, "idle");
        Assert.assertEquals(0L, idle.get("timestampMs").getAsLong());
        Assert.assertFalse(idle.get("inferenceActive").getAsBoolean());
        sub.closeFromClient();
        hub.resetForTest();
    }

    @Test
    public void publish_runningTimestampMsFromConnectionNotFirstSample() throws Exception {
        AiInferenceSseHub hub = AiInferenceSseHub.forLiveCamera("test");
        hub.notifySessionStarted(new AiInferenceSseJson.SessionStart(
                "sid", StainDetectSource.LIVE, 2000L, 640, 480));
        AiInferenceSseHub.SseSubscriber sub = hub.acquireSubscriberAt(1_000_000L);
        InputStream body = sub.getInputStream();

        AiStainDetectResult result = new AiStainDetectResult(
                true, 0, 1, "MILD", "ok", 640, 480, null, "live_infer", 5_000_000L);
        hub.publishLiveCameraRunningAt(result, 1_002_500L);

        JsonObject running = readFirstEvent(body, "running");
        Assert.assertEquals(2_500L, running.get("timestampMs").getAsLong());
        Assert.assertEquals("sid", running.get("sessionId").getAsString());

        sub.closeFromClient();
        hub.resetForTest();
    }

    @Test
    public void publish_eachSubscriberUsesOwnConnectionAnchor() throws Exception {
        AiInferenceSseHub hub = AiInferenceSseHub.forLiveCamera("test");
        hub.notifySessionStarted(new AiInferenceSseJson.SessionStart(
                "sid", StainDetectSource.LIVE, 2000L, null, null));
        AiInferenceSseHub.SseSubscriber subEarly = hub.acquireSubscriberAt(1_000_000L);
        AiInferenceSseHub.SseSubscriber subLate = hub.acquireSubscriberAt(1_010_000L);
        InputStream bodyLate = subLate.getInputStream();

        AiStainDetectResult result = new AiStainDetectResult(
                true, 0, 0, "CLEAN", "b", 640, 480, null, "live_infer", 2L);
        hub.publishLiveCameraRunningAt(result, 1_012_000L);

        JsonObject runningLate = readFirstEvent(bodyLate, "running");
        Assert.assertEquals(2_000L, runningLate.get("timestampMs").getAsLong());

        subEarly.closeFromClient();
        subLate.closeFromClient();
        hub.resetForTest();
    }

    @Test
    public void midJoin_replaysStartAfterIdle() throws Exception {
        AiInferenceSseHub hub = AiInferenceSseHub.forLiveCamera("test");
        hub.notifySessionStarted(new AiInferenceSseJson.SessionStart(
                "sid", StainDetectSource.LIVE, 2000L, null, null));
        AiInferenceSseHub.SseSubscriber sub = hub.acquireSubscriberAt(1_000_000L);
        InputStream body = sub.getInputStream();

        readFirstEvent(body, "idle");
        JsonObject start = readFirstEvent(body, "start");
        Assert.assertEquals("sid", start.get("sessionId").getAsString());
        Assert.assertEquals(0L, start.get("timestampMs").getAsLong());

        sub.closeFromClient();
        hub.resetForTest();
    }

    private static JsonObject readFirstEvent(InputStream body, String eventName) throws Exception {
        String data = readFirstEventData(body, eventName);
        return new JsonParser().parse(data).getAsJsonObject();
    }

    private static String readFirstEventData(InputStream body, String eventName) throws Exception {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        byte[] chunk = new byte[512];
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2);
        String marker = "event: " + eventName;
        while (System.nanoTime() < deadline) {
            int n = body.read(chunk);
            if (n > 0) {
                buf.write(chunk, 0, n);
                String text = buf.toString(StandardCharsets.UTF_8.name());
                int eventIdx = text.indexOf(marker);
                if (eventIdx < 0) {
                    continue;
                }
                int dataIdx = text.indexOf("data: ", eventIdx);
                if (dataIdx >= 0) {
                    int lineEnd = text.indexOf('\n', dataIdx);
                    if (lineEnd > dataIdx) {
                        return text.substring(dataIdx + 6, lineEnd).trim();
                    }
                }
            }
            Thread.sleep(10L);
        }
        Assert.fail("no " + eventName + " SSE frame within timeout");
        return "";
    }
}
