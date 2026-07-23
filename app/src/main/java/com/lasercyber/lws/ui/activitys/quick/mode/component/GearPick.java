package com.lasercyber.lws.ui.activitys.quick.mode.component;

import android.content.Context;
import android.content.res.TypedArray;
import android.util.AttributeSet;
import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.databinding.GearPickBinding;

/**
 * 档位选择组件
 */
public class GearPick extends QuickModelBasePick<GearPickBinding> {
    private boolean clickEnable;

    public GearPick(Context context) {
        super(context);
    }

    public GearPick(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
    }

    public GearPick(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    @Override
    protected int getLayoutId() {
        return R.layout.gear_pick;
    }

    @Override
    public void initView(Context context) {
        Log.d(TAG, "initView: 子类初始话视图");
        binding.setGearPick(this);
    }
    /**
     * 解析参数
     *
     * @param context
     * @param typedArray
     */
    @Override
    public void attrsHandler(Context context, TypedArray typedArray) {
        // 自定义的属性xml
        int modeType = typedArray.getInt(R.styleable.QuickModelBasePick_mode_type, ModelConstant.CONTINUOUS_WELDING);
        clickEnable = typedArray.getBoolean(R.styleable.QuickModelBasePick_click_enable, true);
        binding.setModeType(modeType);
    }

    public void setMode_type(int modeType) {
        binding.setModeType(modeType);
    }

    /**
     * 初始化选择
     *
     * @param index
     */
    @Override
    public void initSelect(int index) {
        if (!clickEnable||dataList==null||dataList.isEmpty()) {
            return;
        }
        binding.setActiveIndex(this.activeIndex);
        binding.setGearPick(this);
//        // 计算进度
        switch (index) {
            case 5:
                binding.setProgressValue(100);
                break;
            case 4:
                binding.setProgressValue(70);
                break;
            case 3:
                binding.setProgressValue(50);
                break;
            case 2:
                binding.setProgressValue(28);
                break;
            default:
                binding.setProgressValue(0);
        }
    }
    public void setClick_enable(boolean clickEnable) {
        this.clickEnable = clickEnable;
    }
}
