package com.lasercyber.lws.ui.network.http.local;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import org.junit.After;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.atomic.AtomicReference;

public class MonitorStatSseHubTest {

  private final AtomicReference<MonitorStatSnapshot> snapshotRef = new AtomicReference<>();
    private ScheduledExecutorService executor;
    private MonitorStatSseHub hub;

    @Before
    public void setUp() {
        GsonInitUtils.initGson();
        executor = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread thread = new Thread(r, "monitor-stat-test");
            thread.setDaemon(true);
            return thread;
        });
        snapshotRef.set(MonitorStatSnapshot.fromRaw(null, null, 1));
        hub = new MonitorStatSseHub(snapshotRef::get, executor);
    }

    @After
    public void tearDown() {
        hub.resetForTest();
        executor.shutdownNow();
        MonitorStatHttpPublisher.resetForTest();
    }

    @Test
    public void encodeEvent_usesSseFramingWithBlankSeparator() {
        byte[] frame = MonitorStatSseHub.encodeEvent("stat", "{\"ok\":true}");
        String text = new String(frame, StandardCharsets.UTF_8);
        Assert.assertEquals("event: stat\ndata: {\"ok\":true}\n\n", text);
    }

    @Test
    public void unchangedSnapshot_doesNotEmitStat() throws Exception {
        DeviceStatus status = new DeviceStatus();
        status.setDeviceType(1);
        status.setMachineStatusSeg1(0);
        DeviceData data = new DeviceData();
        data.setLaserCurrent(10);
        MonitorStatSnapshot stable = MonitorStatSnapshot.fromRaw(status, data, 1);
        snapshotRef.set(stable);

        MonitorStatSseHub.SseSubscriber sub = hub.acquireSubscriber();
        InputStream body = sub.getInputStream();
        readEvent(body, "stat");
        hub.sampleTickForTest();
        readEvent(body, "heartbeat");

        for (int i = 0; i < 12; i++) {
            hub.sampleTickForTest();
        }
        Thread.sleep(50L);
        Assert.assertFalse(drainContains(body, "event: stat"));

        sub.closeFromClient();
    }

    @Test
    public void acquireSubscriber_emitsImmediateStatWithoutWaitingForChange() throws Exception {
        DeviceStatus status = new DeviceStatus();
        status.setDeviceType(1);
        status.setMachineStatusSeg1(0);
        DeviceData data = new DeviceData();
        data.setLaserCurrent(10);
        snapshotRef.set(MonitorStatSnapshot.fromRaw(status, data, 1));

        MonitorStatSseHub.SseSubscriber sub = hub.acquireSubscriber();
        InputStream body = sub.getInputStream();
        JsonObject stat = readEvent(body, "stat");
        Assert.assertEquals(10, stat.getAsJsonObject("deviceData").get("laserCurrent").getAsInt());

        sub.closeFromClient();
    }

    @Test
    public void changedSnapshot_emitsStatOncePerChange() throws Exception {
        DeviceStatus status = new DeviceStatus();
        status.setDeviceType(1);
        DeviceData data = new DeviceData();
        data.setLaserCurrent(10);
        snapshotRef.set(MonitorStatSnapshot.fromRaw(status, data, 1));

        MonitorStatSseHub.SseSubscriber sub = hub.acquireSubscriber();
        InputStream body = sub.getInputStream();
        hub.sampleTickForTest();

        JsonObject first = readEvent(body, "stat");
        Assert.assertTrue(first.has("deviceStatus"));
        Assert.assertTrue(first.has("deviceData"));
        Assert.assertTrue(first.has("processParameters"));
        Assert.assertEquals(1, first.getAsJsonObject("deviceStatus").get("cameraStatus").getAsInt());
        Assert.assertEquals(10, first.getAsJsonObject("deviceData").get("laserCurrent").getAsInt());

        data.setLaserCurrent(11);
        snapshotRef.set(MonitorStatSnapshot.fromRaw(status, data, 1));
        hub.sampleTickForTest();
        JsonObject second = readEvent(body, "stat");
        Assert.assertEquals(11, second.getAsJsonObject("deviceData").get("laserCurrent").getAsInt());

        hub.sampleTickForTest();
        Thread.sleep(30L);
        Assert.assertFalse(drainContains(body, "event: stat"));

        sub.closeFromClient();
    }

    @Test
    public void changedProcessParameters_emitsStat() throws Exception {
        DeviceStatus status = new DeviceStatus();
        status.setDeviceType(1);
        ProcessParametersData params = new ProcessParametersData();
        params.setLaserPower(50);
        snapshotRef.set(MonitorStatSnapshot.fromRaw(status, null, 1, params));

        MonitorStatSseHub.SseSubscriber sub = hub.acquireSubscriber();
        InputStream body = sub.getInputStream();
        hub.sampleTickForTest();
        JsonObject first = readEvent(body, "stat");
        Assert.assertEquals(50, first.getAsJsonObject("processParameters").get("laserPower").getAsInt());

        params.setLaserPower(60);
        snapshotRef.set(MonitorStatSnapshot.fromRaw(status, null, 1, params));
        hub.sampleTickForTest();
        JsonObject second = readEvent(body, "stat");
        Assert.assertEquals(60, second.getAsJsonObject("processParameters").get("laserPower").getAsInt());

        sub.closeFromClient();
    }

    @Test
    public void heartbeat_repeatsAfterFifteenSeconds() throws Exception {
        DeviceStatus status = new DeviceStatus();
        status.setDeviceType(1);
        snapshotRef.set(MonitorStatSnapshot.fromRaw(status, null, 1));

        MonitorStatSseHub.SseSubscriber sub = hub.acquireSubscriber();
        InputStream body = sub.getInputStream();
        hub.sampleTickAtForTest(0L);
        readEvent(body, "heartbeat");

        hub.sampleTickAtForTest(5_000L);
        Thread.sleep(30L);
        Assert.assertFalse(drainContains(body, "event: heartbeat"));

        hub.sampleTickAtForTest(16_000L);
        JsonObject second = readEvent(body, "heartbeat");
        Assert.assertTrue(second.get("ok").getAsBoolean());

        sub.closeFromClient();
    }

    @Test
    public void scheduledSampler_ticksAtApproximately100ms() throws Exception {
        DeviceStatus status = new DeviceStatus();
        status.setDeviceType(1);
        DeviceData data = new DeviceData();
        data.setLaserCurrent(5);
        snapshotRef.set(MonitorStatSnapshot.fromRaw(status, data, 1));

        ScheduledExecutorService liveExecutor = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread thread = new Thread(r, "monitor-stat-live-test");
            thread.setDaemon(true);
            return thread;
        });
        MonitorStatSseHub liveHub = MonitorStatSseHub.forLiveSampling(snapshotRef::get, liveExecutor);
        try {
            MonitorStatSseHub.SseSubscriber sub = liveHub.acquireSubscriber();
            InputStream body = sub.getInputStream();

            readEvent(body, "stat");
            data.setLaserCurrent(6);
            snapshotRef.set(MonitorStatSnapshot.fromRaw(status, data, 1));

            long start = System.nanoTime();
            readEvent(body, "stat");
            long elapsedMs = (System.nanoTime() - start) / 1_000_000L;
            Assert.assertTrue("changed stat should arrive within sampling tolerance",
                    elapsedMs < 500L);

            sub.closeFromClient();
            liveHub.resetForTest();
        } finally {
            liveExecutor.shutdownNow();
        }
    }

    @Test
    public void sseFlushingResponse_setsExpectedHeadersAndFraming() throws Exception {
        DeviceStatus status = new DeviceStatus();
        status.setDeviceType(1);
        snapshotRef.set(MonitorStatSnapshot.fromRaw(status, null, 1));

        MonitorStatSseHub.SseSubscriber sub = hub.acquireSubscriber();
        SseFlushingResponse response = SseFlushingResponse.create(sub, () -> {});
        Assert.assertEquals(AiInferenceSseHub.MIME_SSE, response.getMimeType());
        Assert.assertEquals("no", response.getHeader("X-Accel-Buffering"));
        Assert.assertEquals("no-cache", response.getHeader("Cache-Control"));

        hub.sampleTickForTest();
        byte[] frame = sub.pollChunk(500L);
        Assert.assertNotNull(frame);
        String text = new String(frame, StandardCharsets.UTF_8);
        Assert.assertTrue(text.startsWith("event: "));
        Assert.assertTrue(text.contains("\ndata: "));
        Assert.assertTrue(text.endsWith("\n\n"));

        sub.closeFromClient();
    }

    @Test
    public void twoSubscribers_receiveSameStatSequence() throws Exception {
        DeviceStatus status = new DeviceStatus();
        status.setDeviceType(1);
        DeviceData data = new DeviceData();
        data.setLaserCurrent(5);
        snapshotRef.set(MonitorStatSnapshot.fromRaw(status, data, 1));

        MonitorStatSseHub.SseSubscriber sub1 = hub.acquireSubscriber();
        InputStream body1 = sub1.getInputStream();
        JsonObject stat1 = readEvent(body1, "stat");

        MonitorStatSseHub.SseSubscriber sub2 = hub.acquireSubscriber();
        InputStream body2 = sub2.getInputStream();
        JsonObject stat2 = readEvent(body2, "stat");
        Assert.assertEquals(stat1, stat2);

        data.setLaserCurrent(6);
        snapshotRef.set(MonitorStatSnapshot.fromRaw(status, data, 1));
        hub.sampleTickForTest();

        JsonObject next1 = readEvent(body1, "stat");
        JsonObject next2 = readEvent(body2, "stat");
        Assert.assertEquals(next1, next2);
        Assert.assertEquals(6, next1.getAsJsonObject("deviceData").get("laserCurrent").getAsInt());

        sub1.closeFromClient();
        sub2.closeFromClient();
    }

    private static JsonObject readEvent(InputStream body, String eventName) throws Exception {
        String data = readEventData(body, eventName);
        return new JsonParser().parse(data).getAsJsonObject();
    }

    private static String readEventData(InputStream body, String eventName) throws Exception {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        byte[] chunk = new byte[512];
        long deadline = System.nanoTime() + java.util.concurrent.TimeUnit.SECONDS.toNanos(2);
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

    private static boolean drainContains(InputStream body, String marker) throws Exception {
        byte[] chunk = new byte[512];
        long deadline = System.nanoTime() + java.util.concurrent.TimeUnit.MILLISECONDS.toNanos(150);
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        while (System.nanoTime() < deadline) {
            int n = body.read(chunk);
            if (n > 0) {
                buf.write(chunk, 0, n);
                if (buf.toString(StandardCharsets.UTF_8.name()).contains(marker)) {
                    return true;
                }
            }
            Thread.sleep(10L);
        }
        return buf.toString(StandardCharsets.UTF_8.name()).contains(marker);
    }
}
