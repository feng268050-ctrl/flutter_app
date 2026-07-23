package com.lasercyber.lws.ui.network.http.local.overlay;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.ai.overlay.OverlayGeometry;
import com.lasercyber.lws.ui.common.view.DetectionOverlayView;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Parses native stain check-result JSON into overlay boxes for AI Vision UI and HTTP AI stream.
 */
public final class AiVisionOverlayParser {

    private static final String TAG = "AiVisionOverlayParser";

    static final int MAX_BOXES_PER_FRAME = 100;
    static final float MIN_BOX_PX = 8f;
    static final int MAX_DISPLAY_BOXES = 32;
    static final int CORRUPT_BOX_COUNT_THRESHOLD = 64;
    static final float CORRUPT_DEGENERATE_RATIO = 0.85f;

    private AiVisionOverlayParser() {
    }

    @NonNull
    public static CameraAiOverlayState.Snapshot buildSnapshot(@Nullable String rawMessage,
                                                              @Nullable String status) {
        String display = resolveDisplayMessage(rawMessage);
        List<DetectionOverlayView.Box> boxes = parseOverlayBoxes(rawMessage);
        if (boxes.isEmpty()) {
            boxes = buildFallbackBoxes(status, rawMessage);
        }
        return new CameraAiOverlayState.Snapshot(display, boxes);
    }

    @NonNull
    public static String resolveDisplayMessage(@Nullable String rawMessage) {
        if (rawMessage == null) {
            return "";
        }
        String message = rawMessage.trim();
        if (!message.startsWith("{")) {
            return rawMessage;
        }
        try {
            JSONObject root = new JSONObject(message);
            String human = root.optString("message", "");
            if (!human.trim().isEmpty()) {
                return human;
            }
            String status = root.optString("status", "");
            if (!status.trim().isEmpty()) {
                return status;
            }
        } catch (Exception e) {
            Log.w(TAG, "resolveDisplayMessage skipped non-json message");
        }
        return rawMessage;
    }

    @NonNull
    public static List<DetectionOverlayView.Box> parseOverlayBoxes(@Nullable String rawMessage) {
        List<DetectionOverlayView.Box> parsed = new ArrayList<>();
        if (rawMessage == null) {
            return parsed;
        }
        String message = rawMessage.trim();
        if (!message.startsWith("{")) {
            return parsed;
        }
        try {
            JSONObject root = new JSONObject(message);
            int imageWidth = root.optInt("imageWidth", 0);
            int imageHeight = root.optInt("imageHeight", 0);
            JSONArray boxes;
            try {
                boxes = root.getJSONArray("boxes");
            } catch (Exception e) {
                return parsed;
            }
            List<InferenceBox> raw = new ArrayList<>();
            int boxCount = Math.min(boxes.length(), MAX_BOXES_PER_FRAME);
            for (int i = 0; i < boxCount; i++) {
                JSONObject boxObject = boxes.optJSONObject(i);
                if (boxObject != null) {
                    raw.add(InferenceBox.fromJson(boxObject));
                    continue;
                }
                Object item = boxes.opt(i);
                if (item instanceof JSONObject) {
                    raw.add(InferenceBox.fromJson((JSONObject) item));
                } else if (item instanceof JSONArray) {
                    JSONArray arr = (JSONArray) item;
                    if (arr.length() < 4) {
                        continue;
                    }
                    raw.add(new InferenceBox(
                            (float) arr.optDouble(0, 0.0),
                            (float) arr.optDouble(1, 0.0),
                            (float) arr.optDouble(2, 0.0),
                            (float) arr.optDouble(3, 0.0),
                            -1,
                            "",
                            -1.0));
                }
            }
            for (InferenceBox box : sanitizeBoxes(raw, imageWidth, imageHeight)) {
                DetectionOverlayView.Box overlay = box.toOverlayBox(imageWidth, imageHeight);
                parsed.add(new DetectionOverlayView.Box(
                        overlay.x1,
                        overlay.y1,
                        overlay.x2,
                        overlay.y2,
                        box.displayLabel()));
            }
        } catch (Exception e) {
            Log.w(TAG, "parseOverlayBoxes skipped non-json message");
        }
        return parsed;
    }

    @NonNull
    public static List<DetectionOverlayView.Box> buildFallbackBoxes(@Nullable String status,
                                                                    @Nullable String message) {
        List<DetectionOverlayView.Box> fallback = new ArrayList<>();
        String statusText = status == null ? "" : status.trim();
        String normalized = statusText.toLowerCase(Locale.US);
        String normalizedMessage = message == null ? "" : message.toLowerCase(Locale.US);

        boolean shouldDrawFullFrame =
                "stain_mild".equalsIgnoreCase(statusText)
                        || "stain_heavy".equalsIgnoreCase(statusText)
                        || "clean".equalsIgnoreCase(statusText)
                        || "csl:clean".equalsIgnoreCase(statusText)
                        || normalizedMessage.contains("轻度污染")
                        || normalizedMessage.contains("重度污染")
                        || normalizedMessage.contains("clean")
                        || normalized.contains("csl:clean");
        if (!shouldDrawFullFrame) {
            return fallback;
        }

        String label = statusText.isEmpty() ? message : statusText;
        fallback.add(new DetectionOverlayView.Box(0f, 0f, 1f, 1f, label));
        return fallback;
    }

    static List<InferenceBox> sanitizeBoxes(List<InferenceBox> raw, int imageWidth, int imageHeight) {
        if (raw == null || raw.isEmpty()) {
            return new ArrayList<>();
        }
        if (isCorruptNativeBoxBatch(raw, imageWidth, imageHeight)) {
            Log.w(TAG, "dropped corrupt native inference boxes count=" + raw.size()
                    + " image=" + imageWidth + "x" + imageHeight);
            return new ArrayList<>();
        }
        List<InferenceBox> sanitized = new ArrayList<>();
        for (InferenceBox box : raw) {
            InferenceBox normalized = box.normalized();
            if (isDegenerateInferenceBox(
                    normalized.x1, normalized.y1, normalized.x2, normalized.y2,
                    imageWidth, imageHeight)) {
                continue;
            }
            sanitized.add(normalized);
            if (sanitized.size() >= MAX_DISPLAY_BOXES) {
                break;
            }
        }
        return sanitized;
    }

    static boolean isDegenerateInferenceBox(float x1, float y1, float x2, float y2,
                                            int imageWidth, int imageHeight) {
        float left = Math.min(x1, x2);
        float right = Math.max(x1, x2);
        float top = Math.min(y1, y2);
        float bottom = Math.max(y1, y2);
        float width = right - left;
        float height = bottom - top;
        if (width <= 0f || height <= 0f) {
            return true;
        }
        if (imageWidth > 0 && imageHeight > 0
                && right <= 1.5f && bottom <= 1.5f && left <= 1.5f && top <= 1.5f) {
            return width < 0.002f || height < 0.002f;
        }
        if (imageWidth > 0 && imageHeight > 0) {
            return width < MIN_BOX_PX || height < MIN_BOX_PX;
        }
        return width < 1f || height < 1f;
    }

    static boolean isCorruptNativeBoxBatch(List<InferenceBox> boxes, int imageWidth, int imageHeight) {
        if (boxes == null || boxes.size() < CORRUPT_BOX_COUNT_THRESHOLD) {
            return false;
        }
        int degenerate = 0;
        int scoreOne = 0;
        for (InferenceBox box : boxes) {
            if (isDegenerateInferenceBox(box.x1, box.y1, box.x2, box.y2, imageWidth, imageHeight)) {
                degenerate++;
            }
            if (box.score >= 0.999) {
                scoreOne++;
            }
        }
        float degenerateRatio = degenerate / (float) boxes.size();
        return degenerateRatio >= CORRUPT_DEGENERATE_RATIO
                && scoreOne >= boxes.size() * CORRUPT_DEGENERATE_RATIO;
    }

    static final class InferenceBox {
        final float x1;
        final float y1;
        final float x2;
        final float y2;
        final int classId;
        final String label;
        final double score;

        InferenceBox(float x1, float y1, float x2, float y2, int classId, String label, double score) {
            this.x1 = x1;
            this.y1 = y1;
            this.x2 = x2;
            this.y2 = y2;
            this.classId = classId;
            this.label = label == null ? "" : label;
            this.score = score;
        }

        static InferenceBox fromJson(JSONObject root) {
            return new InferenceBox(
                    (float) root.optDouble("x1", 0.0),
                    (float) root.optDouble("y1", 0.0),
                    (float) root.optDouble("x2", 0.0),
                    (float) root.optDouble("y2", 0.0),
                    root.optInt("classId", -1),
                    root.optString("label", ""),
                    root.optDouble("score", -1.0));
        }

        InferenceBox normalized() {
            return new InferenceBox(
                    Math.min(x1, x2),
                    Math.min(y1, y2),
                    Math.max(x1, x2),
                    Math.max(y1, y2),
                    classId,
                    label,
                    score);
        }

        DetectionOverlayView.Box toOverlayBox(int imageWidth, int imageHeight) {
            android.graphics.RectF norm = OverlayGeometry.toNormalizedRect(
                    x1, y1, x2, y2, imageWidth, imageHeight);
            return new DetectionOverlayView.Box(
                    norm.left, norm.top, norm.right, norm.bottom, displayLabel());
        }

        String displayLabel() {
            String base = formatDetectionClassLabel(label, classId);
            if (score >= 0.0) {
                return base + " " + String.format(Locale.US, "%.2f", score);
            }
            return base;
        }

        private static String formatDetectionClassLabel(String label, int classId) {
            String trimmed = label == null ? "" : label.trim();
            if (!trimmed.isEmpty()) {
                if ("cls=0".equalsIgnoreCase(trimmed)) {
                    return "cls=cont";
                }
                return trimmed;
            }
            if (classId == 0) {
                return "cls=cont";
            }
            return "cls=" + classId;
        }

        private static float clamp(float value, float min, float max) {
            return Math.max(min, Math.min(max, value));
        }
    }
}
