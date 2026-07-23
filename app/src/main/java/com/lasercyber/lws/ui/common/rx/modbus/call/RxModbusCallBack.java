package com.lasercyber.lws.ui.common.rx.modbus.call;

import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusReadFiled;

import java.util.List;

public interface RxModbusCallBack {
    /**
     * 获取数据成功后的回调
     * @param modbusReadFields
     */
    void onSuccess(List<ModbusReadFiled> modbusReadFields);
    /**
     * 获取数据失败后的回调
     * @param tr
     */
    default void onFailure(Throwable tr){

    }
}
