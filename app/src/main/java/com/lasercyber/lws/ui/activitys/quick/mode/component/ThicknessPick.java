package com.lasercyber.lws.ui.activitys.quick.mode.component;

import android.content.Context;
import android.content.res.TypedArray;
import android.util.AttributeSet;
import android.util.Log;

import androidx.annotation.Nullable;

import com.blankj.utilcode.util.GsonUtils;
import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.databinding.ThicknessPickBinding;

public class ThicknessPick extends QuickModelBasePick<ThicknessPickBinding> {
    private boolean clickEnable;
    public ThicknessPick(Context context) {
        super(context);
    }

    public ThicknessPick(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
    }

    public ThicknessPick(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    @Override
    protected int getLayoutId() {
        return R.layout.thickness_pick;
    }

    @Override
    public void initView(Context context) {
        binding.setThicknessPick(this);
    }


    @Override
    public void initSelect(int index) {
        if (!this.clickEnable||dataList==null||dataList.isEmpty()){
            return;
        }
        binding.setActiveIndex(this.activeIndex);
        binding.setThicknessPick(this);
        Log.d(TAG, "initSelect:正在初始化厚度数据："+ GsonUtils.toJson(dataList)+","+this.activeIndex);
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

    @Override
    protected void attrsHandler(Context context, TypedArray typedArray) {
        // 自定义的属性xml
        int modeType = typedArray.getInt(R.styleable.QuickModelBasePick_mode_type, ModelConstant.CONTINUOUS_WELDING);
        clickEnable = typedArray.getBoolean(R.styleable.QuickModelBasePick_click_enable, true);
        binding.setModeType(modeType);
    }
    public void setClick_enable(boolean clickEnable) {
        this.clickEnable = clickEnable;
    }
    public void setMode_type(int modeType) {
        binding.setModeType(modeType);
    }
}
