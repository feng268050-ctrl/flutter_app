package com.lasercyber.lws.ui.component.dialog;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.drawable.Drawable;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import com.lasercyber.lws.ui.R;

/** Rounded warm-yellow → white → warm-yellow backdrop for the work-status dialog. */
public final class WorkStatusDialogBackdropDrawable extends Drawable {

    private final Paint fillPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path clipPath = new Path();
    private final RectF bounds = new RectF();
    private final float cornerRadius;
    private final int edgeWarmColor;
    private final int blendWarmColor;
    private final int centerWhiteColor;

    public WorkStatusDialogBackdropDrawable(@NonNull Context context) {
        cornerRadius = context.getResources().getDimension(R.dimen.frost_corner_radius);
        edgeWarmColor = ContextCompat.getColor(context, R.color.work_status_dialog_backdrop_edge);
        blendWarmColor = ContextCompat.getColor(context, R.color.work_status_dialog_backdrop_blend);
        centerWhiteColor = ContextCompat.getColor(context, R.color.work_status_dialog_backdrop_center);
        fillPaint.setStyle(Paint.Style.FILL);
    }

    @Override
    public void draw(@NonNull Canvas canvas) {
        Rect drawBounds = getBounds();
        if (drawBounds.isEmpty()) {
            return;
        }
        bounds.set(drawBounds);
        clipPath.reset();
        clipPath.addRoundRect(bounds, cornerRadius, cornerRadius, Path.Direction.CW);
        fillPaint.setShader(new LinearGradient(
                bounds.left,
                bounds.top,
                bounds.left,
                bounds.bottom,
                new int[]{edgeWarmColor, blendWarmColor, centerWhiteColor, blendWarmColor, edgeWarmColor},
                new float[]{0f, 0.32f, 0.5f, 0.68f, 1f},
                Shader.TileMode.CLAMP));
        canvas.drawPath(clipPath, fillPaint);
        fillPaint.setShader(null);
    }

    @Override
    public void setAlpha(int alpha) {
        fillPaint.setAlpha(alpha);
        invalidateSelf();
    }

    @Override
    public void setColorFilter(android.graphics.ColorFilter colorFilter) {
        fillPaint.setColorFilter(colorFilter);
        invalidateSelf();
    }

    @Override
    public int getOpacity() {
        return android.graphics.PixelFormat.TRANSLUCENT;
    }
}
