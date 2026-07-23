package com.lasercyber.lws.ui.common.view;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.util.TypedValue;
import android.view.View;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.utils.ResourceUtils;

import cn.hutool.core.convert.Convert;

public class WarnProgressView extends View {
    // 基础画笔
    private Paint bgPaint;      // 背景环画笔
    private Paint progressPaint;// 进度环画笔
    private Paint textPaint;    // 数值文字画笔
    private Paint descPaint;    // 描述文字画笔
    // 刻度相关画笔
    private Paint scaleLinePaint; // 刻度线画笔
    private Paint scaleTextPaint; // 刻度数字画笔

    // 核心配置（新增开口/角度参数）
    private int currentProgress;
    private String unit = "";
    private String descLine1 = "";
    private String descLine2 = "";
    private int descriptionColor = Color.BLACK;
    private int[] progressColors;
    private int progressTotalAngle = 300; // 进度环总角度（留60度开口）
    private int progressStartAngle = 120; // 进度环起始角度（左侧，对应图2“从左开始”）

    // 布局参数
    private int ringWidth = dp2px(20);          // 进度环宽度
    private int ringScaleSpacing = dp2px(16);    // 进度环与刻度的间距
    private int scaleBigLength = dp2px(20);     // 大刻度长度
    private int scaleSmallLength = dp2px(12);    // 小刻度长度
    private int scaleLineWidth = dp2px(2);      // 刻度线宽度
    private int scaleTextSize = sp2px(20);      // 刻度数字大小
    private int scaleInterval = 10;             // 每10步长一个大刻度
    private int maxProgress = 100;
    private int[] progressNumber = new int[]{50, 80, 100};



    public WarnProgressView(Context context) {
        super(context);
        init();
    }
    public WarnProgressView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }
    public WarnProgressView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        // 背景环画笔（半透深色，匹配图2）
        bgPaint = new Paint();
        bgPaint.setColor(Color.parseColor("#33FFFFFF"));
        bgPaint.setStyle(Paint.Style.STROKE);
        bgPaint.setStrokeWidth(ringWidth);
        bgPaint.setAntiAlias(true);

        // 进度环画笔（圆角笔触）
        progressPaint = new Paint();
        progressPaint.setStyle(Paint.Style.STROKE);
        progressPaint.setStrokeWidth(ringWidth);
        progressPaint.setAntiAlias(true);
        progressPaint.setStrokeCap(Paint.Cap.ROUND);

        // 数值文字画笔（白色大字体）
        textPaint = new Paint();
        textPaint.setColor(Color.BLACK);
        textPaint.setTextSize(sp2px(32));
        textPaint.setAntiAlias(true);
        textPaint.setTextAlign(Paint.Align.CENTER);

        // 描述文字画笔（绿色小字体）
        descPaint = new Paint();
        descPaint.setTextSize(sp2px(22));
        descPaint.setAntiAlias(true);
        descPaint.setTextAlign(Paint.Align.CENTER);

        // 刻度线画笔（白色细线条）
        scaleLinePaint = new Paint();
        scaleLinePaint.setColor(getResources().getColor(R.color.tab_text_none));
        scaleLinePaint.setStyle(Paint.Style.STROKE);
        scaleLinePaint.setStrokeWidth(scaleLineWidth);
        scaleLinePaint.setAntiAlias(true);

        // 刻度数字画笔（白色小字体）
        scaleTextPaint = new Paint();
        scaleTextPaint.setColor(Color.BLACK);
        scaleTextPaint.setTextSize(scaleTextSize);
        scaleTextPaint.setAntiAlias(true);
        scaleTextPaint.setTextAlign(Paint.Align.CENTER);
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int DPsize = ResourceUtils.dp2px(getContext(), 328);//调整成对应比例
        setMeasuredDimension(DPsize, DPsize);
    }

    @Override
    protected void onDraw(Canvas canvas) {
        canvas.translate(dp2px(36),dp2px(40));


        super.onDraw(canvas);
        int size = ResourceUtils.dp2px(getContext(), 240);
        int centerX = size / 2;
        int centerY = size / 2;
        float ringRadius = (size - 2 * ringScaleSpacing - ringWidth) / 2f;


        // 1. 绘制背景环（仅显示300度，与进度环匹配）
        drawBgRing(canvas, centerX, centerY, ringRadius);

        // 2. 绘制外层刻度（300度范围，0~100，每10步长一个大刻度）
        drawOuterScale(canvas, centerX, centerY, ringRadius);

        // 3. 绘制进度环（从左开始，300度范围，留60度开口）
        drawProgressRing(canvas, centerX, centerY, ringRadius);

        // 4. 绘制数值+单位
        String valueText = currentProgress + " " + unit;
        float valueY = centerY - (textPaint.getFontMetrics().ascent + textPaint.getFontMetrics().descent) / 2 - dp2px(32);
        canvas.drawText(valueText, centerX, valueY, textPaint);

        // 5. 绘制两行描述文字
        descPaint.setColor(descriptionColor);
        float desc1Y = valueY + dp2px(40);
        canvas.drawText(descLine1, centerX, desc1Y, descPaint);
        float desc2Y = desc1Y + dp2px(24);
        canvas.drawText(descLine2, centerX, desc2Y, descPaint);
    }


    /**
     * 绘制背景环（仅300度，匹配进度环范围）
     */
    private void drawBgRing(Canvas canvas, int centerX, int centerY, float ringRadius) {
        RectF bgRectF = new RectF(centerX - ringRadius, centerY - ringRadius, centerX + ringRadius, centerY + ringRadius);
        canvas.drawArc(bgRectF, progressStartAngle, progressTotalAngle, false, bgPaint);
    }


    /**
     * 绘制外层刻度：300度范围，0~100，每10步长一个大刻度
     */
    private void drawOuterScale(Canvas canvas, int centerX, int centerY, float ringRadius) {
        float scaleInnerRadius = ringRadius + ringScaleSpacing;
        float scaleBigOuterRadius = scaleInnerRadius + scaleBigLength;
        float scaleSmallOuterRadius = scaleInnerRadius + scaleSmallLength;
        float anglePerUnit = (float) progressTotalAngle / maxProgress; // 每单位对应3度（300/100）


        for (int i = 0; i <= maxProgress; i++) {
            if(maxProgress > 100 && i % 2 != 0){
               continue;
            }
            // 刻度角度：从进度环起始角度开始，分布300度范围
            float angle = progressStartAngle + i * anglePerUnit;
            double radian = Math.toRadians(angle);

            // 刻度线起点/终点
            float startX = centerX + (float) (scaleInnerRadius * Math.cos(radian));
            float startY = centerY + (float) (scaleInnerRadius * Math.sin(radian));
            float endX, endY;

            if (i % scaleInterval == 0) {
                // 大刻度+数字（每10步长一个）
                endX = centerX + (float) (scaleBigOuterRadius * Math.cos(radian));
                endY = centerY + (float) (scaleBigOuterRadius * Math.sin(radian));
                // 绘制刻度数字（匹配图2位置）
                float textX = centerX + (float) ((scaleBigOuterRadius + dp2px(8)) * Math.cos(radian));
                float textY = centerY + (float) ((scaleBigOuterRadius + dp2px(8)) * Math.sin(radian));
                Paint.FontMetrics fm = scaleTextPaint.getFontMetrics();
                float textBaseline = textY - (fm.ascent + fm.descent) / 2;
                canvas.drawText(String.valueOf(i), textX, textBaseline, scaleTextPaint);
            } else {
                // 小刻度
                endX = centerX + (float) (scaleSmallOuterRadius * Math.cos(radian));
                endY = centerY + (float) (scaleSmallOuterRadius * Math.sin(radian));
            }
            canvas.drawLine(startX, startY, endX, endY, scaleLinePaint);
        }
    }


    /**
     * 绘制进度环：从左开始，300度范围，留60度开口
     */
    private void drawProgressRing(Canvas canvas, int centerX, int centerY, float ringRadius) {
        float sweepAngle = (float) currentProgress / maxProgress * progressTotalAngle;
        if (progressColors == null || progressColors.length == 0) return;


        // 1. 定义颜色分段规则（绿→橙→红）
        int[][] progressSegments = {
                {progressNumber[0], progressColors[0]},   // 0~50：绿色
                {progressNumber[1], progressColors[1]},   // 50~80：橙色
                {progressNumber[2], progressColors[2]}   // 80~100：红色
        };


        float anglePerPercent = progressTotalAngle / (float) maxProgress;
        float currentStartAngle = progressStartAngle; // 分段起始角度
        int previousProgress = 0;
        int segmentCount = progressSegments.length;


        for (int i = 0; i < segmentCount; i++) {
            int[] segment = progressSegments[i];
            int segmentEndProgress = segment[0];
            int segmentColor = segment[1];

            int actualEndProgress = Math.min(segmentEndProgress, currentProgress);
            if (actualEndProgress <= previousProgress) continue;


            // ========== 2. 绘制分段圆弧（起始端：平角） ==========
            float segmentSweepAngle = (actualEndProgress - previousProgress) * anglePerPercent;
            // 设置画笔：描边 + 平角端点（保证分段起始端是平角）
            progressPaint.setStyle(Paint.Style.STROKE);
            progressPaint.setColor(segmentColor);
            if(i != 0){
                progressPaint.setStrokeCap(Paint.Cap.BUTT); // 平角端点
            }
            progressPaint.setShader(null);

            RectF progressRectF = new RectF(
                    centerX - ringRadius,
                    centerY - ringRadius,
                    centerX + ringRadius,
                    centerY + ringRadius
            );
            // 绘制分段的平角圆弧
            canvas.drawArc(progressRectF, currentStartAngle, segmentSweepAngle, false, progressPaint);


            // ========== 3. 绘制分段结束端的圆角（额外画圆） ==========
            // 计算分段结束角度对应的坐标（在进度环路径上）
            float endAngle = currentStartAngle + segmentSweepAngle;
            double radian = Math.toRadians(endAngle);
            float endX = centerX + (float) (ringRadius * Math.cos(radian));
            float endY = centerY + (float) (ringRadius * Math.sin(radian));

            // 绘制与进度环宽度匹配的圆（形成圆角结束端）
            progressPaint.setStyle(Paint.Style.FILL); // 填充圆
            canvas.drawCircle(endX, endY, ringWidth / 2f, progressPaint);


            // 4. 更新分段参数
            currentStartAngle += segmentSweepAngle;
            previousProgress = segmentEndProgress;
            if (previousProgress >= currentProgress) break;
        }
    }


    /**
     * 设置图2样式参数
     * 1、字体颜色全改为黑色，
     * 2、进度条颜色改为全红色
     */
    public void setProgress(int progress, String unit, String descLine1, String descLine2,int max, int... colors) {
        this.setNumberProgress(max);
        this.currentProgress = progress;
        this.unit = unit;
        this.descLine1 = descLine1;
        this.descLine2 = descLine2;
        this.progressColors = colors;
        invalidate();
    }

    public void setNumberProgress( int max ) {
        this.maxProgress = max;
        this.scaleInterval = max / 10;

        int i1 = max / 2;
        int i2 = Convert.toInt(max / 1.25 );

        this.progressNumber = new int[]{i1, i2, max};

    }


    // dp/sp转px工具
    private int dp2px(float dp) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp, getResources().getDisplayMetrics());
    }
    private int sp2px(float sp) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, getResources().getDisplayMetrics());
    }
}
