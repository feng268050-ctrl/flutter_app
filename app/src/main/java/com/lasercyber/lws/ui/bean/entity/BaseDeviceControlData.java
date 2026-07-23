package com.lasercyber.lws.ui.bean.entity;

import lombok.Data;
import lombok.experimental.Accessors;


@Data
@Accessors(chain = true)
public class BaseDeviceControlData {
    /**
     * 激光器型号
     */
    private int laserDeviceType;
    /**
     * 枪头型号
     */
    private int gunDeviceType;
    /**
     * 送丝机型号
     */
    private int wireFeedDeviceType;
    /**
     * 枪头驱动类型
     */
    private int gunDriveType;
    /**
     * 枪头摆动范围模式
     */
    @Deprecated
    private int gunSwingRangeMode;
    /**
     * 模式
     * 0: 连续焊接 1：点焊接 2：焊道清洗 3：宽幅清洗 4：手持切割
     */
    private int model;
}
