package com.lasercyber.lws.ui.component;

import android.content.Context;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.AttributeSet;
import android.util.Log;
import android.widget.EditText;
import android.widget.NumberPicker;
import android.widget.RelativeLayout;
import android.widget.TextView;

import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

import lombok.Setter;

public class InputNumberPicker extends RelativeLayout {
    private static final String TAG = LogTAGConstant.InputNumberPicker;
    private NumberPicker mNumberPicker;
    private EditText mEtInput;
    private TextView suffixTextView;

    private List<String> mItems; // 自定义选项列表
    @Setter
    private OnDataChangeListener onDataChangeListener;
    /**
     * 后缀文字
     */
    private String suffixText;

    /**
     * 数据变化
     */
    public interface OnDataChangeListener {
        void onChange(String data,int position);
    }


    public InputNumberPicker(Context context) {
        super(context);
        initView(context);
    }

    public InputNumberPicker(Context context, AttributeSet attrs) {
        super(context, attrs);
        initView(context);
    }

    public InputNumberPicker(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        initView(context);
    }

    private void initView(Context context) {
        inflate(context, R.layout.input_number_picker, this);
        mNumberPicker = findViewById(R.id.number_picker);
        mEtInput = findViewById(R.id.et_input);
        suffixTextView= findViewById(R.id.suffix_text_view);

        mItems = new ArrayList<>();

        mNumberPicker.setWrapSelectorWheel(false);
        mNumberPicker.setDescendantFocusability(NumberPicker.FOCUS_BLOCK_DESCENDANTS);

        mNumberPicker.setOnValueChangedListener((picker, oldVal, newVal) -> {
            if (newVal >= 0 && newVal < mItems.size()) {
                String textData = mItems.get(newVal);
//                if (Objects.equals(textData,mEtInput.getText().toString())){
//                    return;
//                }
                if (!StringUtils.isEmpty(suffixText)){
//                    textData+=suffixText;
                    textData=textData.replace(suffixText,"");
                }
                setEditInputText(textData.trim());
                mEtInput.setSelection(mEtInput.getText().length());
                callBack(mItems.get(newVal),newVal);
            }
        });

        mEtInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                if (StringUtils.isEmpty(s)){
                    callBack("",-1);
                    return;
                }
                String textData=s.toString();
                if (!StringUtils.isEmpty(suffixText)){
                    textData+=suffixText;
                }
                int index=-1;
                for (int i = 0; i < mItems.size(); i++) {
                    if (Objects.equals(mItems.get(i),textData)){
                        mNumberPicker.invalidate();
                        mNumberPicker.setValue(i);
                        index=i;
                        break;
                    }
                }
                callBack(textData,index);
            }

            @Override
            public void afterTextChanged(Editable s) {}
        });
    }

    /**
     * 设置自定义选项列表
     */
    public void setItems(List<String> items) {
        if (items == null || items.isEmpty()) {
            return;
        }
        mItems.clear();
        mItems.addAll(items);

        // 设置NumberPicker的范围
        mNumberPicker.setMinValue(0);
        mNumberPicker.setMaxValue(items.size() - 1);

        // 设置自定义格式化器，显示自定义文本
        mNumberPicker.setFormatter(value -> {
            if (value >= 0 && value < mItems.size()) {
                return mItems.get(value);
            }
            return "";
        });

        // 刷新显示
        updateNumberPickerDisplay();
    }

    /**
     * 更新NumberPicker显示（解决setFormatter不立即生效的问题）
     */
    private void updateNumberPickerDisplay() {
        // 触发NumberPicker重新绘制
        mNumberPicker.invalidate();
        // 可选：重新设置值，强制刷新
//        int currentValue = mNumberPicker.getValue();
//        mNumberPicker.setValue(currentValue);
        mNumberPicker.setValue(0);
        setEditInputText(mItems.get(0));
    }

    /**
     * 设置数据
     * @param textData
     */
    private void setEditInputText(String textData){
        if (StringUtils.isEmpty(textData)){
            textData="";
        }
        if (!StringUtils.isEmpty(suffixText)){
            textData=textData.replace(suffixText,"").trim();
        }
        Log.d(TAG, "更新到输入框的数据:"+textData);
        mEtInput.setText(textData.trim());
    }
    /**
     * 获取当前选中项
     */
    public String getSelectedItem() {
        int selectedPos = mNumberPicker.getValue();
        if (selectedPos >= 0 && selectedPos < mItems.size()) {
            return mItems.get(selectedPos);
        }
        return "";
    }

    /**
     * 获取当前选中项位置
     */
    public int getSelectedPosition() {
        return mNumberPicker.getValue();
    }

    /**
     * 设置选中项
     */
    public void setSelectedPosition(int position) {
        if (position >= 0 && position < mItems.size()) {
            mNumberPicker.setValue(position);
        }
    }

    /**
     * 设置后缀
     * @param suffixText
     */
    public void setSuffixText(String suffixText){
        this.suffixText = suffixText;
        suffixTextView.setText(suffixText);
    }

    /**
     * 回调
     * @param data
     * @param position
     */
    public void callBack(String data,int position){
        if (onDataChangeListener==null){
            return;
        }
        onDataChangeListener.onChange(data,position);
    }

    /**
     * 获取输入的数据
     * @return
     */
    public String getInputData(){
        Editable editable = mEtInput.getText();
        if (editable==null){
            return  "";
        }
        String textData = editable.toString();
        if (!StringUtils.isEmpty(suffixText)){
            return textData.replace(suffixText,"").trim();
        }
        return textData.trim();
    }
}
