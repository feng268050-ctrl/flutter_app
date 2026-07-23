package com.lasercyber.lws.ui.common.modbus.register.address;

/**
 * 升级相关Modbus寄存器地址常量类
 * 对应升级相关字段（0000H-004FH），用于Modbus通信时的地址引用
 */
public class DeviceUpgradeRegisterAddress {
    /**
     * OTA固件硬件版本寄存器地址（0000H）
     * 用途：存储OTA升级固件的硬件版本信息
     */
    public static final int OTA_FIRMWARE_HARDWARE_VERSION = 0x0000; // 原始地址：0000H

    /**
     * OTA固件软件版本寄存器地址（0001H）
     * 用途：存储OTA升级固件的软件版本信息
     */
    public static final int OTA_FIRMWARE_SOFTWARE_VERSION = 0x0001; // 原始地址：0001H

    /**
     * OTA固件大小寄存器地址（0002H）
     * 用途：存储OTA升级固件的大小（字节数）
     * 总的字节大小
     */
    public static final int OTA_FIRMWARE_SIZE_HEIGHT = 0x0002; // 原始地址：0002H
    /**
     * OTA固件大小寄存器地址（0003H）
     * 用途：存储OTA升级固件的大小（字节数）
     * 总的字节大小
     */
    public static final int OTA_FIRMWARE_SIZE_LOW = 0x0003; // 原始地址：0003H

    /**
     * OTA固件校验码寄存器地址（0004H）
     * 备注：校验码按字节求和
     * 用途：存储OTA升级固件的校验码，用于校验固件完整性
     */
    public static final int OTA_FIRMWARE_CHECK_CODE_HEIGHT = 0x0004; // 原始地址：0004H
    public static final int OTA_FIRMWARE_CHECK_CODE_LOW = 0x0005; // 原始地址：0004H

    /**
     * OTA固件偏移地址寄存器地址（0006H）
     * 用途：存储OTA升级固件的偏移地址（用于分块升级）
     */
    public static final int OTA_FIRMWARE_OFFSET_ADDRESS_HEIGHT = 0x0006; // 原始地址：0006H
    /**
     * OTA固件偏移地址寄存器地址（0007H）
     * 用途：存储OTA升级固件的偏移地址（用于分块升级）
     */
    public static final int OTA_FIRMWARE_OFFSET_ADDRESS_LOW = 0x0007; // 原始地址：0007H

    /**
     * OTA固件字节数寄存器地址（0008H）
     * 用途：存储单次OTA升级传输的固件字节数
     * 当前包的字节长度
     */
    public static final int OTA_FIRMWARE_BYTE_COUNT = 0x0008; // 原始地址：0008H

    /**
     * OTA固件命令寄存器地址（0009H）
     * 备注：0x1234-固件信息；0x55AA-固件数据
     * 用途：发送OTA升级控制命令（查询固件信息、传输固件数据等）
     */
    public static final int OTA_FIRMWARE_COMMAND = 0x0009; // 原始地址：0009H

    /**
     * 每包固件数据CRC起始地址（000AH）
     * 备注：CRC按字节求和
     * 用途：存储每包OTA固件数据的CRC校验码，用于校验单包数据完整性
     */
    public static final int FIRMWARE_PACKET_CRC_START = 0x000A; // 原始地址：000AH
    public static final int FIRMWARE_PACKET_CRC_END = 0x000B;   // 原始地址：000BH

    /**
     * 预留地址段（000CH-000FH）
     * 说明：未分配具体功能，暂作预留使用
     */
    public static final int RESERVED_SEGMENT_1_START = 0x000C;
    public static final int RESERVED_SEGMENT_1_END = 0x000F;

    /**
     * OTA升级固件数据起始地址（0010H）
     * 备注：OTA_ReqData[64 * 2]
     * 用途：存储OTA升级的固件数据（分块传输，每块64个寄存器，每个寄存器2字节）
     */
    public static final int OTA_FIRMWARE_DATA_START = 0x0010; // 原始地址：0010H
    public static final int OTA_FIRMWARE_DATA_END = 0x004F;   // 原始地址：004FH
}