package com.lasercyber.lws.ui.common.modbus.log;

import android.util.Log;

import com.lasercyber.lws.ui.common.modbus.call.ModbusLogger;

public class ModbusLog implements ModbusLogger {
    @Override
    public void log(String tag, String msg) {
        Log.d(TAG, msg);
    }

    @Override
    public void logTask(String taskId, String priority, String action, String detail) {
        String log = String.format("[任务ID:%s] [优先级:%s] [操作:%s] [详情:%s]", taskId, priority, action, detail);
        Log.d(TAG, log);
    }

    /**
     * 快捷创建日志对象
     * @return
     */
    public static ModbusLog createLog() {
        return new ModbusLog();
    }
}
