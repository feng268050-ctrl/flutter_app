package com.lasercyber.lws.ui.bean.entity;

import lombok.Data;

@Data
public class BluetoothDeviceModel {
    private String deviceName;   // 设备名称
    private String deviceAddress;// 设备唯一地址（MAC）
    private boolean isConnected; // 是否已连接
    private boolean isPaired;    // 是否已配对

    public BluetoothDeviceModel(String deviceName, String deviceAddress, boolean isConnected, boolean isPaired) {
        this.deviceName = deviceName;
        this.deviceAddress = deviceAddress;
        this.isConnected = isConnected;
        this.isPaired = isPaired;
    }

}