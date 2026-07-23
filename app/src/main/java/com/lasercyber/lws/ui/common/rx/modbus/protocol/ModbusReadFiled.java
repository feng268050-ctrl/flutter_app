package com.lasercyber.lws.ui.common.rx.modbus.protocol;

import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 协议读取字段
 */
@EqualsAndHashCode(callSuper = true)
@Data
public class ModbusReadFiled extends BaseModbusFiled{

    /**
     * 十进制的值
     */
    private long value;

    /**
     * 最近一次 Modbus 响应是否包含该寄存器数据（截断响应时为 false）。
     */
    private boolean valuePresent;

    /**
     * 创建字段的快捷方法
     * @param address
     * @return
     */
    public static ModbusReadFiled create(int address){
        ModbusReadFiled modbusReadFiled = new ModbusReadFiled();
        modbusReadFiled.setAddress(address);
        return modbusReadFiled;
    }
}
