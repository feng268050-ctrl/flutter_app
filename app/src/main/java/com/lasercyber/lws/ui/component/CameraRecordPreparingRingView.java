package com.lasercyber.lws.ui.component;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.SweepGradient;
import android.util.AttributeSet;
import android.view.View;
import android.view.animation.LinearInterpolator;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;

import com.lasercyber.lws.ui.R;

/**
 * Indeterminate ring with a bright leading edge and fading tail (frost border style).
 */
public final class CameraRecordPreparingRingView extends View {

    private static final float ARC_SWEEP_DEGREES = 280f;

    private final Paint arcPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF arcBounds = new RectF();
    private final Matrix gradientMatrix = new Matrix();

    private float strokeWidthPx;
    private float rotationDegrees;
    @Nullable
    private ValueAnimator spinAnimator;
    @Nullable
    private SweepGradient sweepGradient;

    public CameraRecordPreparingRingView(Context context) {
        super(context);
        init(context);
    }

    public CameraRecordPreparingRingView(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        init(context);
    }

    public CameraRecordPreparingRingView(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init(context);
    }

    private void init(@NonNull Context context) {
        strokeWidthPx = context.getResources().getDisplayMetrics().density * 3f;
        arcPaint.setStyle(Paint.Style.STROKE);
        arcPaint.setStrokeWidth(strokeWidthPx);
        arcPaint.setStrokeCap(Paint.Cap.ROUND);
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        if (getVisibility() == VISIBLE) {
            startSpin();
        }
    }

    @Override
    protected void onDetachedFromWindow() {
        stopSpin();
        super.onDetachedFromWindow();
    }

    @Override
    protected void onVisibilityChanged(@NonNull View changedView, int visibility) {
        super.onVisibilityChanged(changedView, visibility);
        if (changedView != this) {
            return;
        }
        if (visibility == VISIBLE) {
            startSpin();
        } else {
            stopSpin();
        }
    }

    @Override
    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        super.onSizeChanged(w, h, oldw, oldh);
        if (w <= 0 || h <= 0) {
            sweepGradient = null;
            return;
        }
        float cx = w * 0.5f;
        float cy = h * 0.5f;
        int highlight = ContextCompat.getColor(getContext(), R.color.frost_light_border_highlight);
        int mid = ContextCompat.getColor(getContext(), R.color.frost_border_mid);
        int shadow = ContextCompat.getColor(getContext(), R.color.frost_border_shadow);
        sweepGradient = new SweepGradient(
                cx,
                cy,
                new int[] {0x00FFFFFF, shadow, mid, highlight, 0xFFFFFFFF, 0x00FFFFFF},
                new float[] {0f, 0.45f, 0.68f, 0.84f, 0.94f, 1f});
    }

    @Override
    protected void onDraw(@NonNull Canvas canvas) {
        super.onDraw(canvas);
        if (sweepGradient == null) {
            return;
        }
        float cx = getWidth() * 0.5f;
        float cy = getHeight() * 0.5f;
        float radius = Math.min(cx, cy) - strokeWidthPx * 0.5f;
        arcBounds.set(cx - radius, cy - radius, cx + radius, cy + radius);

        gradientMatrix.setRotate(rotationDegrees - 90f, cx, cy);
        sweepGradient.setLocalMatrix(gradientMatrix);
        arcPaint.setShader(sweepGradient);
        canvas.drawArc(arcBounds, rotationDegrees, ARC_SWEEP_DEGREES, false, arcPaint);
    }

    private void startSpin() {
        if (spinAnimator != null) {
            return;
        }
        spinAnimator = ValueAnimator.ofFloat(0f, 360f);
        spinAnimator.setDuration(900L);
        spinAnimator.setRepeatCount(ValueAnimator.INFINITE);
        spinAnimator.setInterpolator(new LinearInterpolator());
        spinAnimator.addUpdateListener(animation -> {
            rotationDegrees = (float) animation.getAnimatedValue();
            invalidate();
        });
        spinAnimator.start();
    }

    private void stopSpin() {
        if (spinAnimator != null) {
            spinAnimator.cancel();
            spinAnimator.removeAllUpdateListeners();
            spinAnimator.removeAllListeners();
            spinAnimator = null;
        }
    }
}
