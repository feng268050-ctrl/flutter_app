package com.lasercyber.lws.ui.common.rx.modbus.task;

import android.util.Log;

import com.lasercyber.lws.ui.bean.entity.ControllerUpgradeDataCache;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.DeviceStatusConstant;
import com.lasercyber.lws.ui.common.constant.DeviceUpgradeConstant;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.enums.RxTaskOperationType;
import com.lasercyber.lws.ui.common.handler.ControllerUpgradeHandler;
import com.lasercyber.lws.ui.common.rx.modbus.call.RxModbusCallBack;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusReadFiled;

import java.util.List;
import java.util.stream.Collectors;

public class RxModbusTaskBuilder {
    private static final String TAG = LogTAGConstant.RxModbusTaskBuilder;

    /**
     * 生成Id
     * @param rxTaskTag
     * @return
     */
    private static String createTaskId(String rxTaskTag){
        return rxTaskTag+"_"+System.currentTimeMillis();
    }

    /**
     * 创建一个读取输入寄存器的任务
     * @param list
     * @param callBack
     * @param executeInterval
     * @return
     */
    public static RxModbusReadInputTask buildReadInputTask(List<ModbusReadFiled> list, RxModbusCallBack callBack, long executeInterval){
        List<ModbusReadFiled> filedList = list.stream().sorted().collect(Collectors.toList());
        RxModbusReadInputTask rxModbusReadInputTask = new RxModbusReadInputTask();
        rxModbusReadInputTask.setModbusFields(filedList)
                .setCallBack(callBack)
                .setExecuteInterval(executeInterval)
                .setTaskId(createTaskId(RxTaskOperationType.ReadInputRegisters.name()));
        return rxModbusReadInputTask;
    }

    /**
     * 合并轮询：{@link DeviceStatusConstant#POLL_TIMER_INTERVAL_MS} 尝试读设备状态与设备数据；
     * 总线忙或上一轮未完成则丢弃 tick；命令间 {@link com.lasercyber.lws.ui.common.config.ModbusConfig#COMMAND_INTERVAL_MS}。
     */
    public static AbstractRxModbusTask buildDeviceStatusTask(long executeInterval) {
        RxModbusDeviceStatusAndDataPollTask task = new RxModbusDeviceStatusAndDataPollTask();
        task.setExecuteInterval(DeviceStatusConstant.POLL_TIMER_INTERVAL_MS);
        task.setTaskId(createTaskId("DeviceStatusAndDataPoll"));
        return task;
    }

    /**
     * 构建升级状态检测任务
     * @return
     */
    /** Poll every 2s; only time out after {@link DeviceUpgradeConstant#CONTROLLER_UPGRADE_TIMEOUT} with no active OTA cmd. */
    private static final long CONTROLLER_UPGRADE_WATCH_INTERVAL_MS = 2_000L;

    public static AbstractRxModbusTask checkControllerUpgradeStatusTask(){
        AbstractRxModbusTask task = new AbstractRxModbusTask() {
            @Override
            public void run() {
                Log.d(TAG, "正在执行升级状态检测任务====>");
                ControllerUpgradeDataCache upgradeCache = MemoryCacheManager.getInstance()
                        .getSerializable(CacheKey.CONTROLLER_DEVICE_UPGRADE_DATA_KEY);
                if (upgradeCache == null) {
                    return;
                }
                if (upgradeCache.isAwaitingDeviceConfirm()) {
                    ControllerUpgradeHandler.pollDeviceConfirmStatus();
                    return;
                }
                ControllerUpgradeHandler.checkTransferWatchdog();
            }
        };
        task.setExecuteInterval(CONTROLLER_UPGRADE_WATCH_INTERVAL_MS);
        task.setTaskId(createTaskId("upgrade_check"));
        task.setDelay((int) CONTROLLER_UPGRADE_WATCH_INTERVAL_MS);
        return task;
    }
}
