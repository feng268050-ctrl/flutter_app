package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

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
 * Fan-out Server-Sent Events for {@code GET /v1/monitor/stat}.
 */
public final class MonitorStatSseHub {

    public static final long SAMPLE_INTERVAL_MS = 100L;
    private static final long HEARTBEAT_INTERVAL_MS = 15_000L;
    private static final int QUEUE_CAPACITY = 64;

    private final Object lock = new Object();
    private final List<SseSubscriber> subscribers = new ArrayList<>();
    private final Supplier<MonitorStatSnapshot> snapshotSupplier;
    private final ScheduledExecutorService samplerExecutor;
    private final boolean autoSchedule;
    @Nullable
    private ScheduledFuture<?> samplerFuture;
    @Nullable
    private MonitorStatSnapshot lastEmitted;
    private long lastHeartbeatAtMs = -1L;

    public MonitorStatSseHub() {
        this(MonitorStatSnapshot::fromCache, createDefaultSamplerExecutor(), true);
    }

    @VisibleForTesting
    MonitorStatSseHub(@NonNull Supplier<MonitorStatSnapshot> snapshotSupplier,
                      @NonNull ScheduledExecutorService samplerExecutor) {
        this(snapshotSupplier, samplerExecutor, false);
    }

    @VisibleForTesting
    static MonitorStatSseHub forLiveSampling(@NonNull Supplier<MonitorStatSnapshot> snapshotSupplier,
                                               @NonNull ScheduledExecutorService samplerExecutor) {
        return new MonitorStatSseHub(snapshotSupplier, samplerExecutor, true);
    }

    private MonitorStatSseHub(@NonNull Supplier<MonitorStatSnapshot> snapshotSupplier,
                              @NonNull ScheduledExecutorService samplerExecutor,
                              boolean autoSchedule) {
        this.snapshotSupplier = snapshotSupplier;
        this.samplerExecutor = samplerExecutor;
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
            SseSubscriber sub = new SseSubscriber(this);
            subscribers.add(sub);
            startSamplerLocked();
            emitImmediateStatLocked(sub);
            return sub;
        }
    }

    private void emitImmediateStatLocked(@NonNull SseSubscriber sub) {
        MonitorStatSnapshot current = snapshotSupplier.get();
        lastEmitted = current.copy();
        sub.offer(encodeEvent("stat", MonitorStatSseJson.statData(lastEmitted)));
    }

    void releaseSubscriber(@NonNull SseSubscriber subscriber) {
        synchronized (lock) {
            if (!subscribers.remove(subscriber)) {
                return;
            }
            subscriber.closeInternal();
            if (subscribers.isEmpty()) {
                stopSamplerLocked();
                lastEmitted = null;
            }
        }
    }

    @VisibleForTesting
    void sampleTickForTest() {
        sampleTick(System.currentTimeMillis());
    }

    @VisibleForTesting
    void sampleTickAtForTest(long nowMs) {
        sampleTick(nowMs);
    }

    @VisibleForTesting
    void resetForTest() {
        synchronized (lock) {
            stopSamplerLocked();
            lastEmitted = null;
            lastHeartbeatAtMs = -1L;
            for (SseSubscriber sub : subscribers) {
                sub.closeInternal();
            }
            subscribers.clear();
        }
    }

    private void startSamplerLocked() {
        if (!autoSchedule || (samplerFuture != null && !samplerFuture.isCancelled())) {
            return;
        }
        samplerFuture = samplerExecutor.scheduleAtFixedRate(
                () -> sampleTick(System.currentTimeMillis()),
                0L,
                SAMPLE_INTERVAL_MS,
                TimeUnit.MILLISECONDS);
    }

    private void stopSamplerLocked() {
        if (samplerFuture != null) {
            samplerFuture.cancel(false);
            samplerFuture = null;
        }
    }

    private void sampleTick(long nowMs) {
        MonitorStatSnapshot current = snapshotSupplier.get();
        byte[] statFrame = null;
        synchronized (lock) {
            if (subscribers.isEmpty()) {
                return;
            }
            if (current.changedSince(lastEmitted)) {
                lastEmitted = current.copy();
                statFrame = encodeEvent("stat", MonitorStatSseJson.statData(lastEmitted));
            }
            boolean heartbeatDue = lastHeartbeatAtMs < 0L
                    || nowMs - lastHeartbeatAtMs >= HEARTBEAT_INTERVAL_MS;
            byte[] heartbeatFrame = heartbeatDue
                    ? encodeEvent("heartbeat", MonitorStatSseJson.heartbeatData())
                    : null;
            if (heartbeatFrame != null) {
                lastHeartbeatAtMs = nowMs;
            }
            for (SseSubscriber sub : subscribers) {
                if (statFrame != null) {
                    sub.offer(statFrame);
                }
                if (heartbeatFrame != null) {
                    sub.offer(heartbeatFrame);
                }
            }
        }
    }

    @NonNull
    private static ScheduledExecutorService createDefaultSamplerExecutor() {
        return Executors.newSingleThreadScheduledExecutor(r -> {
            Thread thread = new Thread(r, "monitor-stat-sse");
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
        private final MonitorStatSseHub hub;
        private final BlockingQueue<byte[]> queue = new LinkedBlockingQueue<>(QUEUE_CAPACITY);
        private final AtomicBoolean closed = new AtomicBoolean(false);

        SseSubscriber(@NonNull MonitorStatSseHub hub) {
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
