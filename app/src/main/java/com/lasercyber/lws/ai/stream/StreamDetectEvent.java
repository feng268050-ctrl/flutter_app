package com.lasercyber.lws.ai.stream;
import androidx.annotation.NonNull;

import org.json.JSONObject;

/**
 * Parsed C++ stream detect uplink events.
 */
public final class StreamDetectEvent {

    private StreamDetectEvent() {
    }

    public static final class DetectResult {
        public final String module;
        public final long timestampMs;
        public final long frameId;
        public final int imageWidth;
        public final int imageHeight;
        public final int code;
        public final boolean ok;
        public final String summaryJson;

        @NonNull
        public static DetectResult forTest(String module,
                                           long timestampMs,
                                           long frameId,
                                           int imageWidth,
                                           int imageHeight,
                                           int code,
                                           boolean ok,
                                           String summaryJson) {
            return new DetectResult(module, timestampMs, frameId, imageWidth, imageHeight, code, ok, summaryJson);
        }

        DetectResult(String module,
                     long timestampMs,
                     long frameId,
                     int imageWidth,
                     int imageHeight,
                     int code,
                     boolean ok,
                     String summaryJson) {
            this.module = module;
            this.timestampMs = timestampMs;
            this.frameId = frameId;
            this.imageWidth = imageWidth;
            this.imageHeight = imageHeight;
            this.code = code;
            this.ok = ok;
            this.summaryJson = summaryJson;
        }

        @NonNull
        static DetectResult fromJson(@NonNull JSONObject root) {
            return new DetectResult(
                    root.optString("module", ""),
                    root.optLong("timestampMs", 0L),
                    root.optLong("frameId", 0L),
                    root.optInt("imageWidth", 0),
                    root.optInt("imageHeight", 0),
                    root.optInt("code", 0),
                    root.optBoolean("ok", false),
                    root.optString("summaryJson", ""));
        }
    }

    public static final class SessionStart {
        public final String source;
        public final long samplingIntervalMs;
        public final long timestampMs;

        SessionStart(String source, long samplingIntervalMs, long timestampMs) {
            this.source = source;
            this.samplingIntervalMs = samplingIntervalMs;
            this.timestampMs = timestampMs;
        }

        @NonNull
        static SessionStart fromJson(@NonNull JSONObject root) {
            return new SessionStart(
                    root.optString("source", ""),
                    root.optLong("samplingIntervalMs", 500L),
                    root.optLong("timestampMs", 0L));
        }
    }

    public static final class SessionStop {
        public final String reason;
        public final long timestampMs;

        SessionStop(String reason, long timestampMs) {
            this.reason = reason;
            this.timestampMs = timestampMs;
        }

        @NonNull
        static SessionStop fromJson(@NonNull JSONObject root) {
            return new SessionStop(
                    root.optString("reason", ""),
                    root.optLong("timestampMs", 0L));
        }
    }

    public static final class PipelineState {
        public final String state;
        public final String detail;
        public final long timestampMs;

        PipelineState(String state, String detail, long timestampMs) {
            this.state = state;
            this.detail = detail;
            this.timestampMs = timestampMs;
        }

        @NonNull
        static PipelineState fromJson(@NonNull JSONObject root) {
            return new PipelineState(
                    root.optString("state", ""),
                    root.optString("detail", ""),
                    root.optLong("timestampMs", 0L));
        }
    }
}
