package com.lasercyber.lws.ui.component;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PointF;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.View;

import com.lasercyber.lws.ui.R;

public class ArcSlider extends View {
    // 圆弧参数
    private float arcStartAngle = 135f; // 起始角度（默认左上）
    private float arcSweepAngle = 270f; // 总角度（默认270度，覆盖左下到右下）
    private float currentAngle = 0f; // 当前滑块角度（相对于起始角的偏移）

    // 导轨参数
    private int railNormalColor = Color.GRAY;
    private int railSelectedColor = Color.parseColor("#FF9900");
    private float railNormalWidth = 10f;
    private float railSelectedWidth = 20f;

    // 滑块参数
    private float thumbRadius = 20f;
    private int thumbColor = Color.WHITE;
    private PointF thumbCenter = new PointF(); // 滑块中心坐标

    // 刻度参数
    private int tickCount = 5;
    private float tickLength = 15f;
    private int tickColor = Color.LTGRAY;

    // 绘制工具
    private Paint railPaint, thumbPaint, tickPaint;
    private RectF arcRect = new RectF(); // 圆弧所在矩形
    private float arcRadius; // 圆弧半径


    public ArcSlider(Context context) {
        this(context, null);
    }

    public ArcSlider(Context context, AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public ArcSlider(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        initAttrs(context, attrs);
        initPaint();
    }


    // 初始化自定义属性
    private void initAttrs(Context context, AttributeSet attrs) {
        TypedArray ta = context.obtainStyledAttributes(attrs, R.styleable.ArcSlider);
        arcStartAngle = ta.getFloat(R.styleable.ArcSlider_arcStartAngle, 135f);
        arcSweepAngle = ta.getFloat(R.styleable.ArcSlider_arcSweepAngle, 270f);
        railNormalColor = ta.getColor(R.styleable.ArcSlider_railNormalColor, Color.GRAY);
        railSelectedColor = ta.getColor(R.styleable.ArcSlider_railSelectedColor, Color.parseColor("#FF9900"));
        railNormalWidth = ta.getDimension(R.styleable.ArcSlider_railNormalWidth, 10f);
        railSelectedWidth = ta.getDimension(R.styleable.ArcSlider_railSelectedWidth, 20f);
        thumbRadius = ta.getDimension(R.styleable.ArcSlider_thumbRadius, 20f);
        thumbColor = ta.getColor(R.styleable.ArcSlider_thumbColor, Color.WHITE);
        tickCount = ta.getInt(R.styleable.ArcSlider_tickCount, 5);
        tickLength = ta.getDimension(R.styleable.ArcSlider_tickLength, 15f);
        tickColor = ta.getColor(R.styleable.ArcSlider_tickColor, Color.LTGRAY);
        ta.recycle();
    }


    // 初始化画笔
    private void initPaint() {
        // 导轨画笔
        railPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        railPaint.setStyle(Paint.Style.STROKE);

        // 滑块画笔
        thumbPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        thumbPaint.setStyle(Paint.Style.FILL);
        thumbPaint.setColor(thumbColor);

        // 刻度画笔
        tickPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        tickPaint.setStyle(Paint.Style.STROKE);
        tickPaint.setColor(tickColor);
        tickPaint.setStrokeWidth(2f);
    }


    @Override
    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        super.onSizeChanged(w, h, oldw, oldh);
        // 计算圆弧所在矩形（留出滑块和刻度的空间）
        float padding = thumbRadius + tickLength;
        arcRect.set(
                padding,
                padding,
                w - padding,
                h - padding
        );
        arcRadius = arcRect.width() / 2f;
        // 初始化滑块位置（默认在起始角）
        updateThumbPosition(currentAngle);
    }


    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        // 1. 绘制未选中导轨
        railPaint.setColor(railNormalColor);
        railPaint.setStrokeWidth(railNormalWidth);
        canvas.drawArc(arcRect, arcStartAngle, arcSweepAngle, false, railPaint);

        // 2. 绘制已选中导轨（当前角度之前的部分）
        if (currentAngle > 0) {
            railPaint.setColor(railSelectedColor);
            railPaint.setStrokeWidth(railSelectedWidth);
            canvas.drawArc(arcRect, arcStartAngle, currentAngle, false, railPaint);
        }

        // 3. 绘制刻度
        float tickAngleStep = arcSweepAngle / (tickCount - 1);
        for (int i = 0; i < tickCount; i++) {
            float angle = arcStartAngle + i * tickAngleStep;
            // 刻度起点（圆弧上）
            float startX = arcRect.centerX() + (float) Math.cos(Math.toRadians(angle)) * arcRadius;
            float startY = arcRect.centerY() + (float) Math.sin(Math.toRadians(angle)) * arcRadius;
            // 刻度终点（向外延伸）
            float endX = arcRect.centerX() + (float) Math.cos(Math.toRadians(angle)) * (arcRadius + tickLength);
            float endY = arcRect.centerY() + (float) Math.sin(Math.toRadians(angle)) * (arcRadius + tickLength);
            canvas.drawLine(startX, startY, endX, endY, tickPaint);
        }

        // 4. 绘制滑块
        canvas.drawCircle(thumbCenter.x, thumbCenter.y, thumbRadius, thumbPaint);
    }


    @Override
    public boolean onTouchEvent(MotionEvent event) {
        switch (event.getAction()) {
            case MotionEvent.ACTION_DOWN:
            case MotionEvent.ACTION_MOVE:
                // 计算触摸点相对于圆弧中心的角度
                float touchX = event.getX() - arcRect.centerX();
                float touchY = event.getY() - arcRect.centerY();
                float touchAngle = (float) Math.toDegrees(Math.atan2(touchY, touchX));
                // 转换为相对于圆弧起始角的偏移量（并限制在0~arcSweepAngle之间）
                currentAngle = touchAngle - arcStartAngle;
                if (currentAngle < 0) currentAngle = 0;
                if (currentAngle > arcSweepAngle) currentAngle = arcSweepAngle;
                // 更新滑块位置并重绘
                updateThumbPosition(currentAngle);
                invalidate();
                // 回调当前进度（可选）
                if (onProgressChangeListener != null) {
                    float progress = currentAngle / arcSweepAngle;
                    onProgressChangeListener.onProgressChanged(progress);
                }
                return true;
            case MotionEvent.ACTION_UP:
                return true;
        }
        return super.onTouchEvent(event);
    }


    // 更新滑块位置
    private void updateThumbPosition(float offsetAngle) {
        float totalAngle = arcStartAngle + offsetAngle;
        thumbCenter.x = arcRect.centerX() + (float) Math.cos(Math.toRadians(totalAngle)) * arcRadius;
        thumbCenter.y = arcRect.centerY() + (float) Math.sin(Math.toRadians(totalAngle)) * arcRadius;
    }


    // 进度回调接口（可选）
    public interface OnProgressChangeListener {
        void onProgressChanged(float progress); // 进度范围：0~1
    }

    private OnProgressChangeListener onProgressChangeListener;

    public void setOnProgressChangeListener(OnProgressChangeListener listener) {
        this.onProgressChangeListener = listener;
    }
}