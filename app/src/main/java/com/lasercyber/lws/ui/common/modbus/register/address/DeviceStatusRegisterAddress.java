package com.lasercyber.lws.ui.common.modbus.register.address;

/**
 * 设备状态寄存器地址
 */
public class DeviceStatusRegisterAddress {
    /**
     * 设备类型寄存器地址（0000H）
     * 数据类型：16位无符号整型（UInt16）
     * 取值说明：0=未知设备；1=LSW01控制板；2-65535=预留扩展设备类型
     */
    public static final int DEVICE_TYPE = 0x0000; // 原始地址：0000H

    /**
     * 设备硬件版本寄存器地址（0001H）
     * 数据类型：16位无符号整型（UInt16）
     * 格式说明：高8位=主版本号，低8位=次版本号（如 0x0102 表示 V1.02）
     */
    public static final int DEVICE_HARDWARE_VERSION = 0x0001; // 原始地址：0001H

    /**
     * 设备软件版本寄存器地址（0002H）
     * 数据类型：16位无符号整型（UInt16）
     * 格式说明：高8位=主版本号，低8位=次版本号（如 0x0205 表示 V2.05）
     */
    public static final int DEVICE_SOFTWARE_VERSION = 0x0002; // 原始地址：0002H

    /**
     * OTA 升级命令寄存器地址（0003H）
     * 数据类型：16位无符号整型（UInt16）
     * 命令说明：0x0000=无效命令；0x1234=请求固件信息；0x55AA=请求固件数据；
     *          0x1212=升级成功反馈；0x0202=升级失败反馈
     */
    public static final int OTA_UPGRADE_COMMAND = 0x0003; // 原始地址：0003H

    /**
     * 请求固件硬件版本寄存器地址（0004H）
     * 数据类型：16位无符号整型（UInt16）
     * 用途：OTA 升级时，读取待升级固件的硬件版本要求（需与设备硬件版本匹配）
     */
    public static final int REQUEST_FIRMWARE_HARDWARE_VERSION = 0x0004; // 原始地址：0004H

    /**
     * 请求固件软件版本寄存器地址（0005H）
     * 数据类型：16位无符号整型（UInt16）
     * 用途：OTA 升级时，读取待升级固件的软件版本号
     */
    public static final int REQUEST_FIRMWARE_SOFTWARE_VERSION = 0x0005; // 原始地址：0005H

    /**
     * 请求固件偏移地址（寄存器1）（0006H）
     * 数据类型：16位无符号整型（UInt16）
     * 用途：OTA 升级时，固件数据的偏移地址高位（与 0007H 组合为 32位地址）
     */
    public static final int REQUEST_FIRMWARE_OFFSET_ADDRESS_HIGH = 0x0006; // 原始地址：0006H

    /**
     * 请求固件偏移地址（寄存器2）（0007H）
     * 数据类型：16位无符号整型（UInt16）
     * 用途：OTA 升级时，固件数据的偏移地址低位（与 0006H 组合为 32位地址）
     */
    public static final int REQUEST_FIRMWARE_OFFSET_ADDRESS_LOW = 0x0007; // 原始地址：0007H

    /**
     * 请求固件数据长度寄存器地址（0008H）
     * 数据类型：16位无符号整型（UInt16）
     * 用途：OTA 升级时，单次请求的固件数据长度（单位：字节），最大值 65535
     */
    public static final int REQUEST_FIRMWARE_DATA_LENGTH = 0x0008; // 原始地址：0008H
    /**
     * 枪头告警状态字段1寄存器地址（0009H）
     * 位域说明：
     * Bit0: 枪头通信状态（0-正常，1-告警）
     * Bit1: 已废弃，电机驱动板温度报警不再使用此位
     * Bit2: 已废弃，电机温度报警不再使用此位
     * Bit3-Bit15: 预留位
     */
    public static final int GUN_ALARM_STATUS_FIELD_1 = 0x0009; // 原始地址：0009H


    /**
     * 枪头告警状态字段3寄存器地址（000AH）
     * 位域说明：未明确标注，推测为后续告警状态扩展位
     */
    public static final int GUN_ALARM_STATUS_FIELD_3 = 0x000A; // 原始地址：000AH

    /**
     * 枪头告警状态字段2寄存器地址（000BH）
     * 枪头告警状态字段2寄存器地址（000BH）
     * 位域说明：未明确标注，推测为后续告警状态扩展位
     */
    public static final int GUN_ALARM_STATUS_FIELD_2 = 0x000B; // 原始地址：000BH

    /**
     * 枪头告警状态字段4寄存器地址（000CH）
     * 位域说明：未明确标注，推测为后续告警状态扩展位
     */
    public static final int GUN_ALARM_STATUS_FIELD_4 = 0x000C; // 原始地址：000CH
    /**
     * 激光器告警状态字段1寄存器地址（000DH）
     * 位域说明：
     * Bit0: 泵源板温度（0-正常，1-告警）
     * Bit1: 泵源温度（0-正常，1-告警）
     * Bit2: 电流（0-正常，1-告警）
     * Bit3: 红光电流（0-正常，1-告警）
     * Bit4: 泵源电压（0-正常，1-告警）
     * Bit5: 前向光PD电压（0-正常，1-告警）
     * Bit6-Bit15: 预留位
     */
    public static final int LASER_ALARM_STATUS_FIELD_1 = 0x000D; // 原始地址：000DH

    /**
     * 激光器告警状态字段2寄存器地址（000EH）
     * 位域说明：未明确标注，推测为后续激光器告警状态扩展位
     */
    public static final int LASER_ALARM_STATUS_FIELD_2 = 0x000E; // 原始地址：000EH

    /**
     * 激光器告警状态字段3寄存器地址（000FH）
     * 位域说明：未明确标注，推测为后续激光器告警状态扩展位
     */
    public static final int LASER_ALARM_STATUS_FIELD_3 = 0x000F; // 原始地址：000FH

    /**
     * 激光器告警状态字段4寄存器地址（0010H）
     * 位域说明：未明确标注，推测为后续激光器告警状态扩展位
     */
    public static final int LASER_ALARM_STATUS_FIELD_4 = 0x0010; // 原始地址：0010H
    /**
     * 送丝机告警状态字段1寄存器地址（0011H）
     * 位域说明：
     * Bit0: 送丝机通信（0-正常，1-告警）
     * Bit1: 环境板温度（0-正常，1-告警）
     * Bit2-Bit15: 预留位
     */
    public static final int WIRE_FEEDER_ALARM_STATUS_FIELD_1 = 0x0011; // 原始地址：0011H

    /**
     * 送丝机告警状态字段2寄存器地址（0012H）
     * 位域说明：未明确标注，推测为后续送丝机告警状态扩展位
     */
    public static final int WIRE_FEEDER_ALARM_STATUS_FIELD_2 = 0x0012; // 原始地址：0012H
    /**
     * 控制卡告警状态字段1寄存器地址（0013H）
     * 位域说明（A001 保护气路径）：
     * Bit0: 吹气气压告警（0-正常，1-告警）
     * Bit1: 进气气压告警（0-正常，1-告警）
     * Bit2: 气压传感器通信故障（0-正常，1-告警）
     * Bit3: 外部 Flash 故障（0-正常，1-告警）
     * Bit4-Bit15: 预留位
     */
    public static final int CONTROL_CARD_ALARM_STATUS_FIELD_1 = 0x0013; // 原始地址：0013H
    /**
     * 控制卡告警状态字段2寄存器地址（0014H）
     * 位域说明：Bit0-Bit15均为预留位
     */
    public static final int CONTROL_CARD_ALARM_STATUS_FIELD_2 = 0x0014; // 原始地址：0014H

    /**
     * 机台状态字段1寄存器地址（0015H）
     * 位域说明：
     * Bit0: 激光状态（0-关闭，1-开启）
     * Bit1: 气阀状态（0-关闭，1-开启）
     * Bit2: 安全锁状态（0-关闭，1-开启）
     * Bit3: 枪头开关（0-断开，1-闭合）
     * Bit4: 送丝状态（0-停止，1-工作）
     * Bit5: 红光状态（0-关闭，1-开启）
     * Bit6: 钥匙开关（0-关闭，1-开启）
     * Bit7-Bit15: 预留位
     */
    public static final int MACHINE_STATUS_FIELD_1 = 0x0015; // 原始地址：0015H

    /**
     * 机台状态字段2寄存器地址（0016H）
     * 位域说明：未明确标注，推测为后续机台状态扩展位
     */
    public static final int MACHINE_STATUS_FIELD_2 = 0x0016; // 原始地址：0016H

    /**
     * 预留地址段（0017H-002FH）
     * 说明：该地址段未分配具体功能，暂作预留使用
     */
    public static final int RESERVED_START = 0x0017;
    public static final int RESERVED_END = 0x002F;
}
