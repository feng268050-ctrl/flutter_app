package com.lasercyber.lws.ui.common.view;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.util.AttributeSet;
import android.util.Log;
import android.util.TypedValue;
import android.view.View;

import com.blankj.utilcode.util.ColorUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.math.RoundingMode;
import java.text.DecimalFormat;

import cn.hutool.core.convert.Convert;
import lombok.Setter;

public class CircleProgressView extends View {
    // 基础画笔
    private Paint bgPaint;      // 背景环画笔
    private Paint ringOuterStrokePaint; // 外缘 1px 白描边
    private Paint progressPaint;// 进度环画笔
    private Paint textPaint;    // 数值文字画笔
    private Paint descPaint;    // 描述文字画笔
    // 刻度相关画笔
    private Paint scaleLinePaint; // 刻度线画笔
    private Paint scaleTextPaint; // 刻度数字画笔

    private double currentProgress;
    private String unit = "";
    private String descLine1 = "";
    private String descLine2 = "";
    private int descriptionColor = Color.WHITE;
    private float descTextSize = sp2px(20);
    private int[] progressColors;
    /** Full track sweep: bottom-left 0 → bottom-right max (clockwise). */
    private int progressTotalAngle = 270;
    /** Android canvas degrees: 135° = bottom-left. */
    private int progressStartAngle = 135;

    // 布局参数 — 环宽固定；外缘贴紧刻度内侧
    private int ringWidth = dp2px(22);
    /** Major tick length (radial outward); minor ticks are not drawn. */
    private int scaleBigLength = dp2px(12);
    private int scaleLineWidth = dp2px(2);
    private int scaleTextSize = sp2px(18);
    /** Step between labeled major ticks; default yields 11 marks for max=100/1500. */
    private int scaleInterval = 10;
    private int maxProgress = 100;
    private int[] progressNumber = new int[]{50, 80, 100};
    // 刻度线颜色
    private int scaleLineColor= ColorUtils.getColor(R.color.tab_text_none);
    // 刻度数字颜色
    private int scaleNumTextColor=Color.WHITE;
    // 数值
    private int numTextColor = Color.WHITE;
    private int numTextSize=sp2px(32);
    private int numTextWeight=400;
    private float valueTextOffsetX = 0f;
    // 刻度数值与刻度线间隔
    private int scaleValueLineInterval=dp2px(8);
    // 内边距
    private int padding = 0;
    // 文字刻度边距
    private int scaleTextMargin = 0;
    private float circleSideLength = 328;
    /** 1px white stroke on the outer rim of the track (device px). */
    private float ringOuterStrokeWidth = 1f;
    private final static String TAG = LogTAGConstant.CircleProgressView;
    @Setter
    private boolean debug = false;


    public CircleProgressView(Context context) {
        super(context);
        init();
    }
    public CircleProgressView(Context context, AttributeSet attrs) {
        super(context, attrs);
        initAttrs(context, attrs);
        init();
    }
    public CircleProgressView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        initAttrs(context, attrs);
        init();
    }
    /**
     * 初始化并解析自定义属性
     * @param context 上下文
     * @param attrs 属性集合
     */
    private void initAttrs(Context context, AttributeSet attrs) {
        // 1. 获取TypedArray（包含所有自定义属性）
        TypedArray typedArray = context.obtainStyledAttributes(attrs, R.styleable.CircleProgress);

        try {
            // 2. 解析描述文字属性（带默认值）
            descriptionColor = typedArray.getColor(
                    R.styleable.CircleProgress_desc_text_color,
                    descriptionColor
            );
            descTextSize = typedArray.getDimension(
                    R.styleable.CircleProgress_desc_text_size,
                    descTextSize
            );

            // 3. 解析刻度线属性
            scaleLineColor = typedArray.getColor(
                    R.styleable.CircleProgress_scale_line_color,
                    scaleLineColor
            );
            scaleLineWidth = (int) typedArray.getDimension(
                    R.styleable.CircleProgress_scale_line_width,
                    (float) scaleLineWidth
            );

            // 4. 解析刻度数字属性
            scaleNumTextColor = typedArray.getColor(
                    R.styleable.CircleProgress_scale_num_text_color,
                    scaleNumTextColor
            );
            scaleTextSize = (int) typedArray.getDimension(
                    R.styleable.CircleProgress_scale_num_text_size,
                    (float) scaleTextSize
            );

            // 5. 解析数值文字属性
            numTextColor = typedArray.getColor(
                    R.styleable.CircleProgress_num_text_color,
                    numTextColor
            );
            numTextSize =(int) typedArray.getDimension(
                    R.styleable.CircleProgress_num_text_size,
                    numTextSize
            );
            numTextWeight = typedArray.getInt(
                    R.styleable.CircleProgress_num_text_weight,
                    numTextWeight
            );
            valueTextOffsetX = typedArray.getDimension(
                    R.styleable.CircleProgress_value_text_offset_x,
                    valueTextOffsetX
            );
            scaleValueLineInterval=typedArray.getDimensionPixelSize(
                    R.styleable.CircleProgress_scale_value_line_interval,
                    scaleValueLineInterval
            );
            padding = typedArray.getDimensionPixelSize(
                    R.styleable.CircleProgress_circle_padding,
                    padding
            );
            scaleTextMargin = typedArray.getDimensionPixelSize(
                    R.styleable.CircleProgress_circle_scale_text_margin,
                    scaleTextMargin
            );
            circleSideLength = typedArray.getDimension(R.styleable.CircleProgress_circle_side_length, circleSideLength);

        } finally {
            // 6. 回收TypedArray（必须调用，避免内存泄漏）
            typedArray.recycle();
        }
    }
    private void init() {
        // 背景环画笔（半透深色；圆角端点匹配 270° 开口）
        bgPaint = new Paint();
        bgPaint.setColor(Color.parseColor("#33FFFFFF"));
        bgPaint.setStyle(Paint.Style.STROKE);
        bgPaint.setStrokeWidth(ringWidth);
        bgPaint.setAntiAlias(true);
        bgPaint.setStrokeCap(Paint.Cap.ROUND);

        // 外圆弧 1px 白色描边（贴在环外缘、紧贴刻度内侧）
        ringOuterStrokePaint = new Paint();
        ringOuterStrokePaint.setColor(Color.WHITE);
        ringOuterStrokePaint.setStyle(Paint.Style.STROKE);
        ringOuterStrokePaint.setStrokeWidth(ringOuterStrokeWidth);
        ringOuterStrokePaint.setAntiAlias(true);
        ringOuterStrokePaint.setStrokeCap(Paint.Cap.ROUND);

        // 进度环画笔（圆角笔触）
        progressPaint = new Paint();
        progressPaint.setStyle(Paint.Style.STROKE);
        progressPaint.setStrokeWidth(ringWidth);
        progressPaint.setAntiAlias(true);
        progressPaint.setStrokeCap(Paint.Cap.ROUND);

        // 数值文字画笔（白色大字体）
        textPaint = new Paint();
        textPaint.setColor(numTextColor);
        textPaint.setTextSize(numTextSize);
        textPaint.setAntiAlias(true);
        textPaint.setTextAlign(Paint.Align.CENTER);
        if (numTextWeight==500){
            textPaint.setTypeface(Typeface.DEFAULT_BOLD);
        }else if (numTextWeight==400){
            textPaint.setTypeface(Typeface.DEFAULT);
        }


        // 描述文字画笔（绿色小字体）
        descPaint = new Paint();
        descPaint.setTextSize(descTextSize);
        descPaint.setAntiAlias(true);
        descPaint.setTextAlign(Paint.Align.CENTER);

        // 刻度线画笔（白色细线条）
        scaleLinePaint = new Paint();
        scaleLinePaint.setColor(scaleLineColor);
        scaleLinePaint.setStyle(Paint.Style.STROKE);
        scaleLinePaint.setStrokeWidth(scaleLineWidth);
        scaleLinePaint.setAntiAlias(true);

        // 刻度数字画笔（白色小字体）
        scaleTextPaint = new Paint();
        scaleTextPaint.setColor(scaleNumTextColor);
        scaleTextPaint.setTextSize(scaleTextSize);
        scaleTextPaint.setAntiAlias(true);
        scaleTextPaint.setTextAlign(Paint.Align.CENTER);
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        // circleSideLength 来自 getDimension，已是 px，勿再 dp2px
        int desired = Math.round(circleSideLength);
        int w = View.resolveSize(desired, widthMeasureSpec);
        int h = View.resolveSize(desired, heightMeasureSpec);
        // 保持正方形，并尊重父布局上限（机台状态卡片高度 344dp 小于 circleSideLength 时必须缩小）
        int side = Math.min(w, h);
        side = Math.max(side, dp2px(160));
        setMeasuredDimension(side, side);
    }

    /** 刻度外缘到数字布局带的径向间隙（px） */
    private float getScaleLabelGap() {
        return Math.max(scaleTextMargin, scaleValueLineInterval);
    }

    /**
     * Outside-in geometry so the 270° track fills as much of the view as possible
     * while keeping ticks + labels inside the bounds.
     */
    private static final class GaugeGeom {
        final float centerX;
        final float centerY;
        final float ringRadius;
        final float scaleInnerRadius;
        final float scaleOuterRadius;
        final float labelBandRadius;

        GaugeGeom(
                float centerX,
                float centerY,
                float ringRadius,
                float scaleInnerRadius,
                float scaleOuterRadius,
                float labelBandRadius) {
            this.centerX = centerX;
            this.centerY = centerY;
            this.ringRadius = ringRadius;
            this.scaleInnerRadius = scaleInnerRadius;
            this.scaleOuterRadius = scaleOuterRadius;
            this.labelBandRadius = labelBandRadius;
        }
    }

    private GaugeGeom computeGeometry(int viewSide) {
        float center = viewSide / 2f;
        float edgePad = dp2px(3);
        Paint.FontMetrics fm = scaleTextPaint.getFontMetrics();
        float textHalfH = (fm.descent - fm.ascent) / 2f;
        float widestHalf = scaleTextPaint.measureText(String.valueOf(Math.max(maxProgress, 100))) / 2f;
        // Corner labels (0 / max) need both half-width and half-height clearance.
        float labelClearance = Math.max(widestHalf, textHalfH) + edgePad;
        float labelBand = Math.max(center - labelClearance, ringWidth);
        float scaleOuter = Math.max(labelBand - getScaleLabelGap(), ringWidth);
        float scaleInner = Math.max(scaleOuter - scaleBigLength, ringWidth / 2f);
        // Track outer edge flush with tick inner ends; stroke width unchanged.
        float arcOuter = scaleInner;
        float ringRadius = Math.max(arcOuter - ringWidth / 2f - padding, ringWidth / 2f);
        return new GaugeGeom(center, center, ringRadius, scaleInner, scaleOuter, labelBand);
    }

    @Override
    protected void onDraw(Canvas canvas) {
        int viewSide = Math.min(getWidth(), getHeight());
        if (viewSide <= 0) {
            return;
        }
        float tx = (getWidth() - viewSide) / 2f;
        float ty = (getHeight() - viewSide) / 2f;
        canvas.translate(tx, ty);

        super.onDraw(canvas);
        GaugeGeom geom = computeGeometry(viewSide);
        int centerX = Math.round(geom.centerX);
        int centerY = Math.round(geom.centerY);
        float ringRadius = geom.ringRadius;

        // 1. 背景环
        drawBgRing(canvas, centerX, centerY, ringRadius);

        // 2. 绘制进度环（270°，左下→右下）
        drawProgressRing(canvas, centerX, centerY, ringRadius);

        // 3. 外缘描边最后覆盖进度环，确保有数值时仍完整可见
        drawRingOuterStroke(canvas, centerX, centerY, ringRadius);

        // 4. 绘制外层主刻度（270°，仅带数字的主刻度）
        drawOuterScale(canvas, geom);

        // 5–6. 数值+单位+描述：水平数字居环心、单位接右；垂直按整块外接矩形相对环心居中
        DecimalFormat df = new DecimalFormat("#.##");
        df.setRoundingMode(RoundingMode.HALF_UP);
        String num = df.format(currentProgress);
        String unitStr = unit == null ? "" : unit.trim();
        descPaint.setColor(descriptionColor);
        Paint.FontMetrics valueFm = textPaint.getFontMetrics();
        Paint.FontMetrics descFm = descPaint.getFontMetrics();
        float gapValueToDesc1 = dp2px(28);
        float gapDesc1ToDesc2 = dp2px(18);
        boolean hasDesc1 = descLine1 != null && !descLine1.isEmpty();
        boolean hasDesc2 = descLine2 != null && !descLine2.isEmpty();
        float spanBelowValueBaseline;
        if (hasDesc1 && hasDesc2) {
            spanBelowValueBaseline = gapValueToDesc1 + gapDesc1ToDesc2;
        } else if (hasDesc1) {
            spanBelowValueBaseline = gapValueToDesc1;
        } else if (hasDesc2) {
            spanBelowValueBaseline = gapValueToDesc1;
        } else {
            spanBelowValueBaseline = 0;
        }
        float blockBottomBelowValueBaseline = spanBelowValueBaseline
                + ((hasDesc1 || hasDesc2) ? descFm.descent : valueFm.descent);
        float valueY = centerY - (valueFm.ascent + blockBottomBelowValueBaseline) / 2f;

        float valueDrawX = centerX + valueTextOffsetX;
        float unitGap = unitStr.isEmpty() ? 0f : dp2px(4);
        float numWidth = textPaint.measureText(num);
        float unitWidth = unitStr.isEmpty() ? 0f : textPaint.measureText(unitStr);
        float valueGroupLeft = valueDrawX - (numWidth + unitGap + unitWidth) / 2f;

        textPaint.setTextAlign(Paint.Align.LEFT);
        canvas.drawText(num, valueGroupLeft, valueY, textPaint);
        if (!unitStr.isEmpty()) {
            float afterNumX = valueGroupLeft + numWidth + unitGap;
            canvas.drawText(unitStr, afterNumX, valueY, textPaint);
        }
        textPaint.setTextAlign(Paint.Align.CENTER);

        if (hasDesc1) {
            float desc1Y = valueY + gapValueToDesc1;
            canvas.drawText(descLine1, centerX, desc1Y, descPaint);
            if (hasDesc2) {
                float desc2Y = desc1Y + gapDesc1ToDesc2;
                canvas.drawText(descLine2, centerX, desc2Y, descPaint);
            }
        } else if (hasDesc2) {
            float desc2Y = valueY + gapValueToDesc1;
            canvas.drawText(descLine2, centerX, desc2Y, descPaint);
        }
    }


    /** 绘制背景环（270°）。 */
    private void drawBgRing(Canvas canvas, int centerX, int centerY, float ringRadius) {
        RectF bgRectF = new RectF(centerX - ringRadius, centerY - ringRadius, centerX + ringRadius, centerY + ringRadius);
        canvas.drawArc(bgRectF, progressStartAngle, progressTotalAngle, false, bgPaint);
    }

    /** 绘制外缘 1px 白色描边；在进度环之后调用，避免被彩色进度覆盖。 */
    private void drawRingOuterStroke(Canvas canvas, int centerX, int centerY, float ringRadius) {
        // Stroke is centered on path: place path on track outer rim so the 1px line hugs the rim.
        float outerRimRadius = ringRadius + ringWidth / 2f;
        RectF outerStrokeRect = new RectF(
                centerX - outerRimRadius,
                centerY - outerRimRadius,
                centerX + outerRimRadius,
                centerY + outerRimRadius);
        canvas.drawArc(outerStrokeRect, progressStartAngle, progressTotalAngle, false, ringOuterStrokePaint);
    }


    /**
     * 绘制外层主刻度：270°，仅 {@code 0, interval, 2·interval, …, max}（共 11 档当 interval=max/10）。
     * 不绘制主刻度之间的细分小刻度。刻度为径向外侧短线，长度/粗细一致。
     * 数字水平绘制，中心对齐对应刻度角线，落在刻度外侧数字带上，与刻线保持间隙。
     */
    private void drawOuterScale(Canvas canvas, GaugeGeom geom) {
        Paint.FontMetrics labelFm = scaleTextPaint.getFontMetrics();
        float labelBaselineOffset = -(labelFm.ascent + labelFm.descent) / 2f;

        int interval = Math.max(1, scaleInterval);
        float anglePerUnit = (float) progressTotalAngle / maxProgress;

        for (int i = 0; i <= maxProgress; i += interval) {
            float angle = progressStartAngle + i * anglePerUnit;
            double radian = Math.toRadians(angle);
            float cos = (float) Math.cos(radian);
            float sin = (float) Math.sin(radian);

            float startX = geom.centerX + geom.scaleInnerRadius * cos;
            float startY = geom.centerY + geom.scaleInnerRadius * sin;
            float endX = geom.centerX + geom.scaleOuterRadius * cos;
            float endY = geom.centerY + geom.scaleOuterRadius * sin;
            canvas.drawLine(startX, startY, endX, endY, scaleLinePaint);

            float textX = geom.centerX + geom.labelBandRadius * cos;
            float textY = geom.centerY + geom.labelBandRadius * sin;
            canvas.drawText(String.valueOf(i), textX, textY + labelBaselineOffset, scaleTextPaint);
        }
    }


    /**
     * 绘制进度环：左下起始，270° 扫至右下
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

            int actualEndProgress = Math.min(segmentEndProgress,(int) currentProgress);
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

            // 向后退一点点角度（让球往回挪，不超出）
            float offsetAngle = 3f; // 后退角度，越小越精准，你可以微调
            float drawAngle = endAngle - offsetAngle;

            double radian = Math.toRadians(drawAngle);

            // 必须用 ringRadius，不能改！保证贴在圆环上
            float endX = centerX + (float) (ringRadius * Math.cos(radian));
            float endY = centerY + (float) (ringRadius * Math.sin(radian));

            progressPaint.setStyle(Paint.Style.FILL);
            canvas.drawCircle(endX, endY, ringWidth / 2f, progressPaint);

            // 4. 更新分段参数
            currentStartAngle += segmentSweepAngle;
            previousProgress = segmentEndProgress;
            if (previousProgress >= currentProgress) break;
        }
    }


    /**
     * 设置图2样式参数
     */
    public void setProgress(double progress, String unit, String descLine1, String descLine2, int max, int... colors) {
        setNumberProgress(max);
        this.currentProgress = progress;
        this.unit = unit;
        this.descLine1 = descLine1;
        this.descLine2 = descLine2;
        this.progressColors = colors;
        invalidate();
    }

    public void setNumberProgress( int max ) {
        this.maxProgress = Math.max(max, 1);
        // 11 labeled majors: 0, step, 2·step, …, max (e.g. 0…1500 step 150).
        this.scaleInterval = Math.max(1, this.maxProgress / 10);

        int i1 = this.maxProgress / 2;
        int i2 = Convert.toInt(this.maxProgress / 1.25 );

        this.progressNumber = new int[]{i1, i2, this.maxProgress};

    }


    // dp/sp转px工具
    private int dp2px(float dp) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp, getResources().getDisplayMetrics());
    }
    private int sp2px(float sp) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, getResources().getDisplayMetrics());
    }
}
