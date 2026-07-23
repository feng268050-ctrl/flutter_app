package com.lasercyber.lws.ai.model;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ai.NativeBridge;

/**
 * App-side result for OpenCV lens_det ({@link NativeBridge#nativeOpencvStainDetectFromNv12}).
 *
 * <p>Target geometry is pixel-space; map to overlay via
 * {@code com.lasercyber.lws.ui.common.ai.overlay.DetectionOverlayMapper}.
 */
public final class OpencvStainDetectResult {

    /** Half-width of the fallback overlay marker when native bbox is absent. */
    public static final float MARKER_RADIUS_PX = 12f;
    /** HUD status line when stain detect is the active overlay source. */
    public static final String OVERLAY_STATUS = "STAIN_DETECT";

    public final boolean success;
    public final int code;
    @NonNull
    public final String message;
    public final double targetX;
    public final double targetY;
    public final int targetBboxX;
    public final int targetBboxY;
    public final int targetWidth;
    public final int targetHeight;
    public final int imageWidth;
    public final int imageHeight;
    @NonNull
    public final String source;
    public final long timestampMs;
    @NonNull
    public final String frameKind;

    public OpencvStainDetectResult(boolean success,
                                   int code,
                                   @Nullable String message,
                                   double targetX,
                                   double targetY,
                                   int imageWidth,
                                   int imageHeight,
                                   @Nullable String source,
                                   long timestampMs) {
        this(success, code, message, targetX, targetY,
                0, 0, 0, 0, imageWidth, imageHeight, source, timestampMs, "red");
    }

    public OpencvStainDetectResult(boolean success,
                                   int code,
                                   @Nullable String message,
                                   double targetX,
                                   double targetY,
                                   int targetBboxX,
                                   int targetBboxY,
                                   int targetWidth,
                                   int targetHeight,
                                   int imageWidth,
                                   int imageHeight,
                                   @Nullable String source,
                                   long timestampMs) {
        this(success, code, message, targetX, targetY, targetBboxX, targetBboxY, targetWidth, targetHeight,
                imageWidth, imageHeight, source, timestampMs, "red");
    }

    public OpencvStainDetectResult(boolean success,
                                   int code,
                                   @Nullable String message,
                                   double targetX,
                                   double targetY,
                                   int targetBboxX,
                                   int targetBboxY,
                                   int targetWidth,
                                   int targetHeight,
                                   int imageWidth,
                                   int imageHeight,
                                   @Nullable String source,
                                   long timestampMs,
                                   @Nullable String frameKind) {
        this.success = success;
        this.code = code;
        this.message = message == null ? "" : message;
        this.targetX = targetX;
        this.targetY = targetY;
        this.targetBboxX = targetBboxX;
        this.targetBboxY = targetBboxY;
        this.targetWidth = targetWidth;
        this.targetHeight = targetHeight;
        this.imageWidth = imageWidth;
        this.imageHeight = imageHeight;
        this.source = source == null ? "" : source;
        this.timestampMs = timestampMs;
        this.frameKind = frameKind == null || frameKind.isEmpty() ? "red" : frameKind;
    }

    public boolean isBlueFrameKind() {
        return "blue".equalsIgnoreCase(frameKind);
    }

    public boolean hasTarget() {
        return success && Double.isFinite(targetX) && Double.isFinite(targetY);
    }

    public boolean hasNativeBbox() {
        return targetWidth > 0 && targetHeight > 0;
    }
}
