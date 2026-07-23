package com.lasercyber.lws.ui.common.rx.modbus.protocol;

import com.blankj.utilcode.util.StringUtils;

import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 协议写int字段
 */
@EqualsAndHashCode(callSuper = true)
@Data
public class ModbusWriteIntFiled extends BaseModbusFiled implements ModbusHexData{
    /**
     * 数据
     */
    private int value;
    /**
     * 16进制数据，部分字段，无法做统一，需要单独处理
     */
    private String hexData;
    public static ModbusWriteIntFiled create(int address, int value){
        ModbusWriteIntFiled modbusWriteIntFiled = new ModbusWriteIntFiled();
        modbusWriteIntFiled.setAddress(address);
        modbusWriteIntFiled.setValue(value);
        return modbusWriteIntFiled;
    }
    public static ModbusWriteIntFiled create(int address,String hexData){
        ModbusWriteIntFiled modbusWriteIntFiled = new ModbusWriteIntFiled();
        modbusWriteIntFiled.setAddress(address);
        modbusWriteIntFiled.setHexData(hexData);
        return modbusWriteIntFiled;
    }
    @Override
    public String getHexData() {
        if (!StringUtils.isEmpty(hexData)) {
            return hexData;
        }
        return Integer.toHexString(value);
    }
}
