package com.lasercyber.lws.ui.activitys.engineer.mode.component;

import android.content.Context;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.widget.LinearLayout;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.databinding.EngineerTabBinding;

/**
 * 工程师模式的tab栏
 */
public class EngineerTab extends LinearLayout {
    private static final String TAG = LogTAGConstant.EngineerTab;
    private EngineerTabBinding binding;
    private SwitchTabListener switchTabListener;

    public EngineerTab(Context context) {
        super(context);
        initView(context);
    }

    public EngineerTab(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        initView(context);
    }

    public EngineerTab(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        initView(context);
    }

    public void initView(Context context) {
        // 加载自定义布局
        binding = EngineerTabBinding.inflate(LayoutInflater.from(context), this, true);
        /**
         * 当前激活的类型
         */
        int activeType = ModelConstant.CONTINUOUS_WELDING;
        binding.setActiveType(activeType);
        this.switchBackGround(activeType);
        binding.setEngineerTab(this);
    }

    /**
     * 切换 tab
     *
     * @param type
     */
    public void switchTab(int type, int index) {
        binding.setActiveType(type);
        this.switchBackGround(type);
        if (this.switchTabListener != null) {
            this.switchTabListener.switchTab(type, index);
        }
    }

    /**
     * 切换背景
     *
     * @param type
     */
    public void switchBackGround(int type) {
        switch (type) {
            case ModelConstant.CONTINUOUS_WELDING:
                binding.engineerContainer.setBackground(getResources().getDrawable(R.mipmap.continuous_welding_tab_bg));
                break;
            case ModelConstant.POINT_WELDING:
                binding.engineerContainer.setBackground(getResources().getDrawable(R.mipmap.point_welding_tab_bg));
                break;
            case ModelConstant.WELD_CLEAN:
                binding.engineerContainer.setBackground(getResources().getDrawable(R.mipmap.weld_clean_tab_bg));
                break;
            case ModelConstant.WIDTH_CLEAN:
                binding.engineerContainer.setBackground(getResources().getDrawable(R.mipmap.width_clean_tab_bg));
                break;
            case ModelConstant.HAND_CUT:
                binding.engineerContainer.setBackground(getResources().getDrawable(R.mipmap.hand_cut_tab_bg));
                break;
            default:
                binding.engineerContainer.setBackground(getResources().getDrawable(R.drawable.transparent_bg));

        }
    }

    public void setActiveType(Integer activeType) {
        binding.setActiveType(activeType);
        this.switchBackGround(activeType);
    }

    public EngineerTab setSwitchTabListener(SwitchTabListener listener) {
        this.switchTabListener = listener;
        return this;
    }

    public interface SwitchTabListener {
        void switchTab(int type, int index);
    }
}
