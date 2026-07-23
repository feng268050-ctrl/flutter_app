package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.bean.event.WarnLogChangedEvent;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Supplier;

/**
 * Fan-out Server-Sent Events for {@code GET /v1/monitor/alerts}.
 */
public final class MonitorAlertsSseHub {

    private static final long HEARTBEAT_INTERVAL_MS = 15_000L;
    private static final int QUEUE_CAPACITY = 64;

    private final Object lock = new Object();
    private final List<SseSubscriber> subscribers = new ArrayList<>();
    private final Supplier<List<WarnTable>> warnListSupplier;
    private final ScheduledExecutorService heartbeatExecutor;
    private final boolean autoSchedule;
    @Nullable
    private ScheduledFuture<?> heartbeatFuture;
    private long lastHeartbeatAtMs = -1L;
    private boolean eventBusRegistered;

    public MonitorAlertsSseHub(@NonNull Supplier<List<WarnTable>> warnListSupplier) {
        this(warnListSupplier, createDefaultHeartbeatExecutor(), true);
    }

    @VisibleForTesting
    MonitorAlertsSseHub(@NonNull Supplier<List<WarnTable>> warnListSupplier,
                        @NonNull ScheduledExecutorService heartbeatExecutor) {
        this(warnListSupplier, heartbeatExecutor, false);
    }

    private MonitorAlertsSseHub(@NonNull Supplier<List<WarnTable>> warnListSupplier,
                                @NonNull ScheduledExecutorService heartbeatExecutor,
                                boolean autoSchedule) {
        this.warnListSupplier = warnListSupplier;
        this.heartbeatExecutor = heartbeatExecutor;
        this.autoSchedule = autoSchedule;
    }

    public int getSubscriberCount() {
        synchronized (lock) {
            return subscribers.size();
        }
    }

    @NonNull
    public SseSubscriber acquireSubscriber() {
        synchronized (lock) {
            ensureEventBusRegisteredLocked();
            SseSubscriber sub = new SseSubscriber(this);
            subscribers.add(sub);
            startHeartbeatLocked();
            emitListLocked(sub);
            return sub;
        }
    }

    @Subscribe(threadMode = ThreadMode.BACKGROUND)
    public void onWarnLogChanged(@NonNull WarnLogChangedEvent event) {
        dispatchWarnEvent(event);
    }

    @VisibleForTesting
    void dispatchWarnEvent(@NonNull WarnLogChangedEvent event) {
        if (event.getKind() == WarnLogChangedEvent.Kind.CLEARED) {
            byte[] frame = encodeEvent("clear", MonitorAlertsSseJson.clearData());
            fanOut(frame);
            return;
        }
        List<WarnTable> inserted = event.getInsertedRows();
        if (inserted == null || inserted.isEmpty()) {
            return;
        }
        for (WarnTable row : inserted) {
            if (row.getId() == null) {
                continue;
            }
            byte[] frame = encodeEvent("new", MonitorAlertsSseJson.newData(row));
            fanOut(frame);
        }
    }

    private void fanOut(@NonNull byte[] frame) {
        synchronized (lock) {
            if (subscribers.isEmpty()) {
                return;
            }
            for (SseSubscriber sub : subscribers) {
                sub.offer(frame);
            }
        }
    }

    void releaseSubscriber(@NonNull SseSubscriber subscriber) {
        synchronized (lock) {
            if (!subscribers.remove(subscriber)) {
                return;
            }
            subscriber.closeInternal();
            if (subscribers.isEmpty()) {
                stopHeartbeatLocked();
            }
        }
    }

    @VisibleForTesting
    void heartbeatTickForTest() {
        heartbeatTick(System.currentTimeMillis());
    }

    @VisibleForTesting
    void heartbeatTickAtForTest(long nowMs) {
        heartbeatTick(nowMs);
    }

    @VisibleForTesting
    void resetForTest() {
        synchronized (lock) {
            stopHeartbeatLocked();
            lastHeartbeatAtMs = -1L;
            for (SseSubscriber sub : subscribers) {
                sub.closeInternal();
            }
            subscribers.clear();
            if (eventBusRegistered) {
                EventBus.getDefault().unregister(this);
                eventBusRegistered = false;
            }
        }
    }

    private void ensureEventBusRegisteredLocked() {
        if (!eventBusRegistered) {
            EventBus.getDefault().register(this);
            eventBusRegistered = true;
        }
    }

    private void emitListLocked(@NonNull SseSubscriber sub) {
        List<WarnTable> warns = warnListSupplier.get();
        sub.offer(encodeEvent("list", MonitorAlertsSseJson.listData(warns)));
    }

    private void startHeartbeatLocked() {
        if (!autoSchedule || (heartbeatFuture != null && !heartbeatFuture.isCancelled())) {
            return;
        }
        heartbeatFuture = heartbeatExecutor.scheduleAtFixedRate(
                () -> heartbeatTick(System.currentTimeMillis()),
                0L,
                HEARTBEAT_INTERVAL_MS,
                TimeUnit.MILLISECONDS);
    }

    private void stopHeartbeatLocked() {
        if (heartbeatFuture != null) {
            heartbeatFuture.cancel(false);
            heartbeatFuture = null;
        }
    }

    private void heartbeatTick(long nowMs) {
        byte[] heartbeatFrame = null;
        synchronized (lock) {
            if (subscribers.isEmpty()) {
                return;
            }
            boolean heartbeatDue = lastHeartbeatAtMs < 0L
                    || nowMs - lastHeartbeatAtMs >= HEARTBEAT_INTERVAL_MS;
            if (heartbeatDue) {
                lastHeartbeatAtMs = nowMs;
                heartbeatFrame = encodeEvent("heartbeat", MonitorAlertsSseJson.heartbeatData());
            }
            if (heartbeatFrame == null) {
                return;
            }
            for (SseSubscriber sub : subscribers) {
                sub.offer(heartbeatFrame);
            }
        }
    }

    @NonNull
    private static ScheduledExecutorService createDefaultHeartbeatExecutor() {
        return Executors.newSingleThreadScheduledExecutor(r -> {
            Thread thread = new Thread(r, "monitor-alerts-sse");
            thread.setDaemon(true);
            return thread;
        });
    }

    @NonNull
    static byte[] encodeEvent(@NonNull String event, @NonNull String jsonData) {
        String payload = "event: " + event + "\n"
                + "data: " + jsonData + "\n\n";
        return payload.getBytes(StandardCharsets.UTF_8);
    }

    public static final class SseSubscriber implements SseFrameSubscriber {
        private final MonitorAlertsSseHub hub;
        private final BlockingQueue<byte[]> queue = new LinkedBlockingQueue<>(QUEUE_CAPACITY);
        private final AtomicBoolean closed = new AtomicBoolean(false);

        SseSubscriber(@NonNull MonitorAlertsSseHub hub) {
            this.hub = hub;
        }

        void offer(@NonNull byte[] frame) {
            if (closed.get()) {
                return;
            }
            if (!queue.offer(frame)) {
                queue.poll();
                if (!queue.offer(frame)) {
                    closeFromClient();
                }
            }
        }

        @Override
        public boolean isClosed() {
            return closed.get();
        }

        @Override
        @Nullable
        public byte[] pollChunk(long timeoutMs) throws InterruptedException {
            if (closed.get() && queue.isEmpty()) {
                return null;
            }
            return queue.poll(timeoutMs, TimeUnit.MILLISECONDS);
        }

        void closeInternal() {
            closed.set(true);
            queue.offer(new byte[0]);
        }

        @Override
        public void closeFromClient() {
            if (closed.compareAndSet(false, true)) {
                queue.offer(new byte[0]);
                hub.releaseSubscriber(this);
            }
        }
    }
}
