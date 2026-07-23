package com.lasercyber.lws.ui.common.view;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.View;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.utils.ResourceUtils;

public class RingProgressView extends View {
    private Paint bgPaint, fgPaint, dotPaint;
    private float progress = 0;
    private int fgColor, bgColor, dotColor;
    private float strokeWidth;
    private RectF arcRect;
    private float centerX, centerY, radius;

    public RingProgressView(Context context, AttributeSet attrs) {
        super(context, attrs);
        TypedArray ta = context.obtainStyledAttributes(attrs, R.styleable.RingProgressView);
        progress = ta.getFloat(R.styleable.RingProgressView_rpv_progress, 0);
        fgColor = ta.getColor(R.styleable.RingProgressView_rpv_foregroundColor, Color.BLACK);
        bgColor = ta.getColor(R.styleable.RingProgressView_rpv_backgroundColor, Color.GRAY);
        strokeWidth = ResourceUtils.dp2px(getContext(), 16);
        dotColor = ta.getColor(R.styleable.RingProgressView_rpv_dotColor, Color.WHITE);
        ta.recycle();
        initPaints();
    }

    private void initPaints() {
        bgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        bgPaint.setColor(bgColor);
        bgPaint.setStyle(Paint.Style.STROKE);
        bgPaint.setStrokeWidth(strokeWidth);
        bgPaint.setStrokeCap(Paint.Cap.ROUND);

        fgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        fgPaint.setColor(fgColor);
        fgPaint.setStyle(Paint.Style.STROKE);
        fgPaint.setStrokeWidth(strokeWidth);
        fgPaint.setStrokeCap(Paint.Cap.ROUND);

        dotPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        dotPaint.setColor(dotColor);
        dotPaint.setStyle(Paint.Style.FILL);
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int size = Math.min(MeasureSpec.getSize(widthMeasureSpec), MeasureSpec.getSize(heightMeasureSpec));
        setMeasuredDimension(size, size);
    }

    @Override
    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        super.onSizeChanged(w, h, oldw, oldh);
        centerX = w / 2f;
        centerY = h / 2f;
        // 弧为 STROKE + ROUND：端帽会沿切线伸出约半个线宽；原先半径使外缘贴边，易被裁切。
        // 再为端点圆点留一圈半径，整体内缩。
        float minSide = Math.min(w, h);
        float dotRadius = strokeWidth * 0.5f;
        float inset = strokeWidth * 0.5f + dotRadius;
        radius = minSide / 2f - strokeWidth - inset;
        if (radius < strokeWidth) {
            radius = Math.max(strokeWidth, minSide / 2f - strokeWidth * 1.5f);
        }
        arcRect = new RectF(centerX - radius, centerY - radius, centerX + radius, centerY + radius);
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        // 1. 画背景半圆：起始角度-90°（顶部），扫过180°（形成下半圆）
        canvas.drawArc(arcRect, 150, 240, false, bgPaint);

        // 2. 画前景进度：进度占比对应180°范围（原360°改为180°）
        float sweepAngle = progress / 100 * 240; // 总范围从360→180
        canvas.drawArc(arcRect, 150, sweepAngle, false, fgPaint);

        // 3. 画进度端点圆点：基于半圆的角度计算位置
        double radian = Math.toRadians(150 + sweepAngle); // 起始角度仍为-90°
        float dotX = (float) (centerX + radius * Math.cos(radian));
        float dotY = (float) (centerY + radius * Math.sin(radian));
        float dotRadius = strokeWidth * 0.5f;
        canvas.drawCircle(dotX, dotY, dotRadius, dotPaint);
    }

    // 对外暴露的进度、颜色设置方法
    public void setProgress(float progress) {
        this.progress = progress;
        invalidate();
    }

    public void setForegroundColor(int color) {
        this.fgColor = color;
        fgPaint.setColor(color);
        invalidate();
    }
}