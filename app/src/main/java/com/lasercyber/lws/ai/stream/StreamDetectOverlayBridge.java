package com.lasercyber.lws.ai.stream;
import com.lasercyber.lws.ai.engine.AiVisionDualLinkFieldTestLog;
import com.lasercyber.lws.ai.engine.AiVisionResolutionProfileLog;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.stain.OpencvStainDetectResultMapper;
import com.lasercyber.lws.ai.stream.StreamDetectEvent;
import com.lasercyber.lws.ai.stream.StreamDetectResultBus;
import com.lasercyber.lws.ui.common.ai.overlay.DetectionOverlayMapper;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.network.http.local.overlay.CameraAiOverlayState;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Maps C++ {@link StreamDetectResultBus} lens_det events to overlay state (AI Vision + compositor).
 */
public final class StreamDetectOverlayBridge implements StreamDetectResultBus.DetectResultListener {

    private static final String TAG = "StreamDetectOverlay";
    /** Hide overlay when no fresh detect_result within this window (Phase 4 sync tolerance). */
    public static final long STALE_RESULT_MS = 3_000L;

    public interface Listener {
        void onStreamDetectOverlayChanged(@Nullable OpencvStainDetectResult stain, long frameId);

        void onStreamDetectPipelineError(@NonNull String detail);
    }

    private static volatile StreamDetectOverlayBridge instance;

    private final CopyOnWriteArrayList<Listener> listeners = new CopyOnWriteArrayList<>();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private volatile boolean subscribed;
    private volatile OpencvStainDetectResult latestStain;
    private volatile long latestFrameId;
    private volatile long lastResultElapsedMs;
    private volatile boolean pipelineError;

    public static StreamDetectOverlayBridge getInstance() {
        if (instance == null) {
            synchronized (StreamDetectOverlayBridge.class) {
                if (instance == null) {
                    instance = new StreamDetectOverlayBridge();
                }
            }
        }
        return instance;
    }

    private StreamDetectOverlayBridge() {
    }

    public void ensureSubscribed() {
        if (!CameraConfig.isNativeAiVisionStreamDetectEnabled() || subscribed) {
            return;
        }
        StreamDetectResultBus.getInstance().addListener(this);
        subscribed = true;
        Log.i(TAG, "subscribed to StreamDetectResultBus");
    }

    public void unsubscribe() {
        if (!subscribed) {
            return;
        }
        StreamDetectResultBus.getInstance().removeListener(this);
        subscribed = false;
        clear();
    }

    public void addListener(@NonNull Listener listener) {
        listeners.addIfAbsent(listener);
    }

    public void removeListener(@NonNull Listener listener) {
        listeners.remove(listener);
    }

    @Nullable
    public OpencvStainDetectResult getLatestStainIfFresh() {
        if (latestStain == null || isStale()) {
            return null;
        }
        return latestStain;
    }

    public long getLatestFrameId() {
        return latestFrameId;
    }

    public boolean isStale() {
        if (lastResultElapsedMs <= 0L) {
            return true;
        }
        return SystemClock.elapsedRealtime() - lastResultElapsedMs > STALE_RESULT_MS;
    }

    public boolean hasPipelineError() {
        return pipelineError;
    }

    public void clear() {
        latestStain = null;
        latestFrameId = 0L;
        lastResultElapsedMs = 0L;
        pipelineError = false;
        AiVisionDualLinkFieldTestLog.resetSession();
        CameraAiOverlayState.getInstance().clear();
    }

    @Override
    public void onDetectResult(@NonNull StreamDetectEvent.DetectResult event) {
        if (!CameraConfig.isNativeAiVisionStreamDetectEnabled()) {
            return;
        }
        if (!"lens_det".equals(event.module)) {
            return;
        }
        pipelineError = false;
        final long busReceivedMonoMs = SystemClock.elapsedRealtime();
        OpencvStainDetectResult stain = OpencvStainDetectResultMapper.fromNativeSummary(
                event.summaryJson,
                event.imageWidth,
                event.imageHeight,
                event.timestampMs,
                StainDetectSource.LIVE);
        latestStain = stain;
        latestFrameId = event.frameId;
        lastResultElapsedMs = SystemClock.elapsedRealtime();

        List<com.lasercyber.lws.ui.common.view.DetectionOverlayView.Box> boxes = stain.hasTarget()
                ? DetectionOverlayMapper.fromOpencvStainDetect(stain, event.imageWidth, event.imageHeight)
                : new ArrayList<>();
        CameraAiOverlayState.getInstance().updateOverlay(
                boxes,
                stain.success ? OpencvStainDetectResult.OVERLAY_STATUS : stain.message);

        AiVisionDualLinkFieldTestLog.logDetectSample(
                event.frameId, event.imageWidth, event.imageHeight);

        AiVisionResolutionProfileLog.logNativeDetectDecode(
                event.frameId, event.imageWidth, event.imageHeight);

        for (Listener listener : listeners) {
            mainHandler.post(() -> {
                AiVisionDualLinkFieldTestLog.logOverlaySync(
                        event.frameId,
                        SystemClock.elapsedRealtime() - busReceivedMonoMs);
                listener.onStreamDetectOverlayChanged(stain, event.frameId);
            });
        }
    }

    @Override
    public void onSessionStart(@NonNull StreamDetectEvent.SessionStart event) {
        pipelineError = false;
        AiVisionDualLinkFieldTestLog.logDetectSessionStart(
                event.source, event.samplingIntervalMs);
    }

    @Override
    public void onSessionStop(@NonNull StreamDetectEvent.SessionStop event) {
        clear();
        for (Listener listener : listeners) {
            mainHandler.post(() -> listener.onStreamDetectOverlayChanged(null, 0L));
        }
    }

    @Override
    public void onPipelineState(@NonNull StreamDetectEvent.PipelineState event) {
        if (!"error".equals(event.state)) {
            return;
        }
        pipelineError = true;
        String detail = event.detail.isEmpty() ? "stream_detect_error" : event.detail;
        Log.w(TAG, "pipeline_state error detail=" + detail);
        for (Listener listener : listeners) {
            mainHandler.post(() -> listener.onStreamDetectPipelineError(detail));
        }
    }
}
