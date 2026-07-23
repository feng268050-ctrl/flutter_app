package com.lasercyber.lws.ui.activitys.quick.mode.component;

import android.content.Context;
import android.content.res.TypedArray;
import android.util.AttributeSet;
import android.util.Log;
import android.view.ViewGroup;
import android.view.ViewParent;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.quick.mode.builder.OffsetWheelBuilder;
import com.lasercyber.lws.ui.bean.ui.DoubleWheelViewItem;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.component.adapter.OffsetWheelAdapter;
import com.lasercyber.lws.ui.component.wheelview.adapter.BaseWheelAdapter;
import com.lasercyber.lws.ui.databinding.GearPickV2Binding;

import java.util.List;

/**
 * 档位v2
 */
public class GearPickV2 extends QuickModelBasePick<GearPickV2Binding>{
    public GearPickV2(Context context) {
        super(context);
    }

    public GearPickV2(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
    }

    public GearPickV2(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    public GearPickV2(Context context, AttributeSet attrs, int defStyleAttr, int defStyleRes) {
        super(context, attrs, defStyleAttr, defStyleRes);
    }

    @Override
    protected int getLayoutId() {
        return R.layout.gear_pick_v2;
    }

    @Override
    public void initView(Context context) {
        setClipChildren(false);
        setClipToPadding(false);
        binding.scaleLeft.post(this::disableScaleAncestorClipping);

        OffsetWheelAdapter adapter = new OffsetWheelAdapter(context,OffsetWheelBuilder.builderOffsetGearOffset());
        binding.gearWheelView.setWheelAdapter(adapter);
//        adapter.setDEBUG(true);
        OffsetWheelBuilder.builderBasedWheelViewStyle(binding.gearWheelView);

        binding.gearWheelView.setWheelSize(11);
        binding.gearWheelView.setOnWheelItemSelectedListener((position, o) -> changeDataCall(position,o));
        binding.gearWheelView.setOnWheelItemClickListener((position, o) -> changeDataCall(position,o));
    }

    private void disableScaleAncestorClipping() {
        ViewParent pickerParent = getParent();
        ViewParent parent = binding.scaleLeft.getParent();
        while (parent instanceof ViewGroup group) {
            group.setClipChildren(false);
            group.setClipToPadding(false);
            if (group == pickerParent) {
                break;
            }
            parent = group.getParent();
        }
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
    public void setDataList(List<DoubleWheelViewItem> dataList) {
        setDataList(dataList, 0);
    }

    public void setDataList(List<DoubleWheelViewItem> dataList, int selectedIndex) {
        if (binding == null) {
            return;
        }
        Log.d(TAG, "setDataList: 初始化档位:");
        boolean init = super.dataList == null || super.dataList.isEmpty();
        super.dataList = dataList;
        int target = resolveSelectionIndex(dataList, selectedIndex);
        if (init) {
            BaseWheelAdapter adapter = binding.gearWheelView.getMWheelAdapter();
            if (adapter instanceof OffsetWheelAdapter wheelAdapter) {
                wheelAdapter.startInit();
            }
            binding.gearWheelView.setWheelData(dataList);
            if (dataList != null && !dataList.isEmpty()) {
                binding.gearWheelView.setSelection(target);
            }
            binding.gearWheelView.addOnGlobalLayoutListener();
            if (adapter instanceof OffsetWheelAdapter wheelAdapter) {
                binding.gearWheelView.postDelayed(wheelAdapter::endInit, 100);
            }
        } else if (dataList != null && !dataList.isEmpty()) {
            binding.gearWheelView.resetDataScrollTo(dataList, target);
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

    @Override
    public void initSelect(int index) {

    }

    @Override
    protected void attrsHandler(Context context, TypedArray typedArray) {
        // 自定义的属性xml
        int modeType = typedArray.getInt(R.styleable.QuickModelBasePick_mode_type, ModelConstant.CONTINUOUS_WELDING);
        boolean clickEnable = typedArray.getBoolean(R.styleable.QuickModelBasePick_click_enable, true);
        binding.setModeType(modeType);
        binding.gearWheelView.switchEnableStatus(clickEnable);
    }
    public void setClick_enable(boolean clickEnable){
        binding.gearWheelView.switchEnableStatus(clickEnable);
    }
    public void setMode_type(int modeType) {
        binding.setModeType(modeType);
    }
}
