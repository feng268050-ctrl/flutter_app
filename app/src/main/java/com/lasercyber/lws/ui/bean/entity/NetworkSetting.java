package com.lasercyber.lws.ui.bean.entity;

import lombok.Data;

/**
 * 网络设置
 */
@Data
public class NetworkSetting {
    /**
     * 4G网络状态
     */
    private boolean network4G;
    /**
     * WIFI网络状态
     */
    private boolean networkWIFI;
    /**
     * wifi名称
     */
    private String wifiName;
    /**
     * 蓝牙开关
     */
    private boolean bluetooth;
}
