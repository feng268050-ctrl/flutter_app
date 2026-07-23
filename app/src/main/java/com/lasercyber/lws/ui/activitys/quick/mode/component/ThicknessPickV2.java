package com.lasercyber.lws.ui.activitys.quick.mode.component;

import android.content.Context;
import android.content.res.TypedArray;
import android.util.AttributeSet;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.quick.mode.builder.OffsetWheelBuilder;
import com.lasercyber.lws.ui.bean.ui.DoubleWheelViewItem;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.component.adapter.OffsetWheelAdapter;
import com.lasercyber.lws.ui.component.wheelview.adapter.BaseWheelAdapter;
import com.lasercyber.lws.ui.databinding.ThicknessPickV2Binding;

import java.util.List;

public class ThicknessPickV2 extends QuickModelBasePick<ThicknessPickV2Binding>{
    public ThicknessPickV2(Context context) {
        super(context);
    }

    public ThicknessPickV2(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
    }

    public ThicknessPickV2(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    public ThicknessPickV2(Context context, AttributeSet attrs, int defStyleAttr, int defStyleRes) {
        super(context, attrs, defStyleAttr, defStyleRes);
    }

    @Override
    protected int getLayoutId() {
        return R.layout.thickness_pick_v2;
    }

    @Override
    public void initView(Context context) {
        OffsetWheelAdapter adapter = new OffsetWheelAdapter(context, OffsetWheelBuilder.builderOffsetThicknessOffset());
        binding.thicknessWheelView.setWheelAdapter(adapter);
        OffsetWheelBuilder.builderBasedWheelViewStyle(binding.thicknessWheelView);

        binding.thicknessWheelView.setWheelSize(31);
        binding.thicknessWheelView.setOnWheelItemSelectedListener((position, o) -> changeDataCall(position,o));
        binding.thicknessWheelView.setOnWheelItemClickListener((position, o) -> changeDataCall(position,o));
    }

    @Override
    public void setDataList(List<DoubleWheelViewItem> dataList) {
        setDataList(dataList, 0);
    }

    public void setDataList(List<DoubleWheelViewItem> dataList, int selectedIndex) {
        if (binding == null) {
            return;
        }
        boolean init = super.dataList == null || super.dataList.isEmpty();
        super.dataList = dataList;
        int target = resolveSelectionIndex(dataList, selectedIndex);
        if (init) {
            BaseWheelAdapter adapter = binding.thicknessWheelView.getMWheelAdapter();
            if (adapter instanceof OffsetWheelAdapter wheelAdapter) {
                wheelAdapter.startInit();
            }
            binding.thicknessWheelView.setWheelData(dataList);
            if (dataList != null && !dataList.isEmpty()) {
                binding.thicknessWheelView.setSelection(target);
            }
            binding.thicknessWheelView.addOnGlobalLayoutListener();
            if (adapter instanceof OffsetWheelAdapter wheelAdapter) {
                binding.thicknessWheelView.postDelayed(wheelAdapter::endInit, 100);
            }
        } else if (dataList != null && !dataList.isEmpty()) {
            binding.thicknessWheelView.resetDataScrollTo(dataList, target);
        }
    }

    private static int resolveSelectionIndex(List<DoubleWheelViewItem> dataList, int selectedIndex) {
        if (dataList == null || dataList.isEmpty()) {
            return 0;
        }
        if (selectedIndex < 0) {
            return 0;
        }
        if (selectedIndex >= dataList.size()) {
            return dataList.size() - 1;
        }
        return selectedIndex;
    }

    private void changeDataCall(int position,Object o) {
        if (o ==null){
            return;
        }
        if (circularPickListener!=null){
            circularPickListener.onClickListener((DoubleWheelViewItem) o);
        }
    }
    @Override
    protected void attrsHandler(Context context, TypedArray typedArray) {
        // 自定义的属性xml
        int modeType = typedArray.getInt(R.styleable.QuickModelBasePick_mode_type, ModelConstant.CONTINUOUS_WELDING);
        boolean clickEnable = typedArray.getBoolean(R.styleable.QuickModelBasePick_click_enable, true);
        binding.setModeType(modeType);
        binding.thicknessWheelView.switchEnableStatus(clickEnable);
    }
    public void setUse_mm_unit(boolean useMmUnit){
        binding.setUseMmUnit(useMmUnit);
    }
    @Override
    public void initSelect(int index) {

    }
    public void setClick_enable(boolean clickEnable) {
        binding.thicknessWheelView.switchEnableStatus(clickEnable);
    }
    public void setMode_type(int modeType) {
        binding.setModeType(modeType);
    }
}
