package com.lasercyber.lws.ui.bean.entity;

import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.experimental.Accessors;

/**
 * 设备控制的数据封装
 */
@EqualsAndHashCode(callSuper = true)
@Data
@Accessors(chain = true)
public class DeviceControlData extends BaseDeviceControlData {
    /**
     * 激光状态 0-关闭 1-使能
     */
    private int laserStatus;
    /**
     * 手动送气 0-关闭 1-使能
     */
    private int manualGas;
    /**
     * 手动送丝工作（0=停止，1=工作）
     */
    private int wireFeedEnable;
    /**
     * 送丝机方向 0-进丝 1-退丝
     */
    private int wireFeedDirection;
    /**
     * 自动送丝使能 0-停止 1-工作
     */
    private int autoWireFeedEnable;

    /**
     * 是否开启激光
     * @return
     */
    public boolean isOpenLaser(){
        return laserStatus == 1;
    }

    /**
     * 是否开启自动送丝
     * @return
     */
    public boolean isOpenAutoWireFeed(){
        return autoWireFeedEnable == 1;
    }

    /**
     * 是否开启了手动送气
     * @return
     */
    public boolean isOpenManualGas(){
        return manualGas == 1;
    }
}
