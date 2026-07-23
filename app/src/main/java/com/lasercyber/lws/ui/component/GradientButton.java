package com.lasercyber.lws.ui.component;

import android.animation.ValueAnimator;
import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Shader;
import android.util.AttributeSet;
import android.util.Log;

import com.blankj.utilcode.util.SizeUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.util.Objects;

/**
 * 渐变按钮
 */
public class GradientButton extends androidx.appcompat.widget.AppCompatButton {
    private static final String TAG = LogTAGConstant.GradientButton;
    private Paint paint;
    private LinearGradient linearGradient;
    private ValueAnimator breathAnim;
    // 默认颜色（防止属性未设置时为空）
    private static final int DEFAULT_START_COLOR = Color.TRANSPARENT;
    private static final int DEFAULT_MID_COLOR = Color.TRANSPARENT;
    private static final int DEFAULT_END_COLOR = Color.TRANSPARENT;
    private static final int DEFAULT_ANIMATION_TYPE = 1;
    private static final boolean DEFAULT_PAUSE_ANIMATION = false;
    private static final boolean DEFAULT_ANIMATION_POSITIVE = true;

    /**
     * 是否使用动画
     */
    private boolean useAnimation;
    /**
     * 动画时长
     */
    private int animationDuration;
    private int mStartColor;
    private int mMidColor;
    private int mEndColor;
    private boolean mPauseAnimation;
    private float shrinkRatio = 0f;                // 收缩比例（0~0.4，越大两端越窄）
    private float mMaxShrinkRatio = 0.4f;          // 最大收缩比例（避免中间色占满整个控件）
    // 是否正向动画
    private boolean animationPositive;
    /**
     * 动画效果,1:缩放，2：流光
     */
    private int animationType;

    public GradientButton(Context context) {
        super(context);
        attrsHandler(context, null);
        init();
    }

    public GradientButton(Context context, AttributeSet attrs) {
        super(context, attrs);
        attrsHandler(context, attrs);
        init();
    }

    private void attrsHandler(Context context, AttributeSet attrs) {
        // 获取属性值
        TypedArray typedArray = context.obtainStyledAttributes(attrs, R.styleable.GradientButton);
//        centerX = typedArray.getFloat(R.styleable.GradientButton_starting_position, 0.1f);
        shrinkRatio = typedArray.getFloat(R.styleable.GradientButton_shrink_ratio, 0.1f);
        mMaxShrinkRatio = typedArray.getFloat(R.styleable.GradientButton_max_shrink_ratio, mMaxShrinkRatio);
        useAnimation = typedArray.getBoolean(R.styleable.GradientButton_use_animation, false);
        animationDuration = typedArray.getInt(R.styleable.GradientButton_animation_duration, 1500);
        animationType = typedArray.getInt(R.styleable.GradientButton_animation_type, DEFAULT_ANIMATION_TYPE);
        // 解析颜色属性：自动处理「直接颜色值」和「资源引用」
        // getColor() 会自动解析 reference 为真实RGB值，无需手动调用 getResources().getColor()
        mStartColor = typedArray.getColor(R.styleable.GradientButton_start_color, DEFAULT_START_COLOR);
        mMidColor = typedArray.getColor(R.styleable.GradientButton_mid_color, DEFAULT_MID_COLOR);
        mEndColor = typedArray.getColor(R.styleable.GradientButton_end_color, DEFAULT_END_COLOR);

        // 解析布尔属性：暂停动画
        mPauseAnimation = typedArray.getBoolean(R.styleable.GradientButton_pause_animation, DEFAULT_PAUSE_ANIMATION);
        animationPositive=typedArray.getBoolean(R.styleable.GradientButton_animation_positive, DEFAULT_ANIMATION_POSITIVE);
        // 回收typedArray
        typedArray.recycle();
    }
    public void setUse_animation(boolean useAnimation) {
        this.useAnimation = useAnimation;
        destroyAnimator();
        this.initAnimator();
    }
    public void setAnimation_positive(boolean animationPositive){
        this.animationPositive=animationPositive;
        destroyAnimator();
        this.initAnimator();
    }
    public void setStart_color(int startColor) {
        this.mStartColor = startColor;
        invalidate();
    }
    public void setAnimation_duration(int animationDuration){
        this.animationDuration = animationDuration;
        destroyAnimator();
        initAnimator();
    }

    public void setMid_color(int midColor) {
        this.mMidColor = midColor;
        invalidate();
    }

    public void setEnd_color(int endColor) {
        this.mEndColor = endColor;
        invalidate();
    }

    /**
     * 暂停启动动画
     *
     * @param pauseAnimation
     */
    public void setPause_animation(boolean pauseAnimation) {
        Log.d(TAG, "setPause_animation: "+pauseAnimation);
        if (breathAnim == null||Objects.equals(pauseAnimation,this.mPauseAnimation)) {
            return;
        }
        this.mPauseAnimation = pauseAnimation;
        if (mPauseAnimation) {
            breathAnim.pause();
        } else {
            breathAnim.resume();
        }
    }
    public void setMax_shrink_ratio(float maxShrinkRatio ){
        this.mMaxShrinkRatio = maxShrinkRatio;
        destroyAnimator();
        initAnimator();
    }
    /**
     * 设置中间颜色的位置
     *
     * @param startingPosition
     */
    public void setStarting_position(float startingPosition) {
        this.shrinkRatio = startingPosition;
        invalidate(); // 触发重绘
    }

    public void setContent_padding_end(int paddingEnd) {
        this.setPadding(this.getPaddingLeft(), this.getPaddingTop(), SizeUtils.dp2px(paddingEnd), this.getPaddingBottom());
    }
    private void init() {
        paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        this.initAnimator();
    }

    /**
     * 初始化动画
     */
    public void initAnimator(){
        if (!useAnimation) {
            return;
        }
        // 启动动画
        if(breathAnim==null){
            float start=animationPositive?0f:mMaxShrinkRatio;
            float end=animationPositive?mMaxShrinkRatio:0f;
            breathAnim = ValueAnimator.ofFloat(start, end);
            breathAnim.setDuration(animationDuration);
            breathAnim.setRepeatCount(ValueAnimator.INFINITE);
            breathAnim.setRepeatMode(ValueAnimator.REVERSE);
            breathAnim.addUpdateListener(animation -> {
                setStarting_position((float) animation.getAnimatedValue());
            });
        }
        breathAnim.start();
        this.setPause_animation(this.mPauseAnimation);
    }
    @Override
    protected void onDraw(Canvas canvas) {
        // 动态创建线性渐变（基于当前centerX）
        if (isEnabled()) {
            int width = getWidth();
            int height = getHeight();
            // 渐变中心位置：width * centerX
            float leftPos = shrinkRatio;      // 左端色位置（0→0.4）
            float centerPos = 0.5f;           // 中间色固定在中心
            float rightPos = 1f - shrinkRatio;// 右端色位置（1→0.6）
            if (animationType == 2){
                // 流光效果
                leftPos=0f;
                centerPos=width*shrinkRatio/width;
                rightPos=1f;
            }
            linearGradient = new LinearGradient(
                    0, 0, width, 0, // 左→右渐变
                    new int[]{mStartColor, mMidColor, mEndColor}, // 颜色
                    new float[]{leftPos, centerPos, rightPos},    // 动态位置
                    Shader.TileMode.CLAMP
            );
            paint.setShader(linearGradient);
            // 绘制渐变背景
            canvas.drawRect(0, 0, width, height, paint);
        }
        // 绘制文字（保留按钮原有文字）
        super.onDraw(canvas);
    }
    private void destroyAnimator() {
        if (breathAnim != null) {
            breathAnim.cancel();
            breathAnim=null;
        }
    }
    @Override
    protected void onDetachedFromWindow() {
        super.onDetachedFromWindow();
        destroyAnimator();
    }
}