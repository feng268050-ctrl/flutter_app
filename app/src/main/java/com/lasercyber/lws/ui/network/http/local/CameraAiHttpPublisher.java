package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ai.sampling.AiFrameSamplingInterval;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.stain.AiStainDetectResultMapper;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.stain.OpencvStainDetectResultMapper;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.stream.StreamDetectEvent;
import com.lasercyber.lws.ai.stream.StreamDetectResultBus;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.io.InputStream;
import java.util.UUID;

/**
 * Reference-counted SSE inference stream for {@code GET /v1/camera/ai}.
 */
public final class CameraAiHttpPublisher implements StreamDetectResultBus.DetectResultListener {

    private static final String TAG = LogTAGConstant.CAMERA_AI_HTTP;
    private static final CameraAiHttpPublisher INSTANCE = new CameraAiHttpPublisher();
    private final AiInferenceSseHub sseHub = AiInferenceSseHub.forLiveCamera(TAG);
    private final Object sessionLock = new Object();
    @Nullable
    private String activeSessionSource;
    private volatile boolean nativeBusSubscribed;
    private volatile int lastNativeImageWidth;
    private volatile int lastNativeImageHeight;

    private CameraAiHttpPublisher() {
        ensureNativeBusSubscription();
    }

    @NonNull
    public static CameraAiHttpPublisher getInstance() {
        INSTANCE.ensureNativeBusSubscription();
        return INSTANCE;
    }

    private void ensureNativeBusSubscription() {
        if (!CameraConfig.isNativeStreamDetectPipelineEnabled() || nativeBusSubscribed) {
            return;
        }
        StreamDetectResultBus.getInstance().addListener(this);
        nativeBusSubscribed = true;
    }

    public void publish(@NonNull AiStainDetectResult result) {
        sseHub.publishLiveCameraInference(result);
    }

  public void onInferenceSessionStart(@NonNull String source,
                                        long samplingIntervalMs,
                                        int imageWidth,
                                        int imageHeight) {
        synchronized (sessionLock) {
            if ("ai_vision_live".equals(source)
                    && StainDetectSource.LIVE.equals(activeSessionSource)) {
                return;
            }
            if (source.equals(activeSessionSource) && sseHub.hasActiveSession()) {
                return;
            }
            if (StainDetectSource.LIVE.equals(source) && activeSessionSource != null) {
                String oldId = sseHub.getActiveSessionId();
                if (oldId != null) {
                    sseHub.notifySessionStopped(
                            oldId, "preview_stopped", android.os.SystemClock.elapsedRealtime());
                }
            }
            activeSessionSource = source;
            sseHub.notifySessionStarted(new AiInferenceSseJson.SessionStart(
                    UUID.randomUUID().toString(),
                    source,
                    samplingIntervalMs,
                    imageWidth > 0 ? imageWidth : null,
                    imageHeight > 0 ? imageHeight : null));
        }
    }

    public void onInferenceSessionStop(@NonNull String reason) {
        synchronized (sessionLock) {
            if (!sseHub.hasActiveSession()) {
                activeSessionSource = null;
                return;
            }
            String sessionId = sseHub.getActiveSessionId();
            if (sessionId == null) {
                activeSessionSource = null;
                return;
            }
            activeSessionSource = null;
            sseHub.notifySessionStopped(sessionId, reason, android.os.SystemClock.elapsedRealtime());
        }
    }

    @NonNull
    public SseSubscriber acquire() {
        AiInferenceSseHub.SseSubscriber sub = sseHub.acquireSubscriber();
        CameraAiHttpActiveSignal.setCameraAiHttpSubscriberCount(sseHub.getSubscriberCount());
        return new SseSubscriber(sub);
    }

    void onSubscriberReleased() {
        CameraAiHttpActiveSignal.setCameraAiHttpSubscriberCount(sseHub.getSubscriberCount());
    }

    @Override
    public void onDetectResult(@NonNull StreamDetectEvent.DetectResult event) {
        if (!CameraConfig.isNativeStreamDetectPipelineEnabled()) {
            return;
        }
        if (!"lens_det".equals(event.module)) {
            return;
        }
        lastNativeImageWidth = event.imageWidth;
        lastNativeImageHeight = event.imageHeight;
        OpencvStainDetectResult opencvResult = OpencvStainDetectResultMapper.fromNativeSummary(
                event.summaryJson,
                event.imageWidth,
                event.imageHeight,
                event.timestampMs,
                StainDetectSource.LIVE);
        AiStainDetectResult sseResult = AiStainDetectResultMapper.processVideoStainDetectRow(
                opencvResult,
                event.imageWidth,
                event.imageHeight,
                event.timestampMs,
                StainDetectSource.LIVE);
        publish(sseResult);
    }

    @Override
    public void onSessionStart(@NonNull StreamDetectEvent.SessionStart event) {
        if (!CameraConfig.isNativeStreamDetectPipelineEnabled()) {
            return;
        }
        String source = event.source.isEmpty() ? StainDetectSource.LIVE : event.source;
        long intervalMs = event.samplingIntervalMs > 0
                ? event.samplingIntervalMs
                : AiFrameSamplingInterval.LIVE_WELD.getIntervalMs();
        onInferenceSessionStart(
                source,
                intervalMs,
                lastNativeImageWidth,
                lastNativeImageHeight);
        CameraAiHttpActiveSignal.setLivePr1InferenceStreaming(true);
    }

    @Override
    public void onSessionStop(@NonNull StreamDetectEvent.SessionStop event) {
        if (!CameraConfig.isNativeStreamDetectPipelineEnabled()) {
            return;
        }
        onInferenceSessionStop(mapNativeSessionStopReason(event.reason));
        CameraAiHttpActiveSignal.setLivePr1InferenceStreaming(false);
    }

    @Override
    public void onPipelineState(@NonNull StreamDetectEvent.PipelineState event) {
        if (!CameraConfig.isNativeStreamDetectPipelineEnabled()) {
            return;
        }
        if ("error".equals(event.state)) {
            sseHub.publishError(-1, event.detail.isEmpty() ? "stream_detect_error" : event.detail);
            CameraAiHttpActiveSignal.setLivePr1InferenceStreaming(false);
        }
    }

    @NonNull
    private static String mapNativeSessionStopReason(@NonNull String reason) {
        if ("release".equals(reason) || "laser_enable_off".equals(reason)) {
            return "laser_off";
        }
        return reason.isEmpty() ? "stream_error" : reason;
    }

    @VisibleForTesting
    static void resetForTest() {
        CameraAiHttpPublisher p = INSTANCE;
        if (p.nativeBusSubscribed) {
            StreamDetectResultBus.getInstance().removeListener(p);
            p.nativeBusSubscribed = false;
        }
        synchronized (p.sessionLock) {
            p.activeSessionSource = null;
        }
        p.lastNativeImageWidth = 0;
        p.lastNativeImageHeight = 0;
        p.sseHub.resetForTest();
        CameraAiHttpActiveSignal.setCameraAiHttpSubscriberCount(0);
        CameraAiHttpActiveSignal.setLivePr1InferenceStreaming(false);
        CameraAiHttpActiveSignal.setAiVisionLiveInferActive(false);
    }

    public static final class SseSubscriber {
        private final AiInferenceSseHub.SseSubscriber delegate;

        SseSubscriber(@NonNull AiInferenceSseHub.SseSubscriber delegate) {
            this.delegate = delegate;
        }

        @NonNull
        AiInferenceSseHub.SseSubscriber hubSubscriber() {
            return delegate;
        }

        void close() {
            delegate.closeFromClient();
            INSTANCE.onSubscriberReleased();
        }

        @NonNull
        public InputStream getInputStream() {
            return new SseInputStream(INSTANCE, delegate);
        }
    }

    private static final class SseInputStream extends InputStream {
        private final CameraAiHttpPublisher publisher;
        private final InputStream inner;

        SseInputStream(@NonNull CameraAiHttpPublisher publisher,
                       @NonNull AiInferenceSseHub.SseSubscriber delegate) {
            this.publisher = publisher;
            this.inner = delegate.getInputStream();
        }

        @Override
        public void close() throws java.io.IOException {
            inner.close();
            publisher.onSubscriberReleased();
        }

        @Override
        public int read() throws java.io.IOException {
            return inner.read();
        }

        @Override
        public int read(@NonNull byte[] buffer, int offset, int len) throws java.io.IOException {
            return inner.read(buffer, offset, len);
        }
    }
}
