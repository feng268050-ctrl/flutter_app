package com.lasercyber.lws.ui.common.modbus.register.address;

/**
 * 设备信息相关Modbus寄存器地址常量类
 * 对应设备信息字段（0020H-003FH），用于Modbus通信时的地址引用
 */
public class DeviceInfoRegisterAddress {
    /**
     * 字段：激光器硬件版本高
     */
    public static final int LASER_HARDWARE_VERSION_HIGH = 0x0030;
    /**
     *  字段：激光器硬件版本低
     */
    public static final int LASER_HARDWARE_VERSION_LOW= 0x0031;

    /**
     * 字段：激光器软件版本高
     */
    public static final int LASER_SOFTWARE_VERSION_HIGH = 0x0032;
    /**
     * 字段：激光器软件版本低
     */
    public static final int LASER_SOFTWARE_VERSION_LOW = 0x0033;

    /**
     * 字段：送丝机硬件版本
     */
    public static final int WIRE_FEEDER_HARDWARE_VERSION = 0x0034;

    /**
     * 字段：送丝机软件版本
     */
    public static final int WIRE_FEEDER_SOFTWARE_VERSION = 0x0035;

    /**
     * 字段：枪头硬件版本
     */
    public static final int GUN_HEAD_HARDWARE_VERSION = 0x0036;

    /**
     * 字段：枪头软件版本
     */
    public static final int GUN_HEAD_SOFTWARE_VERSION = 0x0037;

    /**
     * 字段：枪头SN高2字节（用于存储枪头序列号的高半部分）
     */
    public static final int GUN_HEAD_SN_HIGH = 0x0038;

    /**
     * 字段：枪头SN低2字节（用于存储枪头序列号的低半部分）
     */
    public static final int GUN_HEAD_SN_LOW = 0x0039;
}