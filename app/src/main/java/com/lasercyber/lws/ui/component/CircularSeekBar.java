/*
 *
 * 版权所有 2013 Matt Joseph
 *
 * 根据Apache许可证2.0版（以下简称"许可证"）授权；
 * 除非遵守许可证，否则您不得使用本软件。
 * 您可以在以下地址获取许可证的副本：
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * 除非适用法律要求或书面同意，软件
 * 按"原样"分发，不附带任何明示或暗示的担保或条件。
 * 请参阅许可证以了解管理权限和
 * 限制的具体条款。
 *
 *
 *
 * 此自定义视图/控件的灵感和指导来自于：
 *
 * HoloCircleSeekBar - 版权所有 2012 Jes�s Manzano
 * HoloColorPicker - 版权所有 2012 Lars Werkman（由Marie Schweiz设计）
 *
 * 尽管我没有直接使用这两个项目的代码，但它们都被用作
 * 参考资料，因此非常有帮助。
 */

package com.lasercyber.lws.ui.component;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.BlurMaskFilter;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PathMeasure;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.SweepGradient;
import android.os.Bundle;
import android.os.Parcelable;
import android.util.AttributeSet;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.component.listener.CircularSeekColorCall;

import java.util.Arrays;

import lombok.Getter;

@Getter
public class CircularSeekBar extends View {

	private static final String TAG = LogTAGConstant.CircularSeekBar;
	private static final boolean DEFAULT_TOUCH_ENABLED = true;
	/**
	 * 用于将dp单位转换为像素
	 */
	protected final float DPTOPX_SCALE = getResources().getDisplayMetrics().density;

	/**
	 * 最小触摸目标大小（以dp为单位）。48dp是Android设计推荐值
	 */
	protected final float MIN_TOUCH_TARGET_DP = 48;

	// 默认值
	protected static final float DEFAULT_CIRCLE_X_RADIUS = 30f;
	protected static final float DEFAULT_CIRCLE_Y_RADIUS = 30f;
	protected static final float DEFAULT_POINTER_RADIUS = 7f;
	protected static final float DEFAULT_POINTER_HALO_WIDTH = 6f;
	protected static final float DEFAULT_POINTER_HALO_BORDER_WIDTH = 2f;
	protected static final float DEFAULT_CIRCLE_STROKE_WIDTH = 5f;
	protected static final float DEFAULT_START_ANGLE = 270f; // 几何角度（顺时针，相对于3点钟方向）
	protected static final float DEFAULT_END_ANGLE = 270f; // 几何角度（顺时针，相对于3点钟方向）
	protected static final int DEFAULT_MAX = 100;
	protected static final int DEFAULT_PROGRESS = 0;
	protected static final int DEFAULT_CIRCLE_COLOR = Color.DKGRAY;
	protected static final int DEFAULT_CIRCLE_PROGRESS_COLOR = Color.argb(235, 74, 138, 255);
	protected static final int DEFAULT_POINTER_COLOR = Color.argb(235, 74, 138, 255);
	protected static final int DEFAULT_POINTER_HALO_COLOR = Color.argb(135, 74, 138, 255);
	protected static final int DEFAULT_POINTER_HALO_COLOR_ONTOUCH = Color.argb(135, 74, 138, 255);
	protected static final int DEFAULT_CIRCLE_FILL_COLOR = Color.TRANSPARENT;
	protected static final int DEFAULT_POINTER_ALPHA = 135;
	protected static final int DEFAULT_POINTER_ALPHA_ONTOUCH = 100;
	protected static final boolean DEFAULT_USE_CUSTOM_RADII = false;
	protected static final boolean DEFAULT_MAINTAIN_EQUAL_CIRCLE = true;
	protected static final boolean DEFAULT_MOVE_OUTSIDE_CIRCLE = false;
	protected static final boolean DEFAULT_LOCK_ENABLED = true;
	protected static final boolean DEFAULT_USE_ROUND=true; // 使用圆形
	protected static final boolean DEFAULT_USE_HALO_PAINT=true; // 使用拖动的滑块

	/**
	 * 用于绘制非活动圆环的{@code Paint}实例。
	 */
	protected Paint mCirclePaint;

	/**
	 * 用于绘制圆环填充的{@code Paint}实例。
	 */
	protected Paint mCircleFillPaint;

	/**
	 * 用于绘制活动圆环（表示进度）的{@code Paint}实例。
	 */
	protected Paint mCircleProgressPaint;

	/**
	 * 用于绘制活动圆环光晕的{@code Paint}实例。
	 */
	protected Paint mCircleProgressGlowPaint;

	/**
	 * 用于绘制指针中心的{@code Paint}实例。
	 * 注意：在4.0+版本上此功能可能失效，因为硬件加速不支持模糊遮罩。
	 */
	protected Paint mPointerPaint;

	/**
	 * 用于绘制指针光晕的{@code Paint}实例。
	 * 注意：光晕是透明度会变化的部分。
	 */
	protected Paint mPointerHaloPaint;

	/**
	 * 用于绘制指针光晕边框（在光晕外部）的{@code Paint}实例。
	 */
	protected Paint mPointerHaloBorderPaint;

	/**
	 * 圆环的宽度（以像素为单位）。
	 */
	protected float mCircleStrokeWidth;

	/**
	 * 圆环的X半径（以像素为单位）。
	 */
	protected float mCircleXRadius;

	/**
	 * 圆环的Y半径（以像素为单位）。
	 */
	protected float mCircleYRadius;

	/**
	 * 指针的半径（以像素为单位）。
	 */
	protected float mPointerRadius;

	/**
	 * 指针光晕的宽度（以像素为单位）。
	 */
	protected float mPointerHaloWidth;

	/**
	 * 指针光晕边框的宽度（以像素为单位）。
	 */
	protected float mPointerHaloBorderWidth;

	/**
	 * 圆形SeekBar的起始角度。
	 * 注意：如果mStartAngle和mEndAngle设置为相同角度，会从mEndAngle减去0.1
	 * 以使圆环正常工作。
	 */
	protected float mStartAngle;

	/**
	 * 圆形SeekBar的结束角度。
	 * 注意：如果mStartAngle和mEndAngle设置为相同角度，会从mEndAngle减去0.1
	 * 以使圆环正常工作。
	 */
	protected float mEndAngle;

	/**
	 * 表示SeekBar圆环（或椭圆）的{@code RectF}。
	 */
	protected RectF mCircleRectF = new RectF();

	/**
	 * 在创建{@code Paint}实例之前，保存{@code mPointerPaint}的颜色值。
	 */
	protected int mPointerColor = DEFAULT_POINTER_COLOR;

	/**
	 * 在创建{@code Paint}实例之前，保存{@code mPointerHaloPaint}的颜色值。
	 */
	protected int mPointerHaloColor = DEFAULT_POINTER_HALO_COLOR;

	/**
	 * 在创建{@code Paint}实例之前，保存{@code mPointerHaloPaint}的颜色值。
	 */
	protected int mPointerHaloColorOnTouch = DEFAULT_POINTER_HALO_COLOR_ONTOUCH;

	/**
	 * 在创建{@code Paint}实例之前，保存{@code mCirclePaint}的颜色值。
	 */
	protected int mCircleColor = DEFAULT_CIRCLE_COLOR;

	/**
	 * 在创建{@code Paint}实例之前，保存{@code mCircleFillPaint}的颜色值。
	 */
	protected int mCircleFillColor = DEFAULT_CIRCLE_FILL_COLOR;

	/**
	 * 在创建{@code Paint}实例之前，保存{@code mCircleProgressPaint}的颜色值。
	 */
	protected int mCircleProgressColor = DEFAULT_CIRCLE_PROGRESS_COLOR;

	/**
	 * 保存{@code mPointerHaloPaint}的透明度值。
	 */
	protected int mPointerAlpha = DEFAULT_POINTER_ALPHA;

	/**
	 * 保存触摸时{@code mPointerHaloPaint}的透明度值。
	 */
	protected int mPointerAlphaOnTouch = DEFAULT_POINTER_ALPHA_ONTOUCH;

	/**
	 * 圆环/半圆所占据的角度（以度为单位）。
	 * 此值表示圆环的最大角度范围。
	 */
	protected float mTotalCircleDegrees;

	/**
	 * 当前进度在圆环中所占据的角度（以度为单位）。
	 */
	protected float mProgressDegrees;

	/**
	 * 用于绘制圆环/半圆的{@code Path}。
	 */
	protected Path mCirclePath;

	/**
	 * 用于绘制圆环上进度的{@code Path}。
	 */
	protected Path mCircleProgressPath;

	/**
	 * 此CircularSeekBar所表示的最大值。
	 */
	protected int mMax;

	/**
	 * 此CircularSeekBar所表示的进度值。
	 */
	protected int mProgress;

	/**
	 * 如果为true，则用户可以指定X和Y半径。
	 * 如果为false，则视图本身决定CircularSeekBar的大小。
	 */
	protected boolean mCustomRadii;

	/**
	 * 保持完美的圆形（X和Y半径相等），无论视图或自定义属性如何设置。
	 * 在这种情况下，将始终使用两个半径中较小的一个。
	 * 默认情况下为圆形而非椭圆，这是由于椭圆的行为特性。
	 */
	protected boolean mMaintainEqualCircle;

	/**
	 * 一旦用户触摸圆环，此属性决定在圆环外部移动是否能够
	 * 改变指针的位置（进而改变进度）。
	 */
	protected boolean mMoveOutsideCircle;

	/**
	 * 用于启用/禁用锁定选项，以便更容易达到0进度标记。
	 */
	protected boolean lockEnabled = true;

	/**
	 * 当用户逆时针移动超过圆环的起点时使用。
	 * 使达到0进度标记更容易。
	 */
	protected boolean lockAtStart = true;

	/**
	 * 当用户顺时针移动超过圆环的终点时使用。
	 * 使达到100%（最大）进度标记更容易。
	 */
	protected boolean lockAtEnd = false;

	/**
	 * 当用户在ACTION_DOWN时触摸圆环，此值设置为true。
	 * 在触摸CircularSeekBar时使用。
	 */
	protected boolean mUserIsMovingPointer = false;

	/**
	 * 表示从{@code mStartAngle}到触摸角度的顺时针距离。
	 * 在触摸CircularSeekBar时使用。
	 */
	protected float cwDistanceFromStart;

	/**
	 * 表示从{@code mStartAngle}到触摸角度的逆时针距离。
	 * 在触摸CircularSeekBar时使用。
	 */
	protected float ccwDistanceFromStart;

	/**
	 * 表示从{@code mEndAngle}到触摸角度的顺时针距离。
	 * 在触摸CircularSeekBar时使用。
	 */
	protected float cwDistanceFromEnd;

	/**
	 * 表示从{@code mEndAngle}到触摸角度的逆时针距离。
	 * 在触摸CircularSeekBar时使用。
	 * 目前未使用，但保留备用。
	 */
	@SuppressWarnings("unused")
	protected float ccwDistanceFromEnd;

	/**
	 * {@code cwDistanceFromStart}的上一个触摸动作值。
	 * 在触摸CircularSeekBar时使用。
	 */
	protected float lastCWDistanceFromStart;

	/**
	 * 表示从{@code mPointerPosition}到触摸角度的顺时针距离。
	 * 在触摸CircularSeekBar时使用。
	 */
	protected float cwDistanceFromPointer;

	/**
	 * 表示从{@code mPointerPosition}到触摸角度的逆时针距离。
	 * 在触摸CircularSeekBar时使用。
	 */
	protected float ccwDistanceFromPointer;

	/**
	 * 如果用户沿顺时针方向绕圆环移动则为true，如果沿逆时针方向移动则为false。
	 * 在触摸CircularSeekBar时使用。
	 */
	protected boolean mIsMovingCW;

	/**
	 * 用于绘制圆环的{@code RectF}中使用的圆环宽度。
	 * 基于视图宽度或自定义X半径。
	 */
	protected float mCircleWidth;

	/**
	 * 用于绘制圆环的{@code RectF}中使用的圆环高度。
	 * 基于视图宽度或自定义Y半径。
	 */
	protected float mCircleHeight;

	/**
	 * 表示圆环上的进度标记，以几何角度为单位。
	 * 这不是用户提供的，而是计算得出的；
	 */
	protected float mPointerPosition;

	/**
	 * 指针位置的X和Y坐标。
	 */
	protected float[] mPointerPositionXY = new float[2];

	/**
	 * 监听器。
	 */
	protected OnCircularSeekBarChangeListener mOnCircularSeekBarChangeListener;

	/**
	 * 如果为true，则启用用户触摸输入；如果为false，则忽略用户触摸输入。
	 * 这不影响通过编程方式设置值。
	 */
	protected boolean isTouchEnabled = true;
	// 新增：进度宽度变量
	private float progressWidth = 0f; // 已选中进度的宽度（默认10dp）
	private boolean useRound=DEFAULT_USE_ROUND; // 使用圆形
	/**
	 * 是否使用HaloPaint
	 */
	private boolean useHaloPaint=DEFAULT_USE_HALO_PAINT;
	/**
	 * 着色器
	 */
	private CircularSeekColorCall circularSeekColorCall;
	private float circlePaddingLeft=0;
	private float circlePaddingRight=0;
	/**
	 * 使用XML样式中的属性初始化CircularSeekBar。
	 * 当用户未指定属性时，使用本文件顶部定义的默认值。
	 * @param attrArray 包含属性的TypedArray。
	 */
	protected void initAttributes(TypedArray attrArray) {
		mCircleXRadius = attrArray.getDimension(R.styleable.CircularSeekBar_circle_x_radius, DEFAULT_CIRCLE_X_RADIUS * DPTOPX_SCALE);
		mCircleYRadius = attrArray.getDimension(R.styleable.CircularSeekBar_circle_y_radius, DEFAULT_CIRCLE_Y_RADIUS * DPTOPX_SCALE);
		mPointerRadius = attrArray.getDimension(R.styleable.CircularSeekBar_pointer_radius, DEFAULT_POINTER_RADIUS * DPTOPX_SCALE);
		mPointerHaloWidth = attrArray.getDimension(R.styleable.CircularSeekBar_pointer_halo_width, DEFAULT_POINTER_HALO_WIDTH * DPTOPX_SCALE);
		mPointerHaloBorderWidth = attrArray.getDimension(R.styleable.CircularSeekBar_pointer_halo_border_width, DEFAULT_POINTER_HALO_BORDER_WIDTH * DPTOPX_SCALE);
		mCircleStrokeWidth = attrArray.getDimension(R.styleable.CircularSeekBar_circle_stroke_width, DEFAULT_CIRCLE_STROKE_WIDTH * DPTOPX_SCALE);

		mPointerColor = attrArray.getColor(R.styleable.CircularSeekBar_pointer_color, DEFAULT_POINTER_COLOR);
		mPointerHaloColor = attrArray.getColor(R.styleable.CircularSeekBar_pointer_halo_color, DEFAULT_POINTER_HALO_COLOR);
		mPointerHaloColorOnTouch = attrArray.getColor(R.styleable.CircularSeekBar_pointer_halo_color_ontouch, DEFAULT_POINTER_HALO_COLOR_ONTOUCH);
		mCircleColor = attrArray.getColor(R.styleable.CircularSeekBar_circle_color, DEFAULT_CIRCLE_COLOR);
		mCircleProgressColor = attrArray.getColor(R.styleable.CircularSeekBar_circle_progress_color, DEFAULT_CIRCLE_PROGRESS_COLOR);
		mCircleFillColor = attrArray.getColor(R.styleable.CircularSeekBar_circle_fill, DEFAULT_CIRCLE_FILL_COLOR);

		mPointerAlpha = Color.alpha(mPointerHaloColor);

		mPointerAlphaOnTouch = attrArray.getInt(R.styleable.CircularSeekBar_pointer_alpha_ontouch, DEFAULT_POINTER_ALPHA_ONTOUCH);
		if (mPointerAlphaOnTouch > 255 || mPointerAlphaOnTouch < 0) {
			mPointerAlphaOnTouch = DEFAULT_POINTER_ALPHA_ONTOUCH;
		}

		mMax = attrArray.getInt(R.styleable.CircularSeekBar_max, DEFAULT_MAX);
		mProgress = attrArray.getInt(R.styleable.CircularSeekBar_progress, DEFAULT_PROGRESS);
		mCustomRadii = attrArray.getBoolean(R.styleable.CircularSeekBar_use_custom_radii, DEFAULT_USE_CUSTOM_RADII);
		circlePaddingLeft = attrArray.getDimension(R.styleable.CircularSeekBar_circle_padding_left, 0f);
		circlePaddingRight = attrArray.getDimension(R.styleable.CircularSeekBar_circle_padding_right, 0f);
		mMaintainEqualCircle = attrArray.getBoolean(R.styleable.CircularSeekBar_maintain_equal_circle, DEFAULT_MAINTAIN_EQUAL_CIRCLE);
		mMoveOutsideCircle = attrArray.getBoolean(R.styleable.CircularSeekBar_move_outside_circle, DEFAULT_MOVE_OUTSIDE_CIRCLE);
		lockEnabled = attrArray.getBoolean(R.styleable.CircularSeekBar_lock_enabled, DEFAULT_LOCK_ENABLED);

		// 现在进行360取模以避免频繁转换
		mStartAngle = ((360f + (attrArray.getFloat((R.styleable.CircularSeekBar_start_angle), DEFAULT_START_ANGLE) % 360f)) % 360f);
		mEndAngle = ((360f + (attrArray.getFloat((R.styleable.CircularSeekBar_end_angle), DEFAULT_END_ANGLE) % 360f)) % 360f);
		progressWidth=attrArray.getDimension(R.styleable.CircularSeekBar_progress_width, mCircleStrokeWidth);
		useRound= attrArray.getBoolean(R.styleable.CircularSeekBar_use_round, DEFAULT_USE_ROUND);
		useHaloPaint= attrArray.getBoolean(R.styleable.CircularSeekBar_use_halo_paint, DEFAULT_USE_HALO_PAINT);
		isTouchEnabled=attrArray.getBoolean(R.styleable.CircularSeekBar_is_touch_enabled, DEFAULT_TOUCH_ENABLED);
		if (mStartAngle == mEndAngle) {
			//mStartAngle = mStartAngle + 1f;
			mEndAngle = mEndAngle - .1f;
		}
	}

	/**
	 * 初始化所有绘图画笔（Paint）对象，并配置其样式属性
	 * 包括：基础圆环画笔、圆环填充画笔、进度圆环画笔、进度光晕画笔、指针画笔、指针光晕画笔、指针光晕边框画笔
	 * 每个画笔根据其绘制用途设置对应的抗锯齿、颜色、宽度、样式等属性
	 */
	protected void initPaints() {
		// 初始化基础圆环画笔：用于绘制非活动状态的圆环轮廓
		mCirclePaint = new Paint();
		mCirclePaint.setAntiAlias(true); // 开启抗锯齿，使绘制边缘更平滑
		mCirclePaint.setDither(true); // 开启抖动处理，提升低精度屏幕的绘制效果
		mCirclePaint.setColor(mCircleColor); // 设置基础圆环的颜色
		mCirclePaint.setStrokeWidth(mCircleStrokeWidth); // 设置圆环边框的宽度
		mCirclePaint.setStyle(Paint.Style.STROKE); // 设置为描边模式（仅绘制轮廓）
		mCirclePaint.setStrokeJoin(Paint.Join.ROUND); // 设置线段连接处为圆角，使圆环拐角更平滑
		// 根据配置决定圆环端点是否为圆形（ROUND）或方形（BUTT）
		if (useRound) {
			mCirclePaint.setStrokeCap(Paint.Cap.ROUND); // 端点为圆形
		} else {
			mCirclePaint.setStrokeCap(Paint.Cap.BUTT); // 端点为方形（默认）
		}

		// 初始化圆环填充画笔：用于绘制圆环内部的填充区域
		mCircleFillPaint = new Paint();
		mCircleFillPaint.setAntiAlias(true); // 开启抗锯齿
		mCircleFillPaint.setDither(true); // 开启抖动处理
		mCircleFillPaint.setColor(mCircleFillColor); // 设置圆环填充颜色（默认透明）
		mCircleFillPaint.setStyle(Paint.Style.FILL); // 设置为填充模式（绘制内部区域）

		// 初始化进度圆环画笔：用于绘制表示进度的活动圆环轮廓
		mCircleProgressPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
		mCircleProgressPaint.setAntiAlias(true); // 开启抗锯齿
		mCircleProgressPaint.setDither(true); // 开启抖动处理
		mCircleProgressPaint.setColor(mCircleProgressColor); // 设置进度圆环的颜色
		mCircleProgressPaint.setStrokeWidth(progressWidth); // 设置进度条的宽度（可自定义）
		mCircleProgressPaint.setStyle(Paint.Style.STROKE); // 设置为描边模式
		mCircleProgressPaint.setStrokeJoin(Paint.Join.ROUND); // 设置线段连接处为圆角
		// 根据配置决定进度条端点是否为圆形或方形
		if (useRound) {
			mCircleProgressPaint.setStrokeCap(Paint.Cap.ROUND); // 端点为圆形
		} else {
			mCircleProgressPaint.setStrokeCap(Paint.Cap.BUTT); // 端点为方形
		}

		// 初始化进度圆环光晕画笔：基于进度画笔，添加模糊效果实现光晕
		mCircleProgressGlowPaint = new Paint();
		mCircleProgressGlowPaint.set(mCircleProgressPaint); // 复制进度画笔的所有属性
		// 设置模糊遮罩滤镜，实现光晕效果（模糊半径按dp转换为像素，模糊模式为普通）
		mCircleProgressGlowPaint.setMaskFilter(new BlurMaskFilter((5f * DPTOPX_SCALE), BlurMaskFilter.Blur.NORMAL));

		// 初始化指针画笔：用于绘制进度指针的中心实心圆
		mPointerPaint = new Paint();
		mPointerPaint.setAntiAlias(true); // 开启抗锯齿
		mPointerPaint.setDither(true); // 开启抖动处理
		mPointerPaint.setStyle(Paint.Style.FILL); // 设置为填充模式（实心）
		mPointerPaint.setColor(mPointerColor); // 设置指针的颜色
		mPointerPaint.setStrokeWidth(mPointerRadius); // 设置指针的笔触宽度（与半径一致）

		// 初始化指针光晕画笔：用于绘制指针周围的半透明光晕
		mPointerHaloPaint = new Paint();
		mPointerHaloPaint.set(mPointerPaint); // 复制指针画笔的所有属性
		mPointerHaloPaint.setColor(mPointerHaloColor); // 设置光晕的颜色
		mPointerHaloPaint.setAlpha(mPointerAlpha); // 设置光晕的透明度
		// 设置光晕的笔触宽度（指针半径 + 光晕宽度）
		mPointerHaloPaint.setStrokeWidth(mPointerRadius + mPointerHaloWidth);

		// 初始化指针光晕边框画笔：用于绘制指针光晕的外边框（仅触摸时显示）
		mPointerHaloBorderPaint = new Paint();
		mPointerHaloBorderPaint.set(mPointerPaint); // 复制指针画笔的所有属性
		mPointerHaloBorderPaint.setStrokeWidth(mPointerHaloBorderWidth); // 设置边框的宽度
		mPointerHaloBorderPaint.setStyle(Paint.Style.STROKE); // 设置为描边模式（仅绘制边框）

	}

	/**
	 * 计算mStartAngle和mEndAngle之间的总角度，并将mTotalCircleDegrees设置为该值。
	 */
	protected void calculateTotalDegrees() {
		mTotalCircleDegrees = (360f - (mStartAngle - mEndAngle)) % 360f; // 整个圆环/弧线的长度
		if (mTotalCircleDegrees <= 0f) {
			mTotalCircleDegrees = 360f;
		}
	}

	/**
	 * 计算进度所代表的角度。也称为扫过角度。
	 * 将mProgressDegrees设置为该值。
	 */
	protected void calculateProgressDegrees() {
		mProgressDegrees = mPointerPosition - mStartAngle; // 已验证
		mProgressDegrees = (mProgressDegrees < 0 ? 360f + mProgressDegrees : mProgressDegrees); // 已验证
	}

	/**
	 * 计算指针位置（以及进度弧线的终点）的角度。
	 * 将mPointerPosition设置为该值。
	 */
	protected void calculatePointerAngle() {
		float progressPercent = ((float)mProgress / (float)mMax);
		mPointerPosition = (progressPercent * mTotalCircleDegrees) + mStartAngle;
		mPointerPosition = mPointerPosition % 360f;
	}

	protected void calculatePointerXYPosition() {
		PathMeasure pm = new PathMeasure(mCircleProgressPath, false);
		boolean returnValue = pm.getPosTan(pm.getLength(), mPointerPositionXY, null);
		if (!returnValue) {
			pm = new PathMeasure(mCirclePath, false);
			returnValue = pm.getPosTan(0, mPointerPositionXY, null);
		}
	}

	/**
	 * 使用适当的值初始化{@code Path}对象。
	 */
	protected void initPaths() {
		mCirclePath = new Path();
		mCirclePath.addArc(mCircleRectF, mStartAngle, mTotalCircleDegrees);

		mCircleProgressPath = new Path();
		mCircleProgressPath.addArc(mCircleRectF, mStartAngle, mProgressDegrees);
	}

	/**
	 * 使用适当的值初始化{@code RectF}对象。
	 */
	protected void initRects() {
		mCircleRectF.set(-mCircleWidth, -mCircleHeight, mCircleWidth, mCircleHeight);
	}

	@Override
	protected void onDraw(Canvas canvas) {
		super.onDraw(canvas);

		canvas.translate(this.getWidth() / 2, this.getHeight() / 2);

		canvas.drawPath(mCirclePath, mCirclePaint);
		canvas.drawPath(mCircleProgressPath, mCircleProgressGlowPaint);
		canvas.drawPath(mCircleProgressPath, mCircleProgressPaint);

		canvas.drawPath(mCirclePath, mCircleFillPaint);
		if (useHaloPaint){
			// 绘制拖动滑块的光晕
			canvas.drawCircle(mPointerPositionXY[0], mPointerPositionXY[1], mPointerRadius + mPointerHaloWidth, mPointerHaloPaint);
//		canvas.drawText("嘻嘻", mPointerPositionXY[0], mPointerPositionXY[1], mPointerPaint);
			// 绘制拖动的滑块的圆
			canvas.drawCircle(mPointerPositionXY[0], mPointerPositionXY[1], mPointerRadius, mPointerPaint);
			// 拖动过程中的坏块
			if (mUserIsMovingPointer) {
				canvas.drawCircle(mPointerPositionXY[0], mPointerPositionXY[1], mPointerRadius + mPointerHaloWidth + (mPointerHaloBorderWidth / 2f), mPointerHaloBorderPaint);
			}
		}
	}

	/**
	 * 获取CircularSeekBar的进度。
	 * @return CircularSeekBar的进度。
	 */
	public int getProgress() {
		int progress = Math.round((float)mMax * mProgressDegrees / mTotalCircleDegrees);
		return progress;
	}

	/**
	 * 设置CircularSeekBar的进度。
	 * 如果进度相同，则任何监听器都不会收到onProgressChanged事件。
	 * @param progress 要设置CircularSeekBar的进度。
	 */
	public void setProgress(int progress) {
		if (mProgress != progress) {
			mProgress = progress;
			if (mOnCircularSeekBarChangeListener != null) {
				mOnCircularSeekBarChangeListener.onProgressChanged(this, progress, false);
			}

			recalculateAll();
			invalidate();
		}
	}

	protected void setProgressBasedOnAngle(float angle) {
		mPointerPosition = angle;
		calculateProgressDegrees();
		mProgress = Math.round((float)mMax * mProgressDegrees / mTotalCircleDegrees);
	}

	protected void recalculateAll() {
		calculateTotalDegrees();
		calculatePointerAngle();
		calculateProgressDegrees();

		initRects();

		initPaths();

		calculatePointerXYPosition();

		// 补充：重新设置进度画笔的渐变（适配视图尺寸变化）
		resetProgressPaintGradient();
	}
	/**
	 * 重新设置进度画笔的渐变着色器（适配视图尺寸变化或角度变化）
	 */
	private void resetProgressPaintGradient() {
		if (this.circularSeekColorCall==null){
			return;
		}
		Shader shader = this.circularSeekColorCall.createShader(this);
		mCircleProgressPaint.setShader(shader);
		// 同步更新光晕画笔的着色器
		mCircleProgressGlowPaint.setShader(shader);
		if (true){
			return;
		}
		// 重新创建扫描渐变（与initPaints中的逻辑一致）
//		int[] gradientColors = new int[]{
//				Color.parseColor("#FF00FF"),
//				Color.parseColor("#00FFFF"),
//				Color.parseColor("#00FF00")
//		};
//		float[] gradientPositions = new float[]{0f, 0.5f, 1f};
//		SweepGradient sweepGradient = new SweepGradient(0, 0, gradientColors, gradientPositions);
//		Matrix gradientMatrix = new Matrix();
//		gradientMatrix.setRotate(mStartAngle, 0, 0);
//		sweepGradient.setLocalMatrix(gradientMatrix);
		// 1. 定义渐变颜色：内层橙色，外层红色
		int[] gradientColors = new int[]{
				Color.parseColor("#B75717"), // 内层：
				Color.parseColor("#FFB016"), //
				Color.parseColor("#FFB016"), //
//				Color.parseColor("#FFB016"), //
				Color.parseColor("#FFBD18")  // 外层
//				Color.parseColor("#3144EF")  // 外层
		};

		float[] gradientPositions = new float[]{progressWidth/mCircleXRadius,0.5f,0.9f,1f};
		Log.d(TAG, "gradientPositions=====>: "+ Arrays.toString(gradientPositions));
		float centerX =mCircleStrokeWidth/2f;
		float centerY = mCircleStrokeWidth/2f;
		// 计算渐变半径（根据你的业务逻辑调整，此处为SeekBar的外半径）
		float gradientRadius = mCircleXRadius/2;
// 4. 创建径向渐变（圆形渐变）对象
// 参数说明：中心点X, 中心点Y, 渐变半径, 颜色数组, 位置数组, 平铺模式
		RadialGradient radialGradient = new RadialGradient(
				centerX,
				centerY,
				gradientRadius,
				gradientColors,
				gradientPositions,
				Shader.TileMode.CLAMP // 超出半径后使用最后一个颜色（红色）
		);

// 5. （可选）矩阵变换（若需要旋转/平移渐变，可保留Matrix，径向渐变一般无需旋转）
//		Matrix gradientMatrix = new Matrix();
//		gradientMatrix.setRotate(-90f, centerX, centerY);
//		radialGradient.setLocalMatrix(gradientMatrix);
		mCircleProgressPaint.setShader(radialGradient);
		// 同步更新光晕画笔的着色器
		mCircleProgressGlowPaint.setShader(radialGradient);


		// 重新设置给进度画笔
//		mCircleProgressPaint.setShader(this.progressPaintShader);
//		// 同步更新光晕画笔的着色器
//		mCircleProgressGlowPaint.setShader(this.progressPaintShader);
	}

	@Override
	protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
		int height = getDefaultSize(getSuggestedMinimumHeight(), heightMeasureSpec);
		int width = getDefaultSize(getSuggestedMinimumWidth(), widthMeasureSpec);
		if (mMaintainEqualCircle) {
			int min = Math.min(width, height);
			setMeasuredDimension(min, min);
		} else {
			setMeasuredDimension(width, height);
		}

		// 暂时基于视图设置圆环的宽度和高度
//		mCircleHeight = (float)height / 2f - mCircleStrokeWidth - mPointerRadius - (mPointerHaloBorderWidth * 1.5f);
//		mCircleWidth = (float)width / 2f - mCircleStrokeWidth - mPointerRadius - (mPointerHaloBorderWidth * 1.5f);
		mCircleHeight = (float)height / 2f - mCircleStrokeWidth  - mPointerHaloBorderWidth -circlePaddingLeft-circlePaddingRight;
		mCircleWidth = (float)width / 2f - mCircleStrokeWidth  - mPointerHaloBorderWidth-circlePaddingLeft-circlePaddingRight;

		// 如果未设置为使用自定义值
		if (mCustomRadii) {
			// 检查自定义半径是否在视图范围内。如果超出，则使用视图值
			if ((mCircleYRadius - mCircleStrokeWidth - mPointerRadius - mPointerHaloBorderWidth) < mCircleHeight) {
				mCircleHeight = mCircleYRadius - mCircleStrokeWidth - mPointerRadius - (mPointerHaloBorderWidth * 1.5f);
			}

			if ((mCircleXRadius - mCircleStrokeWidth - mPointerRadius - mPointerHaloBorderWidth) < mCircleWidth) {
				mCircleWidth = mCircleXRadius - mCircleStrokeWidth - mPointerRadius - (mPointerHaloBorderWidth * 1.5f);
			}
		}

		if (mMaintainEqualCircle) { // 无论值如何确定，都适用
			float min = Math.min(mCircleHeight, mCircleWidth);
			mCircleHeight = min;
			mCircleWidth = min;
		}

		recalculateAll();
	}

	/**
	 * 获取指针是否锁定在零和最大值处。
	 * @return 如果指针锁定在零和最大值处则为true，否则为false。
	 */
	public boolean isLockEnabled() {
		return lockEnabled;
	}

	/**
	 * 设置指针是否锁定在零和最大值处。
	 * @param lockEnabled。如果指针应锁定在零和最大值处则为true，否则为false。
	 */
	public void setLockEnabled(boolean lockEnabled) {
		this.lockEnabled = lockEnabled;
	}

	@Override
	public boolean onTouchEvent(MotionEvent event) {
		if(!isTouchEnabled){
			return false;
		}

		// 将坐标转换到我们的内部坐标系
		float x = event.getX() - getWidth() / 2;
		float y = event.getY() - getHeight() / 2;

		// 获取到圆心的X和Y方向距离
		float distanceX = mCircleRectF.centerX() - x;
		float distanceY = mCircleRectF.centerY() - y;

		// 获取到圆心的径向距离
		float touchEventRadius = (float) Math.sqrt((Math.pow(distanceX, 2) + Math.pow(distanceY, 2)));

		float minimumTouchTarget = MIN_TOUCH_TARGET_DP * DPTOPX_SCALE; // 将最小触摸目标转换为像素
		float additionalRadius; // 要么使用最小触摸目标大小，要么如果圆环/指针更大则使用更大的值

		if (mCircleStrokeWidth < minimumTouchTarget) { // 如果宽度小于最小触摸目标，使用最小触摸目标
			additionalRadius = minimumTouchTarget / 2;
		}
		else {
			additionalRadius = mCircleStrokeWidth / 2; // 否则使用宽度
		}
		float outerRadius = Math.max(mCircleHeight, mCircleWidth) + additionalRadius; // 圆环的最大外半径，包括最小触摸目标或轮宽
		float innerRadius = Math.min(mCircleHeight, mCircleWidth) - additionalRadius; // 圆环的最小内半径，包括最小触摸目标或轮宽

		if (mPointerRadius < (minimumTouchTarget / 2)) { // 如果指针半径小于最小触摸目标，使用最小触摸目标
			additionalRadius = minimumTouchTarget / 2;
		}
		else {
			additionalRadius = mPointerRadius; // 否则使用半径
		}

		float touchAngle;
		touchAngle = (float) ((Math.atan2(y, x) / Math.PI * 180) % 360); // 已验证
		touchAngle = (touchAngle < 0 ? 360 + touchAngle : touchAngle); // 已验证

		cwDistanceFromStart = touchAngle - mStartAngle; // 已验证
		cwDistanceFromStart = (cwDistanceFromStart < 0 ? 360f + cwDistanceFromStart : cwDistanceFromStart); // 已验证
		ccwDistanceFromStart = 360f - cwDistanceFromStart; // 已验证

		cwDistanceFromEnd = touchAngle - mEndAngle; // 已验证
		cwDistanceFromEnd = (cwDistanceFromEnd < 0 ? 360f + cwDistanceFromEnd : cwDistanceFromEnd); // 已验证
		ccwDistanceFromEnd = 360f - cwDistanceFromEnd; // 已验证

		switch (event.getAction()) {
			case MotionEvent.ACTION_DOWN:
				// 这些仅在ACTION_DOWN时用于处理是否触摸的是指针部分
				float pointerRadiusDegrees = (float) ((mPointerRadius * 180) / (Math.PI * Math.max(mCircleHeight, mCircleWidth)));
				cwDistanceFromPointer = touchAngle - mPointerPosition;
				cwDistanceFromPointer = (cwDistanceFromPointer < 0 ? 360f + cwDistanceFromPointer : cwDistanceFromPointer);
				ccwDistanceFromPointer = 360f - cwDistanceFromPointer;
				// 这是用于首次触摸实际指针的情况。
				if (((touchEventRadius >= innerRadius) && (touchEventRadius <= outerRadius)) && ( (cwDistanceFromPointer <= pointerRadiusDegrees) || (ccwDistanceFromPointer <= pointerRadiusDegrees)) ) {
					setProgressBasedOnAngle(mPointerPosition);
					lastCWDistanceFromStart = cwDistanceFromStart;
					mIsMovingCW = true;
					mPointerHaloPaint.setAlpha(mPointerAlphaOnTouch);
					mPointerHaloPaint.setColor(mPointerHaloColorOnTouch);
					recalculateAll();
					invalidate();
					if (mOnCircularSeekBarChangeListener != null) {
						mOnCircularSeekBarChangeListener.onStartTrackingTouch(this);
					}
					mUserIsMovingPointer = true;
					lockAtEnd = false;
					lockAtStart = false;
				} else if (cwDistanceFromStart > mTotalCircleDegrees) { // 如果用户触摸的是起点和终点之外
					mUserIsMovingPointer = false;
					return false;
				} else if ((touchEventRadius >= innerRadius) && (touchEventRadius <= outerRadius)) { // 如果用户触摸的是圆环附近
					setProgressBasedOnAngle(touchAngle);
					lastCWDistanceFromStart = cwDistanceFromStart;
					mIsMovingCW = true;
					mPointerHaloPaint.setAlpha(mPointerAlphaOnTouch);
					mPointerHaloPaint.setColor(mPointerHaloColorOnTouch);
					recalculateAll();
					invalidate();
					if (mOnCircularSeekBarChangeListener != null) {
						mOnCircularSeekBarChangeListener.onStartTrackingTouch(this);
						mOnCircularSeekBarChangeListener.onProgressChanged(this, mProgress, true);
					}
					mUserIsMovingPointer = true;
					lockAtEnd = false;
					lockAtStart = false;
				} else { // 如果用户没有触摸圆环附近
					mUserIsMovingPointer = false;
					return false;
				}
				break;
			case MotionEvent.ACTION_MOVE:
				if (mUserIsMovingPointer) {
					if (lastCWDistanceFromStart < cwDistanceFromStart) {
						if ((cwDistanceFromStart - lastCWDistanceFromStart) > 180f && !mIsMovingCW) {
							lockAtStart = true;
							lockAtEnd = false;
						} else {
							mIsMovingCW = true;
						}
					} else {
						if ((lastCWDistanceFromStart - cwDistanceFromStart) > 180f && mIsMovingCW) {
							lockAtEnd = true;
							lockAtStart = false;
						} else {
							mIsMovingCW = false;
						}
					}

					if (lockAtStart && mIsMovingCW) {
						lockAtStart = false;
					}
					if (lockAtEnd && !mIsMovingCW) {
						lockAtEnd = false;
					}
					if (lockAtStart && !mIsMovingCW && (ccwDistanceFromStart > 90)) {
						lockAtStart = false;
					}
					if (lockAtEnd && mIsMovingCW && (cwDistanceFromEnd > 90)) {
						lockAtEnd = false;
					}
					// 快速经过半圆终点的修复
					if (!lockAtEnd && cwDistanceFromStart > mTotalCircleDegrees && mIsMovingCW && lastCWDistanceFromStart < mTotalCircleDegrees) {
						lockAtEnd = true;
					}

					if (lockAtStart && lockEnabled) {
						// TODO: 添加检查如果mProgress已经是0，则不调用监听器
						mProgress = 0;
						recalculateAll();
						invalidate();
						if (mOnCircularSeekBarChangeListener != null) {
							mOnCircularSeekBarChangeListener.onProgressChanged(this, mProgress, true);
						}

					} else if (lockAtEnd && lockEnabled) {
						mProgress = mMax;
						recalculateAll();
						invalidate();
						if (mOnCircularSeekBarChangeListener != null) {
							mOnCircularSeekBarChangeListener.onProgressChanged(this, mProgress, true);
						}
					} else if ((mMoveOutsideCircle) || (touchEventRadius <= outerRadius)) {
						if (!(cwDistanceFromStart > mTotalCircleDegrees)) {
							setProgressBasedOnAngle(touchAngle);
						}
						recalculateAll();
						invalidate();
						if (mOnCircularSeekBarChangeListener != null) {
							mOnCircularSeekBarChangeListener.onProgressChanged(this, mProgress, true);
						}
					} else {
						break;
					}

					lastCWDistanceFromStart = cwDistanceFromStart;
				} else {
					return false;
				}
				break;
			case MotionEvent.ACTION_UP:
				mPointerHaloPaint.setAlpha(mPointerAlpha);
				mPointerHaloPaint.setColor(mPointerHaloColor);
				if (mUserIsMovingPointer) {
					mUserIsMovingPointer = false;
					invalidate();
					if (mOnCircularSeekBarChangeListener != null) {
						mOnCircularSeekBarChangeListener.onStopTrackingTouch(this);
					}
				} else {
					return false;
				}
				break;
			case MotionEvent.ACTION_CANCEL: // 当父视图拦截触摸（如滚动）时使用
				mPointerHaloPaint.setAlpha(mPointerAlpha);
				mPointerHaloPaint.setColor(mPointerHaloColor);
				mUserIsMovingPointer = false;
				invalidate();
				break;
		}

		if (event.getAction() == MotionEvent.ACTION_MOVE && getParent() != null) {
			getParent().requestDisallowInterceptTouchEvent(true);
		}

		return true;
	}

	protected void init(AttributeSet attrs, int defStyle) {
		final TypedArray attrArray = getContext().obtainStyledAttributes(attrs, R.styleable.CircularSeekBar, defStyle, 0);

		initAttributes(attrArray);

		attrArray.recycle();

		initPaints();
	}

	public CircularSeekBar(Context context) {
		super(context);
		init(null, 0);
	}

	public CircularSeekBar(Context context, AttributeSet attrs) {
		super(context, attrs);
		init(attrs, 0);
	}

	public CircularSeekBar(Context context, AttributeSet attrs, int defStyle) {
		super(context, attrs, defStyle);
		init(attrs, defStyle);
	}

	@Override
	protected Parcelable onSaveInstanceState() {
		Parcelable superState = super.onSaveInstanceState();

		Bundle state = new Bundle();
		state.putParcelable("PARENT", superState);
		state.putInt("MAX", mMax);
		state.putInt("PROGRESS", mProgress);
		state.putInt("mCircleColor", mCircleColor);
		state.putInt("mCircleProgressColor", mCircleProgressColor);
		state.putInt("mPointerColor", mPointerColor);
		state.putInt("mPointerHaloColor", mPointerHaloColor);
		state.putInt("mPointerHaloColorOnTouch", mPointerHaloColorOnTouch);
		state.putInt("mPointerAlpha", mPointerAlpha);
		state.putInt("mPointerAlphaOnTouch", mPointerAlphaOnTouch);
		state.putBoolean("lockEnabled", lockEnabled);
		state.putBoolean("isTouchEnabled", isTouchEnabled);

		return state;
	}

	@Override
	protected void onRestoreInstanceState(Parcelable state) {
		Bundle savedState = (Bundle) state;

		Parcelable superState = savedState.getParcelable("PARENT");
		super.onRestoreInstanceState(superState);

		mMax = savedState.getInt("MAX");
		mProgress = savedState.getInt("PROGRESS");
		mCircleColor = savedState.getInt("mCircleColor");
		mCircleProgressColor = savedState.getInt("mCircleProgressColor");
		mPointerColor = savedState.getInt("mPointerColor");
		mPointerHaloColor = savedState.getInt("mPointerHaloColor");
		mPointerHaloColorOnTouch = savedState.getInt("mPointerHaloColorOnTouch");
		mPointerAlpha = savedState.getInt("mPointerAlpha");
		mPointerAlphaOnTouch = savedState.getInt("mPointerAlphaOnTouch");
		lockEnabled = savedState.getBoolean("lockEnabled");
		isTouchEnabled = savedState.getBoolean("isTouchEnabled");

		initPaints();

		recalculateAll();
	}

	public void setOnSeekBarChangeListener(OnCircularSeekBarChangeListener l) {
		mOnCircularSeekBarChangeListener = l;
	}

	/**
	 * CircularSeekBar的监听器。实现与普通OnSeekBarChangeListener相同的方法。
	 */
	public interface OnCircularSeekBarChangeListener {

		public abstract void onProgressChanged(CircularSeekBar circularSeekBar, int progress, boolean fromUser);

		public abstract void onStopTrackingTouch(CircularSeekBar seekBar);

		public abstract void onStartTrackingTouch(CircularSeekBar seekBar);
	}

	/**
	 * 设置圆环颜色。
	 * @param color 圆环的颜色
	 */
	public void setCircle_color(int color) {
		mCircleColor = color;
		mCirclePaint.setColor(mCircleColor);
		invalidate();
	}

	/**
	 * 获取圆环颜色。
	 * @return 圆环的整数颜色值
	 */
	public int getCircle_color() {
		return mCircleColor;
	}

	/**
	 * 设置圆环进度颜色。
	 * @param color 圆环进度的颜色
	 */
	public void setCircle_progress_color(int color) {
		mCircleProgressColor = color;
		mCircleProgressPaint.setColor(mCircleProgressColor);
		invalidate();
	}

	/**
	 * 获取圆环进度颜色。
	 * @return 圆环进度的整数颜色值
	 */
	public int getCircleProgressColor() {
		return mCircleProgressColor;
	}

	/**
	 * 设置指针颜色。
	 * @param color 指针的颜色
	 */
	public void setPointerColor(int color) {
		mPointerColor = color;
		mPointerPaint.setColor(mPointerColor);
		invalidate();
	}

	/**
	 * 获取指针颜色。
	 * @return 指针的整数颜色值
	 */
	public int getPointerColor() {
		return mPointerColor;
	}

	/**
	 * 设置指针光晕颜色。
	 * @param color 指针光晕的颜色
	 */
	public void setPointer_halo_color(int color) {
		mPointerHaloColor = color;
		mPointerHaloPaint.setColor(mPointerHaloColor);
		invalidate();
	}

	/**
	 * 获取指针光晕颜色。
	 * @return 指针光晕的整数颜色值
	 */
	public int getPointerHaloColor() {
		return mPointerHaloColor;
	}

	/**
	 * 设置指针透明度。
	 * @param alpha 指针的透明度
	 */
	public void setPointerAlpha(int alpha) {
		if (alpha >=0 && alpha <= 255) {
			mPointerAlpha = alpha;
			mPointerHaloPaint.setAlpha(mPointerAlpha);
			invalidate();
		}
	}

	/**
	 * 获取指针透明度值。
	 * @return 指针的整数透明度值（0..255）
	 */
	public int getPointerAlpha() {
		return mPointerAlpha;
	}

	/**
	 * 设置触摸时指针的透明度。
	 * @param alpha 触摸时指针的透明度（0..255）
	 */
	public void setPointerAlphaOnTouch(int alpha) {
		if (alpha >=0 && alpha <= 255) {
			mPointerAlphaOnTouch = alpha;
		}
	}

	/**
	 * 获取触摸时指针的透明度值。
	 * @return 触摸时指针的整数透明度值（0..255）
	 */
	public int getPointerAlphaOnTouch() {
		return mPointerAlphaOnTouch;
	}

	/**
	 * 设置圆环填充颜色。
	 * @param color 圆环填充的颜色
	 */
	public void setCircleFillColor(int color) {
		mCircleFillColor = color;
		mCircleFillPaint.setColor(mCircleFillColor);
		invalidate();
	}

	/**
	 * 获取圆环填充颜色。
	 * @return 圆环填充的整数颜色值
	 */
	public int getCircleFillColor() {
		return mCircleFillColor;
	}

	/**
	 * 设置CircularSeekBar的最大值。
	 * 如果新的最大值小于当前进度，则进度将设置为零。
	 * 如果结果更改了进度，则任何监听器都将收到onProgressChanged事件。
	 * @param max CircularSeekBar的新最大值。
	 */
	public void setMax(int max) {
		if (!(max <= 0)) { // 检查确保它大于零
			if (max <= mProgress) {
				mProgress = 0; // 如果新的最大值小于当前进度，将进度设置为零
				if (mOnCircularSeekBarChangeListener != null) {
					mOnCircularSeekBarChangeListener.onProgressChanged(this, mProgress, false);
				}
			}
			mMax = max;

			recalculateAll();
			invalidate();
		}
	}

	/**
	 * 获取CircularSeekBar的当前最大值。
	 * @return 最大值的同步整数值。
	 */
	public synchronized int getMax() {
		return mMax;
	}

	/**
	 * 设置是否接受或忽略用户触摸输入。
	 * @param isTouchEnabled。如果要接受用户触摸输入则为true，如果要忽略用户触摸输入则为false。
	 */
	public void setIsTouchEnabled(boolean isTouchEnabled) {
		this.isTouchEnabled = isTouchEnabled;
	}

	/**
	 * 获取是否接受用户触摸输入。
	 * @return 如果接受用户触摸输入则为true，如果忽略用户触摸输入则为false。
	 */
	public boolean getIsTouchEnabled() {
		return isTouchEnabled;
	}

	/**
	 * 设置着色器
	 * @param circularSeekColorCall
	 */
	public void setCircularSeekColorCall(CircularSeekColorCall circularSeekColorCall){
		this.circularSeekColorCall=circularSeekColorCall;
		invalidate();
	}
}