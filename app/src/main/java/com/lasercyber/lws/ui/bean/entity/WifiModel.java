package com.lasercyber.lws.ui.bean.entity;

import lombok.Data;

@Data
public class WifiModel {
    private String ssid;       // WiFi名称
    private String bssid;
    private String capabilities;
    private boolean isConnected; // 是否连接
    private boolean isEncrypted; // 是否加密
    private int mWifiStandard;
    private int rssi;          // 信号强度

    public WifiModel(String ssid,String bssid,String capabilities, boolean isConnected, boolean isEncrypted, int rssi,int mWifiStandard) {
        this.ssid = ssid;
        this.bssid = bssid;
        this.capabilities = capabilities;
        this.isConnected = isConnected;
        this.isEncrypted = isEncrypted;
        this.mWifiStandard = mWifiStandard;
        this.rssi = rssi;
    }

}
