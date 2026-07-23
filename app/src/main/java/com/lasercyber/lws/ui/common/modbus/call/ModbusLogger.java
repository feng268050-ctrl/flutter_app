package com.lasercyber.lws.ui.common.modbus.call;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

/**
 * 日志回调（支持持久化扩展）
 */
public interface ModbusLogger {
    String TAG= LogTAGConstant.ModbusLogger;
    void log(String tag, String msg);

    /**
     * 任务日志（含ID和优先级）
     * @param taskId
     * @param priority
     * @param action
     * @param detail
     */
    void logTask(String taskId, String priority, String action, String detail);

    /**
     * 预留日志持久化接口
     * @param log
     */
    default void persistLog(String log) {}
}
