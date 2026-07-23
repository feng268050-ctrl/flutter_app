package com.lasercyber.lws.ai.model;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * Detection box in normalized image coordinates (0..1): top-left {@link #x}/{@link #y} and
 * {@link #w}/{@link #h} extent.
 */
public final class NormalizedBox {

    public final float x;
    public final float y;
    public final float w;
    public final float h;
    public final int classId;
    @NonNull
    public final String label;
    public final double score;

    public NormalizedBox(float x,
                         float y,
                         float w,
                         float h,
                         int classId,
                         @Nullable String label,
                         double score) {
        this.x = clamp01(x);
        this.y = clamp01(y);
        this.w = clamp01(w);
        this.h = clamp01(h);
        this.classId = classId;
        this.label = label == null ? "" : label;
        this.score = score;
    }

    public float x2() {
        return clamp01(x + w);
    }

    public float y2() {
        return clamp01(y + h);
    }

    @NonNull
    public static NormalizedBox fromPixelRect(float x1,
                                              float y1,
                                              float x2,
                                              float y2,
                                              int imageWidth,
                                              int imageHeight,
                                              int classId,
                                              @Nullable String label,
                                              double score) {
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
        return new NormalizedBox(left, top, right - left, bottom - top, classId, label, score);
    }

    /** Maps normalized box back to pixel xyxy for timeline persistence / SSE wire format. */
    @NonNull
    public float[] toPixelXyxy(int imageWidth, int imageHeight) {
        if (imageWidth <= 0 || imageHeight <= 0) {
            return new float[]{x, y, x2(), y2()};
        }
        return new float[]{
                x * imageWidth,
                y * imageHeight,
                x2() * imageWidth,
                y2() * imageHeight
        };
    }

    private static boolean looksNormalized(float left, float top, float right, float bottom) {
        return right <= 1.5f && bottom <= 1.5f && left <= 1.5f && top <= 1.5f;
    }

    private static float clamp01(float value) {
        return Math.max(0f, Math.min(1f, value));
    }
}
