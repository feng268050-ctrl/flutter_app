package com.lasercyber.lws.ui.common.modbus.core;

import com.lasercyber.lws.ui.common.modbus.call.ModbusCallback;
import com.lasercyber.lws.ui.common.modbus.enums.ModbusProtocolType;

import java.util.UUID;

import lombok.Getter;

/**
 * Modbus 任务封装（支持优先级、插队、动态调整）
 */
public class ModbusTask  implements Comparable<ModbusTask>{
    // getter/setter
    @Getter
    private final String taskId; // 任务ID（用于日志追踪）
    @Getter
    private final ModbusProtocolType protocolType;
    @Getter
    private final byte[] requestData;
    @Getter
    private final ModbusCallback callback;
    private final boolean isUiTask; // 是否UI任务（优先）
    @Getter
    private int priority; // 优先级（1-10，数字越大优先级越高）
    @Getter
    private int retryCount; // 已重试次数
    @Getter
    private final int maxRetryCount; // 最大重试次数
    @Getter
    private final Runnable retryFailedCallback; // 重试失败回调
    private boolean isCancelled; // 是否已取消
    public static ModbusTask createUiTask(byte[] requestData, ModbusCallback callback) {
        return new ModbusTask(true, ModbusProtocolType.UNIVERSAL_PROTOCOL, requestData, callback, 10, 3, null);
    }
    // 构造器（UI任务）
    public static ModbusTask createUiTask(ModbusProtocolType protocolType, byte[] requestData, ModbusCallback callback) {
        return new ModbusTask(true, protocolType, requestData, callback, 10, 3, null);
    }
    public static ModbusTask createTimerTask(byte[] requestData, ModbusCallback callback, int priority) {
        return new ModbusTask(false, ModbusProtocolType.UNIVERSAL_PROTOCOL, requestData, callback, priority, 3, null);
    }
    // 构造器（定时任务）
    public static ModbusTask createTimerTask(ModbusProtocolType protocolType, byte[] requestData, ModbusCallback callback, int priority) {
        return new ModbusTask(false, protocolType, requestData, callback, priority, 3, null);
    }

    private ModbusTask(boolean isUiTask, ModbusProtocolType protocolType, byte[] requestData,
                       ModbusCallback callback, int priority, int maxRetryCount, Runnable retryFailedCallback) {
        // 使用更唯一的任务ID生成方式
        String uuid = UUID.randomUUID().toString().replace("-", "");
        this.taskId = isUiTask ? "ui-task-" + uuid : "timer-task-" + uuid;
        this.isUiTask = isUiTask;
        this.protocolType = protocolType;
        this.requestData = requestData;
        this.callback = callback;
        this.priority = priority;
        this.maxRetryCount = maxRetryCount;
        this.retryFailedCallback = retryFailedCallback;
    }

    /**
     * 动态调整优先级
     * @param priority
     */
    public void updatePriority(int priority) {
        if (priority < 1) priority = 1;
        if (priority > 10) priority = 10;
        this.priority = priority;
    }

    /**
     *  取消任务
     */
    public void cancel() {
        this.isCancelled = true;
    }

    /**
     *  是否已取消
     * @return
     */
    public boolean isCancelled() {
        return isCancelled;
    }

    /**
     * 优先级比较：UI任务 > 定时任务；同类型按priority降序
     * @param other the object to be compared.
     * @return
     */
    @Override
    public int compareTo(ModbusTask other) {
        if (this.isUiTask && !other.isUiTask) return -1;
        if (!this.isUiTask && other.isUiTask) return 1;
        return Integer.compare(other.priority, this.priority);
    }

    /**
     *  重试次数递增
     */
    public void incrementRetryCount() { this.retryCount++; }

    /**
     *  是否UI任务
     * @return
     */

    public boolean isUiTask() { return isUiTask; }
}
