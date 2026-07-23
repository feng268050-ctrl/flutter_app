package com.lasercyber.lws.ui.common.utils;

import com.lasercyber.lws.ui.bean.entity.DeviceControlData;

/**
 * 设备控制工具类
 */
public class DeviceControlUtils {
    /**
     * 创建打开送丝的配置
     * @return
     */
    public static DeviceControlData createOpenFeedConfig(DeviceControlData oldData){
        DeviceControlData deviceControlData = new DeviceControlData();
        deviceControlData.setLaserStatus(0);
        deviceControlData.setManualGas(0);
        deviceControlData.setWireFeedEnable(1);
        deviceControlData.setWireFeedDirection(0);
        if (oldData!=null){
            deviceControlData.setManualGas(oldData.getManualGas());
            deviceControlData.setAutoWireFeedEnable(oldData.getAutoWireFeedEnable());
        }
        return deviceControlData;
    }
    /**
     * 创建关闭送丝、退丝的配置
     * @return
     */
    public static DeviceControlData createCloseFeedOrBackConfig(DeviceControlData oldData){
        DeviceControlData openFeedConfig = createOpenFeedConfig(oldData);
        openFeedConfig.setWireFeedEnable(0);
        return openFeedConfig;
    }
    /**
     * 创建手动送气配置
     */
    public static DeviceControlData createOpenManualGasConfig(){
        DeviceControlData deviceControlData = new DeviceControlData();
        deviceControlData.setLaserStatus(0);
        deviceControlData.setManualGas(1);
        deviceControlData.setWireFeedEnable(0);
        return deviceControlData;
    }
    /**
     * 创建关闭手动送气配置
     */
    public static DeviceControlData createCloseManualGasConfig(){
        DeviceControlData deviceControlData = createOpenManualGasConfig();
        deviceControlData.setManualGas(0);
        return deviceControlData;
    }
    /**
     * 创建退丝的配置
     */
    public static DeviceControlData createBackFeedConfig(DeviceControlData oldData){
        DeviceControlData deviceControlData = createOpenFeedConfig(oldData);
        deviceControlData.setWireFeedDirection(1);
        return deviceControlData;
    }
    /**
     * 创建开启激光
     */
    public static DeviceControlData createOpenLaserConfig(DeviceControlData deviceControlData){
        deviceControlData.setLaserStatus(1);
        deviceControlData.setManualGas(0);
        deviceControlData.setWireFeedEnable(0);
        return deviceControlData;
    }
    /**
     * 创建关闭激光
     */
    public static DeviceControlData createCloseLaserConfig(DeviceControlData deviceControlData){
         createOpenLaserConfig(deviceControlData);
        deviceControlData.setLaserStatus(0);
        return deviceControlData;
    }
}
