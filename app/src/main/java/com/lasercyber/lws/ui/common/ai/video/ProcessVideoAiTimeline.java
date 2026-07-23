package com.lasercyber.lws.ui.common.ai.video;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ai.stain.LensDetConsecutiveOkFilter;
import com.lasercyber.lws.ai.model.OpencvDetectCodes;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

/**
 * In-memory timeline of per-sample inference results for a process video session.
 */
public final class ProcessVideoAiTimeline {

    private static final int MAX_BOXES_PER_FRAME = 100;
    private static final int MAX_DISPLAY_BOXES = 32;
    private static final int CORRUPT_BOX_COUNT_THRESHOLD = 64;
    private static final float CORRUPT_DEGENERATE_RATIO = 0.85f;
    private static final float MIN_BOX_PX = 8f;

    public final String cacheKey;
    public final long durationMs;
    public final long sampleIntervalMs;
    private final List<Frame> frames = new ArrayList<>();

    public ProcessVideoAiTimeline(@NonNull String cacheKey, long durationMs, long sampleIntervalMs) {
        this.cacheKey = cacheKey;
        this.durationMs = durationMs;
        this.sampleIntervalMs = sampleIntervalMs;
    }

    public synchronized void addFrame(@NonNull Frame frame) {
        frames.add(frame);
    }

    @NonNull
    public synchronized List<Frame> snapshotFrames() {
        return Collections.unmodifiableList(new ArrayList<>(frames));
    }

    /**
     * Drops per-sample detections that are not part of a consecutive native-ok run long enough to
     * be considered valid (see {@link LensDetConsecutiveOkFilter}).
     */
    public synchronized void applyLensDetConsecutiveOkFilter(int redMinConsecutive, int blueMinConsecutive) {
        List<Frame> filtered = filterTimelineFrames(frames, redMinConsecutive, blueMinConsecutive);
        frames.clear();
        frames.addAll(filtered);
    }

    /**
     * Clears per-sample boxes on timeline frames whose native detection is not part of a valid
     * consecutive run. Summary frames are passed through unchanged.
     */
    @NonNull
    public static List<Frame> filterTimelineFrames(
            @NonNull List<Frame> frames,
            int redMinConsecutive,
            int blueMinConsecutive) {
        if (frames.isEmpty() || (redMinConsecutive <= 1 && blueMinConsecutive <= 1)) {
            return frames;
        }
        List<Integer> sampleIndices = new ArrayList<>();
        List<Boolean> nativeOk = new ArrayList<>();
        List<Integer> minRequired = new ArrayList<>();
        for (int i = 0; i < frames.size(); i++) {
            Frame frame = frames.get(i);
            if (frame.temporalSummary) {
                continue;
            }
            sampleIndices.add(i);
            nativeOk.add(frameHasNativeDetection(frame));
            minRequired.add(minConsecutiveForFrame(frame, redMinConsecutive, blueMinConsecutive));
        }
        boolean[] nativeOkArray = new boolean[nativeOk.size()];
        int[] minArray = new int[minRequired.size()];
        for (int i = 0; i < nativeOk.size(); i++) {
            nativeOkArray[i] = nativeOk.get(i);
            minArray[i] = minRequired.get(i);
        }
        boolean[] effective = LensDetConsecutiveOkFilter.effectiveOkMask(nativeOkArray, minArray);

        List<Frame> out = new ArrayList<>(frames);
        for (int j = 0; j < sampleIndices.size(); j++) {
            if (effective[j]) {
                continue;
            }
            int frameIndex = sampleIndices.get(j);
            Frame frame = frames.get(frameIndex);
            if (!frameHasNativeDetection(frame)) {
                continue;
            }
            out.set(frameIndex, clearedDetectionFrame(frame));
        }
        return out;
    }

    /** @deprecated use {@link #filterTimelineFrames(List, int, int)} */
    @NonNull
    public static List<Frame> filterTimelineFrames(@NonNull List<Frame> frames, int minConsecutive) {
        return filterTimelineFrames(frames, minConsecutive, minConsecutive);
    }

    private static int minConsecutiveForFrame(@NonNull Frame frame,
                                              int redMinConsecutive,
                                              int blueMinConsecutive) {
        if (frame.stainDetect != null && "blue".equalsIgnoreCase(frame.stainDetect.frameKind)) {
            return blueMinConsecutive;
        }
        return redMinConsecutive;
    }

    private static boolean frameHasNativeDetection(@NonNull Frame frame) {
        if (!frame.boxes.isEmpty()) {
            return true;
        }
        return frame.stainDetect != null && frame.stainDetect.hasTarget();
    }

    @NonNull
    private static Frame clearedDetectionFrame(@NonNull Frame frame) {
        return new Frame(
                frame.timeMs,
                0,
                "CLEAN",
                OpencvDetectCodes.REASON_INSUFFICIENT_CONSECUTIVE_OK_FRAMES,
                frame.imageWidth,
                frame.imageHeight,
                Collections.emptyList(),
                frame.stainDetect == null
                        ? null
                        : new StainDetect(
                                false,
                                frame.stainDetect.code,
                                Double.NaN,
                                Double.NaN,
                                frame.stainDetect.source,
                                frame.stainDetect.frameKind),
                frame.temporalSummary);
    }

    @Nullable
    public synchronized Frame findFrameAt(long positionMs) {
        if (frames.isEmpty()) {
            return null;
        }
        Frame selected = frames.get(0);
        for (Frame frame : frames) {
            if (frame.timeMs <= positionMs) {
                selected = frame;
            } else {
                break;
            }
        }
        return selected;
    }

    /** Latest temporal summary frame appended at session end, or null when not yet reduced. */
    @Nullable
    public synchronized Frame findTemporalSummaryFrame() {
        Frame selected = null;
        for (Frame frame : frames) {
            if (frame.temporalSummary) {
                selected = frame;
            }
        }
        return selected;
    }

    public synchronized boolean hasSampleAt(long sampleMs) {
        for (Frame frame : frames) {
            if (frame.timeMs == sampleMs) {
                return true;
            }
        }
        return false;
    }

    @NonNull
    public static Frame fromNativeJson(long timeMs, @NonNull String json, int frameWidth, int frameHeight)
            throws Exception {
        JSONObject root = new JSONObject(json);
        int code = root.optInt("code", -999);
        if (code != 0) {
            throw new IllegalStateException(root.optString("message", "Native inference failed code=" + code));
        }
        return fromJsonRoot(timeMs, root, frameWidth, frameHeight);
    }

    @NonNull
    private static Frame fromJsonRoot(long timeMs, @NonNull JSONObject root, int fallbackWidth, int fallbackHeight) {
        int imageWidth = root.optInt("imageWidth", 0);
        int imageHeight = root.optInt("imageHeight", 0);
        if (imageWidth <= 0 && fallbackWidth > 0) {
            imageWidth = fallbackWidth;
        }
        if (imageHeight <= 0 && fallbackHeight > 0) {
            imageHeight = fallbackHeight;
        }
        List<Box> boxes = new ArrayList<>();
        JSONArray boxArray = root.optJSONArray("boxes");
        if (boxArray != null) {
            int boxCount = Math.min(boxArray.length(), MAX_BOXES_PER_FRAME);
            for (int i = 0; i < boxCount; i++) {
                JSONObject box = boxArray.optJSONObject(i);
                if (box != null) {
                    boxes.add(Box.fromJson(box));
                }
            }
        }
        boxes = sanitizeBoxes(boxes, imageWidth, imageHeight);
        return new Frame(
                timeMs,
                root.optInt("level", -1),
                root.optString("status", ""),
                root.optString("message", ""),
                imageWidth,
                imageHeight,
                boxes);
    }

    @NonNull
    private static List<Box> sanitizeBoxes(@NonNull List<Box> boxes, int imageWidth, int imageHeight) {
        if (boxes.isEmpty()) {
            return boxes;
        }
        if (boxes.size() >= CORRUPT_BOX_COUNT_THRESHOLD) {
            int degenerate = 0;
            for (Box box : boxes) {
                if (box.y2 <= MIN_BOX_PX) {
                    degenerate++;
                }
            }
            if (degenerate / (float) boxes.size() >= CORRUPT_DEGENERATE_RATIO) {
                return Collections.emptyList();
            }
        }
        List<Box> out = new ArrayList<>(Math.min(boxes.size(), MAX_DISPLAY_BOXES));
        for (int i = 0; i < boxes.size() && out.size() < MAX_DISPLAY_BOXES; i++) {
            Box box = boxes.get(i);
            float w = Math.abs(box.x2 - box.x1);
            float h = Math.abs(box.y2 - box.y1);
            if (w >= MIN_BOX_PX && h >= MIN_BOX_PX) {
                out.add(box);
            }
        }
        return out;
    }

    /** Stain-detect snapshot on a timeline frame (capability-level; no backend exposed). */
    public static final class StainDetect {
        public final boolean success;
        public final int code;
        public final double targetX;
        public final double targetY;
        @NonNull
        public final String source;
        @NonNull
        public final String frameKind;

        public StainDetect(boolean success,
                           int code,
                           double targetX,
                           double targetY,
                           @Nullable String source) {
            this(success, code, targetX, targetY, source, "red");
        }

        public StainDetect(boolean success,
                           int code,
                           double targetX,
                           double targetY,
                           @Nullable String source,
                           @Nullable String frameKind) {
            this.success = success;
            this.code = code;
            this.targetX = targetX;
            this.targetY = targetY;
            this.source = source == null ? "" : source;
            this.frameKind = frameKind == null || frameKind.isEmpty() ? "red" : frameKind;
        }

        public boolean hasTarget() {
            return success && Double.isFinite(targetX) && Double.isFinite(targetY);
        }

        @NonNull
        public static StainDetect fromResult(@NonNull OpencvStainDetectResult result) {
            return new StainDetect(
                    result.success,
                    result.code,
                    result.targetX,
                    result.targetY,
                    result.source,
                    result.frameKind);
        }
    }

    public static final class Frame {
        public final long timeMs;
        public final int level;
        @NonNull
        public final String status;
        @NonNull
        public final String message;
        public final int imageWidth;
        public final int imageHeight;
        @NonNull
        public final List<Box> boxes;
        @Nullable
        public final StainDetect stainDetect;
        /** True for the single reduced summary frame appended when a detect session completes. */
        public final boolean temporalSummary;

        public Frame(long timeMs,
                     int level,
                     @Nullable String status,
                     @Nullable String message,
                     int imageWidth,
                     int imageHeight,
                     @Nullable List<Box> boxes) {
            this(timeMs, level, status, message, imageWidth, imageHeight, boxes, null);
        }

        public Frame(long timeMs,
                     int level,
                     @Nullable String status,
                     @Nullable String message,
                     int imageWidth,
                     int imageHeight,
                     @Nullable List<Box> boxes,
                     @Nullable StainDetect stainDetect) {
            this(timeMs, level, status, message, imageWidth, imageHeight, boxes, stainDetect, false);
        }

        public Frame(long timeMs,
                     int level,
                     @Nullable String status,
                     @Nullable String message,
                     int imageWidth,
                     int imageHeight,
                     @Nullable List<Box> boxes,
                     @Nullable StainDetect stainDetect,
                     boolean temporalSummary) {
            this.timeMs = timeMs;
            this.level = level;
            this.status = status == null ? "" : status;
            this.message = message == null ? "" : message;
            this.imageWidth = imageWidth;
            this.imageHeight = imageHeight;
            this.boxes = boxes == null ? Collections.emptyList() : boxes;
            this.stainDetect = stainDetect;
            this.temporalSummary = temporalSummary;
        }

        @NonNull
        public String displayMessage() {
            if (!message.trim().isEmpty()) {
                return message;
            }
            if (!status.trim().isEmpty()) {
                return status;
            }
            return "level=" + level;
        }

        @NonNull
        public List<com.lasercyber.lws.ui.common.view.DetectionOverlayView.Box> toOverlayBoxes() {
            return com.lasercyber.lws.ui.common.ai.overlay.DetectionOverlayMapper.fromTimelineFrame(this);
        }

        /** True when this sample produced overlay boxes or a stain-detect target. */
        public boolean hasDetection() {
            if (!boxes.isEmpty()) {
                return true;
            }
            return stainDetect != null && stainDetect.hasTarget();
        }
    }

    public static final class Box {
        public final float x1;
        public final float y1;
        public final float x2;
        public final float y2;
        public final int classId;
        @NonNull
        public final String label;
        public final double score;

        public Box(float x1, float y1, float x2, float y2, int classId, @Nullable String label, double score) {
            this.x1 = x1;
            this.y1 = y1;
            this.x2 = x2;
            this.y2 = y2;
            this.classId = classId;
            this.label = label == null ? "" : label;
            this.score = score;
        }

        @NonNull
        static Box fromJson(@NonNull JSONObject root) {
            return new Box(
                    (float) root.optDouble("x1", 0.0),
                    (float) root.optDouble("y1", 0.0),
                    (float) root.optDouble("x2", 0.0),
                    (float) root.optDouble("y2", 0.0),
                    root.optInt("classId", root.optInt("class_id", -1)),
                    root.optString("label", ""),
                    root.optDouble("score", 0.0));
        }

        @NonNull
        String displayLabel() {
            if (!label.trim().isEmpty()) {
                return label;
            }
            if (classId >= 0) {
                return String.format(Locale.US, "cls_%d", classId);
            }
            return String.format(Locale.US, "%.2f", score);
        }
    }
}
