package com.lasercyber.lws.ui.common.ai.video;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;

import com.lasercyber.lws.ui.common.ai.overlay.OverlayGeometry;

import androidx.annotation.NonNull;

/**
 * Draws a video frame plus inference boxes for encode / preview.
 */
public final class ProcessVideoAiFrameRenderer {

    private ProcessVideoAiFrameRenderer() {
    }

    public static void drawFrame(@NonNull Bitmap target,
                               @NonNull Bitmap source,
                               @NonNull ProcessVideoAiTimeline.Frame frame) {
        Canvas canvas = new Canvas(target);
        canvas.drawColor(Color.BLACK);
        Paint bitmapPaint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
        float scale = Math.min(
                target.getWidth() / (float) source.getWidth(),
                target.getHeight() / (float) source.getHeight());
        float drawWidth = source.getWidth() * scale;
        float drawHeight = source.getHeight() * scale;
        float left = (target.getWidth() - drawWidth) / 2f;
        float top = (target.getHeight() - drawHeight) / 2f;
        RectF dst = new RectF(left, top, left + drawWidth, top + drawHeight);
        canvas.drawBitmap(source, null, dst, bitmapPaint);
        drawStatusBanner(canvas, frame);
        drawBoxes(canvas, dst, frame);
    }

    private static void drawStatusBanner(@NonNull Canvas canvas,
                                         @NonNull ProcessVideoAiTimeline.Frame frame) {
        String message = frame.displayMessage();
        if (message.trim().isEmpty()) {
            return;
        }
        Paint bgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        bgPaint.setStyle(Paint.Style.FILL);
        bgPaint.setColor(Color.parseColor("#B3000000"));
        Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        textPaint.setColor(Color.WHITE);
        textPaint.setTextSize(34f);

        String banner = String.format(java.util.Locale.US, "[%d %s] %s", frame.level, frame.status, message);
        float paddingX = 18f;
        float paddingY = 12f;
        float textW = textPaint.measureText(banner);
        float textH = textPaint.getTextSize();
        float left = 18f;
        float top = 18f;
        canvas.drawRect(
                left,
                top,
                left + textW + paddingX * 2f,
                top + textH + paddingY * 2f,
                bgPaint);
        canvas.drawText(banner, left + paddingX, top + paddingY + textH - 6f, textPaint);
    }

    private static void drawBoxes(@NonNull Canvas canvas,
                                  @NonNull RectF videoRect,
                                  @NonNull ProcessVideoAiTimeline.Frame frame) {
        Paint boxPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        boxPaint.setStyle(Paint.Style.STROKE);
        boxPaint.setStrokeWidth(4f);
        boxPaint.setColor(Color.parseColor("#00E676"));
        Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        textPaint.setColor(Color.WHITE);
        textPaint.setTextSize(28f);
        Paint textBgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        textBgPaint.setStyle(Paint.Style.FILL);
        textBgPaint.setColor(Color.parseColor("#992B2B2B"));
        int imageWidth = frame.imageWidth > 0 ? frame.imageWidth : Math.round(videoRect.width());
        int imageHeight = frame.imageHeight > 0 ? frame.imageHeight : Math.round(videoRect.height());
        for (ProcessVideoAiTimeline.Box box : frame.boxes) {
            RectF rect = OverlayGeometry.toVideoRect(
                    box.x1, box.y1, box.x2, box.y2, imageWidth, imageHeight, videoRect);
            canvas.drawRect(rect, boxPaint);
            String label = box.displayLabel();
            if (!label.trim().isEmpty()) {
                float textW = textPaint.measureText(label);
                float textH = textPaint.getTextSize() + 8f;
                float bgTop = Math.max(0, rect.top - textH - 6f);
                canvas.drawRect(rect.left, bgTop, rect.left + textW + 16f, bgTop + textH, textBgPaint);
                canvas.drawText(label, rect.left + 8f, bgTop + textH - 8f, textPaint);
            }
        }
    }

    private static float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }

    public static int evenDimension(int value) {
        int safe = Math.max(2, value);
        return (safe % 2 == 0) ? safe : safe - 1;
    }
}
