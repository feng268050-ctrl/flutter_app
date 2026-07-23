package com.lasercyber.lws.ui.common.handler;

import android.util.Log;

import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.DeviceStatusConstant;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusOtaExclusiveSession;
import com.lasercyber.lws.ui.common.rx.modbus.task.AbstractRxModbusTask;
import com.lasercyber.lws.ui.common.rx.modbus.task.RxModbusTaskBuilder;
import com.lasercyber.lws.ui.common.rx.modbus.task.RxTaskManager;

public class DeviceStatusTaskHandler {
    private static final String TAG = LogTAGConstant.DeviceStatusTaskHandler;
    private static boolean deprecatedIntervalWarned;

    /**
     * 控制器升级结束
     */
    public static void controllerUpgradeEnd() {
        ModbusOtaExclusiveSession.end();
        MemoryCacheManager.getInstance().remove(CacheKey.CONTROLLER_UPGRADE_ERROR_CALL_KEY);
        startDevicePoll();
        MemoryCacheManager.getInstance().remove(CacheKey.CONTROLLER_DEVICE_UPGRADE_DATA_KEY);
        String taskId = MemoryCacheManager.getInstance().getString(CacheKey.CONTROLLER_UPGRADE_STATUS_CHECK_TASK_ID_KEY);
        if (StringUtils.isEmpty(taskId)) {
            return;
        }
        RxTaskManager.getInstance().cancelTask(taskId);
        MemoryCacheManager.getInstance().remove(CacheKey.CONTROLLER_UPGRADE_STATUS_CHECK_TASK_ID_KEY);
    }

    public static void startDevicePoll() {
        recreateDeviceStatusTask(DeviceStatusConstant.POLL_TIMER_INTERVAL_MS);
    }

    public static void pauseDevicePoll() {
        removeDeviceStatusTask();
    }

    /**
     * 重置合并轮询任务（100ms 尝试读设备状态 + 设备数据，总线忙则丢弃 tick）。
     */
    public static void recreateDeviceStatusTask(long executeInterval) {
        if (executeInterval != DeviceStatusConstant.POLL_TIMER_INTERVAL_MS && !deprecatedIntervalWarned) {
            deprecatedIntervalWarned = true;
            Log.w(TAG, "Ignoring custom poll interval " + executeInterval
                    + "; using POLL_TIMER_INTERVAL_MS=" + DeviceStatusConstant.POLL_TIMER_INTERVAL_MS);
        }
        Log.d(TAG, "正在重置设备状态/数据的合并轮询任务=====>");
        removeDeviceStatusTask();
        removeDeviceDataTask();
        AbstractRxModbusTask rxModbusReadInputTask =
                RxModbusTaskBuilder.buildDeviceStatusTask(DeviceStatusConstant.POLL_TIMER_INTERVAL_MS);
        RxTaskManager.getInstance().addTask(rxModbusReadInputTask);

        MemoryCacheManager.getInstance().putString(CacheKey.DEVICE_STATUS_TASK_ID_KEY, rxModbusReadInputTask.getTaskId());
        Log.d(TAG, "添加新的设备状态/数据合并轮询任务:" + rxModbusReadInputTask.getTaskId());
    }

    /**
     * 设备数据已合并进 {@link #recreateDeviceStatusTask(long)}；保留此方法以取消历史独立数据任务。
     */
    public static void recreateDeviceDataTask(long executeInterval) {
        removeDeviceDataTask();
    }

    public static void removeDeviceStatusTask() {
        String oldTaskId = MemoryCacheManager.getInstance().getString(CacheKey.DEVICE_STATUS_TASK_ID_KEY);
        if (!StringUtils.isEmpty(oldTaskId)) {
            Log.d(TAG, "正在移除原始的设备状态定时任务:" + oldTaskId);
            RxTaskManager.getInstance().cancelTask(oldTaskId);
        }
    }

    public static void removeDeviceDataTask() {
        String dataId = MemoryCacheManager.getInstance().getString(CacheKey.DEVICE_DATA_TASK_ID_KEY);
        if (!StringUtils.isEmpty(dataId)) {
            Log.d(TAG, "正在移除原始的设备数据定时任务:" + dataId);
            RxTaskManager.getInstance().cancelTask(dataId);
        }
    }
}
