package com.lasercyber.lws.ui.common.rx.modbus.protocol;

import java.io.Serializable;

/**
 * modbus 十六进制数据接口
 */
public interface ModbusHexData extends Serializable {
    /**
     * 获取十六进制数据
     * @return
     */
    String getHexData();

    /**
     * 获取十六进制长度
     * @return
     */
    int getHexLength();

    /**
     * 获取地址
     * @return
     */
    int getAddress();

    /**
     * 获取数据
     * @return
     */
    int getValue();
}
