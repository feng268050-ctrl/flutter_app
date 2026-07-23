package com.lasercyber.lws.ui.network.http.local;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.bean.event.WarnLogChangedEvent;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import org.junit.After;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Collections;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.atomic.AtomicReference;

public class MonitorAlertsSseHubTest {

    private final AtomicReference<java.util.List<WarnTable>> warnListRef = new AtomicReference<>();
    private ScheduledExecutorService executor;
    private MonitorAlertsSseHub hub;

    @Before
    public void setUp() {
        GsonInitUtils.initGson();
        executor = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread thread = new Thread(r, "monitor-alerts-test");
            thread.setDaemon(true);
            return thread;
        });
        warnListRef.set(Collections.emptyList());
        hub = new MonitorAlertsSseHub(warnListRef::get, executor);
    }

    @After
    public void tearDown() {
        hub.resetForTest();
        executor.shutdownNow();
        MonitorAlertsHttpPublisher.resetForTest();
    }

    @Test
    public void acquireSubscriber_emitsListFirst() throws Exception {
        WarnTable row = new WarnTable();
        row.setCode("C002");
        row.setContent("Camera fault");
        warnListRef.set(Collections.singletonList(row));

        MonitorAlertsSseHub.SseSubscriber sub = hub.acquireSubscriber();
        InputStream body = sub.getInputStream();
        JsonArray list = readEventArray(body, "list");
        Assert.assertEquals(1, list.size());
        Assert.assertEquals("C002", list.get(0).getAsJsonObject().get("code").getAsString());

        sub.closeFromClient();
    }

    @Test
    public void dispatchInserted_emitsNewPerRow() throws Exception {
        MonitorAlertsSseHub.SseSubscriber sub = hub.acquireSubscriber();
        InputStream body = sub.getInputStream();
        readEventArray(body, "list");

        WarnTable a = new WarnTable();
        a.setId(1L);
        a.setCode("A001");
        a.setContent("One");
        WarnTable b = new WarnTable();
        b.setId(2L);
        b.setCode("A002");
        b.setContent("Two");
        hub.dispatchWarnEvent(WarnLogChangedEvent.inserted(Arrays.asList(a, b)));

        JsonObject first = readEvent(body, "new");
        JsonObject second = readEvent(body, "new");
        Assert.assertEquals("A001", first.get("code").getAsString());
        Assert.assertEquals("A002", second.get("code").getAsString());

        sub.closeFromClient();
    }

    @Test
    public void dispatchCleared_emitsClear() throws Exception {
        MonitorAlertsSseHub.SseSubscriber sub = hub.acquireSubscriber();
        InputStream body = sub.getInputStream();
        readEventArray(body, "list");

        hub.dispatchWarnEvent(WarnLogChangedEvent.cleared());
        JsonObject clear = readEvent(body, "clear");
        Assert.assertEquals(0, clear.size());

        sub.closeFromClient();
    }

    @Test
    public void heartbeat_repeatsAfterFifteenSeconds() throws Exception {
        MonitorAlertsSseHub.SseSubscriber sub = hub.acquireSubscriber();
        InputStream body = sub.getInputStream();
        readEventArray(body, "list");

        hub.heartbeatTickAtForTest(0L);
        readEvent(body, "heartbeat");

        hub.heartbeatTickAtForTest(5_000L);
        Thread.sleep(30L);
        Assert.assertFalse(drainContains(body, "event: heartbeat"));

        hub.heartbeatTickAtForTest(16_000L);
        JsonObject second = readEvent(body, "heartbeat");
        Assert.assertTrue(second.get("ok").getAsBoolean());

        sub.closeFromClient();
    }

    @Test
    public void twoSubscribers_receiveSameNewAndClearSequence() throws Exception {
        warnListRef.set(Collections.emptyList());

        MonitorAlertsSseHub.SseSubscriber sub1 = hub.acquireSubscriber();
        InputStream body1 = sub1.getInputStream();
        readEventArray(body1, "list");

        MonitorAlertsSseHub.SseSubscriber sub2 = hub.acquireSubscriber();
        InputStream body2 = sub2.getInputStream();
        readEventArray(body2, "list");

        WarnTable row = new WarnTable();
        row.setId(3L);
        row.setCode("X001");
        row.setContent("Test");
        hub.dispatchWarnEvent(WarnLogChangedEvent.inserted(row));

        JsonObject new1 = readEvent(body1, "new");
        JsonObject new2 = readEvent(body2, "new");
        Assert.assertEquals(new1, new2);

        hub.dispatchWarnEvent(WarnLogChangedEvent.cleared());
        JsonObject clear1 = readEvent(body1, "clear");
        JsonObject clear2 = readEvent(body2, "clear");
        Assert.assertEquals(clear1, clear2);

        sub1.closeFromClient();
        sub2.closeFromClient();
    }

    private static JsonObject readEvent(InputStream body, String eventName) throws Exception {
        String data = readEventData(body, eventName);
        return new JsonParser().parse(data).getAsJsonObject();
    }

    private static JsonArray readEventArray(InputStream body, String eventName) throws Exception {
        String data = readEventData(body, eventName);
        return new JsonParser().parse(data).getAsJsonArray();
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
