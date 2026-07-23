package com.lasercyber.lws.ui.activitys.other.adapter;

import android.graphics.Color;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.BluetoothDeviceModel;

import java.util.List;

public class BluetoothDeviceAdapter extends RecyclerView.Adapter<BluetoothDeviceAdapter.DeviceViewHolder> {
    private List<BluetoothDeviceModel> deviceList;
    private OnDeviceClickListener listener;

    // 设备点击事件接口
    public interface OnDeviceClickListener {
        void onDeviceClick(BluetoothDeviceModel device,Boolean close);
    }

    public BluetoothDeviceAdapter(List<BluetoothDeviceModel> deviceList, OnDeviceClickListener listener) {
        this.deviceList = deviceList;
        this.listener = listener;
    }

    @NonNull
    @Override
    public DeviceViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_bluetooth_device, parent, false);
        return new DeviceViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull DeviceViewHolder holder, int position) {
        BluetoothDeviceModel device = deviceList.get(position);
        // 设置设备名称
        holder.tvDeviceName.setText(device.getDeviceName());
        // 设置连接状态
        holder.tvConnectState.setText(device.isConnected() ? "Connected" : "Not connected");
        holder.tvConnectState.setTextColor( device.isConnected() ? Color.parseColor("#00BF60") : Color.parseColor("#94A3B8"));
        // 点击事件
        holder.itemView.setOnClickListener(v -> listener.onDeviceClick(device,false));
    }

    @Override
    public int getItemCount() {
        return deviceList.size();
    }

    // 更新设备列表
    public void updateDevices(List<BluetoothDeviceModel> newDevices) {
        deviceList.clear();
        deviceList.addAll(newDevices);
        notifyDataSetChanged();
    }

    // 更新单个设备的状态（配对/连接）
    public void updateDeviceStatus(BluetoothDeviceModel updatedDevice) {
        int index = 0;
        for (BluetoothDeviceModel dev : deviceList) {
            if(dev.getDeviceAddress().equals(updatedDevice.getDeviceAddress())){
                break;
            }
            index++;
        }
        if (index != -1) {
            deviceList.set(index, updatedDevice);
            notifyItemChanged(index);
        }
    }
    // ViewHolder
    static class DeviceViewHolder extends RecyclerView.ViewHolder {
        TextView tvDeviceName, tvConnectState;

        public DeviceViewHolder(@NonNull View itemView) {
            super(itemView);
            tvDeviceName = itemView.findViewById(R.id.tv_device_name);
            tvConnectState = itemView.findViewById(R.id.tv_connect_state);
        }
    }
}