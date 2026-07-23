package com.lasercyber.lws.ui.common.modbus.register.address;

/**
 * 设备控制字段相关Modbus寄存器地址常量类
 * 对应控制字段（0050H-005FH），用于Modbus通信时的地址引用
 */
public class DeviceControllerRegisterAddress {
    /**
     * 配件型号字段1寄存器地址（0050H）
     * 位域说明：高字节-激光器型号；低字节-枪头型号
     * 用途：存储设备配件的型号信息（激光器、枪头）
     */
    public static final int ACCESSORY_MODEL_FIELD_1 = 0x0050; // 原始地址：0050H

    /**
     * 配件型号字段2寄存器地址（0051H）
     * 位域说明：高字节-预留；低字节-送丝机型号
     * 用途：存储设备配件的型号信息（送丝机）
     */
    public static final int ACCESSORY_MODEL_FIELD_2 = 0x0051; // 原始地址：0051H

    /**
     * 枪头驱动类型寄存器地址（0052H）
     * 用途：存储枪头驱动的类型信息
     */
    public static final int GUN_DRIVE_TYPE = 0x0052; // 原始地址：0052H

    /**
     * 枪头摆动范围模式寄存器地址（0053H）
     * 用途：存储枪头摆动范围的模式信息
     */
    public static final int GUN_SWING_RANGE_MODE = 0x0053; // 原始地址：0053H
    /**
     * 字段：工艺类型
     * 说明：枚举值：0-连续焊接、1-点焊、2-清洗、3-切割
     */
    public static final int PROCESS_TYPE = 0x0054;
    @Deprecated
    public static final int CONTROL_FIELD_1_START = 0x0055; // 控制字段1起始地址
    @Deprecated
    public static final int CONTROL_FIELD_1_END = 0x0057;   // 控制字段1结束地址
    /**
     * 字段：控制字段1
     * 说明：寄存器地址为0058H，Bit位定义如下：
     * - Bit0：激光开启（0=关闭，1=使能）
     * - Bit1：手动送气（0=关闭，1=使能）
     * - Bit2：手动送丝工作（0=停止，1=工作）
     * - Bit3：送丝机方向（0=进丝，1=退丝）
     * - Bit4：送丝控制模式（0=自动，1=手动）
     */
    public static final int CONTROL_FIELD_1 = 0x0058; // 控制字段1地址（修正为0058H）
    @Deprecated
    public static final int RESERVED_2_START = 0x0059;
    @Deprecated
    public static final int RESERVED_2_END = 0x005F;
}