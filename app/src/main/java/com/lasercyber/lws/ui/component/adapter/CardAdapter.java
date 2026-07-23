package com.lasercyber.lws.ui.component.adapter;

import android.animation.AnimatorSet;
import android.animation.ObjectAnimator;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.ItemTouchHelper;
import androidx.recyclerview.widget.RecyclerView;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.CustomLayout;
import com.lasercyber.lws.ui.bean.entity.vo.CustomLayoutVoid;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.function.Supplier;

public class CardAdapter extends RecyclerView.Adapter<CardAdapter.CardViewHolder> {

    private boolean isDragging = false; // 是否处于拖拽中
    private List<CustomLayoutVoid> tempList; // 拖拽过程中的临时数据
    private Supplier<ItemTouchHelper> touchHelperSupplier;

    public CardAdapter(List<CustomLayoutVoid> data, Supplier<ItemTouchHelper> touchHelperSupplier) {
        this.tempList = data; // 初始化临时列表为原始数据
        this.touchHelperSupplier = touchHelperSupplier;
    }

    // 开始拖拽：初始化临时列表（复制原始数据）
    public void startDragging() {
        if (!isDragging) {
            isDragging = true;
        }
    }

    // 拖拽过程中：交换临时列表数据
    public void swapTempItems(int fromPos, int toPos) {
        if (isDragging) {
            // 关键：先修改数据源（移除原位置，插入新位置）
            CustomLayoutVoid remove = tempList.remove(fromPos);
            tempList.add(toPos, remove);

            // 通知UI更新：触发“移除+插入”动画（中间元素自动后移）
            notifyItemMoved(fromPos, toPos);
        }
    }

    // 松开卡片：确认排序（临时列表替换原始数据）
    public void confirmDrag() {
        if (isDragging) {
            notifyItemRangeChanged(0, tempList.size());
            isDragging = false;
        }
    }


    // 拖拽取消：恢复原始数据
    public void cancelDrag() {
        if (isDragging) {
            notifyItemRangeChanged(0, tempList.size());
            isDragging = false;
        }
    }



    @NonNull
    @Override
    public CardViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_card, parent, false);
        return new CardViewHolder(view,touchHelperSupplier);
    }

    @Override
    public void onBindViewHolder(@NonNull CardViewHolder holder, int position) {
        // 用临时列表显示（拖拽过程中显示临时排序）
        holder.tvTitle.setText(tempList.get(position).getTitle());
        // 前4项用“选中”WebP（实线边框），其余用“未选中”WebP（虚线边框）
        if (position < 4) {
            holder.itemView.setBackgroundResource(R.mipmap.item_car_border_true);
        } else {
            holder.itemView.setBackgroundResource(R.mipmap.item_car_border_false);
        }
    }

    @Override
    public int getItemCount() {
        return tempList.size();
    }


    // 获取当前排序后的卡片列表（用于保存）
    public List<CustomLayoutVoid> getCurrentCardList() {
        return tempList;
    }

    public static class CardViewHolder extends RecyclerView.ViewHolder {
        TextView tvTitle;
        private AnimatorSet currentAnimator;
        private Supplier<ItemTouchHelper> touchHelperSupplier;


        public CardViewHolder(@NonNull View itemView,Supplier<ItemTouchHelper> touchHelperSupplier) {
            super(itemView);
            tvTitle = itemView.findViewById(R.id.tvTitle);
            this.touchHelperSupplier = touchHelperSupplier;
            initTouchListener(); // 按下即拖拽
        }

        // 核心：按下卡片直接触发拖拽（无需长按）
        private void initTouchListener() {
            itemView.setOnTouchListener((v, event) -> {
                if (event.getAction() == MotionEvent.ACTION_DOWN) {
                    ItemTouchHelper touchHelper = touchHelperSupplier.get();
                    if (touchHelper != null) {
                        touchHelper.startDrag(CardViewHolder.this);
                    }
                    return true; // 拦截事件确保拖拽触发
                }
                return false;
            });
        }

        // 拖拽中视觉反馈（放大+半透明）
        public void setDraggingState() {
            if (currentAnimator != null) currentAnimator.cancel();
            currentAnimator = new AnimatorSet();
            currentAnimator.playTogether(
                    ObjectAnimator.ofFloat(itemView, "scaleX", 1.0f, 1.05f),
                    ObjectAnimator.ofFloat(itemView, "scaleY", 1.0f, 1.05f),
                    ObjectAnimator.ofFloat(itemView, "alpha", 1.0f, 0.8f)
            );
            currentAnimator.setDuration(200).start();
        }

        // 松开后恢复视图
        public void resetViewState() {
            if (currentAnimator != null) currentAnimator.cancel();
            itemView.setScaleX(1.0f);
            itemView.setScaleY(1.0f);
            itemView.setAlpha(1.0f);
        }
    }
}