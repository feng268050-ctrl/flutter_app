package com.lasercyber.lws.ui.common.view;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.View;

import com.lasercyber.lws.ui.common.utils.ResourceUtils;
import com.lasercyber.lws.ui.common.utils.web.HomeLayoutUtils;

public class SemiCircleProgressView extends View {
    private Paint bgPaint;    // 半圆背景画笔
    private Paint progressPaint; // 进度弧画笔
    private Paint textPaint;  // 百分比文字画笔
    private int progress = 0; // 进度（0-100）

    public int viewSize = 118;//默认59dp

    public int fontSize = 38; //字体大小

    public int trokeWidth = 10; //圆弧宽度

    private String color = "#FF0000";

    public SemiCircleProgressView(Context context) {
        super(context);
        init();
    }

    public SemiCircleProgressView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public SemiCircleProgressView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        int DPWidth = ResourceUtils.dp2px(getContext(), trokeWidth);
        // 半圆背景（更淡，匹配图2的透明感）
        bgPaint = new Paint();
        bgPaint.setColor(Color.parseColor("#22FFFFFF")); // 极淡半透明
        bgPaint.setStyle(Paint.Style.STROKE);
        bgPaint.setStrokeWidth(DPWidth); // 进度条更粗，匹配图2
        bgPaint.setAntiAlias(true);

        // 进度弧（图2的橙色高亮）
        progressPaint = new Paint();
        progressPaint.setColor(Color.parseColor(color)); // 更亮的橙色
        progressPaint.setStyle(Paint.Style.STROKE);
        progressPaint.setStrokeWidth(DPWidth);
        progressPaint.setAntiAlias(true);
        progressPaint.setStrokeCap(Paint.Cap.ROUND); // 端点圆角

        // 百分比文字（图2的大号白色）
        textPaint = new Paint();
        textPaint.setColor(Color.WHITE);
        int DPFontSize = ResourceUtils.dp2px(getContext(), fontSize);
        textPaint.setTextSize(DPFontSize); // 与“26 min”字号一致
        textPaint.setFakeBoldText(true);
        textPaint.setAntiAlias(true);
        textPaint.setTextAlign(Paint.Align.CENTER);
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        // 放大View尺寸，匹配图2的半圆大小
        int DPsize = ResourceUtils.dp2px(getContext(), viewSize);//调整成对应比例
        setMeasuredDimension(DPsize, DPsize);
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        this.progressPaint.setColor(Color.parseColor(this.color));
        int centerX = getWidth() / 2;
        int centerY = getHeight() / 2;
        float radius = Math.min(centerX, centerY) - bgPaint.getStrokeWidth() / 2;

        // 画半圆背景（180°-360°上半圆）
        RectF arcRect = new RectF(centerX - radius, centerY - radius, centerX + radius, centerY + radius);
        canvas.drawArc(arcRect, 180, 180, false, bgPaint);

        // 画进度弧
        float sweepAngle = 180 * (progress / 100f);
        canvas.drawArc(arcRect, 180, sweepAngle, false, progressPaint);

        // 画大号百分比文字（覆盖在半圆上）
        String text = progress + "%";
        Paint.FontMetrics fm = textPaint.getFontMetrics();
        float textY = centerY - (fm.ascent + fm.descent) / 10;
        canvas.drawText(text, centerX, textY, textPaint);
    }

    // 外部设置进度
    public void setProgress(int progress,int type) {
        this.progress = Math.max(0, Math.min(100, progress));
        //根据 type做宽度变更
        if(type == HomeLayoutUtils.cuttingRatio){
            this.color = "#FF8000";
        }
        if(type == HomeLayoutUtils.rinseRatio){
            this.color = "#00A4F2";
        }

        invalidate();
    }

}