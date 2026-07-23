package com.lasercyber.lws.ai.stream;
import com.lasercyber.lws.ai.stream.StreamDetectEvent;
import com.lasercyber.lws.ai.stream.StreamDetectNativeCallback;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONObject;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Single Java entry for C++ {@code StreamDetectPipeline} uplink events (Pub-Sub bus).
 */
public final class StreamDetectResultBus implements StreamDetectNativeCallback {

    private static final String TAG = "StreamDetectResultBus";
    private static final AtomicBoolean NATIVE_CALLBACK_NOOP_LOGGED = new AtomicBoolean(false);

    public interface DetectResultListener {
        void onDetectResult(@NonNull StreamDetectEvent.DetectResult event);

        void onSessionStart(@NonNull StreamDetectEvent.SessionStart event);

        void onSessionStop(@NonNull StreamDetectEvent.SessionStop event);

        void onPipelineState(@NonNull StreamDetectEvent.PipelineState event);
    }

    private static volatile StreamDetectResultBus instance;

    private final CopyOnWriteArrayList<DetectResultListener> listeners = new CopyOnWriteArrayList<>();
    private final ExecutorService dispatchExecutor = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "stream-detect-bus");
        t.setDaemon(true);
        return t;
    });
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private volatile StreamDetectEvent.DetectResult latestLensDetResult;
    private volatile StreamDetectEvent.DetectResult latestZeroPointResult;
    private volatile StreamDetectEvent.DetectResult latestRknnStainResult;

    public static StreamDetectResultBus getInstance() {
        if (instance == null) {
            synchronized (StreamDetectResultBus.class) {
                if (instance == null) {
                    instance = new StreamDetectResultBus();
                }
            }
        }
        return instance;
    }

    private StreamDetectResultBus() {
    }

    public void registerNativeCallback() {
        // Product path: StreamDetect uplink is daemon evt → ingestDaemonEvent (no JNI).
        if (NATIVE_CALLBACK_NOOP_LOGGED.compareAndSet(false, true)) {
            Log.i(TAG, "registerNativeCallback no-op (daemon IPC; no NativeBridge)");
        }
    }

    public void unregisterNativeCallback() {
        if (NATIVE_CALLBACK_NOOP_LOGGED.compareAndSet(false, true)) {
            Log.i(TAG, "unregisterNativeCallback no-op (daemon IPC; no NativeBridge)");
        }
    }

    public void addListener(@NonNull DetectResultListener listener) {
        listeners.addIfAbsent(listener);
    }

    public void removeListener(@NonNull DetectResultListener listener) {
        listeners.remove(listener);
    }

    @Nullable
    public StreamDetectEvent.DetectResult getLatestLensDetResult() {
        return latestLensDetResult;
    }

    @Nullable
    public StreamDetectEvent.DetectResult getLatestZeroPointResult() {
        return latestZeroPointResult;
    }

    @Nullable
    public StreamDetectEvent.DetectResult getLatestRknnStainResult() {
        return latestRknnStainResult;
    }

    @Override
    public void onStreamDetectEvent(@NonNull String jsonLine) {
        dispatchExecutor.execute(() -> handleEvent(jsonLine));
    }

    /**
     * Ingress for daemon evt JSON Lines (same parse path as JNI uplink).
     * Used by {@link com.lasercyber.lws.ai.daemon.AiDaemonSupervisor}.
     */
    public void ingestDaemonEvent(@NonNull String jsonLine) {
        onStreamDetectEvent(jsonLine);
    }

    /** Same-package unit tests call {@link #handleEvent} synchronously (no main-looper listener). */
    void handleEventForTest(@NonNull String jsonLine) {
        handleEvent(jsonLine);
    }

    private void handleEvent(@NonNull String jsonLine) {
        try {
            JSONObject root = new JSONObject(jsonLine);
            String type = root.optString("type", "");
            switch (type) {
                case "combined_frame":
                    handleCombinedFrame(root);
                    break;
                case "detect_result": {
                    /** @deprecated Prefer native {@code combined_frame}; kept for transitional events. */
                    StreamDetectEvent.DetectResult event = StreamDetectEvent.DetectResult.fromJson(root);
                    dispatchDetectResult(event);
                    break;
                }
                case "session_start":
                    notifySessionStart(StreamDetectEvent.SessionStart.fromJson(root));
                    break;
                case "session_stop":
                    notifySessionStop(StreamDetectEvent.SessionStop.fromJson(root));
                    break;
                case "pipeline_state":
                    notifyPipelineState(StreamDetectEvent.PipelineState.fromJson(root));
                    break;
                default:
                    Log.w(TAG, "unknown event type=" + type);
                    break;
            }
        } catch (Exception e) {
            Log.w(TAG, "parse event failed: " + jsonLine, e);
        }
    }

    private void handleCombinedFrame(@NonNull JSONObject root) {
        final long framePts = root.optLong("frame_pts_ms", root.optLong("timestampMs", 0L));
        final long frameId = root.optLong("frameId", 0L);
        final int imageWidth = root.optInt("imageWidth", 0);
        final int imageHeight = root.optInt("imageHeight", 0);
        JSONObject modules = root.optJSONObject("modules");
        if (modules == null) {
            Log.w(TAG, "combined_frame missing modules");
            return;
        }
        for (String module : new String[]{"lens_det", "zero_point", "rknn_stain", "edgedrawing"}) {
            JSONObject mod = modules.optJSONObject(module);
            if (mod == null) {
                continue;
            }
            dispatchModuleResult(module, mod, framePts, frameId, imageWidth, imageHeight);
        }
        java.util.Iterator<String> keys = modules.keys();
        while (keys.hasNext()) {
            String module = keys.next();
            if ("lens_det".equals(module) || "zero_point".equals(module) || "rknn_stain".equals(module)
                    || "edgedrawing".equals(module)) {
                continue;
            }
            JSONObject mod = modules.optJSONObject(module);
            if (mod == null) {
                continue;
            }
            dispatchModuleResult(module, mod, framePts, frameId, imageWidth, imageHeight);
        }
    }

    private void dispatchModuleResult(String module,
                                      JSONObject mod,
                                      long framePts,
                                      long frameId,
                                      int imageWidth,
                                      int imageHeight) {
        try {
            JSONObject eventJson = new JSONObject();
            eventJson.put("module", module);
            eventJson.put("timestampMs", framePts);
            eventJson.put("frameId", frameId);
            eventJson.put("imageWidth", imageWidth);
            eventJson.put("imageHeight", imageHeight);
            eventJson.put("code", mod.optInt("code", 0));
            eventJson.put("ok", mod.optBoolean("ok", false));
            eventJson.put("summaryJson", mod.optString("summaryJson", ""));
            dispatchDetectResult(StreamDetectEvent.DetectResult.fromJson(eventJson));
        } catch (Exception e) {
            Log.w(TAG, "combined_frame module parse failed module=" + module, e);
        }
    }

    private void dispatchDetectResult(@NonNull StreamDetectEvent.DetectResult event) {
        if ("lens_det".equals(event.module)) {
            latestLensDetResult = event;
        } else if ("zero_point".equals(event.module)) {
            latestZeroPointResult = event;
        } else if ("rknn_stain".equals(event.module)) {
            latestRknnStainResult = event;
        }
        notifyDetectResult(event);
    }

    private void notifyDetectResult(@NonNull StreamDetectEvent.DetectResult event) {
        for (DetectResultListener listener : listeners) {
            mainHandler.post(() -> listener.onDetectResult(event));
        }
    }

    private void notifySessionStart(@NonNull StreamDetectEvent.SessionStart event) {
        for (DetectResultListener listener : listeners) {
            mainHandler.post(() -> listener.onSessionStart(event));
        }
    }

    private void notifySessionStop(@NonNull StreamDetectEvent.SessionStop event) {
        for (DetectResultListener listener : listeners) {
            mainHandler.post(() -> listener.onSessionStop(event));
        }
    }

    private void notifyPipelineState(@NonNull StreamDetectEvent.PipelineState event) {
        for (DetectResultListener listener : listeners) {
            mainHandler.post(() -> listener.onPipelineState(event));
        }
    }
}
