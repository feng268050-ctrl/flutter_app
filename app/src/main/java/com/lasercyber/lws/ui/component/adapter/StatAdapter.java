package com.lasercyber.lws.ui.component.adapter;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.recyclerview.widget.RecyclerView;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.utils.bean.StatItem;
import com.lasercyber.lws.ui.common.view.RingProgressView;
import com.lasercyber.lws.frostui.border.BorderGradientCenter;
import com.lasercyber.lws.frostui.card.interop.FrostCardView;

import java.util.List;

import cn.hutool.core.convert.Convert;

public class StatAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    private List<StatItem> itemList;
    private Context context;

    public StatAdapter(Context context, List<StatItem> itemList) {
        this.context = context;
        this.itemList = itemList;
    }

    @Override
    public int getItemViewType(int position) {
        return itemList.get(position).getType();
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        LayoutInflater inflater = LayoutInflater.from(context);
        if (viewType == StatItem.TYPE_RING) {
            View view = inflater.inflate(R.layout.item_ring, parent, false);
            return new RingViewHolder(view);
        } else {
            View view = inflater.inflate(R.layout.item_data, parent, false);
            return new DataViewHolder(view);
        }
    }


    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        StatItem item = itemList.get(position);
        if (holder.itemView instanceof FrostCardView cardView) {
            cardView.setBorderGradientCenter(borderGradientForColumn(position));
        }
        if (holder instanceof RingViewHolder) {

            RingViewHolder ringHolder = (RingViewHolder) holder;
            ringHolder.tvTitle.setText(item.getTitle());
            ringHolder.tvPercent.setText(item.getValue() + "%");

            // 设置进度（去掉%符号转float）
            ringHolder.ringView.setProgress( Convert.toFloat(item.getValue()) );
            ringHolder.ringView.setForegroundColor(item.getColor());

        } else if (holder instanceof DataViewHolder) {
            DataViewHolder dataHolder = (DataViewHolder) holder;
            dataHolder.tvTitle.setText(item.getTitle());
            dataHolder.tvValue.setText(item.getValue());
            dataHolder.info.setText( item.getInfo() );
        }
    }

    @Override
    public int getItemCount() {
        return itemList.size();
    }

    /** Column 0/1/2 in the 3-column grid: bottom-left-top-right, top-bottom, top-left-bottom-right. */
    private static BorderGradientCenter borderGradientForColumn(int position) {
        switch (position % 3) {
            case 0:
                return BorderGradientCenter.BOTTOM_LEFT_TOP_RIGHT;
            case 1:
                return BorderGradientCenter.TOP_BOTTOM;
            case 2:
            default:
                return BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT;
        }
    }

    // 环形卡片ViewHolder
    static class RingViewHolder extends RecyclerView.ViewHolder {
        TextView tvTitle, tvPercent;
        RingProgressView ringView;

        public RingViewHolder(View itemView) {
            super(itemView);
            tvTitle = itemView.findViewById(R.id.tv_title);
            tvPercent = itemView.findViewById(R.id.tv_percent);
            ringView = itemView.findViewById(R.id.ring_view);
        }
    }

    // 数据卡片ViewHolder
    static class DataViewHolder extends RecyclerView.ViewHolder {
        TextView tvTitle, tvValue, info;

        public DataViewHolder(View itemView) {
            super(itemView);
            tvTitle = itemView.findViewById(R.id.tv_title);
            tvValue = itemView.findViewById(R.id.tv_value);
            info = itemView.findViewById(R.id.info);
        }
    }
}