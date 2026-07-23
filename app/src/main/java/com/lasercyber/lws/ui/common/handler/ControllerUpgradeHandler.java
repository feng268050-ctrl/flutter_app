package com.lasercyber.lws.ui.common.handler;

import android.util.Log;

import com.blankj.utilcode.util.GsonUtils;
import com.lasercyber.lws.ui.bean.entity.ControllerUpgradeDataCache;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.event.DeviceUpgradeEvent;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.config.ModbusConfig;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.DeviceUpgradeConstant;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.enums.UpgradeStatusEnum;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusOtaExclusiveSession;
import com.lasercyber.lws.ui.common.rx.modbus.call.RxModbusCallBack;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledConvert;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusHexData;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusReadFiled;
import com.lasercyber.lws.ui.common.rx.modbus.task.AbstractRxModbusTask;
import com.lasercyber.lws.ui.common.rx.modbus.task.RxModbusTaskBuilder;
import com.lasercyber.lws.ui.common.rx.modbus.task.RxTaskManager;
import com.lasercyber.lws.ui.common.upgrade.FirmwareUpgradeProgressReporter;
import com.lasercyber.lws.ui.common.utils.UpgradeFileReaderUtils;

import org.apache.commons.lang3.time.DurationFormatUtils;
import org.greenrobot.eventbus.EventBus;

import java.io.File;
import java.util.List;
import java.util.Objects;
import java.util.function.Supplier;

/**
 * 控制设备升级处理：固件信息写成功后进入 OTA 独占期，顺序下发固件数据帧（50ms gate），
 * 传输结束后轮询 {@code otaUpgradeCmd} 直至设备确认烧录完成。
 */
public class ControllerUpgradeHandler {
    private static final String TAG = LogTAGConstant.ControllerUpgradeHandler;

    public static void sendControllerUpgradeInfo(File file) {
        sendControllerUpgradeInfo(file, false);
    }

    /**
     * @param skipSameVersionCheck when true, always start OTA even if file HW/SW matches device (dev sync).
     */
    public static void sendControllerUpgradeInfo(File file, boolean skipSameVersionCheck) {
        String fileName = file.getName();
        Integer fileHardwareVersion = UpgradeFileReaderUtils.getFileHardwareVersion(fileName);
        Integer fileSoftwareVersion = UpgradeFileReaderUtils.getFileSoftwareVersion(fileName);
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (!skipSameVersionCheck
                && isFirmwareAlreadyCurrent(deviceStatus, fileHardwareVersion, fileSoftwareVersion)) {
            Log.w(TAG, "设备版本相同,无需升级");
            DeviceUpgradeEvent controllerUpgradeEvent = DeviceUpgradeEvent.createControllerUpgradeEvent(
                    UpgradeStatusEnum.UPGRADE_FAIL);
            controllerUpgradeEvent.setErrorCode(DeviceUpgradeConstant.VERSION_SAME_NOT_NEED_UPGRADE_ERROR);
            EventBus.getDefault().post(controllerUpgradeEvent);
            return;
        }

        List<ModbusHexData> controllerUpgradeFileInfoData = ModbusFiledBuilder.createControllerUpgradeFileInfoData(file);
        Log.d(TAG, "升级的文件信息数据:" + GsonUtils.toJson(controllerUpgradeFileInfoData));
        MemoryCacheManager.getInstance().putSerializableNoNotice(CacheKey.CONTROLLER_DEVICE_UPGRADE_DATA_KEY,
                ControllerUpgradeDataCache.init(
                        file,
                        ModbusFiledBuilder.createControllerUpgradeFileBaseInfo(file)
                ));
        ModbusManagerRtu.get().writeRegistersCall(controllerUpgradeFileInfoData, new ModbusManagerRtu.WriteCallback() {
            @Override
            public void onSuccess() {
                MemoryCacheManager.getInstance().putSerializableNoNotice(
                        CacheKey.CONTROLLER_UPGRADE_ERROR_CALL_KEY, Boolean.TRUE);
                DeviceUpgradeEvent controllerUpgradeEvent = DeviceUpgradeEvent.createControllerUpgradeEvent(
                        UpgradeStatusEnum.UPGRADE_ING);
                EventBus.getDefault().post(controllerUpgradeEvent);
                ModbusOtaExclusiveSession.beginTransfer();
                DeviceStatusTaskHandler.pauseDevicePoll();
                AbstractRxModbusTask abstractRxModbusTask = RxModbusTaskBuilder.checkControllerUpgradeStatusTask();
                RxTaskManager.getInstance().addTask(abstractRxModbusTask);
                MemoryCacheManager.getInstance().putString(
                        CacheKey.CONTROLLER_UPGRADE_STATUS_CHECK_TASK_ID_KEY, abstractRxModbusTask.getTaskId());
                sendNextFirmwareChunk(0);
            }

            @Override
            public void onFailure() {
                MemoryCacheManager.getInstance().remove(CacheKey.CONTROLLER_DEVICE_UPGRADE_DATA_KEY);
                DeviceUpgradeEvent controllerUpgradeEvent = DeviceUpgradeEvent.createControllerUpgradeEvent(
                        UpgradeStatusEnum.UPGRADE_FAIL);
                controllerUpgradeEvent.setErrorCode(DeviceUpgradeConstant.REQUEST_UPGRADE_FAIL_ERROR);
                EventBus.getDefault().post(controllerUpgradeEvent);
            }
        });
    }

    /**
     * Invoked by {@link RxModbusTaskBuilder#checkControllerUpgradeStatusTask()} while awaiting device confirm.
     */
    public static void pollDeviceConfirmStatus() {
        ControllerUpgradeDataCache cache = MemoryCacheManager.getInstance()
                .getSerializable(CacheKey.CONTROLLER_DEVICE_UPGRADE_DATA_KEY);
        if (cache == null || !cache.isAwaitingDeviceConfirm()) {
            return;
        }
        long nowMs = System.currentTimeMillis();
        long confirmElapsedMs = nowMs - cache.getTransferCompletedAtMs();
        if (confirmElapsedMs >= DeviceUpgradeConstant.CONTROLLER_UPGRADE_DEVICE_CONFIRM_TIMEOUT_MS) {
            Log.e(TAG, "controller upgrade confirm timeout confirmElapsedMs=" + confirmElapsedMs);
            DeviceUpgradeEvent timeoutEvent = DeviceUpgradeEvent.createControllerUpgradeEvent(
                    UpgradeStatusEnum.UPGRADE_TIME_OUT);
            timeoutEvent.setUpgradeStartTime(cache.getCreateTime());
            EventBus.getDefault().post(timeoutEvent);
            DeviceStatusTaskHandler.controllerUpgradeEnd();
            return;
        }
        if (cache.isConfirmPollInFlight()) {
            return;
        }
        if (ModbusConfig.isMock()) {
            completeUpgradeSuccess(cache);
            return;
        }
        cache.setConfirmPollInFlight(true);
        MemoryCacheManager.getInstance().putSerializableNoNotice(
                CacheKey.CONTROLLER_DEVICE_UPGRADE_DATA_KEY, cache);
        ModbusManagerRtu.get().readInputRegistersOtaConfirm(
                ModbusFiledBuilder.createOtaUpgradeCommandRead(),
                new RxModbusCallBack() {
                    @Override
                    public void onSuccess(List<ModbusReadFiled> statusFields) {
                        clearConfirmPollInFlight();
                        ControllerUpgradeDataCache liveCache = MemoryCacheManager.getInstance()
                                .getSerializable(CacheKey.CONTROLLER_DEVICE_UPGRADE_DATA_KEY);
                        if (liveCache == null || !liveCache.isAwaitingDeviceConfirm()) {
                            return;
                        }
                        DeviceStatus deviceStatus = ModbusFiledConvert.deviceStatusConvert(statusFields, new DeviceStatus());
                        if (deviceStatus.upgradeSuccess()) {
                            completeUpgradeSuccess(liveCache);
                        } else if (deviceStatus.upgradeFail()) {
                            Log.e(TAG, "controller upgrade device reported failure otaUpgradeCmd=0x0202");
                            failUpgradeAndEnd(deviceStatus, DeviceUpgradeConstant.UPGRADE_FAIL_ERROR, liveCache);
                        }
                    }

                    @Override
                    public void onFailure(Throwable error) {
                        clearConfirmPollInFlight();
                        Log.w(TAG, "controller upgrade confirm poll failed", error);
                    }
                });
    }

    /**
     * Invoked by {@link RxModbusTaskBuilder#checkControllerUpgradeStatusTask()} during firmware transfer.
     */
    public static void checkTransferWatchdog() {
        ControllerUpgradeDataCache upgradeCache = MemoryCacheManager.getInstance()
                .getSerializable(CacheKey.CONTROLLER_DEVICE_UPGRADE_DATA_KEY);
        if (upgradeCache == null || upgradeCache.isAwaitingDeviceConfirm()) {
            return;
        }
        long nowMs = System.currentTimeMillis();
        long elapsedMs = nowMs - upgradeCache.getCreateTime().getTime();
        long lastProgressMs = Math.max(
                upgradeCache.getLastPacketSentAtMs(),
                upgradeCache.getLastSentOffsetAtMs());
        if (lastProgressMs > 0) {
            if (nowMs - lastProgressMs < DeviceUpgradeConstant.CONTROLLER_UPGRADE_STALL_MS) {
                return;
            }
            Log.e(TAG, "controller upgrade stall stallMs=" + (nowMs - lastProgressMs)
                    + " offset=" + upgradeCache.getLastSentOffset());
        } else if (elapsedMs < DeviceUpgradeConstant.CONTROLLER_UPGRADE_TIMEOUT) {
            return;
        } else {
            Log.e(TAG, "controller upgrade stall (no first packet) elapsedMs=" + elapsedMs);
        }
        DeviceUpgradeEvent controllerUpgradeEvent =
                DeviceUpgradeEvent.createControllerUpgradeEvent(UpgradeStatusEnum.UPGRADE_TIME_OUT);
        EventBus.getDefault().post(controllerUpgradeEvent);
        DeviceStatusTaskHandler.controllerUpgradeEnd();
    }

    static boolean isFirmwareAlreadyCurrent(DeviceStatus deviceStatus,
                                            Integer fileHardwareVersion,
                                            Integer fileSoftwareVersion) {
        if (deviceStatus == null
                || fileHardwareVersion == null
                || fileSoftwareVersion == null
                || deviceStatus.getHardwareVersion() == null
                || deviceStatus.getSoftwareVersion() == null) {
            return false;
        }
        return Objects.equals(deviceStatus.getHardwareVersion(), fileHardwareVersion)
                && Objects.equals(deviceStatus.getSoftwareVersion(), fileSoftwareVersion);
    }

    private static void sendNextFirmwareChunk(int offset) {
        ControllerUpgradeDataCache cache = MemoryCacheManager.getInstance()
                .getSerializable(CacheKey.CONTROLLER_DEVICE_UPGRADE_DATA_KEY);
        if (cache == null || cache.getFile() == null) {
            Log.e(TAG, "sendNextFirmwareChunk: missing upgrade cache");
            failUpgradeAndEnd(null, DeviceUpgradeConstant.NOT_FOUND_UPGRADE_FILE_ERROR, null);
            return;
        }
        long fileLength = cache.getFile().length();
        if (offset >= fileLength) {
            sendSequentialUpgradeEnd(cache);
            return;
        }
        int chunkLength = (int) Math.min(DeviceUpgradeConstant.FIRMWARE_PACKET_MAX_BYTES, fileLength - offset);
        List<ModbusHexData> modbusHexData = ModbusFiledBuilder.createControllerUpgradeFilePackageDataAtOffset(
                cache, offset, chunkLength);
        if (modbusHexData == null) {
            Log.e(TAG, "create package failed offset=" + offset + " length=" + chunkLength);
            failUpgradeAndEnd(null, DeviceUpgradeConstant.CREATE_CURRENT_PACKAGE_UPGRADE_DATA_ERROR, cache);
            return;
        }
        long nowMs = System.currentTimeMillis();
        cache.setLastSentOffset(offset);
        cache.setLastSentLength(chunkLength);
        cache.setLastSentOffsetAtMs(nowMs);
        cache.setLastPacketSentAtMs(nowMs);
        MemoryCacheManager.getInstance().putSerializableNoNotice(
                CacheKey.CONTROLLER_DEVICE_UPGRADE_DATA_KEY, cache);
        FirmwareUpgradeProgressReporter.reportPacketProgress(cache, offset, chunkLength);
        Log.d(TAG, "正在发送控制器升级数据,偏移地址:" + offset + " length=" + chunkLength);
        ModbusManagerRtu.get().writeRegistersOta(modbusHexData, new ModbusManagerRtu.WriteCallback() {
            @Override
            public void onSuccess() {
                sendNextFirmwareChunk(offset + chunkLength);
            }

            @Override
            public void onFailure() {
                failUpgradeAndEnd(null, DeviceUpgradeConstant.UPGRADE_FAIL_ERROR, cache);
            }
        });
    }

    private static void sendSequentialUpgradeEnd(ControllerUpgradeDataCache cache) {
        List<ModbusHexData> upgradeEnd = ModbusFiledBuilder.createUpgradeEndFromFileVersions(
                cache.getFileHardwareVersion(),
                cache.getFileSoftwareVersion());
        ModbusManagerRtu.get().writeRegistersOta(upgradeEnd, new ModbusManagerRtu.WriteCallback() {
            @Override
            public void onSuccess() {
                long transferMs = System.currentTimeMillis() - cache.getCreateTime().getTime();
                Log.i(TAG, "控制器固件传输完成,耗时:" + DurationFormatUtils.formatDurationHMS(transferMs)
                        + " — 等待设备烧录确认");
                cache.setAwaitingDeviceConfirm(true);
                cache.setTransferCompletedAtMs(System.currentTimeMillis());
                cache.setConfirmPollInFlight(false);
                MemoryCacheManager.getInstance().putSerializableNoNotice(
                        CacheKey.CONTROLLER_DEVICE_UPGRADE_DATA_KEY, cache);
                ModbusOtaExclusiveSession.beginAwaitConfirm();
                pollDeviceConfirmStatus();
            }

            @Override
            public void onFailure() {
                failUpgradeAndEnd(null, DeviceUpgradeConstant.UPGRADE_FAIL_ERROR, cache);
            }
        });
    }

    private static void completeUpgradeSuccess(ControllerUpgradeDataCache cache) {
        long upgradeTime = System.currentTimeMillis() - cache.getCreateTime().getTime();
        Log.i(TAG, "控制器升级成功,耗时:" + DurationFormatUtils.formatDurationHMS(upgradeTime));
        DeviceUpgradeEvent event = DeviceUpgradeEvent.createControllerUpgradeEvent(
                UpgradeStatusEnum.UPGRADE_SUCCESS);
        event.setUpgradeStartTime(cache.getCreateTime());
        EventBus.getDefault().post(event);
        DeviceStatusTaskHandler.controllerUpgradeEnd();
    }

    private static void clearConfirmPollInFlight() {
        ControllerUpgradeDataCache cache = MemoryCacheManager.getInstance()
                .getSerializable(CacheKey.CONTROLLER_DEVICE_UPGRADE_DATA_KEY);
        if (cache == null) {
            return;
        }
        cache.setConfirmPollInFlight(false);
        MemoryCacheManager.getInstance().putSerializableNoNotice(
                CacheKey.CONTROLLER_DEVICE_UPGRADE_DATA_KEY, cache);
    }

    private static void failUpgradeAndEnd(DeviceStatus deviceStatus, int errorCode,
                                          ControllerUpgradeDataCache cache) {
        DeviceUpgradeEvent controllerUpgradeEvent = DeviceUpgradeEvent.createControllerUpgradeEvent(
                UpgradeStatusEnum.UPGRADE_FAIL);
        controllerUpgradeEvent.setErrorCode(errorCode);
        if (cache != null) {
            controllerUpgradeEvent.setUpgradeStartTime(cache.getCreateTime());
        }
        EventBus.getDefault().post(controllerUpgradeEvent);
        DeviceStatusTaskHandler.controllerUpgradeEnd();
        sendUpgradeEnd(deviceStatus, null);
    }

    /**
     * 下发升级结束指令
     */
    public static void sendUpgradeEnd(DeviceStatus deviceStatus, Supplier<?> supplier) {
        List<ModbusHexData> upgradeEnd;
        if (deviceStatus != null
                && deviceStatus.getHardwareVersion() != null
                && deviceStatus.getSoftwareVersion() != null) {
            upgradeEnd = ModbusFiledBuilder.createUpgradeEnd(deviceStatus);
        } else {
            ControllerUpgradeDataCache cache = MemoryCacheManager.getInstance()
                    .getSerializable(CacheKey.CONTROLLER_DEVICE_UPGRADE_DATA_KEY);
            if (cache == null) {
                if (supplier != null) {
                    supplier.get();
                }
                return;
            }
            upgradeEnd = ModbusFiledBuilder.createUpgradeEndFromFileVersions(
                    cache.getFileHardwareVersion(),
                    cache.getFileSoftwareVersion());
        }
        if (upgradeEnd == null || upgradeEnd.isEmpty()) {
            if (supplier != null) {
                supplier.get();
            }
            return;
        }
        ModbusManagerRtu.WriteCallback callback = new ModbusManagerRtu.WriteCallback() {
            @Override
            public void onSuccess() {
                if (supplier == null) {
                    return;
                }
                Boolean callBack = MemoryCacheManager.getInstance().getSerializable(
                        CacheKey.CONTROLLER_UPGRADE_ERROR_CALL_KEY);
                if (Objects.equals(callBack, Boolean.TRUE)) {
                    MemoryCacheManager.getInstance().remove(CacheKey.CONTROLLER_UPGRADE_ERROR_CALL_KEY);
                    supplier.get();
                }
            }

            @Override
            public void onFailure() {
                Log.e(TAG, "onFailure: 下发终止升级失败");
                if (supplier != null) {
                    supplier.get();
                }
            }
        };
        if (ModbusOtaExclusiveSession.isActive()) {
            ModbusManagerRtu.get().writeRegistersOta(upgradeEnd, callback);
        } else {
            ModbusManagerRtu.get().writeRegistersCall(upgradeEnd, callback);
        }
    }
}
