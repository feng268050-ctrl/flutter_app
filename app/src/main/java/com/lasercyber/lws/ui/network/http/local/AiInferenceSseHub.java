package com.lasercyber.lws.ui.network.http.local;

import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ai.model.AiStainDetectResult;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Fan-out Server-Sent Events for AI inference lifecycle and samples to multiple HTTP subscribers.
 */
public final class AiInferenceSseHub {

    public static final String MIME_SSE = "text/event-stream; charset=utf-8";
    private static final int QUEUE_CAPACITY = 64;
    private static final long IDLE_INTERVAL_MS = 15_000L;
    static final long READ_POLL_MS = 50L;

    @NonNull
    private final String logTag;
    @NonNull
    private final SseTimestampClock clock;
    private final Object lock = new Object();
    private final List<SseSubscriber> subscribers = new ArrayList<>();
    private final Handler idleHandler = new Handler(Looper.getMainLooper());
    private final Runnable idleRunnable = this::emitPeriodicIdle;
    @Nullable
    private AiInferenceSseJson.SessionStart activeSession;

    public AiInferenceSseHub(@NonNull String logTag) {
        this(logTag, new ConnectionRelativeSseClock());
    }

    AiInferenceSseHub(@NonNull String logTag, @NonNull SseTimestampClock clock) {
        this.logTag = logTag;
        this.clock = clock;
    }

    @NonNull
    public static AiInferenceSseHub forLiveCamera(@NonNull String logTag) {
        return new AiInferenceSseHub(logTag, new ConnectionRelativeSseClock());
    }

    @NonNull
    public static AiInferenceSseHub forProcessVideo(@NonNull String logTag,
                                                    @NonNull MediaPositionMs mediaPosition) {
        return new AiInferenceSseHub(logTag, new MediaTimelineSseClock(mediaPosition));
    }

    public int getSubscriberCount() {
        synchronized (lock) {
            return subscribers.size();
        }
    }

    public boolean hasActiveSession() {
        synchronized (lock) {
            return activeSession != null;
        }
    }

    @Nullable
  public String getActiveSessionId() {
        synchronized (lock) {
            return activeSession == null ? null : activeSession.sessionId;
        }
    }

    @NonNull
    public SseSubscriber acquireSubscriber() {
        return acquireSubscriberAt(SystemClock.elapsedRealtime());
    }

    @VisibleForTesting
    @NonNull
    SseSubscriber acquireSubscriberAt(long connectionElapsedRealtimeMs) {
        synchronized (lock) {
            SseSubscriber sub = new SseSubscriber(this, connectionElapsedRealtimeMs);
            subscribers.add(sub);
            enqueueIdleLocked(sub, clock.connectIdleTimestampMs());
            if (activeSession != null) {
                enqueueStartLocked(sub, activeSession, true);
            }
            scheduleIdleIfNeededLocked();
            return sub;
        }
    }

    void releaseSubscriber(@NonNull SseSubscriber subscriber) {
        synchronized (lock) {
            if (!subscribers.remove(subscriber)) {
                return;
            }
            subscriber.closeInternal();
            if (subscribers.isEmpty()) {
                idleHandler.removeCallbacks(idleRunnable);
            }
        }
    }

    public void notifySessionStarted(@NonNull AiInferenceSseJson.SessionStart session) {
        synchronized (lock) {
            activeSession = session;
            long contextMs = SystemClock.elapsedRealtime();
            for (SseSubscriber sub : subscribers) {
                enqueueStartLocked(sub, session, false);
            }
        }
    }

    public void notifySessionStopped(@NonNull String sessionId,
                                     @NonNull String reason,
                                     long contextMs) {
        synchronized (lock) {
            if (activeSession != null && activeSession.sessionId.equals(sessionId)) {
                activeSession = null;
            }
            for (SseSubscriber sub : subscribers) {
                long timestampMs = clock.stopTimestampMs(sub, contextMs);
                sub.offer(encodeEvent("stop",
                        AiInferenceSseJson.stopData(sessionId, timestampMs, reason)));
            }
        }
    }

    public void clearActiveSession() {
        synchronized (lock) {
            activeSession = null;
        }
    }

    public void publishRunning(@NonNull AiStainDetectResult result, long contextMs) {
        publishRunning(result, contextMs, getActiveSessionId());
    }

    public void publishRunning(@NonNull AiStainDetectResult result,
                               long contextMs,
                               @Nullable String sessionId) {
        synchronized (lock) {
            for (SseSubscriber sub : subscribers) {
                long timestampMs = clock.runningTimestampMs(sub, contextMs);
                sub.offer(encodeEvent("running",
                        AiInferenceSseJson.runningData(result, timestampMs, sessionId)));
            }
        }
    }

    @VisibleForTesting
    void publishLiveCameraRunningAt(@NonNull AiStainDetectResult result, long elapsedRealtimeMs) {
        publishRunning(result, elapsedRealtimeMs, getActiveSessionId());
    }

    public void publishLiveCameraInference(@NonNull AiStainDetectResult result) {
        publishLiveCameraRunningAt(result, SystemClock.elapsedRealtime());
    }

    public void publishError(int code, @NonNull String message) {
        byte[] frame = encodeEvent("error", AiInferenceSseJson.errorData(code, message));
        broadcast(frame);
        synchronized (lock) {
            activeSession = null;
            for (SseSubscriber sub : new ArrayList<>(subscribers)) {
                sub.closeInternal();
            }
            subscribers.clear();
            idleHandler.removeCallbacks(idleRunnable);
        }
    }

    @VisibleForTesting
    void resetForTest() {
        synchronized (lock) {
            activeSession = null;
            for (SseSubscriber sub : subscribers) {
                sub.closeInternal();
            }
            subscribers.clear();
            idleHandler.removeCallbacks(idleRunnable);
        }
    }

    private void broadcast(@NonNull byte[] frame) {
        synchronized (lock) {
            for (SseSubscriber sub : subscribers) {
                sub.offer(frame);
            }
        }
    }

    private void scheduleIdleIfNeededLocked() {
        if (subscribers.size() == 1) {
            idleHandler.removeCallbacks(idleRunnable);
            idleHandler.postDelayed(idleRunnable, IDLE_INTERVAL_MS);
        }
    }

    private void emitPeriodicIdle() {
        synchronized (lock) {
            for (SseSubscriber sub : subscribers) {
                enqueueIdleLocked(sub, clock.periodicIdleTimestampMs(sub));
            }
            if (!subscribers.isEmpty()) {
                idleHandler.postDelayed(idleRunnable, IDLE_INTERVAL_MS);
            }
        }
    }

    private void enqueueIdleLocked(@NonNull SseSubscriber sub, long timestampMs) {
        sub.offer(encodeEvent("idle",
                AiInferenceSseJson.idleData(timestampMs, activeSession != null)));
    }

    private void enqueueStartLocked(@NonNull SseSubscriber sub,
                                    @NonNull AiInferenceSseJson.SessionStart session,
                                    boolean replay) {
        long timestampMs = clock.startTimestampMs(sub, replay);
        sub.offer(encodeEvent("start", AiInferenceSseJson.startData(
                session.sessionId,
                timestampMs,
                session.source,
                session.samplingIntervalMs,
                session.imageWidth,
                session.imageHeight)));
    }

    @NonNull
    private static byte[] encodeEvent(@NonNull String event, @NonNull String jsonData) {
        String payload = "event: " + event + "\n"
                + "data: " + jsonData + "\n\n";
        return payload.getBytes(StandardCharsets.UTF_8);
    }

    public static final class SseSubscriber implements SseFrameSubscriber {
        private final AiInferenceSseHub hub;
        private final BlockingQueue<byte[]> queue = new LinkedBlockingQueue<>(QUEUE_CAPACITY);
        private final AtomicBoolean closed = new AtomicBoolean(false);
        private final LiveSseTimeline liveTimeline;

        SseSubscriber(@NonNull AiInferenceSseHub hub, long connectionElapsedRealtimeMs) {
            this.hub = hub;
            this.liveTimeline = new LiveSseTimeline(connectionElapsedRealtimeMs);
        }

        @NonNull
        public InputStream getInputStream() {
            return new SseInputStream(this);
        }

        long connectionTimelineMs(long elapsedRealtimeMs) {
            return liveTimeline.timelineMs(elapsedRealtimeMs);
        }

        void offer(@NonNull byte[] frame) {
            if (closed.get()) {
                return;
            }
            if (!queue.offer(frame)) {
                queue.poll();
                queue.offer(frame);
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

    private static final class SseInputStream extends InputStream {
        private final SseSubscriber subscriber;
        @Nullable
        private byte[] current;
        private int position;
        private volatile boolean released;

        SseInputStream(@NonNull SseSubscriber subscriber) {
            this.subscriber = subscriber;
        }

        @Override
        public void close() throws IOException {
            if (!released) {
                released = true;
                subscriber.closeFromClient();
            }
            super.close();
        }

        @Override
        public int read(@NonNull byte[] buffer, int offset, int len) throws IOException {
            if (subscriber.closed.get()
                    && (current == null || position >= current.length)
                    && subscriber.queue.isEmpty()) {
                return -1;
            }
            while (true) {
                if (current != null && position < current.length) {
                    int toCopy = Math.min(len, current.length - position);
                    System.arraycopy(current, position, buffer, offset, toCopy);
                    position += toCopy;
                    return toCopy;
                }
                try {
                    current = subscriber.pollChunk(READ_POLL_MS);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return -1;
                }
                if (current == null) {
                    if (subscriber.closed.get()) {
                        return -1;
                    }
                    continue;
                }
                if (current.length == 0 && subscriber.closed.get()) {
                    return -1;
                }
                position = 0;
            }
        }

        @Override
        public int read() throws IOException {
            byte[] one = new byte[1];
            int n = read(one, 0, 1);
            return n < 0 ? -1 : (one[0] & 0xFF);
        }
    }
}
