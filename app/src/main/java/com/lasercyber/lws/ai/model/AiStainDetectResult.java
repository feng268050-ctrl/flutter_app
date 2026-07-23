package com.lasercyber.lws.ai.model;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ai.engine.AiManager;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Unified RKNN stain-detect result for {@link AiManager#rknnStainDetectFromNv12}, {@link AiManager#rknnStainDetectFromJpg}, etc.
 *
 * <p>Note: {@link #level} and {@link #status} are always present (required by OpenSpec).
 * Overlay boxes are {@link NormalizedBox} in 0..1 coordinates; map to UI via
 * {@code com.lasercyber.lws.ui.common.ai.overlay.DetectionOverlayMapper}.
 */
public final class AiStainDetectResult {

    public static final int LEVEL_ERROR = -1;

    public final boolean success;
    public final int code;
    public final int level;
    @NonNull
    public final String status;
    @NonNull
    public final String message;
    public final int imageWidth;
    public final int imageHeight;
    @NonNull
    public final List<NormalizedBox> boxes;
    @NonNull
    public final String source;
    public final long timestampMs;

    public AiStainDetectResult(boolean success,
                               int code,
                               int level,
                               @Nullable String status,
                               @Nullable String message,
                               int imageWidth,
                               int imageHeight,
                               @Nullable List<NormalizedBox> boxes,
                               @Nullable String source,
                               long timestampMs) {
        this.success = success;
        this.code = code;
        this.level = level;
        this.status = status == null ? "" : status;
        this.message = message == null ? "" : message;
        this.imageWidth = imageWidth;
        this.imageHeight = imageHeight;
        this.boxes = boxes == null ? Collections.emptyList() : Collections.unmodifiableList(new ArrayList<>(boxes));
        this.source = source == null ? "" : source;
        this.timestampMs = timestampMs;
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
}
