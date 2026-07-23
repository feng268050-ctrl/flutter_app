package com.lasercyber.lws.ui.component;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.PopupWindow;
import android.widget.TextView;

import androidx.core.content.ContextCompat;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.util.List;

public class SpinnerDropDownPopup extends PopupWindow {
    private static final String TAG = LogTAGConstant.SpinnerDropDownPopup;
    private Context mContext;
    private View mContentView;
    private TextView masterTitleText;
    private TextView secondTitleText;
    private TextView popupDescText;
    //    private ImageButton mIbClose;
    private FrameLayout mFlContent;
    private OnSpinnerListener mOnSpinnerListener;
    private int suffixTextId=-1;
    /**
     * 输入的数据
     */
    private String inputData;
    private InputNumberPicker numberPicker;


    // 监听器接口
    public interface OnSpinnerListener extends InputNumberPicker.OnDataChangeListener {
        @Override
        default void onChange(String data, int position){
        }

        /**
         * 关闭弹窗之前回调
         *
         * @return
         */
        boolean closeBefore(String inputData);
    }

    public SpinnerDropDownPopup(Context context) {
        super(context);
        mContext = context;
        initView();
        initPopup();
    }

    private void initView() {
        // 加载布局
        mContentView = LayoutInflater.from(mContext).inflate(R.layout.popup_spinner_dropdown, null);
        masterTitleText = mContentView.findViewById(R.id.spinner_popup_master_title);
        secondTitleText = mContentView.findViewById(R.id.spinner_popup_second_title);
        popupDescText = mContentView.findViewById(R.id.popup_desc);
//        mIbClose = mContentView.findViewById(R.id.ib_close);
        mFlContent = mContentView.findViewById(R.id.fl_content);

        // 可选：添加内容区域触摸拦截，避免内容区域点击导致弹窗关闭
        mFlContent.setOnTouchListener((v, event) -> {
            // 消费触摸事件，不向下传递（防止内容区域点击关闭弹窗）
            return true;
        });
    }

    private void initPopup() {
        // 设置弹窗属性
        setContentView(mContentView);
        setWidth(ViewGroup.LayoutParams.MATCH_PARENT); // 默认宽度匹配父布局
        setHeight(ViewGroup.LayoutParams.WRAP_CONTENT); // 高度包裹内容
        setFocusable(true); // 允许获取焦点（输入框需要）
        setOutsideTouchable(true); // 关键：允许外部触摸关闭
        // 关键：设置透明背景（必须非空，否则外部触摸无效）
        setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
        setAnimationStyle(R.style.PopupAnimation); // 设置动画

        // 可选：添加触摸事件监听，进一步确保外部触摸关闭
        setTouchInterceptor((v, event) -> {
            if (event.getAction() == MotionEvent.ACTION_OUTSIDE) {
                // 触摸事件发生在弹窗外部，关闭弹窗
                this.dismiss();
                return true;
            }
            // 触摸事件在弹窗内部，不处理
            return false;
        });
    }


    /**
     * 显示弹窗（动态调整位置）
     */
    public void show(View anchorView) {
        // 1. 测量弹窗高度
        mContentView.measure(
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        );
        int popupHeight = mContentView.getMeasuredHeight();

        // 2. 获取屏幕高度
        DisplayMetrics displayMetrics = mContext.getResources().getDisplayMetrics();
        int screenHeight = displayMetrics.heightPixels;

        // 3. 获取按钮在屏幕上的位置和尺寸
        int[] anchorLocation = new int[2];
        anchorView.getLocationOnScreen(anchorLocation);
        int anchorY = anchorLocation[1];
        int anchorHeight = anchorView.getHeight();
        int anchorWidth = anchorView.getWidth();

        // 4. 计算按钮下方的可用空间
        int spaceBelow = screenHeight - (anchorY + anchorHeight);

        // 5. 调整弹窗宽度为按钮宽度
        setWidth(anchorWidth);

        // 6. 动态计算y偏移量
        int yOffset;
        if (spaceBelow >= popupHeight) {
            yOffset = 0; // 下方显示
        } else {
            yOffset = -(anchorHeight + popupHeight); // 上方显示
        }

        // 7. 显示弹窗
        showAsDropDown(anchorView, 0, yOffset);
    }

    /**
     * 显示弹窗（支持自定义x/y偏移量）
     */
    public void show(View anchorView, int xOffset, int yOffsetBase) {
        mContentView.measure(
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        );
        int popupHeight = mContentView.getMeasuredHeight();

        DisplayMetrics displayMetrics = mContext.getResources().getDisplayMetrics();
        int screenHeight = displayMetrics.heightPixels;

        int[] anchorLocation = new int[2];
        anchorView.getLocationOnScreen(anchorLocation);
        int anchorY = anchorLocation[1];
        int anchorHeight = anchorView.getHeight();
        int anchorWidth = anchorView.getWidth();

        int spaceBelow = screenHeight - (anchorY + anchorHeight);

        setWidth(anchorWidth);

        int yOffset;
        if (spaceBelow >= popupHeight) {
            yOffset = yOffsetBase;
        } else {
            yOffset = -(anchorHeight + popupHeight) + yOffsetBase;
        }

        showAsDropDown(anchorView, xOffset, yOffset);
    }

    public SpinnerDropDownPopup setMasterTitle(int titleId) {
        masterTitleText.setText(titleId);
        return this;
    }

    public SpinnerDropDownPopup setSecondTitle(int titleId) {
        secondTitleText.setText(titleId);
        return this;
    }

    /**
     * 设置后缀
     * @param suffixTextId
     * @return
     */
    public SpinnerDropDownPopup setSuffixText(int suffixTextId){
        this.suffixTextId=suffixTextId;
        if (numberPicker!=null){
            numberPicker.setSuffixText(mContext.getString(suffixTextId));
        }
        return this;
    }
    /**
     * 设置副标题颜色
     *
     * @param colorId
     * @return
     */
    public SpinnerDropDownPopup setSecondColor(int colorId) {
        ColorStateList colorStateList = ContextCompat.getColorStateList(mContext, colorId);
        secondTitleText.setTextColor(colorStateList);
        return this;
    }

    /**
     * 设置描述
     *
     * @param descText
     * @return
     */
    public SpinnerDropDownPopup setPopupDesc(String descText) {
        popupDescText.setText(descText);
        return this;
    }

    // 新增方法：设置为NumberPicker模式
    public void setNumberPickerMode(List<String> items, OnSpinnerListener listener) {
        mFlContent.removeAllViews(); // 清空之前的内容
        this.mOnSpinnerListener = listener;
        // 创建自定义NumberPicker
        numberPicker= new InputNumberPicker(mContext);
        numberPicker.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
        ));
        if (this.suffixTextId>=0){
            numberPicker.setSuffixText(mContext.getString(suffixTextId));
        }
        numberPicker.setItems(items); // 设置自定义选项
        // 设置输入变化监听器

        numberPicker.setOnDataChangeListener(new InputNumberPicker.OnDataChangeListener() {
            @Override
            public void onChange(String data, int position) {
                inputData = data;
                if (mOnSpinnerListener != null) {
                    mOnSpinnerListener.onChange(data, position);
                }
            }
        });


        mFlContent.addView(numberPicker);
    }

    @Override
    public void dismiss() {
        Log.d(TAG, "正在关闭弹窗"+this.inputData);
        if (mOnSpinnerListener != null) {
            if (mOnSpinnerListener.closeBefore(this.inputData)) {
                super.dismiss();
            }
        } else {
            super.dismiss();
        }
    }
}
