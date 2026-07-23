package com.lasercyber.lws.ui.common.modbus.call;

import com.lasercyber.lws.ui.common.modbus.protocol.ModbusResponse;
import com.lasercyber.lws.ui.common.modbus.core.ModbusTask;

/**
 *  Modbus通信回调（UI层实现）
 */
public interface ModbusCallback {
    /**
     * 成功回调
     * @param task
     * @param response
     */
    void onSuccess(ModbusTask task, ModbusResponse response);
    /**
     * 失败回调
     * @param task
     * @param errorMsg
     */
    void onFailed(ModbusTask task, String errorMsg);
}
