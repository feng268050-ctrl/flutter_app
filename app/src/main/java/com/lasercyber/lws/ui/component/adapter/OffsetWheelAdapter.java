package com.lasercyber.lws.ui.component.adapter;


import android.content.Context;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.blankj.utilcode.util.SizeUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.ui.WheelViewItem;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.component.config.OffsetWheelConfig;
import com.lasercyber.lws.ui.component.wheelview.adapter.BaseWheelAdapter;
import com.lasercyber.lws.ui.component.wheelview.adapter.WheelViewRender;

import lombok.Setter;


public class OffsetWheelAdapter extends BaseWheelAdapter<WheelViewItem> implements WheelViewRender {
    private static final String TAG = LogTAGConstant.OffsetWheelAdapter;
    private Context mContext;
    // 是否在初始化中
    private volatile boolean isInit = true;
    @Setter
    private boolean DEBUG = false;
    /**
     * 偏移方向,-1不偏移,0:左偏移,1:右偏移
     */
    private final OffsetWheelConfig offsetWheelConfig;
    @Setter
    private volatile float animationFactor = 0.25f; // 动画衰减因子（0-1），越小越丝滑
    private static final int MIN_PADDING_DIFF = 1;      // 最小差值阈值，避免无效刷新
    private static final int FINAL_DIFF_THRESHOLD = 3;  // 最终差值阈值，直接收尾

    public OffsetWheelAdapter(Context context,OffsetWheelConfig offsetWheelConfig) {
        this.mContext = context;
        this.offsetWheelConfig = offsetWheelConfig;
    }

    @Override
    public void setCurrentPosition(int position) {
        super.setCurrentPosition(position);
//        Log.d(TAG, "setCurrentPosition: 当前选中:" + position);
    }

    @Override
    protected View bindView(int position, View convertView, ViewGroup parent) {
        WheelViewItem wheelViewItem = super.mList.get(position);
        if (convertView == null) {
            convertView = LayoutInflater.from(this.mContext).inflate(R.layout.item_offset_wheel, parent, false);
            wheelViewItem.setPosition(position);
            convertView.setTag(R.id.offset_wheel_view_data_tag, wheelViewItem);
            if (offsetWheelConfig.isRightOffset()){
                // 右偏移
                ((LinearLayout) convertView).setGravity(Gravity.START);
            }else if (offsetWheelConfig.isLeftOffset()){
                ((LinearLayout) convertView).setGravity(Gravity.END);
            }
            if (offsetWheelConfig.getWheelBackgroundRes()>0){
                convertView.setBackgroundResource(offsetWheelConfig.getWheelBackgroundRes());
            }
            ViewGroup.LayoutParams layoutParams = convertView.getLayoutParams();
            layoutParams.width = SizeUtils.dp2px(offsetWheelConfig.getWheelWidth());
            convertView.setLayoutParams(layoutParams);
            LinearLayout wheelTextContent = convertView.findViewById(R.id.wheel_text_content);
            ViewGroup.LayoutParams contentLayoutParams = wheelTextContent.getLayoutParams();
            contentLayoutParams.height = SizeUtils.dp2px(offsetWheelConfig.getWheelHeight());
        }
        TextView textView = convertView.findViewById(R.id.offset_wheel_text);
        textView.setText(wheelViewItem.getText());
        if (DEBUG)
            Log.d(TAG, "bindView: 正在渲染:" + position + "," + wheelViewItem.getText() + "当前选中:" + getMCurrentPositon());
        return convertView;
    }

    /**
     * 刷新Item视图
     * @param position 目标位置
     * @param curPosition 当前选中位置
     * @param itemView 列表Item视图
     * @param wellSelect 选中状态标识
     */
    @Override
    public void refreshItemView(int position, int curPosition, View itemView, int wellSelect) {
        // ========== 关键1：优先用ViewHolder缓存View（必须做，否则findViewById会卡顿） ==========
        WheelViewHolder holder = (WheelViewHolder) itemView.getTag(R.id.offset_wheel_view_holder_tag);
        if (holder == null) {
            holder = new WheelViewHolder(itemView);
            itemView.setTag(R.id.offset_wheel_view_holder_tag, holder);
        }
        View wheelTextView = holder.wheelTextView;
        TextView textView = holder.textView;
        WheelViewItem wheelViewItem = (WheelViewItem) itemView.getTag(R.id.offset_wheel_view_data_tag);
        wheelTextView.setBackgroundResource(android.R.color.transparent);

        // ========== 关键3：缓存目标Padding值，避免重复计算 ==========
        int targetLeft = 0;
        int targetRight = 0;
        int targetTop = wheelTextView.getPaddingTop();
        int targetBottom = wheelTextView.getPaddingBottom();

        if (position == curPosition) {
            // 选中状态
            if (wheelViewItem.getBackGroundRes() > 0) {
                wheelTextView.setBackgroundResource(wheelViewItem.getBackGroundRes());
            }
            int targetPadding = SizeUtils.dp2px(offsetWheelConfig.getSelectedTextMarginBottomTop());
            targetLeft = targetPadding;
            targetRight = targetPadding;

            // 文本样式一次性设置（无动画，减少开销）
            textView.setTextSize(offsetWheelConfig.getSelectedTextSize());
            textView.setAlpha(offsetWheelConfig.getSelectedTextAlpha());
        } else {
            // 未选中状态
            int textOffset = offsetWheelConfig.getUnSelectedTextOffset().getUnSelectedTextOffset(wheelViewItem, wellSelect);
            targetLeft = offsetWheelConfig.isRightOffset() ? textOffset : 0;
            targetRight = offsetWheelConfig.isLeftOffset() ? textOffset : 0;

            // 文本样式一次性设置
            textView.setTextSize(offsetWheelConfig.getUnSelectedTextSize());
            float unSelectedTextAlpha = offsetWheelConfig.getUnSelectedTextAlpha().getUnSelectedTextAlpha(wheelViewItem, curPosition);
            textView.setAlpha(unSelectedTextAlpha);
        }

        // ========== 关键4：优化版轻量化插值Padding（更丝滑的过渡效果） ==========
        // 获取当前Padding（避免频繁调用getPaddingX，减少View调用开销）
        int currentLeft = wheelTextView.getPaddingLeft();
        int currentRight = wheelTextView.getPaddingRight();

        // 计算差值
        int diffLeft = targetLeft - currentLeft;
        int diffRight = targetRight - currentRight;

        // 阈值判断：仅当差值>最小阈值时才更新
        if (Math.abs(diffLeft) > MIN_PADDING_DIFF || Math.abs(diffRight) > MIN_PADDING_DIFF) {
            int newLeft = currentLeft;
            int newRight = currentRight;

            if (!isInit) {
                // 优化1：使用衰减因子做平滑插值，模拟物理减速效果
                newLeft = currentLeft + Math.round(diffLeft * animationFactor);
                newRight = currentRight + Math.round(diffRight * animationFactor);

                // 优化2：更合理的兜底逻辑，差值小于阈值时直接设置目标值
                if (Math.abs(targetLeft - newLeft) <= FINAL_DIFF_THRESHOLD) {
                    newLeft = targetLeft;
                }
                if (Math.abs(targetRight - newRight) <= FINAL_DIFF_THRESHOLD) {
                    newRight = targetRight;
                }

                if (DEBUG)
                    Log.d(TAG, "refreshItemView: 使用平滑动画，diffLeft=" + diffLeft + ", newLeft=" + newLeft);
            } else {
                // 初始化时直接设置目标值
                newLeft = targetLeft;
                newRight = targetRight;
                if (DEBUG) Log.d(TAG, "refreshItemView: 初始化直接设置目标值");
            }

            // 核心：一次性设置Padding，仅触发1次重绘
            wheelTextView.setPadding(newLeft, targetTop, newRight, targetBottom);
        }
    }
    public void startInit() {
        isInit = true;
        if (DEBUG) Log.d(TAG, "startInit: 正在初始化");
    }

    public void endInit() {
        isInit = false;
        if (DEBUG) Log.d(TAG, "endInit: 正在结束初始化");
    }

    @Override
    public void updateDataViewBefore() {
        super.updateDataViewBefore();
        // 动态调节动画因子
        if (super.mList == null || super.mList.size() <= 7) {
            animationFactor = 0.25f;
        } else {
            animationFactor = 0.6f;
        }
    }

    static class WheelViewHolder {
        View wheelTextView;
        TextView textView;

        WheelViewHolder(View itemView) {
            wheelTextView = itemView.findViewById(R.id.wheel_text_content);
            textView = wheelTextView.findViewById(R.id.offset_wheel_text);
        }
    }
}
