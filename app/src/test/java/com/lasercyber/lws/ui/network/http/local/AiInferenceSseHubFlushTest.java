package com.lasercyber.lws.ui.network.http.local;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.model.NormalizedBox;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;

import org.junit.After;
import org.junit.Assert;
import org.junit.Test;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Verifies lifecycle events are readable from the SSE body stream without waiting for connection close.
 */
public class AiInferenceSseHubFlushTest {

    @After
    public void tearDown() {
        CameraAiHttpPublisher.resetForTest();
    }

    @Test
    public void publishRunning_eventReadableBeforeSubscriberClose() throws Exception {
        AiInferenceSseHub hub = AiInferenceSseHub.forProcessVideo("test", () -> 0L);
        hub.notifySessionStarted(new AiInferenceSseJson.SessionStart(
                "sid", StainDetectSource.OFFLINE, 500L, null, null));
        AiInferenceSseHub.SseSubscriber sub = hub.acquireSubscriber();
        InputStream body = sub.getInputStream();
        CountDownLatch published = new CountDownLatch(1);
        AtomicReference<Exception> readError = new AtomicReference<>();

        Thread reader = new Thread(() -> {
            try {
                byte[] buf = new byte[4096];
                while (published.getCount() > 0) {
                    int n = body.read(buf);
                    if (n > 0) {
                        String text = new String(buf, 0, n, StandardCharsets.UTF_8);
                        if (text.contains("event: running")) {
                            published.countDown();
                            return;
                        }
                    }
                }
            } catch (Exception e) {
                readError.set(e);
            }
        }, "sse-read");
        reader.start();

        AiStainDetectResult result = new AiStainDetectResult(
                true, 0, 1, "MILD", "test", 640, 480, null, "test", 1L);
        hub.publishRunning(result, 100L, "sid");

        Assert.assertTrue("running SSE frame not available before close",
                published.await(2, TimeUnit.SECONDS));
        Assert.assertNull(readError.get());

        reader.interrupt();
        reader.join(500L);
        sub.closeFromClient();
        hub.resetForTest();
    }

    @Test
    public void processVideo_summaryRunningBeforeStop() throws Exception {
        AtomicLong mediaMs = new AtomicLong(0L);
        AiInferenceSseHub hub = AiInferenceSseHub.forProcessVideo("test", mediaMs::get);
        hub.notifySessionStarted(new AiInferenceSseJson.SessionStart(
                "sid", StainDetectSource.OFFLINE, 500L, null, null));
        AiInferenceSseHub.SseSubscriber sub = hub.acquireSubscriber();
        InputStream body = sub.getInputStream();

        readEvent(body, "idle");
        readEvent(body, "start");

        AiStainDetectResult sample = new AiStainDetectResult(
                true, 0, 0, OpencvStainDetectResult.OVERLAY_STATUS, "",
                640, 360,
                java.util.Collections.singletonList(
                        NormalizedBox.fromPixelRect(10f, 20f, 30f, 40f, 640, 360, 0, "contamination", 1.0)),
                StainDetectSource.OFFLINE, 400L);
        hub.publishRunning(sample, 400L, "sid");
        readEvent(body, "running");

        AiStainDetectResult summary = new AiStainDetectResult(
                true, 0, 2, OpencvStainDetectResult.OVERLAY_STATUS, "",
                640, 360, sample.boxes, StainDetectSource.OFFLINE, 5000L);
        hub.publishRunning(summary, 5000L, "sid");
        JsonObject summaryRunning = readEvent(body, "running");
        Assert.assertEquals(5000L, summaryRunning.get("timestampMs").getAsLong());

        mediaMs.set(5000L);
        hub.notifySessionStopped("sid", "session_complete", 5000L);
        JsonObject stop = readEvent(body, "stop");
        Assert.assertEquals("session_complete", stop.get("reason").getAsString());

        sub.closeFromClient();
        hub.resetForTest();
    }

    @Test
    public void processVideo_lifecycleUsesMediaTimeline() throws Exception {
        AtomicLong mediaMs = new AtomicLong(0L);
        AiInferenceSseHub hub = AiInferenceSseHub.forProcessVideo("test", mediaMs::get);
        hub.notifySessionStarted(new AiInferenceSseJson.SessionStart(
                "sid", StainDetectSource.OFFLINE, 500L, null, null));
        AiInferenceSseHub.SseSubscriber sub = hub.acquireSubscriber();
        InputStream body = sub.getInputStream();

        JsonObject idle = readEvent(body, "idle");
        Assert.assertEquals(0L, idle.get("timestampMs").getAsLong());
        Assert.assertTrue(idle.get("inferenceActive").getAsBoolean());

        JsonObject start = readEvent(body, "start");
        Assert.assertEquals(0L, start.get("timestampMs").getAsLong());
        Assert.assertEquals(StainDetectSource.OFFLINE, start.get("source").getAsString());

        AiStainDetectResult result = new AiStainDetectResult(
                true, 0, 1, "MILD", "test", 640, 480, null, StainDetectSource.OFFLINE, 1L);
        hub.publishRunning(result, 500L, "sid");
        JsonObject running = readEvent(body, "running");
        Assert.assertEquals(500L, running.get("timestampMs").getAsLong());

        mediaMs.set(3000L);
        hub.notifySessionStopped("sid", "session_complete", 3000L);
        JsonObject stop = readEvent(body, "stop");
        Assert.assertEquals(3000L, stop.get("timestampMs").getAsLong());
        Assert.assertEquals("session_complete", stop.get("reason").getAsString());

        sub.closeFromClient();
        hub.resetForTest();
    }

    @Test
    public void sseFlushingResponse_disablesGzipAndWritesChunkPerFrame() throws Exception {
        AiInferenceSseHub hub = AiInferenceSseHub.forProcessVideo("test", () -> 0L);
        hub.notifySessionStarted(new AiInferenceSseJson.SessionStart(
                "sid", StainDetectSource.OFFLINE, 500L, null, null));
        AiInferenceSseHub.SseSubscriber sub = hub.acquireSubscriber();

        ByteArrayOutputStream captured = new ByteArrayOutputStream();
        SseFlushingResponse response = SseFlushingResponse.create(sub, () -> {});
        Assert.assertEquals("no", response.getHeader("X-Accel-Buffering"));

        Thread pump = new Thread(() -> response.send(captured), "sse-send");
        pump.start();
        Thread.sleep(50L);

        AiStainDetectResult result = new AiStainDetectResult(
                true, 0, 1, "MILD", "test", 640, 480, null, "test", 1L);
        hub.publishRunning(result, 100L, "sid");
        Thread.sleep(50L);
        sub.closeFromClient();
        pump.join(3000L);
        String body = captured.toString(StandardCharsets.UTF_8.name());
        Assert.assertFalse("SSE must not be gzip-encoded", body.contains("Content-Encoding: gzip"));
        Assert.assertTrue("chunked SSE body should contain running event",
                body.contains("event: running"));

        hub.resetForTest();
    }

    private static JsonObject readEvent(InputStream body, String eventName) throws Exception {
        String data = readEventData(body, eventName);
        return new JsonParser().parse(data).getAsJsonObject();
    }

    private static String readEventData(InputStream body, String eventName) throws Exception {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        byte[] chunk = new byte[512];
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2);
        String marker = "event: " + eventName;
        while (System.nanoTime() < deadline) {
            int n = body.read(chunk);
            if (n > 0) {
                buf.write(chunk, 0, n);
                String text = buf.toString(StandardCharsets.UTF_8.name());
                int from = 0;
                while (true) {
                    int eventIdx = text.indexOf(marker, from);
                    if (eventIdx < 0) {
                        break;
                    }
                    int dataIdx = text.indexOf("data: ", eventIdx);
                    if (dataIdx >= 0) {
                        int lineEnd = text.indexOf('\n', dataIdx);
                        if (lineEnd > dataIdx) {
                            return text.substring(dataIdx + 6, lineEnd).trim();
                        }
                    }
                    from = eventIdx + marker.length();
                }
            }
            Thread.sleep(10L);
        }
        Assert.fail("no " + eventName + " SSE frame within timeout");
        return "";
    }
}
