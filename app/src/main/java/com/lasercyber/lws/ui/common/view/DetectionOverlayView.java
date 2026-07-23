package com.lasercyber.lws.ui.common.view;

import android.content.Context;
import android.content.res.Resources;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ai.zeropoint.ZeroPointOverlaySnapshot;
import com.lasercyber.lws.ui.R;

import java.util.ArrayList;
import java.util.List;

/** Single overlay layer for AI Vision: detection boxes and zero-point markers. */
public class DetectionOverlayView extends View {

    public static class Box {
        public final float x1;
        public final float y1;
        public final float x2;
        public final float y2;
        public final @Nullable String label;

        public Box(float x1, float y1, float x2, float y2, @Nullable String label) {
            this.x1 = x1;
            this.y1 = y1;
            this.x2 = x2;
            this.y2 = y2;
            this.label = label;
        }
    }

    private final Paint boxPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint textBgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint zeroRefAxisPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint zeroRefMarkerPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint zeroTargetPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint zeroLabelPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint zeroLabelBgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF rect = new RectF();
    private final List<Box> boxes = new ArrayList<>();
    /** When set, normalized box coords map into this rect; otherwise the full view bounds. */
    @Nullable
    private RectF videoContentRect;

    @Nullable
    private ZeroPointOverlaySnapshot zeroPointOverlay;

    public DetectionOverlayView(Context context) {
        this(context, null);
    }

    public DetectionOverlayView(Context context, @Nullable AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public DetectionOverlayView(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        initOverlayMetrics(context.getResources());
        boxPaint.setStyle(Paint.Style.STROKE);
        boxPaint.setStrokeWidth(context.getResources().getDimension(R.dimen.ai_vision_overlay_box_stroke_width));
        boxPaint.setColor(Color.parseColor("#00E676"));

        textPaint.setColor(Color.WHITE);

        textBgPaint.setStyle(Paint.Style.FILL);
        textBgPaint.setColor(Color.parseColor("#992B2B2B"));

        zeroRefAxisPaint.setStyle(Paint.Style.STROKE);
        zeroRefAxisPaint.setStrokeWidth(1f);
        zeroRefAxisPaint.setColor(Color.parseColor("#00E5FF"));

        zeroRefMarkerPaint.setStyle(Paint.Style.STROKE);
        zeroRefMarkerPaint.setStrokeWidth(2f);
        zeroRefMarkerPaint.setColor(Color.parseColor("#00E5FF"));

        zeroTargetPaint.setStyle(Paint.Style.STROKE);
        zeroTargetPaint.setStrokeWidth(2f);
        zeroTargetPaint.setColor(Color.parseColor("#00E676"));

        zeroLabelPaint.setColor(Color.WHITE);

        zeroLabelBgPaint.setStyle(Paint.Style.FILL);
        zeroLabelBgPaint.setColor(Color.parseColor("#992B2B2B"));
    }

    private void initOverlayMetrics(@NonNull Resources res) {
        float boxLabelPx = res.getDimension(R.dimen.ai_vision_overlay_box_label_text_size);
        textPaint.setTextSize(boxLabelPx);
        zeroLabelPaint.setTextSize(boxLabelPx);
    }

    public void setZeroPointOverlay(@Nullable ZeroPointOverlaySnapshot snapshot) {
        if (zeroPointOverlay == snapshot) {
            return;
        }
        zeroPointOverlay = snapshot;
        invalidate();
    }

    public void setBoxes(@Nullable List<Box> list) {
        boxes.clear();
        if (list != null) {
            boxes.addAll(list);
        }
        invalidate();
    }

    public void setVideoContentRect(@Nullable RectF rect) {
        if (videoContentRect == null && rect == null) {
            return;
        }
        if (videoContentRect != null && rect != null && videoContentRect.equals(rect)) {
            return;
        }
        videoContentRect = rect != null ? new RectF(rect) : null;
        invalidate();
    }

    public void clear() {
        boolean hadContent = !boxes.isEmpty()
                || videoContentRect != null
                || zeroPointOverlay != null;
        boxes.clear();
        videoContentRect = null;
        zeroPointOverlay = null;
        if (hadContent) {
            invalidate();
        }
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        final int width = getWidth();
        final int height = getHeight();
        RectF contentTarget = videoContentRect != null
                ? videoContentRect
                : new RectF(0f, 0f, width, height);
        if (zeroPointOverlay != null && zeroPointOverlay.isValid()) {
            drawZeroPointOverlay(canvas, contentTarget, zeroPointOverlay);
        }
        for (Box box : boxes) {
            float left = box.x1;
            float top = box.y1;
            float right = box.x2;
            float bottom = box.y2;
            if (right <= 1.5f && bottom <= 1.5f) {
                left = contentTarget.left + box.x1 * contentTarget.width();
                right = contentTarget.left + box.x2 * contentTarget.width();
                top = contentTarget.top + box.y1 * contentTarget.height();
                bottom = contentTarget.top + box.y2 * contentTarget.height();
            }
            rect.set(left, top, right, bottom);
            if (rect.width() < 2f || rect.height() < 2f) {
                continue;
            }
            canvas.drawRect(rect, boxPaint);
            if (box.label != null && !box.label.isEmpty()) {
                float labelPadH = textPaint.getTextSize() * 0.35f;
                float labelPadV = textPaint.getTextSize() * 0.2f;
                float textW = textPaint.measureText(box.label);
                float textH = textPaint.getTextSize() + labelPadV * 2f;
                float bgTop = Math.max(0, rect.top - textH - labelPadV);
                canvas.drawRect(
                        rect.left,
                        bgTop,
                        rect.left + textW + labelPadH * 2f,
                        bgTop + textH,
                        textBgPaint);
                canvas.drawText(box.label, rect.left + labelPadH, bgTop + textH - labelPadV, textPaint);
            }
        }
    }

    private void drawZeroPointOverlay(@NonNull Canvas canvas,
                                      @NonNull RectF contentTarget,
                                      @NonNull ZeroPointOverlaySnapshot snapshot) {
        final float refX = mapImageX(snapshot.referenceX, snapshot.frameWidth, contentTarget);
        final float refY = mapImageY(snapshot.referenceY, snapshot.frameHeight, contentTarget);
        final float targetX = mapImageX(snapshot.detectedX, snapshot.frameWidth, contentTarget);
        final float targetY = mapImageY(snapshot.detectedY, snapshot.frameHeight, contentTarget);
        final float markerRadius = Math.max(6f, Math.min(contentTarget.width(), contentTarget.height()) * 0.012f);

        canvas.drawLine(contentTarget.left, refY, contentTarget.right, refY, zeroRefAxisPaint);
        canvas.drawLine(refX, contentTarget.top, refX, contentTarget.bottom, zeroRefAxisPaint);
        canvas.drawCircle(refX, refY, markerRadius, zeroRefMarkerPaint);
        canvas.drawCircle(targetX, targetY, markerRadius, zeroTargetPaint);

        String label = snapshot.labelText();
        float padH = zeroLabelPaint.getTextSize() * 0.35f;
        float padV = zeroLabelPaint.getTextSize() * 0.2f;
        float textW = zeroLabelPaint.measureText(label);
        float textH = zeroLabelPaint.getTextSize() + padV * 2f;
        float bgLeft = targetX + markerRadius + 4f;
        float bgTop = targetY - textH - padV;
        canvas.drawRect(bgLeft, bgTop, bgLeft + textW + padH * 2f, bgTop + textH, zeroLabelBgPaint);
        canvas.drawText(label, bgLeft + padH, bgTop + textH - padV, zeroLabelPaint);
    }

    private static float mapImageX(double imageX, int imageWidth, @NonNull RectF contentTarget) {
        return contentTarget.left + (float) (imageX / imageWidth) * contentTarget.width();
    }

    private static float mapImageY(double imageY, int imageHeight, @NonNull RectF contentTarget) {
        return contentTarget.top + (float) (imageY / imageHeight) * contentTarget.height();
    }

}
