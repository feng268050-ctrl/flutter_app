package com.lasercyber.lws.ai.zeropoint;

import android.content.Context;
import android.os.Handler;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.blankj.utilcode.util.GsonUtils;
import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.entity.DeviceControlData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusHexData;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusWriteIntFiled;
import com.lasercyber.lws.ui.common.state.ProcessParametersSnapshotStore;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;
import com.lasercyber.lws.ui.common.utils.DeviceControlUtils;

import java.util.List;

/**
 * Modbus laser enable / weld-context preparation for manual zero-point auto correction.
 */
final class ZeroPointLaserController {

    private static final String TAG = "ZeroPointManualAuto";
    private static final long AUTO_LASER_PULSE_MS = 15_000L;
    private static final int AUTO_LASER_WELD_MODEL = ModelConstant.POINT_WELDING;
    private static final int AUTO_LASER_POWER_PERCENT = 15;
    private static final int AUTO_POINT_WELD_DURATION_MS = 500;
    private static final int AUTO_POINT_WELD_INTERVAL_MS = 10_000;
    private static final double AUTO_ZERO_POINT_CORRECTION = 0.0;

    @Nullable
    private DeviceControlData controlDataTemplate;

    long autoLaserPulseMs() {
        return AUTO_LASER_PULSE_MS;
    }

    boolean isPhysicallyOn() {
        DeviceStatus status = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        return status != null && status.isLaserOn();
    }

    boolean isModbusAvailable() {
        return ModbusManagerRtu.get().isCanSendData();
    }

    boolean prepareWeldContext(@NonNull Context context, long runId) {
        if (!isModbusAvailable()) {
            Log.w(TAG, "manual_auto laser_prepare_unavailable runId=" + runId);
            return false;
        }

        int contextModel = resolveWeldModel();
        DeviceControlData controlData = createControlData();
        ProcessParametersData processParametersData = resolveProcessParameters(context, contextModel);
        AdvancedSettings parameterSettings = resolveParameterSettings(context, processParametersData);

        controlDataTemplate = controlData;

        try {
            logModbusPayload(runId, "prepare_device_control", controlData, null, null);
            ModbusManagerRtu.get().writeRegisters(
                    ModbusFiledBuilder.createDeviceControlData(controlData));
            logModbusPayload(runId, "prepare_process_params", null, processParametersData, null);
            ModbusManagerRtu.get().writeRegisters(
                    ModbusFiledBuilder.createProcessParametersData(processParametersData));
            logModbusPayload(runId, "prepare_parameter_settings", null, null, parameterSettings);
            ModbusManagerRtu.get().writeRegisters(
                    ModbusFiledBuilder.doCreateWriteDeviceSetting(parameterSettings));
            ProcessParametersSnapshotStore.update(processParametersData);
            Log.i(TAG, "manual_auto laser_context_prepared runId=" + runId
                    + " contextModel=" + contextModel
                    + " deviceModel=" + controlData.getModel()
                    + " (point_weld)"
                    + " laserPower=" + AUTO_LASER_POWER_PERCENT
                    + "% duration=" + AUTO_POINT_WELD_DURATION_MS
                    + "ms interval=" + AUTO_POINT_WELD_INTERVAL_MS
                    + "ms zeroOffset=" + AUTO_ZERO_POINT_CORRECTION
                    + " processId=" + processParametersData.getId());
            return true;
        } catch (Exception exception) {
            Log.w(TAG, "manual_auto laser_context_prepare_failed runId=" + runId, exception);
            return false;
        }
    }

    void openLaser(long runId, @NonNull OpenCallback callback) {
        if (!isModbusAvailable()) {
            Log.w(TAG, "manual_auto laser_open_unavailable runId=" + runId);
            callback.onFailure();
            return;
        }
        DeviceControlData openConfig = createSwitchConfig(true);
        ModbusManagerRtu.get().writeRegistersCall(
                ModbusFiledBuilder.createDeviceControlSwitchData(openConfig),
                new ModbusManagerRtu.WriteCallback() {
                    @Override
                    public void onSuccess() {
                        Log.i(TAG, "manual_auto laser_modbus_open runId=" + runId);
                        callback.onSuccess();
                    }

                    @Override
                    public void onFailure() {
                        Log.w(TAG, "manual_auto laser_modbus_open_failed runId=" + runId);
                        callback.onFailure();
                    }
                });
    }

    void closeLaser(long runId,
                    @NonNull String reason,
                    @Nullable ModbusManagerRtu.WriteCallback callback) {
        writeSwitch(false, runId, reason, callback);
    }

    void closeLaserQuietly(long runId, @NonNull String reason) {
        writeSwitch(false, runId, reason, null);
    }

    void scheduleAutoClose(long runId,
                           @NonNull Handler handler,
                           @NonNull Runnable onTimeout,
                           @Nullable Runnable holderToReplace) {
        if (holderToReplace != null) {
            handler.removeCallbacks(holderToReplace);
        }
        handler.postDelayed(onTimeout, AUTO_LASER_PULSE_MS);
    }

    void cancelScheduledClose(@NonNull Handler handler, @Nullable Runnable runnable) {
        if (runnable != null) {
            handler.removeCallbacks(runnable);
        }
    }

    @NonNull
    DeviceControlData createSwitchConfig(boolean open) {
        DeviceControlData base = controlDataTemplate;
        DeviceControlData config = new DeviceControlData();
        if (base != null) {
            config.setLaserDeviceType(base.getLaserDeviceType());
            config.setGunDeviceType(base.getGunDeviceType());
            config.setWireFeedDeviceType(base.getWireFeedDeviceType());
            config.setGunDriveType(base.getGunDriveType());
            config.setGunSwingRangeMode(base.getGunSwingRangeMode());
            config.setModel(base.getModel());
            config.setAutoWireFeedEnable(base.getAutoWireFeedEnable());
        } else {
            config.setModel(AUTO_LASER_WELD_MODEL);
            config.setAutoWireFeedEnable(1);
        }
        return open
                ? DeviceControlUtils.createOpenLaserConfig(config)
                : DeviceControlUtils.createCloseLaserConfig(config);
    }

    void logSwitchPayload(long runId, boolean open, @NonNull String reason, @NonNull DeviceControlData config) {
        Log.i(TAG, "manual_auto modbus_payload runId=" + runId
                + " phase=laser_switch open=" + open
                + " reason=" + reason
                + " switchConfig=" + GsonUtils.toJson(config));
        logRegisters(runId, "laser_switch",
                ModbusFiledBuilder.createDeviceControlSwitchData(config));
    }

    void reset() {
        controlDataTemplate = null;
    }

    @NonNull
    private DeviceControlData createControlData() {
        DeviceControlData controlData = new DeviceControlData();
        controlData.setModel(AUTO_LASER_WELD_MODEL);
        controlData.setAutoWireFeedEnable(1);
        return controlData;
    }

    private void writeSwitch(boolean open,
                             long runId,
                             @NonNull String reason,
                             @Nullable ModbusManagerRtu.WriteCallback callback) {
        DeviceControlData config = createSwitchConfig(open);
        logSwitchPayload(runId, open, reason, config);
        if (!isModbusAvailable()) {
            Log.w(TAG, "manual_auto laser_modbus_unavailable runId=" + runId
                    + " open=" + open
                    + " reason=" + reason);
            if (callback != null) {
                callback.onFailure();
            }
            return;
        }
        ModbusManagerRtu.get().writeRegistersCall(
                ModbusFiledBuilder.createDeviceControlSwitchData(config),
                callback);
    }

    private int resolveWeldModel() {
        ProcessParametersData snapshot = ProcessParametersSnapshotStore.getSnapshot();
        if (snapshot != null && isWeldModel(snapshot.getProcessType())) {
            return snapshot.getProcessType();
        }

        Integer topMode = MemoryCacheManager.getInstance()
                .getSerializable(CacheKey.LAST_TOP_MODE_CONTEXT_KEY);
        if (topMode != null && topMode == CacheKey.TOP_MODE_CONTEXT_QUICK) {
            Integer quickModel = readWeldModelFromCache(CacheKey.LAST_END_WORK_MODEL_QUICK_KEY);
            if (quickModel != null) {
                return quickModel;
            }
        }

        Integer engineerModel = readWeldModelFromCache(CacheKey.ENGINEER_LAST_MODEL_KEY);
        if (engineerModel != null) {
            return engineerModel;
        }
        engineerModel = readWeldModelFromCache(CacheKey.LAST_END_WORK_MODEL_ENGINEER_KEY);
        if (engineerModel != null) {
            return engineerModel;
        }
        Integer quickModel = readWeldModelFromCache(CacheKey.LAST_END_WORK_MODEL_QUICK_KEY);
        if (quickModel != null) {
            return quickModel;
        }
        return ModelConstant.CONTINUOUS_WELDING;
    }

    @Nullable
    private Integer readWeldModelFromCache(@NonNull String key) {
        Integer model = MemoryCacheManager.getInstance().getSerializable(key);
        return isWeldModel(model) ? model : null;
    }

    private boolean isWeldModel(@Nullable Integer model) {
        return model != null
                && (model == ModelConstant.CONTINUOUS_WELDING
                || model == ModelConstant.POINT_WELDING);
    }

    @NonNull
    private ProcessParametersData resolveProcessParameters(@NonNull Context context, int model) {
        ProcessParametersData snapshot = ProcessParametersSnapshotStore.getSnapshot();
        if (snapshot != null && isWeldModel(snapshot.getProcessType())
                && snapshot.getProcessType() == model) {
            return normalizeProcessParameters(snapshot, model);
        }

        ProcessParametersData cacheData = MemoryCacheManager.getInstance()
                .getSerializable(CacheKey.ENGINEER_DATA_CACHE_KEY + model);
        if (cacheData != null) {
            return normalizeProcessParameters(cacheData.clone(), model);
        }

        List<ProcessParametersData> rows = AppDatabase.getInstance(context)
                .processParametersDataDao()
                .selectEngineerAllSync(model);
        if (rows != null && !rows.isEmpty()) {
            return normalizeProcessParameters(rows.get(0).clone(), model);
        }

        ProcessParametersData fallback = model == ModelConstant.POINT_WELDING
                ? DefaultValueUtils.createPointWeldingProcessParametersData()
                : DefaultValueUtils.createContinuousWeldingProcessParametersData();
        return normalizeProcessParameters(fallback, model);
    }

    @NonNull
    private ProcessParametersData normalizeProcessParameters(
            @NonNull ProcessParametersData data,
            int model) {
        data.setProcessType(AUTO_LASER_WELD_MODEL);
        data.setLaserPower(AUTO_LASER_POWER_PERCENT);
        data.setPointWeldingDuration(AUTO_POINT_WELD_DURATION_MS);
        data.setPointWeldingInterval(AUTO_POINT_WELD_INTERVAL_MS);
        data.setSwingWidth(0.0);
        data.setSwingFrequency(0);
        return data;
    }

    @NonNull
    private AdvancedSettings resolveParameterSettings(@NonNull Context context,
                                                      @NonNull ProcessParametersData data) {
        AdvancedSettings settings = AppDatabase.getInstance(context)
                .advancedSettingsDao()
                .selectOne();
        if (settings == null) {
            settings = DefaultValueUtils.createDefaultAdvancedSettings();
        }
        settings.setZeroPointCorrection(AUTO_ZERO_POINT_CORRECTION);
        settings.setLaserEndPower((double) AUTO_LASER_POWER_PERCENT);
        return settings;
    }

    private void logModbusPayload(long runId,
                                  @NonNull String phase,
                                  @Nullable DeviceControlData controlData,
                                  @Nullable ProcessParametersData processParametersData,
                                  @Nullable AdvancedSettings parameterSettings) {
        if (controlData != null) {
            Log.i(TAG, "manual_auto modbus_payload runId=" + runId + " phase=" + phase
                    + " deviceControl=" + GsonUtils.toJson(controlData));
            logRegisters(runId, phase + "_device_control",
                    ModbusFiledBuilder.createDeviceControlData(controlData));
        }
        if (processParametersData != null) {
            Log.i(TAG, "manual_auto modbus_payload runId=" + runId + " phase=" + phase
                    + " processParameters=" + GsonUtils.toJson(processParametersData));
            logRegisters(runId, phase + "_process_params",
                    ModbusFiledBuilder.createProcessParametersData(processParametersData));
        }
        if (parameterSettings != null) {
            Log.i(TAG, "manual_auto modbus_payload runId=" + runId + " phase=" + phase
                    + " parameterSettings=" + GsonUtils.toJson(parameterSettings));
            logRegisters(runId, phase + "_parameter_settings",
                    ModbusFiledBuilder.doCreateWriteDeviceSetting(parameterSettings));
        }
    }

    private static void logRegisters(long runId,
                                     @NonNull String batch,
                                     @NonNull List<ModbusHexData> registers) {
        StringBuilder sb = new StringBuilder();
        for (ModbusHexData item : registers) {
            if (item instanceof ModbusWriteIntFiled field) {
                sb.append(" [addr=").append(field.getAddress())
                        .append(" value=").append(field.getValue())
                        .append(" hex=0x").append(field.getHexData())
                        .append(']');
            }
        }
        Log.i(TAG, "manual_auto modbus_registers runId=" + runId + " batch=" + batch + sb);
    }

    interface OpenCallback {
        void onSuccess();

        void onFailure();
    }
}
