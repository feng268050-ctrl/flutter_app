package com.lasercyber.lws.ui.common.ai.overlay;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.model.NormalizedBox;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiTimeline;
import com.lasercyber.lws.ui.common.view.DetectionOverlayView;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

/**
 * Maps AI result DTOs ({@link NormalizedBox}) to {@link DetectionOverlayView} draw primitives.
 */
public final class DetectionOverlayMapper {

    private DetectionOverlayMapper() {
    }

    @NonNull
    public static DetectionOverlayView.Box toOverlayBox(@NonNull NormalizedBox box) {
        return new DetectionOverlayView.Box(
                box.x,
                box.y,
                box.x2(),
                box.y2(),
                formatDetectionClassLabel(box.label, box.classId, box.score));
    }

    @NonNull
    public static List<DetectionOverlayView.Box> toOverlayBoxes(@Nullable List<NormalizedBox> boxes) {
        if (boxes == null || boxes.isEmpty()) {
            return Collections.emptyList();
        }
        List<DetectionOverlayView.Box> out = new ArrayList<>(boxes.size());
        for (NormalizedBox box : boxes) {
            out.add(toOverlayBox(box));
        }
        return out;
    }

    @NonNull
    public static List<DetectionOverlayView.Box> fromAiStainDetectResult(@NonNull AiStainDetectResult result) {
        return toOverlayBoxes(result.boxes);
    }

    @NonNull
    public static List<DetectionOverlayView.Box> fromOpencvStainDetect(
            @NonNull OpencvStainDetectResult result,
            int fallbackWidth,
            int fallbackHeight) {
        if (!result.hasTarget()) {
            return Collections.emptyList();
        }
        int w = result.imageWidth > 0 ? result.imageWidth : fallbackWidth;
        int h = result.imageHeight > 0 ? result.imageHeight : fallbackHeight;
        float x0;
        float y0;
        float x1;
        float y1;
        if (result.hasNativeBbox()) {
            x0 = result.targetBboxX;
            y0 = result.targetBboxY;
            x1 = result.targetBboxX + result.targetWidth;
            y1 = result.targetBboxY + result.targetHeight;
        } else {
            float cx = (float) result.targetX;
            float cy = (float) result.targetY;
            float r = OpencvStainDetectResult.MARKER_RADIUS_PX;
            x0 = cx - r;
            y0 = cy - r;
            x1 = cx + r;
            y1 = cy + r;
        }
        NormalizedBox box = NormalizedBox.fromPixelRect(
                x0, y0, x1, y1, w, h, 0, "contamination", 1.0);
        return Collections.singletonList(new DetectionOverlayView.Box(
                box.x, box.y, box.x2(), box.y2(), "contamination"));
    }

    @NonNull
    public static List<DetectionOverlayView.Box> fromTimelineFrame(@NonNull ProcessVideoAiTimeline.Frame frame) {
        List<DetectionOverlayView.Box> out = new ArrayList<>();
        for (ProcessVideoAiTimeline.Box box : frame.boxes) {
            NormalizedBox normalized = NormalizedBox.fromPixelRect(
                    box.x1, box.y1, box.x2, box.y2,
                    frame.imageWidth, frame.imageHeight,
                    box.classId, box.label, box.score);
            out.add(new DetectionOverlayView.Box(
                    normalized.x,
                    normalized.y,
                    normalized.x2(),
                    normalized.y2(),
                    timelineBoxLabel(box)));
        }
        return out;
    }

    @NonNull
    private static String timelineBoxLabel(@NonNull ProcessVideoAiTimeline.Box box) {
        if (!box.label.trim().isEmpty()) {
            return box.label;
        }
        if (box.classId >= 0) {
            return String.format(Locale.US, "cls_%d", box.classId);
        }
        return String.format(Locale.US, "%.2f", box.score);
    }

    @NonNull
    public static String formatDetectionClassLabel(@NonNull String label, int classId, double score) {
        String base = formatClassLabel(label, classId);
        if (score >= 0.0) {
            return base + " " + String.format(Locale.US, "%.2f", score);
        }
        return base;
    }

    @NonNull
    private static String formatClassLabel(@NonNull String label, int classId) {
        String trimmed = label.trim();
        if (!trimmed.isEmpty()) {
            if ("cls=0".equalsIgnoreCase(trimmed)) {
                return "cls=cont";
            }
            return trimmed;
        }
        if (classId == 0) {
            return "cls=cont";
        }
        if (classId >= 0) {
            return "cls=" + classId;
        }
        return "";
    }
}
