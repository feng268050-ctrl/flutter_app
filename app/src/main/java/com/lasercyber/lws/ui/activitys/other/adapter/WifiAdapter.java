package com.lasercyber.lws.ui.activitys.other.adapter;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.WifiModel;
import com.lasercyber.lws.ui.component.ListSelectionBackgroundUtils;

import java.util.List;

public class WifiAdapter extends RecyclerView.Adapter<WifiAdapter.WifiHolder> {
    private List<WifiModel> wifiList;
    private Context context;
    private OnWifiItemClickListener clickListener; // 点击回调接口

    // 定义点击回调接口
    public interface OnWifiItemClickListener {
        void onWifiClick(WifiModel wifiModel); // 点击WiFi项的回调
    }

    public WifiAdapter(Context context, List<WifiModel> wifiList, OnWifiItemClickListener clickListener) {
        this.context = context;
        this.wifiList = wifiList;
        this.clickListener = clickListener;
    }

    @NonNull
    @Override
    public WifiHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(context).inflate(R.layout.item_wifi, parent, false);
        return new WifiHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull WifiHolder holder, int position) {
        WifiModel model = wifiList.get(position);
        holder.tvSsid.setText(model.getSsid());

        holder.tvStandard.setText(context.getString(R.string.wifi_list_standard_format, model.getMWifiStandard()));
        if (model.isConnected()) {
            holder.ivConnected.setVisibility(View.VISIBLE);
            holder.tvState.setVisibility(View.GONE);
        } else {
            holder.ivConnected.setVisibility(View.INVISIBLE);
            holder.tvState.setVisibility(View.GONE);
        }
        holder.ivLock.setVisibility(model.isEncrypted() ? View.VISIBLE : View.GONE);
        // 信号强度图标
        holder.ivSignal.setImageResource(getSignalIconRes(model.getRssi()));
        holder.divider.setVisibility(position < getItemCount() - 1 ? View.VISIBLE : View.GONE);

        ListSelectionBackgroundUtils.applyPressRipple(
                holder.wifiRow, position, getItemCount(), R.dimen.frost_corner_radius);

        // Click must be on wifi_row: InsetListRow is clickable and would swallow taps on itemView.
        holder.wifiRow.setOnClickListener(v -> {
            if (clickListener != null) {
                clickListener.onWifiClick(model);
            }
        });
    }

    private static int getSignalIconRes(int rssi) {
        if (rssi >= -70) {
            return R.mipmap.wifi_icon;
        }
        if (rssi >= -85) {
            return R.mipmap.wifi_icon_1;
        }
        return R.mipmap.wifi_icon;
    }

    // 刷新数据
    public void updateData(List<WifiModel> newList) {
        wifiList = newList;
        notifyDataSetChanged();
    }

    @Override
    public int getItemCount() { return wifiList.size(); }

    static class WifiHolder extends RecyclerView.ViewHolder {
        View wifiRow;
        TextView tvSsid, tvState, tvStandard;
        ImageView ivConnected, ivLock, ivSignal;
        View divider;

        public WifiHolder(@NonNull View itemView) {
            super(itemView);
            wifiRow = itemView.findViewById(R.id.wifi_row);
            tvSsid = itemView.findViewById(R.id.tv_ssid);
            tvState = itemView.findViewById(R.id.tv_state);
            ivConnected = itemView.findViewById(R.id.iv_connected);
            ivLock = itemView.findViewById(R.id.iv_lock);
            ivSignal = itemView.findViewById(R.id.iv_signal);
            tvStandard = itemView.findViewById(R.id.tv_standard);
            divider = itemView.findViewById(R.id.wifi_row_divider);
        }
    }
}