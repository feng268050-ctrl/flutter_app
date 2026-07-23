package com.lasercyber.lws.ui.common.modbus.register.address;

/**
 * 工艺参数字段相关Modbus寄存器地址常量类
 * 对应工艺参数字段（0060H-007FH），用于Modbus通信时的地址引用
 */
public class DeviceWorkmanshipRegisterAddress {
    /**
     * 激光功率寄存器地址（0060H）
     * 范围：0-100，单位：%
     * 用途：存储激光功率的工艺参数
     */
    public static final int LASER_POWER = 0x0060; // 原始地址：0060H

    /**
     * 激光占空比寄存器地址（0061H）
     * 范围：0-100，单位：%
     * 用途：存储激光占空比的工艺参数
     */
    public static final int LASER_DUTY_CYCLE = 0x0061; // 原始地址：0061H

    /**
     * 激光频率寄存器地址（0062H）
     * 范围：0-5000，单位：Hz
     * 用途：存储激光频率的工艺参数
     */
    public static final int LASER_FREQUENCY = 0x0062; // 原始地址：0062H

    /**
     * 穿孔功率寄存器地址（0063H）
     * 范围：0-100，单位：%
     * 用途：存储穿孔功率的工艺参数
     */
    public static final int PIERCING_POWER = 0x0063; // 原始地址：0063H

    /**
     * 穿孔频率寄存器地址（0064H）
     * 范围：0-5000，单位：Hz
     * 用途：存储穿孔频率的工艺参数
     */
    public static final int PIERCING_FREQUENCY = 0x0064; // 原始地址：0064H

    /**
     * 穿孔占空比寄存器地址（0065H）
     * 范围：0-100，单位：%
     * 用途：存储穿孔占空比的工艺参数
     */
    public static final int PIERCING_DUTY_CYCLE = 0x0065; // 原始地址：0065H

    /**
     * 摆动频率寄存器地址（0066H）
     * 范围：0-220，单位：Hz
     * 用途：存储摆动频率的工艺参数
     */
    public static final int SWING_FREQUENCY = 0x0066; // 原始地址：0066H

    /**
     * 摆动宽度寄存器地址（0067H）
     * 范围：0-60，单位：0.1mm（界面mm值下发前乘10）
     * 用途：存储摆动宽度的工艺参数
     */
    public static final int SWING_WIDTH = 0x0067; // 原始地址：0067H

    /**
     * 送丝速度寄存器地址（0068H）
     * 范围：0-80，单位：mm/s
     * 用途：存储送丝速度的工艺参数
     */
    public static final int WIRE_FEEDING_SPEED = 0x0068; // 原始地址：0068H

    /**
     * 回抽长度寄存器地址（0069H）
     * 范围：0-400，单位：mm
     * 用途：存储回抽长度的工艺参数
     */
    public static final int BACK_DRAW_LENGTH = 0x0069; // 原始地址：0069H

    /**
     * 回抽速度寄存器地址（006AH）
     * 范围：0-300，单位：mm/s
     * 用途：存储回抽速度的工艺参数
     */
    public static final int BACK_DRAW_SPEED = 0x006A; // 原始地址：006AH

    /**
     * 补丝长度寄存器地址（006BH）
     * 范围：0-30，单位：mm
     * 用途：存储补丝长度的工艺参数
     */
    public static final int WIRE_FILLING_LENGTH = 0x006B; // 原始地址：006BH

    /**
     * 补丝延时寄存器地址（006CH）
     * 范围：无明确标注，单位：ms
     * 用途：存储补丝延时的工艺参数
     */
    public static final int WIRE_FILLING_DELAY = 0x006C; // 原始地址：006CH
    /**
     * 送丝延时
     * 范围：0-2000，单位：ms
     */
    public static final int WIRE_FEEDING_DELAY = 0x006D;
    /**
     * 吹气延时寄存器地址（0x006E）
     * 范围：0-2000，单位：ms
     * 用途：存储吹气延时的工艺参数
     */
    public static final int BLOWING_DELAY = 0x006E; // 原始地址：0x006E

    /**
     * 关气延时寄存器地址（0x006F）
     * 范围：0-2000，单位：ms
     * 用途：存储关气延时的工艺参数
     */
    public static final int GAS_OFF_DELAY = 0x006F; // 原始地址：0x006F

    /**
     * 关光延时寄存器地址（0x0070）
     * 范围：0-2000，单位：ms
     * 用途：存储关光延时的工艺参数
     */
    public static final int LIGHT_OFF_DELAY = 0x0070; // 原始地址：0x0070

    /**
     * 功率缓升时长寄存器地址（0x0071）
     * 范围：100-2000，单位：ms
     * 用途：存储功率缓升时长的工艺参数
     */
    public static final int POWER_RAMP_UP_DURATION = 0x0071; // 原始地址：0x0071

    /**
     * 功率缓降时长寄存器地址（0x0072）
     * 范围：100-2000，单位：ms
     * 用途：存储功率缓降时长的工艺参数
     */
    public static final int POWER_RAMP_DOWN_DURATION = 0x0072; // 原始地址：0x0072

    /**
     * 点焊时长寄存器地址（0x0073）
     * 范围：0-10000，单位：ms
     * 用途：存储点焊时长的工艺参数
     */
    public static final int SPOT_WELDING_DURATION = 0x0073; // 原始地址：0x0073

    /**
     * 点焊间隔寄存器地址（0x0074）
     * 范围：0-10000，单位：ms
     * 用途：存储点焊间隔的工艺参数
     */
    public static final int SPOT_WELDING_INTERVAL = 0x0074; // 原始地址：0x0074

    /**
     * 穿孔时长寄存器地址（0x0075）
     * 范围：100-20000，单位：ms
     * 用途：存储穿孔时长的工艺参数
     */
    public static final int PIERCING_DURATION = 0x0075; // 原始地址：0x0075
    public static final int RESERVED_SEGMENT_START = 0x0076;
    /**
     * 预留地址段（0x0076-007FH）
     * 说明：该地址段未分配具体功能，暂作预留使用
     */
    public static final int ACCELERATION = 0x0076;
    public static final int RESERVED_SEGMENT_END = 0x007F;
}