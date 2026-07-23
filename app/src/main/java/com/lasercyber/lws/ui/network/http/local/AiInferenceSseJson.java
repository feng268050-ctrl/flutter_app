package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.lasercyber.lws.ai.model.AiStainDetectResult;

/**
 * JSON payloads for AI inference SSE events.
 */
public final class AiInferenceSseJson {

    private static final Gson GSON = new Gson();

    private AiInferenceSseJson() {
    }

    @NonNull
    public static String idleData(long timestampMs, boolean inferenceActive) {
        JsonObject root = new JsonObject();
        root.addProperty("timestampMs", timestampMs);
        root.addProperty("inferenceActive", inferenceActive);
        return GSON.toJson(root);
    }

    @NonNull
    public static String startData(@NonNull String sessionId,
                                   long timestampMs,
                                   @NonNull String source,
                                   long samplingIntervalMs,
                                   @Nullable Integer imageWidth,
                                   @Nullable Integer imageHeight) {
        JsonObject root = new JsonObject();
        root.addProperty("sessionId", sessionId);
        root.addProperty("timestampMs", timestampMs);
        root.addProperty("source", source);
        root.addProperty("samplingIntervalMs", samplingIntervalMs);
        if (imageWidth != null && imageWidth > 0) {
            root.addProperty("imageWidth", imageWidth);
        }
        if (imageHeight != null && imageHeight > 0) {
            root.addProperty("imageHeight", imageHeight);
        }
        return GSON.toJson(root);
    }

    @NonNull
    public static String stopData(@NonNull String sessionId, long timestampMs, @NonNull String reason) {
        JsonObject root = new JsonObject();
        root.addProperty("sessionId", sessionId);
        root.addProperty("timestampMs", timestampMs);
        root.addProperty("reason", reason);
        return GSON.toJson(root);
    }

    /**
     * {@code running} payload for {@code GET /v1/camera/ai} and {@code GET /v1/videos/:id/ai}.
     * {@code timestampMs} is supplied by the publisher clock (connection-relative or media timeline).
     */
    @NonNull
    public static String runningData(@NonNull AiStainDetectResult result,
                                     long timestampMs,
                                     @Nullable String sessionId) {
        JsonObject root = new JsonObject();
        if (sessionId != null && !sessionId.isEmpty()) {
            root.addProperty("sessionId", sessionId);
        }
        root.addProperty("timestampMs", timestampMs);
        root.addProperty("success", result.success);
        root.addProperty("code", result.code);
        root.addProperty("level", result.level);
        root.addProperty("status", result.status);
        root.addProperty("message", result.message);
        root.addProperty("imageWidth", result.imageWidth);
        root.addProperty("imageHeight", result.imageHeight);
        root.addProperty("source", result.source);
        JsonArray boxes = new JsonArray();
        for (com.lasercyber.lws.ai.model.NormalizedBox box : result.boxes) {
            JsonObject b = new JsonObject();
            float[] xyxy = box.toPixelXyxy(result.imageWidth, result.imageHeight);
            b.addProperty("x1", xyxy[0]);
            b.addProperty("y1", xyxy[1]);
            b.addProperty("x2", xyxy[2]);
            b.addProperty("y2", xyxy[3]);
            b.addProperty("classId", box.classId);
            b.addProperty("label", box.label);
            b.addProperty("score", box.score);
            boxes.add(b);
        }
        root.add("boxes", boxes);
        return GSON.toJson(root);
    }

    @NonNull
    public static String errorData(int code, @NonNull String message) {
        JsonObject root = new JsonObject();
        root.addProperty("code", code);
        root.addProperty("message", message);
        return GSON.toJson(root);
    }

    public static final class SessionStart {
        @NonNull
        public final String sessionId;
        @NonNull
        public final String source;
        public final long samplingIntervalMs;
        @Nullable
        public final Integer imageWidth;
        @Nullable
        public final Integer imageHeight;

        public SessionStart(@NonNull String sessionId,
                            @NonNull String source,
                            long samplingIntervalMs,
                            @Nullable Integer imageWidth,
                            @Nullable Integer imageHeight) {
            this.sessionId = sessionId;
            this.source = source;
            this.samplingIntervalMs = samplingIntervalMs;
            this.imageWidth = imageWidth;
            this.imageHeight = imageHeight;
        }
    }
}
