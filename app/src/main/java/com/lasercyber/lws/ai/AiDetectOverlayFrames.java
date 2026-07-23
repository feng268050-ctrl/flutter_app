package com.lasercyber.lws.ai;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.model.NormalizedBox;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.stain.LensStainBoxTemporalReducer;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiTimeline;

import java.util.ArrayList;
import java.util.List;

/** Builds {@link ProcessVideoAiTimeline.Frame} from stain-detect results for timeline / overlay. */
public final class AiDetectOverlayFrames {

    private AiDetectOverlayFrames() {
    }

    @NonNull
    public static ProcessVideoAiTimeline.Frame toTimelineFrame(@Nullable AiStainDetectResult result,
                                                               int fallbackWidth,
                                                               int fallbackHeight) {
        if (result == null) {
            return emptyFrame(fallbackWidth, fallbackHeight);
        }
        int imageWidth = result.imageWidth > 0 ? result.imageWidth : fallbackWidth;
        int imageHeight = result.imageHeight > 0 ? result.imageHeight : fallbackHeight;
        List<ProcessVideoAiTimeline.Box> boxes = new ArrayList<>();
        for (NormalizedBox box : result.boxes) {
            float[] xyxy = box.toPixelXyxy(imageWidth, imageHeight);
            boxes.add(new ProcessVideoAiTimeline.Box(
                    xyxy[0], xyxy[1], xyxy[2], xyxy[3], box.classId, box.label, box.score));
        }
        return new ProcessVideoAiTimeline.Frame(
                result.timestampMs,
                result.level,
                result.status,
                result.message,
                imageWidth,
                imageHeight,
                boxes);
    }

    @NonNull
    public static ProcessVideoAiTimeline.Frame buildTemporalSummaryFrame(
            @NonNull LensStainBoxTemporalReducer.Result reduced,
            long summaryTimeMs) {
        List<ProcessVideoAiTimeline.Box> boxes = new ArrayList<>();
        for (LensStainBoxTemporalReducer.PersistentBox box : reduced.boxes) {
            boxes.add(box.toTimelineBox());
        }
        boolean dirty = reduced.hasContamination();
        int level = dirty ? 2 : 0;
        String status = dirty ? OpencvStainDetectResult.OVERLAY_STATUS : "CLEAN";
        return new ProcessVideoAiTimeline.Frame(
                summaryTimeMs,
                level,
                status,
                "",
                reduced.imageWidth,
                reduced.imageHeight,
                boxes,
                null,
                true);
    }

    @NonNull
    private static ProcessVideoAiTimeline.Frame emptyFrame(int fallbackWidth, int fallbackHeight) {
        return new ProcessVideoAiTimeline.Frame(
                0L,
                -1,
                "",
                "",
                fallbackWidth,
                fallbackHeight,
                new ArrayList<>());
    }
}
