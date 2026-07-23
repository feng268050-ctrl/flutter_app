package com.lasercyber.lws.ui.component;

import android.content.Context;
import android.util.AttributeSet;
import android.util.Log;
import android.view.LayoutInflater;
import android.widget.LinearLayout;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.databinding.DataPickerBinding;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;

/**
 * 数据选择器组件
 */
public class CustomizeDataPicker<T> extends LinearLayout {
    private static final String TAG = LogTAGConstant.DataPicker;
    private DataPickerBinding binding;
    /**
     * 标题列表
     */
    private final List<String> textList=new ArrayList<>();
    /**
     * 数据列表
     */
    private final List<T> dataList=new ArrayList<>();
    /**
     * 循环滚动
     */
    private boolean wrapSelectorWheel=true;
    /**
     * 监听器
     */
    private OnValueChangeListener onValueChangeListener;

    public CustomizeDataPicker(Context context) {
        super(context);
        initView(context);
    }

    public CustomizeDataPicker(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        initView(context);
    }

    public CustomizeDataPicker(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        initView(context);
    }

    private void initView(Context context) {
        binding= DataPickerBinding.inflate(LayoutInflater.from(context), this, true);
        binding.previous.setOnClickListener(v -> {
            if (textList.isEmpty()){
                return;
            }
            // 上一个
            int value = binding.dataPickerContent.getValue();

            if (value==0){
                if(wrapSelectorWheel){
                    // 允许循环滚动
                    binding.dataPickerContent.setValue(textList.size()-1);
                }
                return;
            }
            binding.dataPickerContent.setValue(value-1);
            Log.d(TAG, "initView: 手动选中的"+textList.get(binding.dataPickerContent.getValue()));
            selectAndCallBack(binding.dataPickerContent.getValue());
        });
        binding.next.setOnClickListener(v -> {
            if (textList.isEmpty()){
                return;
            }
            // 下一个
            int value = binding.dataPickerContent.getValue();
            if (value==textList.size()-1){
                if(wrapSelectorWheel){
                    // 允许循环滚动
                    binding.dataPickerContent.setValue(0);
                }
                return;
            }
            binding.dataPickerContent.setValue(value+1);
            Log.d(TAG, "initView: 手动选中的"+textList.get(binding.dataPickerContent.getValue()));
            selectAndCallBack(binding.dataPickerContent.getValue());
        });
        binding.dataPickerContent.setOnValueChangedListener((picker, oldVal, newVal) -> {
            selectAndCallBack(newVal);
        });
    }

    /**
     * 选中后进行回调
     * @param newVal
     */
    private void selectAndCallBack(int newVal) {
        Log.d(TAG, "onValueChange: 当前选中"+ newVal);
        if (onValueChangeListener==null){
            return;
        }
        onValueChangeListener.onValueChange(textList.get(newVal),dataList.get(newVal), newVal);
    }

    /**
     * 初始化数据
     * @param dataMap
     * @return
     */
    public CustomizeDataPicker setMapData(HashMap<String,T> dataMap){
        if (dataMap==null||dataMap.isEmpty()){
            return this;
        }
        int oldSize = textList.size();
        textList.clear();
        dataList.clear();
        dataMap.forEach((key,value)->{
            textList.add(key);
            dataList.add(value);
        });
        // NumberPicker有坑，不这样处理，会出现下标越界
        if (textList.size()>oldSize){
            binding.dataPickerContent.setDisplayedValues(textList.toArray(new String[0]));
            binding.dataPickerContent.setMinValue(0);
            binding.dataPickerContent.setMaxValue(textList.size()-1);
        }else {
            binding.dataPickerContent.setMinValue(0);
            binding.dataPickerContent.setMaxValue(textList.size()-1);
            binding.dataPickerContent.setDisplayedValues(textList.toArray(new String[0]));
        }
        this.setSelectedIndex(0);
        return this;
    }

    /**
     * 设置当前选中的
     * @param index
     * @return
     */
    public CustomizeDataPicker setSelectedIndex(int index){
        binding.dataPickerContent.setValue(index);
        return this;
    }

    /**
     * 设置监听器
     * @param listener
     * @return
     */
    public CustomizeDataPicker setOnValueChangedListener(OnValueChangeListener  listener){
        this.onValueChangeListener=listener;
        return this;
    }

    /**
     * 循环滚动
     * @param wrapSelectorWheel
     * @return
     */
    public CustomizeDataPicker setWrapSelectorWheel(boolean wrapSelectorWheel){
        this.wrapSelectorWheel=wrapSelectorWheel;
        binding.dataPickerContent.setWrapSelectorWheel(wrapSelectorWheel);
        return this;
    }
    public interface OnValueChangeListener <T>{
        void onValueChange(String titleText,T data,int index);
    }
}
