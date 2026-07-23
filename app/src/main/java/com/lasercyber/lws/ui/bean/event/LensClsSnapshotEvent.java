package com.lasercyber.lws.ui.bean.event;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Read-only classification snapshot from libai.so.
 * The native side owns labels, score semantics, TopK, and validity.
 */
public class LensClsSnapshotEvent {
    private final boolean valid;
    private final int classId;
    private final String className;
    private final double score;
    private final long timestampMs;
    private final String modelVersion;
    private final String source;
    private final List<TopKItem> topK;
    private final String rawJson;
    private final String errorMessage;

    public LensClsSnapshotEvent(boolean valid,
                                int classId,
                                String className,
                                double score,
                                long timestampMs,
                                String modelVersion,
                                String source,
                                List<TopKItem> topK,
                                String rawJson,
                                String errorMessage) {
        this.valid = valid;
        this.classId = classId;
        this.className = className != null ? className : "";
        this.score = score;
        this.timestampMs = timestampMs;
        this.modelVersion = modelVersion != null ? modelVersion : "";
        this.source = source != null ? source : "";
        this.topK = topK != null
                ? Collections.unmodifiableList(new ArrayList<>(topK))
                : Collections.emptyList();
        this.rawJson = rawJson != null ? rawJson : "";
        this.errorMessage = errorMessage != null ? errorMessage : "";
    }

    public static LensClsSnapshotEvent fromJson(String rawJson) {
        if (rawJson == null || rawJson.trim().isEmpty()) {
            return invalid(rawJson, "empty cls snapshot");
        }
        try {
            JSONObject root = new JSONObject(rawJson);
            JSONArray topkJson = root.optJSONArray("topk");
            List<TopKItem> topK = new ArrayList<>();
            if (topkJson != null) {
                for (int i = 0; i < topkJson.length(); i++) {
                    JSONObject item = topkJson.optJSONObject(i);
                    if (item == null) {
                        continue;
                    }
                    topK.add(new TopKItem(
                            item.optInt("classId", -1),
                            item.optString("className", ""),
                            item.optDouble("score", 0.0)
                    ));
                }
            }
            return new LensClsSnapshotEvent(
                    root.optBoolean("valid", false),
                    root.optInt("classId", -1),
                    root.optString("className", ""),
                    root.optDouble("score", 0.0),
                    root.optLong("timestampMs", 0L),
                    root.optString("modelVersion", ""),
                    root.optString("source", ""),
                    topK,
                    rawJson,
                    root.optString("errorMessage", "")
            );
        } catch (Exception e) {
            return invalid(rawJson, "parse cls snapshot failed: " + e.getMessage());
        }
    }

    public static LensClsSnapshotEvent invalid(String rawJson, String errorMessage) {
        return new LensClsSnapshotEvent(
                false,
                -1,
                "",
                0.0,
                0L,
                "",
                "focus_cls",
                Collections.emptyList(),
                rawJson,
                errorMessage
        );
    }

    public boolean isValid() {
        return valid;
    }

    public int getClassId() {
        return classId;
    }

    public String getClassName() {
        return className;
    }

    public double getScore() {
        return score;
    }

    public long getTimestampMs() {
        return timestampMs;
    }

    public String getModelVersion() {
        return modelVersion;
    }

    public String getSource() {
        return source;
    }

    public List<TopKItem> getTopK() {
        return topK;
    }

    public String getRawJson() {
        return rawJson;
    }

    public String getErrorMessage() {
        return errorMessage;
    }

    public static class TopKItem {
        private final int classId;
        private final String className;
        private final double score;

        public TopKItem(int classId, String className, double score) {
            this.classId = classId;
            this.className = className != null ? className : "";
            this.score = score;
        }

        public int getClassId() {
            return classId;
        }

        public String getClassName() {
            return className;
        }

        public double getScore() {
            return score;
        }
    }
}
