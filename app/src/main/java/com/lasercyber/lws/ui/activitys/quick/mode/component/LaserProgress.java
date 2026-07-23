package com.lasercyber.lws.ui.activitys.quick.mode.component;

import android.animation.ValueAnimator;
import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Color;
import android.graphics.RadialGradient;
import android.graphics.Shader;
import android.util.AttributeSet;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.LinearLayout;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.databinding.LaserProgressBinding;

import java.util.Objects;

/**
 * 激光进度组件
 */
public class LaserProgress extends LinearLayout implements MemoryCacheManager.OnCacheChangedListener {
    private static final String TAG = LogTAGConstant.LaserProgress;
    private LaserProgressBinding binding;
    private int progressValue = 0;
    private ValueAnimator upAnimator; // 从0→100的递增动画
    private ValueAnimator downAnimator; // 从当前值→0的递减动画
    // 动画时长配置（可根据需求调整）
    private static final long UP_DURATION = 5000; // 从0到100的总时长（5秒）
    private static final long DOWN_DURATION = 3000; // 从当前值到0的时长（300毫秒，更快的回弹效果）
    /**
     * 枪头状态
     */
    private Boolean gunSwitchStatus;
    /**
     * 激光状态
     */
    private boolean laserStatus = false;
    /**
     * 上一次的吹气气压
     */
    private Integer lastBlowAirPressure;
    /**
     * 设备logo点击事件
     */
    private OnClickListener deviceLogoBtnClickListener;

    public LaserProgress(Context context) {
        super(context);
    }

    public LaserProgress(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        this.initView(context);
        this.attrsHandler(context, attrs);

    }

    public LaserProgress(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        this.initView(context);
        this.attrsHandler(context, attrs);
    }

    private void initView(Context context) {
        binding = LaserProgressBinding.inflate(LayoutInflater.from(context), this, true);
        initBtnClick();
        this.initUpAnimator();
        this.initDownAnimator();
        binding.pressureValueText.setText("0");
        this.initStatusCache();
    }

    /**
     * 解析参数
     *
     * @param context
     * @param attrs
     */
    private void attrsHandler(Context context, @Nullable AttributeSet attrs) {
        TypedArray typedArray = context.obtainStyledAttributes(attrs, R.styleable.LaserProgress);
        // 自定义的属性xml
        int modelType = typedArray.getInt(R.styleable.LaserProgress_mode_type, ModelConstant.CONTINUOUS_WELDING);
        int progressValue = typedArray.getInt(R.styleable.LaserProgress_progress_value, 0);
        this.setMode_type(modelType);
        this.setProgress_value(progressValue);
        boolean laserStatus = typedArray.getBoolean(R.styleable.LaserProgress_laser_status, false);
        this.setLaser_status(laserStatus);
        // 回收typedArray
        typedArray.recycle();
    }

    public void setMode_type(int modelType) {
        binding.setModelType(modelType);
        // 更新进度颜色
        this.updateProgressColor();
    }

    public void setLaser_status(boolean laserStatus) {
        binding.setLaserStatus(laserStatus);
    }

    public void setProgress_value(int progressValue) {
        this.progressValue = progressValue;
        binding.setProgressValue(progressValue);
    }

    public void setDeviceLogoBtnClickListener(OnClickListener deviceLogoBtnClickListener) {
        this.deviceLogoBtnClickListener = deviceLogoBtnClickListener;
        initBtnClick();
    }

    private void initBtnClick() {
        if (this.deviceLogoBtnClickListener == null) {
            return;
        }
        binding.moreMonitorBtn.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                GlobalSoundManager.playClickSound();
                deviceLogoBtnClickListener.onClick(v);
            }
        });
//        binding.deviceLogoBtn.setOnClickListener(new OnClickListener() {
//            @Override
//            public void onClick(View v) {
//                GlobalSoundManager.playClickSound();
//                deviceLogoBtnClickListener.onClick(v);
//            }
//        });
    }

    /**
     * 更新进度颜色
     */
    public void updateProgressColor() {
        if (Objects.equals(binding.getModelType(), ModelConstant.CONTINUOUS_WELDING) ||
                Objects.equals(binding.getModelType(), ModelConstant.POINT_WELDING)) {
            Log.d(TAG, "正在切换为焊接");
            this.updateWeldingModeColor();
        } else if (Objects.equals(binding.getModelType(), ModelConstant.WELD_CLEAN) ||
                Objects.equals(binding.getModelType(), ModelConstant.WIDTH_CLEAN)) {
            Log.d(TAG, "正在切换为清洗");
            this.updateCleaningModeColor();
        } else if (Objects.equals(binding.getModelType(), ModelConstant.HAND_CUT) ||
                Objects.equals(binding.getModelType(), ModelConstant.CNC_CUT)) {
            Log.d(TAG, "正在切换为切割");
            this.updateCuttingModeColor();
        }
    }

    /**
     * 更新焊接模式颜色
     */
    public void updateWeldingModeColor() {
        binding.laserCircularSeek.setCircularSeekColorCall(circularSeekBar -> {
            // 1. 定义渐变颜色：内层橙色，外层红色
            int[] gradientColors = new int[]{
                    Color.parseColor("#B75717"), // 内层：
                    Color.parseColor("#FFB016"), //
                    Color.parseColor("#FFB016"), //
                    Color.parseColor("#FFBD18")  // 外层
            };

            float[] gradientPositions = new float[]{circularSeekBar.getProgressWidth() / circularSeekBar.getMCircleXRadius(), 0.5f, 0.9f, 1f};
            float centerX = circularSeekBar.getMCircleStrokeWidth() / 2f;
            float centerY = circularSeekBar.getMCircleStrokeWidth() / 2f;
            // 计算渐变半径（根据你的业务逻辑调整，此处为SeekBar的外半径）
            float gradientRadius = circularSeekBar.getMCircleXRadius() / 2;
            // 4. 创建径向渐变（圆形渐变）对象
            // 参数说明：中心点X, 中心点Y, 渐变半径, 颜色数组, 位置数组, 平铺模式
            return new RadialGradient(
                    centerX,
                    centerY,
                    gradientRadius,
                    gradientColors,
                    gradientPositions,
                    Shader.TileMode.CLAMP // 超出半径后使用最后一个颜色（红色）
            );
        });
        binding.laserCircularSeekMini.setCircularSeekColorCall(circularSeekBar -> {
            // 1. 定义渐变颜色：内层橙色，外层红色
            int[] gradientColors = new int[]{
                    Color.parseColor("#42260D"), // 内层：
                    Color.parseColor("#DD7315"), //
                    Color.parseColor("#DD7315"), //
                    Color.parseColor("#FFBD16")  // 外层
            };

            float[] gradientPositions = new float[]{circularSeekBar.getProgressWidth() / circularSeekBar.getMCircleXRadius(), 0.5f, 0.9f, 1f};
            float centerX = circularSeekBar.getMCircleStrokeWidth() / 2f;
            float centerY = circularSeekBar.getMCircleStrokeWidth() / 2f;
            // 计算渐变半径（根据你的业务逻辑调整，此处为SeekBar的外半径）
            float gradientRadius = circularSeekBar.getMCircleXRadius() / 2;
            // 4. 创建径向渐变（圆形渐变）对象
            // 参数说明：中心点X, 中心点Y, 渐变半径, 颜色数组, 位置数组, 平铺模式
            return new RadialGradient(
                    centerX,
                    centerY,
                    gradientRadius,
                    gradientColors,
                    gradientPositions,
                    Shader.TileMode.CLAMP // 超出半径后使用最后一个颜色（红色）
            );
//            Bitmap bitmap = BitmapFactory.decodeResource(getResources(), R.mipmap.laser_enable_btn_blue);
//            BitmapShader bitmapShader = new BitmapShader(
//                    bitmap,
//                    Shader.TileMode.CLAMP, // X轴：拉伸边缘
//                    Shader.TileMode.CLAMP  // Y轴：拉伸边缘
//            );
//            return bitmapShader;
        });
    }

    /**
     * 更新切割模式颜色
     */
    public void updateCuttingModeColor() {
        binding.laserCircularSeek.setCircularSeekColorCall(circularSeekBar -> {
            // 1. 定义渐变颜色：内层橙色，外层红色
            int[] gradientColors = new int[]{
                    Color.parseColor("#5552FF"), // 内层：
                    Color.parseColor("#7858FB"), //
                    Color.parseColor("#7858FB"), //
                    Color.parseColor("#B161F4")  // 外层
            };

            float[] gradientPositions = new float[]{circularSeekBar.getProgressWidth() / circularSeekBar.getMCircleXRadius(), 0.5f, 0.9f, 1f};
            float centerX = circularSeekBar.getMCircleStrokeWidth() / 2f;
            float centerY = circularSeekBar.getMCircleStrokeWidth() / 2f;
            // 计算渐变半径（根据你的业务逻辑调整，此处为SeekBar的外半径）
            float gradientRadius = circularSeekBar.getMCircleXRadius() / 2;
            // 4. 创建径向渐变（圆形渐变）对象
            // 参数说明：中心点X, 中心点Y, 渐变半径, 颜色数组, 位置数组, 平铺模式
            return new RadialGradient(
                    centerX,
                    centerY,
                    gradientRadius,
                    gradientColors,
                    gradientPositions,
                    Shader.TileMode.CLAMP // 超出半径后使用最后一个颜色（红色）
            );
        });
        binding.laserCircularSeekMini.setCircularSeekColorCall(circularSeekBar -> {
            // 1. 定义渐变颜色：内层橙色，外层红色
            int[] gradientColors = new int[]{
                    Color.parseColor("#5552FF"), // 内层：
                    Color.parseColor("#7858FB"), //
                    Color.parseColor("#7858FB"), //
                    Color.parseColor("#B161F4")  // 外层
            };

            float[] gradientPositions = new float[]{circularSeekBar.getProgressWidth() / circularSeekBar.getMCircleXRadius(), 0.5f, 0.9f, 1f};
            float centerX = circularSeekBar.getMCircleStrokeWidth() / 2f;
            float centerY = circularSeekBar.getMCircleStrokeWidth() / 2f;
            // 计算渐变半径（根据你的业务逻辑调整，此处为SeekBar的外半径）
            float gradientRadius = circularSeekBar.getMCircleXRadius() / 2;
            // 4. 创建径向渐变（圆形渐变）对象
            // 参数说明：中心点X, 中心点Y, 渐变半径, 颜色数组, 位置数组, 平铺模式
            return new RadialGradient(
                    centerX,
                    centerY,
                    gradientRadius,
                    gradientColors,
                    gradientPositions,
                    Shader.TileMode.CLAMP // 超出半径后使用最后一个颜色（红色）
            );
        });
    }

    /**
     * 更新清洗模式颜色
     */
    public void updateCleaningModeColor() {
        binding.laserCircularSeek.setCircularSeekColorCall(circularSeekBar -> {
            // 1. 定义渐变颜色：内层橙色，外层红色
            int[] gradientColors = new int[]{
                    Color.parseColor("#37EFD3"), // 内层：
                    Color.parseColor("#3CD2E4"), //
                    Color.parseColor("#3CD2E4"), //
                    Color.parseColor("#41A2FC")  // 外层
            };

            float[] gradientPositions = new float[]{circularSeekBar.getProgressWidth() / circularSeekBar.getMCircleXRadius(), 0.5f, 0.9f, 1f};
            float centerX = circularSeekBar.getMCircleStrokeWidth() / 2f;
            float centerY = circularSeekBar.getMCircleStrokeWidth() / 2f;
            // 计算渐变半径（根据你的业务逻辑调整，此处为SeekBar的外半径）
            float gradientRadius = circularSeekBar.getMCircleXRadius() / 2;
            // 4. 创建径向渐变（圆形渐变）对象
            // 参数说明：中心点X, 中心点Y, 渐变半径, 颜色数组, 位置数组, 平铺模式
            return new RadialGradient(
                    centerX,
                    centerY,
                    gradientRadius,
                    gradientColors,
                    gradientPositions,
                    Shader.TileMode.CLAMP // 超出半径后使用最后一个颜色（红色）
            );
        });
        binding.laserCircularSeekMini.setCircularSeekColorCall(circularSeekBar -> {
            // 1. 定义渐变颜色：内层橙色，外层红色
            int[] gradientColors = new int[]{
                    Color.parseColor("#196055"), // 内层：
                    Color.parseColor("#3CD2E4"), //
                    Color.parseColor("#3CD2E4"), //
                    Color.parseColor("#41A2FC")  // 外层
            };

            float[] gradientPositions = new float[]{circularSeekBar.getProgressWidth() / circularSeekBar.getMCircleXRadius(), 0.5f, 0.9f, 1f};
            float centerX = circularSeekBar.getMCircleStrokeWidth() / 2f;
            float centerY = circularSeekBar.getMCircleStrokeWidth() / 2f;
            // 计算渐变半径（根据你的业务逻辑调整，此处为SeekBar的外半径）
            float gradientRadius = circularSeekBar.getMCircleXRadius() / 2;
            // 4. 创建径向渐变（圆形渐变）对象
            // 参数说明：中心点X, 中心点Y, 渐变半径, 颜色数组, 位置数组, 平铺模式
            return new RadialGradient(
                    centerX,
                    centerY,
                    gradientRadius,
                    gradientColors,
                    gradientPositions,
                    Shader.TileMode.CLAMP // 超出半径后使用最后一个颜色（红色）
            );
        });
    }

    /**
     * 初始化递增动画：从0到100的线性动画
     */
    private void initUpAnimator() {
        upAnimator = ValueAnimator.ofInt(0, 100);
        upAnimator.setDuration(UP_DURATION);
        // 线性插值器（匀速递增，默认就是，可省略）
        // upAnimator.setInterpolator(new LinearInterpolator());

        // 监听数值变化，更新当前值和UI
        upAnimator.addUpdateListener(animation -> {
            progressValue = (int) animation.getAnimatedValue();
            binding.setProgressValue(progressValue);
        });
    }

    /**
     * 初始化状态监听
     */
    private void initStatusCache() {
        this.onCacheChanged(CacheKey.DEVICE_STATUS_KEY);
        this.onCacheChanged(CacheKey.DEVICE_DATA_KEY);
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_STATUS_KEY, this);
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_DATA_KEY, this);
    }


    /**
     * 初始化递减动画：动态设置起始值，从当前值到0
     */
    private void initDownAnimator() {
        // 初始值设为0，后续会动态修改
        downAnimator = ValueAnimator.ofInt(0, 0);
        downAnimator.setDuration(DOWN_DURATION);

        // 监听数值变化，更新当前值和UI
        downAnimator.addUpdateListener(animation -> {
            progressValue = (int) animation.getAnimatedValue();
            binding.setProgressValue(progressValue);
        });

        // 监听递减动画结束（可选：做一些收尾操作）
//        downAnimator.addListener(new android.animation.Animator.AnimatorListener() {
//            @Override
//            public void onAnimationStart(android.animation.Animator animation) {}
//
//            @Override
//            public void onAnimationEnd(android.animation.Animator animation) {
//                // 动画结束后，确保数值是0（防止精度问题）
//                progressValue=0;
//                binding.setProgressValue(0);
//                Log.d(TAG, "onAnimationEnd: 递减动画结束:"+progressValue);
//            }
//
//            @Override
//            public void onAnimationCancel(android.animation.Animator animation) {}
//
//            @Override
//            public void onAnimationRepeat(android.animation.Animator animation) {}
//        });
    }

    /**
     * 启动递增动画（按下按钮时调用）
     */
    public void startUpAnimator() {
        // 先停止递减动画（如果正在执行）
        if (downAnimator.isRunning()) {
            downAnimator.cancel();
        }
        if (progressValue == 100) {
            return;
        }
        // 重置递增动画：从0开始（每次按下都重新开始）
        upAnimator.cancel();
        upAnimator.setIntValues(progressValue, 100);
        upAnimator.start();
    }

    /**
     * 启动递减动画（松开按钮时调用）：从当前值动画到0
     */
    public void startDownAnimator() {
        // 先停止递增动画（如果正在执行）
        if (upAnimator.isRunning()) {
            upAnimator.cancel();
        }
        // 如果当前值已经是0，无需执行递减动画
        if (progressValue == 0) {
            return;
        }
        // 动态设置递减动画的起始值和结束值（当前值 → 0）
        downAnimator.cancel(); // 先取消原有动画，避免冲突
        downAnimator.setIntValues(progressValue, 0); // 更新数值范围
        downAnimator.start(); // 启动递减动画
    }

    public void destroyAnimator() {
        // 停止并释放递增动画
        if (upAnimator != null) {
            upAnimator.cancel();
            upAnimator.removeAllUpdateListeners();
        }
        // 停止并释放递减动画
        if (downAnimator != null) {
            downAnimator.cancel();
            downAnimator.removeAllUpdateListeners();
            downAnimator.removeAllListeners();
        }
    }

    @Override
    protected void onDetachedFromWindow() {
        super.onDetachedFromWindow();
        proactivelyDestroy();
    }

    /**
     * 主动销毁
     */
    public void proactivelyDestroy() {
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_DATA_KEY, this);
        this.destroyAnimator();
        if (binding != null) {
            binding.unbind();
            binding = null;
        }
    }

    @Override
    public void onCacheChanged(String key) {
        if (Objects.equals(key, CacheKey.DEVICE_STATUS_KEY)) {
            // 处理设备状态
            DeviceStatus status = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
            if (status == null) {
                startDownAnimator();
                return;
            }
            boolean gunSwitchOn = status.isLaserOn();
            if (Objects.equals(gunSwitchStatus, gunSwitchOn)) {
                return;
            }
            gunSwitchStatus = gunSwitchOn;
            if (gunSwitchStatus) {
                startUpAnimator();
            } else {
                startDownAnimator();
            }
        } else if (Objects.equals(key, CacheKey.DEVICE_DATA_KEY)) {
            // 处理设备数据
            DeviceData data = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_DATA_KEY);
            if (data == null) {
                return;
            }
            Integer blowAirPressure = data.getBlowAirPressure();
            if (blowAirPressure == null||Objects.equals(lastBlowAirPressure,blowAirPressure)) {
                return;
            }
            lastBlowAirPressure = blowAirPressure;
            binding.pressureValueText.setText(String.valueOf(blowAirPressure));
        }

    }
}
