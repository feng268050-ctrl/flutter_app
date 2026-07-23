package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.NativeBridge;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.model.NormalizedBox;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

/**
 * Centralized mapper for native inference JSON and onCheckResult callback text into
 * {@link AiStainDetectResult}.
 */
public final class AiStainDetectResultMapper {

    private static final String TAG = "AiStainDetectResultMapper";

    static final int MAX_BOXES_PER_FRAME = 100;
    static final float MIN_BOX_PX = 8f;
    static final int MAX_DISPLAY_BOXES = 32;
    static final int CORRUPT_BOX_COUNT_THRESHOLD = 64;
    static final float CORRUPT_DEGENERATE_RATIO = 0.85f;

    private AiStainDetectResultMapper() {
    }

    /**
     * Maps a native onCheckResult callback, merging {@code level}/{@code status} from callback with
     * any JSON found inside {@code message}.
     *
     * <p>Merge rule: if {@code message} is JSON and contains {@code level}/{@code status}, they
     * override the callback args.
     */
    @NonNull
    public static AiStainDetectResult fromCheckResult(int callbackLevel,
                                                           @Nullable String callbackStatus,
                                                           @Nullable String message,
                                                           long timestampMs,
                                                           @Nullable String defaultSource) {
        return fromCheckResult(
                callbackLevel,
                callbackStatus,
                message,
                timestampMs,
                defaultSource,
                0,
                0);
    }

    @NonNull
    public static AiStainDetectResult fromCheckResult(int callbackLevel,
                                                           @Nullable String callbackStatus,
                                                           @Nullable String message,
                                                           long timestampMs,
                                                           @Nullable String defaultSource,
                                                           int fallbackFrameWidth,
                                                           int fallbackFrameHeight) {
        JSONObject root = parseJsonObject(message);
        if (root == null) {
            return new AiStainDetectResult(
                    true,
                    0,
                    callbackLevel,
                    callbackStatus,
                    message,
                    fallbackFrameWidth,
                    fallbackFrameHeight,
                    Collections.emptyList(),
                    defaultSource,
                    timestampMs);
        }
        int code = root.optInt("code", 0);
        int level = root.has("level") ? root.optInt("level", callbackLevel) : callbackLevel;
        String status = root.has("status") ? root.optString("status", callbackStatus) : callbackStatus;
        String human = root.optString("message", message == null ? "" : message);
        int imageWidth = root.optInt("imageWidth", 0);
        int imageHeight = root.optInt("imageHeight", 0);
        if (imageWidth <= 0) {
            imageWidth = fallbackFrameWidth;
        }
        if (imageHeight <= 0) {
            imageHeight = fallbackFrameHeight;
        }
        List<NormalizedBox> boxes = toNormalizedBoxes(
                parseBoxes(root.optJSONArray("boxes")), imageWidth, imageHeight);
        return new AiStainDetectResult(
                code == 0,
                code,
                level,
                normalizeStatus(status),
                human,
                imageWidth,
                imageHeight,
                boxes,
                root.optString("source", defaultSource == null ? "" : defaultSource),
                timestampMs);
    }

    @NonNull
    public static AiStainDetectResult fromStainInferOutcome(@NonNull NativeBridge.StainInferOutcome outcome,
                                                                 long timestampMs,
                                                                 @Nullable String defaultSource) {
        if (outcome.boxesTruncated) {
            Log.w(TAG, "native boxes truncated total=" + outcome.boxesTotal
                    + " returned=" + (outcome.boxes == null ? 0 : outcome.boxes.length));
        }
        String source = outcome.source;
        if (source == null || source.isEmpty()) {
            source = defaultSource == null ? "" : defaultSource;
        }
        List<PixelBox> rawBoxes = new ArrayList<>();
        if (outcome.boxes != null) {
            for (NativeBridge.StainBox box : outcome.boxes) {
                rawBoxes.add(new PixelBox(
                        box.x1, box.y1, box.x2, box.y2, box.classId, "", box.score));
            }
        }
        List<NormalizedBox> boxes = toNormalizedBoxes(rawBoxes, outcome.imageWidth, outcome.imageHeight);
        String message = outcome.isSuccess()
                ? outcome.detailMessage
                : outcome.errorMessage;
        if (message == null) {
            message = "";
        }
        int level = outcome.isSuccess()
                ? outcome.level
                : (outcome.level >= 0 ? outcome.level : AiStainDetectResult.LEVEL_ERROR);
        String status = outcome.isSuccess()
                ? normalizeStatus(outcome.status)
                : (outcome.status == null || outcome.status.isEmpty() ? "ERROR" : normalizeStatus(outcome.status));
        return new AiStainDetectResult(
                outcome.isSuccess(),
                outcome.code,
                level,
                status,
                message,
                outcome.imageWidth,
                outcome.imageHeight,
                boxes,
                source,
                timestampMs);
    }

    @NonNull
    public static AiStainDetectResult appError(int code,
                                                    @NonNull String status,
                                                    @NonNull String message,
                                                    long timestampMs,
                                                    @Nullable String source) {
        return new AiStainDetectResult(
                false,
                code,
                AiStainDetectResult.LEVEL_ERROR,
                status,
                message,
                0,
                0,
                Collections.emptyList(),
                source,
                timestampMs);
    }

    /** Internal timeline placeholder — must not be shown on AI Vision HUD. */
    public static final String STATUS_RKNN_OFF = "RKNN_OFF";

    /** True for stain placeholders / disabled markers that are not user-facing overlay labels. */
    public static boolean isNonDisplayOverlayStatus(@Nullable String status) {
        if (status == null) {
            return false;
        }
        String normalized = status.trim().toUpperCase(Locale.US);
        return STATUS_RKNN_OFF.equals(normalized) || "DISABLED".equals(normalized);
    }

    /** Placeholder RKNN-off row when timeline/SSE still need a stain-shaped payload. */
    @NonNull
    public static AiStainDetectResult rknnSkippedPlaceholder(int imageWidth,
                                                             int imageHeight,
                                                             long timestampMs,
                                                             @Nullable String source) {
        return new AiStainDetectResult(
                true,
                0,
                -1,
                STATUS_RKNN_OFF,
                "",
                imageWidth,
                imageHeight,
                Collections.emptyList(),
                source,
                timestampMs);
    }

    /** SSE/timeline stain row from OpenCV backend (wire format stays capability-level). */
    @NonNull
    public static AiStainDetectResult processVideoStainDetectRow(@NonNull OpencvStainDetectResult lensDet,
                                                            int imageWidth,
                                                            int imageHeight,
                                                            long timestampMs,
                                                            @Nullable String source) {
        return new AiStainDetectResult(
                lensDet.success,
                lensDet.code,
                lensDet.success ? 0 : -1,
                lensDet.success ? OpencvStainDetectResult.OVERLAY_STATUS : "ERROR",
                lensDet.message,
                imageWidth,
                imageHeight,
                boxesFromOpencvStainDetect(lensDet),
                source,
                timestampMs);
    }

    /** Rebuilds a running-row payload from a persisted timeline frame (replay / SSE parity). */
    @NonNull
    public static AiStainDetectResult fromTimelineFrame(@NonNull com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiTimeline.Frame frame,
                                                        @NonNull String source) {
        boolean success = frame.level >= 0 && !"ERROR".equalsIgnoreCase(frame.status.trim());
        int code = success ? 0 : -1;
        List<NormalizedBox> boxes = new ArrayList<>();
        for (com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiTimeline.Box box : frame.boxes) {
            boxes.add(NormalizedBox.fromPixelRect(
                    box.x1, box.y1, box.x2, box.y2,
                    frame.imageWidth, frame.imageHeight,
                    box.classId, box.label, box.score));
        }
        return new AiStainDetectResult(
                success,
                code,
                frame.level,
                frame.status,
                frame.message,
                frame.imageWidth,
                frame.imageHeight,
                boxes,
                source,
                frame.timeMs);
    }

    @NonNull
    public static List<NormalizedBox> boxesFromOpencvStainDetect(
            @NonNull OpencvStainDetectResult lensDet) {
        List<NormalizedBox> boxes = new ArrayList<>();
        if (!lensDet.hasTarget()) {
            return boxes;
        }
        float x1;
        float y1;
        float x2;
        float y2;
        if (lensDet.hasNativeBbox()) {
            x1 = lensDet.targetBboxX;
            y1 = lensDet.targetBboxY;
            x2 = lensDet.targetBboxX + lensDet.targetWidth;
            y2 = lensDet.targetBboxY + lensDet.targetHeight;
        } else {
            float cx = (float) lensDet.targetX;
            float cy = (float) lensDet.targetY;
            float r = OpencvStainDetectResult.MARKER_RADIUS_PX;
            x1 = cx - r;
            y1 = cy - r;
            x2 = cx + r;
            y2 = cy + r;
        }
        boxes.add(NormalizedBox.fromPixelRect(
                x1, y1, x2, y2,
                lensDet.imageWidth, lensDet.imageHeight,
                0, "contamination", 1.0));
        return boxes;
    }

    @Nullable
    private static String jsonEscape(@Nullable String value) {
        if (value == null) {
            return "";
        }
        return value.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r");
    }

    @Nullable
    private static JSONObject parseJsonObject(@Nullable String raw) {
        if (raw == null) {
            return null;
        }
        String trimmed = raw.trim();
        if (!trimmed.startsWith("{")) {
            return null;
        }
        try {
            return new JSONObject(trimmed);
        } catch (Exception e) {
            Log.w(TAG, "Skipped non-json check-result message");
            return null;
        }
    }

    @NonNull
    private static List<PixelBox> parseBoxes(@Nullable JSONArray boxes) {
        List<PixelBox> out = new ArrayList<>();
        if (boxes == null) {
            return out;
        }
        int boxCount = Math.min(boxes.length(), MAX_BOXES_PER_FRAME);
        for (int i = 0; i < boxCount; i++) {
            JSONObject boxObject = boxes.optJSONObject(i);
            if (boxObject != null) {
                out.add(boxFromJson(boxObject));
                continue;
            }
            Object item = boxes.opt(i);
            if (item instanceof JSONObject) {
                out.add(boxFromJson((JSONObject) item));
            } else if (item instanceof JSONArray) {
                JSONArray arr = (JSONArray) item;
                if (arr.length() < 4) {
                    continue;
                }
                out.add(new PixelBox(
                        (float) arr.optDouble(0, 0.0),
                        (float) arr.optDouble(1, 0.0),
                        (float) arr.optDouble(2, 0.0),
                        (float) arr.optDouble(3, 0.0),
                        -1,
                        "",
                        -1.0));
            }
        }
        return out;
    }

    @NonNull
    private static PixelBox boxFromJson(@NonNull JSONObject root) {
        return new PixelBox(
                (float) root.optDouble("x1", 0.0),
                (float) root.optDouble("y1", 0.0),
                (float) root.optDouble("x2", 0.0),
                (float) root.optDouble("y2", 0.0),
                root.optInt("classId", root.optInt("class_id", -1)),
                root.optString("label", ""),
                root.optDouble("score", -1.0));
    }

    @NonNull
    private static List<NormalizedBox> toNormalizedBoxes(@Nullable List<PixelBox> raw,
                                                         int imageWidth,
                                                         int imageHeight) {
        List<PixelBox> sanitized = sanitizePixelBoxes(raw, imageWidth, imageHeight);
        List<NormalizedBox> out = new ArrayList<>();
        for (PixelBox box : sanitized) {
            out.add(NormalizedBox.fromPixelRect(
                    box.x1, box.y1, box.x2, box.y2,
                    imageWidth, imageHeight,
                    box.classId, box.label, box.score));
        }
        return out;
    }

    @NonNull
    static List<PixelBox> sanitizePixelBoxes(@Nullable List<PixelBox> raw,
                                             int imageWidth,
                                             int imageHeight) {
        if (raw == null || raw.isEmpty()) {
            return new ArrayList<>();
        }
        if (isCorruptNativeBoxBatch(raw, imageWidth, imageHeight)) {
            Log.w(TAG, "dropped corrupt native inference boxes count=" + raw.size()
                    + " image=" + imageWidth + "x" + imageHeight);
            return new ArrayList<>();
        }
        List<PixelBox> sanitized = new ArrayList<>();
        for (PixelBox box : raw) {
            PixelBox ordered = ordered(box);
            if (isDegenerateInferenceBox(
                    ordered.x1, ordered.y1, ordered.x2, ordered.y2,
                    imageWidth, imageHeight)) {
                continue;
            }
            sanitized.add(ordered);
            if (sanitized.size() >= MAX_DISPLAY_BOXES) {
                break;
            }
        }
        return sanitized;
    }

    private static PixelBox ordered(@NonNull PixelBox box) {
        return new PixelBox(
                Math.min(box.x1, box.x2),
                Math.min(box.y1, box.y2),
                Math.max(box.x1, box.x2),
                Math.max(box.y1, box.y2),
                box.classId,
                box.label,
                box.score);
    }

    private static boolean isDegenerateInferenceBox(float x1, float y1, float x2, float y2,
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

    private static boolean isCorruptNativeBoxBatch(@Nullable List<PixelBox> boxes,
                                                   int imageWidth,
                                                   int imageHeight) {
        if (boxes == null || boxes.size() < CORRUPT_BOX_COUNT_THRESHOLD) {
            return false;
        }
        int degenerate = 0;
        int scoreOne = 0;
        for (PixelBox box : boxes) {
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

    @Nullable
    static String normalizeStatus(@Nullable String status) {
        if (status == null) {
            return "";
        }
        String trimmed = status.trim();
        if (trimmed.isEmpty()) {
            return "";
        }
        if ("stain_mild".equalsIgnoreCase(trimmed)) {
            return "MILD";
        }
        if ("stain_heavy".equalsIgnoreCase(trimmed)) {
            return "HEAVY";
        }
        if ("csl:clean".equalsIgnoreCase(trimmed)) {
            return "CLEAN";
        }
        if ("clean".equalsIgnoreCase(trimmed)) {
            return "CLEAN";
        }
        return trimmed.toUpperCase(Locale.US);
    }

    static final class PixelBox {
        final float x1;
        final float y1;
        final float x2;
        final float y2;
        final int classId;
        @NonNull
        final String label;
        final double score;

        PixelBox(float x1, float y1, float x2, float y2, int classId, @Nullable String label, double score) {
            this.x1 = x1;
            this.y1 = y1;
            this.x2 = x2;
            this.y2 = y2;
            this.classId = classId;
            this.label = label == null ? "" : label;
            this.score = score;
        }
    }
}

