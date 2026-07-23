package com.lasercyber.lws.ui.common.ai.overlay;

import android.graphics.RectF;

import androidx.annotation.NonNull;

/**
 * Maps detection boxes (pixel xyxy on the detect frame, or 0–1 normalized) into normalized
 * [0,1] coordinates and fit-center video bounds for overlay drawing.
 */
public final class OverlayGeometry {

    private OverlayGeometry() {
    }

    public static boolean looksNormalized(float x1, float y1, float x2, float y2) {
        float right = Math.max(x1, x2);
        float bottom = Math.max(y1, y2);
        float left = Math.min(x1, x2);
        float top = Math.min(y1, y2);
        return right <= 1.5f && bottom <= 1.5f && left <= 1.5f && top <= 1.5f;
    }

    @NonNull
    public static RectF toNormalizedRect(float x1,
                                         float y1,
                                         float x2,
                                         float y2,
                                         int imageWidth,
                                         int imageHeight) {
        float left = Math.min(x1, x2);
        float right = Math.max(x1, x2);
        float top = Math.min(y1, y2);
        float bottom = Math.max(y1, y2);
        if (imageWidth > 0 && imageHeight > 0 && !looksNormalized(left, top, right, bottom)) {
            left = left / imageWidth;
            right = right / imageWidth;
            top = top / imageHeight;
            bottom = bottom / imageHeight;
        }
        return new RectF(
                clamp01(left),
                clamp01(top),
                clamp01(right),
                clamp01(bottom));
    }

    @NonNull
    public static RectF toVideoRect(float x1,
                                    float y1,
                                    float x2,
                                    float y2,
                                    int imageWidth,
                                    int imageHeight,
                                    @NonNull RectF videoRect) {
        RectF norm = toNormalizedRect(x1, y1, x2, y2, imageWidth, imageHeight);
        return normalizedRectToVideoRect(norm, videoRect);
    }

    @NonNull
    public static RectF computeFitCenterContentRect(int viewWidth,
                                                    int viewHeight,
                                                    int videoWidth,
                                                    int videoHeight) {
        if (viewWidth <= 0 || viewHeight <= 0) {
            return new RectF(0f, 0f, Math.max(0, viewWidth), Math.max(0, viewHeight));
        }
        if (videoWidth <= 0 || videoHeight <= 0) {
            return new RectF(0f, 0f, viewWidth, viewHeight);
        }
        float scale = Math.min(viewWidth / (float) videoWidth, viewHeight / (float) videoHeight);
        float drawWidth = videoWidth * scale;
        float drawHeight = videoHeight * scale;
        float left = (viewWidth - drawWidth) / 2f;
        float top = (viewHeight - drawHeight) / 2f;
        return new RectF(left, top, left + drawWidth, top + drawHeight);
    }

    @NonNull
    public static RectF normalizedRectToVideoRect(@NonNull RectF normalized, @NonNull RectF videoRect) {
        return new RectF(
                videoRect.left + normalized.left * videoRect.width(),
                videoRect.top + normalized.top * videoRect.height(),
                videoRect.left + normalized.right * videoRect.width(),
                videoRect.top + normalized.bottom * videoRect.height());
    }

    private static float clamp01(float value) {
        return Math.max(0f, Math.min(1f, value));
    }
}
