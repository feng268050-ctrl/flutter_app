package com.lasercyber.lws.ui.common.modbus.register.address;

/**
 * 设置参数相关Modbus寄存器地址常量类
 * 对应设置参数字段（0090H-009FH），用于Modbus通信时的地址引用
 */
public class DeviceSettingRegisterAddress {
    /**
     * 零点校正寄存器地址（0090H）
     * 用途：存储零点校正的设置参数
     */
    public static final int ZERO_POINT_CORRECTION = 0x0090; // 原始地址：0090H

    /**
     * 摆宽校正寄存器地址（0091H）
     * 备注：有符号类型（最高位为符号位，0-正数 1-负数）
     * 用途：存储摆宽校正的设置参数
     */
    public static final int SWING_WIDTH_CORRECTION = 0x0091; // 原始地址：0091H

    /**
     * 激光起始功率寄存器地址（0092H）
     * 范围：0-100，单位：%
     * 用途：存储激光起始功率的设置参数
     */
    public static final int LASER_START_POWER = 0x0092; // 原始地址：0092H

    /**
     * 激光终止功率寄存器地址（0093H）
     * 范围：0-100，单位：%
     * 用途：存储激光终止功率的设置参数
     */
    public static final int LASER_END_POWER = 0x0093; // 原始地址：0093H

    /**
     * 吹气气压阈值寄存器地址（0094H）
     * 单位：kPa
     * 用途：存储吹气气压阈值的设置参数
     */
    public static final int BLOWING_PRESSURE_THRESHOLD = 0x0094; // 原始地址：0094H

    /**
     * 红光偏移寄存器地址（0095H）
     * 用途：存储红光偏移的设置参数
     */
    public static final int RED_LIGHT_OFFSET = 0x0095; // 原始地址：0095H

    /**
     * 摆速区间上限寄存器地址（0096H）
     * 用途：存储摆速区间上限的设置参数
     */
    public static final int SWING_SPEED_UPPER_LIMIT = 0x0096; // 原始地址：0096H

    /**
     * 摆速区间下限寄存器地址（0097H）
     * 用途：存储摆速区间下限的设置参数
     */
    public static final int SWING_SPEED_LOWER_LIMIT = 0x0097; // 原始地址：0097H
    /**
     * 手动送丝速度 0098H
     * 范围（1-80）单位（mm/s）
     */
    public static final int MANUAL_WIRE_FEED_SPEED = 0x0098;
    /**
     * 手动抽丝速度 0099H
     * 范围（1-80）单位（mm/s）
     */
    public static final int MANUAL_DRAW_STRING_SPEED = 0x0099;
    /**
     * 进气气压阈值 009AH
     * 单位：kPa
     */
    public static final int INLET_GAS_PRESSURE_THRESHOLD = 0x009A;
    /**
     * 驱动器温度报警阈值 009BH
     * 默认：70；单位：°C
     * 范围：0.0~80.0 
     * 备注 0：保留 1 位小数，Modbus 下发时 *10 按整数下发
     * 备注 1:设置 0 时，报警屏蔽。 
     * 备注 2:设置非 0 时，根据设定的阈值进行检测，温度下降“温度报警恢复差值”度（默认 5 度）后，自动取消报警。
     */
    public static final int DRIVER_TEMPERATURE_ALARM_THRESHOLD = 0x009B;
    /**
     * 保护镜温度报警阈值 009CH
     * 默认：70；单位：°C
     * 范围：0.0～85.0
     * 备注 0：保留 1 位小数，Modbus 下发时 *10 按整数下发
     * 备注 1：设置 0 时不报警
     * 备注 2:设置非 0 时，根据设定的阈值进行检测，温度下降“温度报警恢复差值”度（默认 5 度）后，自动取消报警。
     */
    public static final int PROTECTIVE_LENS_TEMPERATURE_ALARM_THRESHOLD = 0x009C;
    /**
     * 聚焦镜温度报警阈值 009DH
     * 默认：65；单位：°C
     * 范围：0.0～85.0
     * 备注 0：保留 1 位小数，Modbus 下发时 *10 按整数下发
     * 备注 1：设置 0 时不报警
     * 备注 2:设置非 0 时，根据设定的阈值进行检测，温度下降“温度报警恢复差值”度（默认 5 度）后，自动取消报警。
     */
    public static final int COLLIMATING_LENS_TEMPERATURE_ALARM_THRESHOLD = 0x009D;
    /**
     * 电机温度报警阈值 009EH
     * 默认：70；单位：°C
     * 范围：0.0～80.0
     * 备注 0：保留 1 位小数，Modbus 下发时 *10 按整数下发
     * 备注 1：设置 0 时不报警
     * 备注 2:设置非 0 时，根据设定的阈值进行检测，温度下降“温度报警恢复差值”度（默认 5 度）后，自动取消报警。
     */
    public static final int MOTOR_TEMPERATURE_ALARM_THRESHOLD = 0x009E;
    /**
     * 温度报警恢复差值 009FH
     * 默认：5；单位：°C
     * 备注 0：保留 1 位小数，Modbus 下发时 *10 按整数下发
     * 备注 1：默认温度恢复为报警阈值 5 度以下取消报警，所有温度报警都用这个参数
     */
    public static final int TEMPERATURE_ALARM_RECOVERY_INTERVAL = 0x009F;
}