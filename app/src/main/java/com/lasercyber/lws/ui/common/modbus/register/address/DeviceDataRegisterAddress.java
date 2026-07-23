package com.lasercyber.lws.ui.common.modbus.register.address;

/**
 * 设备数据查询相关Modbus寄存器地址常量类
 * 对应设备数据字段（0060H-007FH），用于Modbus通信时的地址引用
 */
public class DeviceDataRegisterAddress {
    /**
     * 吹气气压寄存器地址（0060H）
     * 单位：kPa
     * 用途：存储设备吹气气压的实时数据
     */
    public static final int BLOWING_PRESSURE = 0x0060; // 原始地址：0060H

    /**
     * 枪头电机温度寄存器地址（0061H）
     * 有符号数  范围(999.0-999.0)
     * 设备扩大 10 倍上传，保留 1 位小数
     * 备注 1：特殊值定义
     * 特殊值：-999.0 代表测温未
     * 连接或错误，不报警
     * 特殊值：200.0 超过测温极限
     * 时温度显示为 200 度，此时
     * 会报警
     * 单位：℃
     */
    public static final int GUN_MOTOR_CURRENT = 0x0061; // 原始地址：0061H

    /**
     * 字段：枪头电机驱动温度
     * 单位：℃
     * 备注：有符号数，范围(99.0-999.0)，设备扩大 10 倍上传，保留1位小数；
     * 特殊值-999.0代表测温未连接或错误（不报警）；
     * 特殊值2000.0代表超过测温极限（显示200度，会报警）
     */
    public static final int GUN_MOTOR_DRIVE_TEMPERATURE = 0x0062;
    /**
     * 字段：保护镜温度
     * 单位：℃
     * 备注：有符号数，范围(99.0-999.0)，设备扩大 10 倍上传，保留1位小数；
     * 特殊值-999.0代表测温未连接或错误（不报警）；
     * 特殊值2000.0代表超过测温极限（显示200度，会报警）
     */
    public static final int PROTECTIVE_COVER_TEMPERATURE = 0x0063;

    /**
     * 字段：聚焦镜温度
     * 单位：℃
     * 备注：有符号数，范围(99.0-999.0)，设备扩大 10 倍上传，保留1位小数；
     * 特殊值-999.0代表测温未连接或错误（不报警）；
     * 特殊值2000.0代表超过测温极限（显示200度，会报警）
     */
    public static final int COLLIMATOR_TEMPERATURE = 0x0064;

    /**
     * 字段：枪头24V电压
     * 单位：V
     * 备注：范围0-36V
     */
    public static final int GUN_HEAD_24V_VOLTAGE = 0x0065;

    /**
     * 字段：枪头24V电流
     * 单位：mA
     * 备注：范围0-2000mA
     */
    public static final int GUN_HEAD_24V_CURRENT = 0x0066;

    /**
     * 字段：预留寄存器（0067H-006BH）
     * 说明：连续5个预留地址，此处定义起始地址
     */
    @Deprecated
    public static final int RESERVED_START = 0x0067;
    @Deprecated
    public static final int RESERVED_END = 0x006B; // 预留地址结束

    /**
     * 字段：激光反馈功率
     * 说明：无额外备注（表格未提供更多信息）
     * 单位：0.1w
     */
    public static final int LASER_FEEDBACK_POWER = 0x006C;
    /**
     * 泵源板温度，对应内存地址：006DH
     */
    public static final int PUMP_SOURCE_BOARD_TEMPERATURE = 0x006D;

    /**
     * 泵源温度，对应内存地址：006EH
     */
    public static final int PUMP_SOURCE_TEMPERATURE = 0x006E;

    /**
     * 激光器电流，对应内存地址：006FH
     */
    public static final int LASER_CURRENT = 0x006F;

    /**
     * 激光器红光电流，对应内存地址：0070H
     */
    public static final int LASER_RED_LIGHT_CURRENT = 0x0070;

    /**
     * 泵源电流，对应内存地址：0071H
     *
     * @deprecated 请使用 {@link #LASER_CURRENT}（0x006F）；本寄存器读数不再用于 HMI / 远程监测。
     */
    @Deprecated
    public static final int PUMP_SOURCE_CURRENT = 0x0071;

    /**
     * 环境温度，对应内存地址：0072H
     */
    public static final int AMBIENT_TEMPERATURE = 0x0072;
}