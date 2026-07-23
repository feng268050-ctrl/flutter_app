package com.lasercyber.lws.ui.bean.entity;

import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusHexData;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusWriteIntFiled;

import java.util.LinkedList;

import lombok.Data;

/**
 * 控制器升级的分包数据
 */
@Data
public class ControllerUpgradePackage {
    /**
     * 字段列表
     */
    private LinkedList<ModbusHexData> list = new LinkedList<>();
    /**
     * 包最大字节数
     */
    private int packMaxSize;
    /**
     * 包校验码
     **/
    private int packCheckCode;
    public void push(int packMaxSize, int packCheckCode,ModbusWriteIntFiled modbusWriteIntFiled){
        this.packMaxSize=packMaxSize*2;
        this.packCheckCode+=packCheckCode;
        list.add(modbusWriteIntFiled);
    }
    public static ControllerUpgradePackage create(int packMaxSize, int packCheckCode,ModbusWriteIntFiled modbusWriteIntFiled){
        ControllerUpgradePackage controllerUpgradePackage=new ControllerUpgradePackage();
        controllerUpgradePackage.push(packMaxSize,packCheckCode,modbusWriteIntFiled);
        return controllerUpgradePackage;
    }
}
