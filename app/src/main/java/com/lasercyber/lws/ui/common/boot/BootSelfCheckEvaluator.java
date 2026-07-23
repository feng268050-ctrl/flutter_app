package com.lasercyber.lws.ui.common.boot;

import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.config.DeviceModelConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusOtaExclusiveSession;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusTraffic;
import com.lasercyber.lws.ui.common.utils.AndroidEmulatorUtils;
import com.lasercyber.lws.ui.common.rx.modbus.call.RxModbusCallBack;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledConvert;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusReadFiled;
import com.lasercyber.lws.ui.common.utils.CameraUtils;

import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Synchronous Modbus reads and per-item pass/fail evaluation for boot self-check.
 */
public final class BootSelfCheckEvaluator {

    private static final String TAG = LogTAGConstant.BootSelfCheck;
    static final long MODBUS_READ_TIMEOUT_MS = 3000L;

    @Nullable
    private static Boolean emulatorOverrideForTest;
    @Nullable
    private static Boolean modbusAvailableOverrideForTest;
    @Nullable
    private static Boolean cameraHostConfiguredOverrideForTest;

    private BootSelfCheckEvaluator() {
    }

    /**
     * Modbus-backed self-check items run only on production hardware with an open Modbus link.
     * Emulator builds skip them (mock reads are not treated as real controller data).
     */
    public static boolean isModbusSelfCheckAvailable() {
        if (modbusAvailableOverrideForTest != null) {
            return modbusAvailableOverrideForTest;
        }
        return !isEmulatorSelfCheck() && ModbusManagerRtu.get().isCanSendData();
    }

    /**
     * Camera ping check runs on device always; on emulator only when {@code camera_ip} is set in ROM.
     */
    public static boolean isCameraSelfCheckApplicable() {
        if (isEmulatorSelfCheck()) {
            return isCameraHostConfigured();
        }
        return true;
    }

    static boolean isEmulatorSelfCheck() {
        if (emulatorOverrideForTest != null) {
            return emulatorOverrideForTest;
        }
        return AndroidEmulatorUtils.isLikelyEmulator();
    }

    static boolean isCameraHostConfigured() {
        if (cameraHostConfiguredOverrideForTest != null) {
            return cameraHostConfiguredOverrideForTest;
        }
        return DeviceModelConfig.getCameraIp() != null;
    }

    public static final class ModbusSnapshot {
        @Nullable
        public final DeviceStatus status;
        @Nullable
        public final DeviceData data;
        public final boolean controllerReady;

        ModbusSnapshot(@Nullable DeviceStatus status, @Nullable DeviceData data, boolean controllerReady) {
            this.status = status;
            this.data = data;
            this.controllerReady = controllerReady;
        }
    }

    @Nullable
    public static DeviceStatus readDeviceStatusBlocking(long timeoutMs) {
        if (!ModbusManagerRtu.get().isCanSendData()) {
            Log.w(TAG, "readDeviceStatusBlocking: modbus not ready");
            return null;
        }
        if (ModbusOtaExclusiveSession.checkBlocked(ModbusTraffic.READ) != null) {
            Log.w(TAG, "readDeviceStatusBlocking: deferred — OTA exclusive session active");
            return null;
        }
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<DeviceStatus> result = new AtomicReference<>();
        ModbusManagerRtu.get().readInputRegistersSort(
                ModbusFiledBuilder.createDeviceStatus(),
                new RxModbusCallBack() {
                    @Override
                    public void onSuccess(List<ModbusReadFiled> modbusReadFields) {
                        result.set(ModbusFiledConvert.mergeDeviceStatusFromPoll(
                                modbusReadFields, new DeviceStatus()));
                        latch.countDown();
                    }

                    @Override
                    public void onFailure(Throwable throwable) {
                        Log.w(TAG, "readDeviceStatusBlocking failed", throwable);
                        latch.countDown();
                    }
                });
        awaitLatch(latch, timeoutMs);
        return result.get();
    }

    @Nullable
    public static ModbusSnapshot readFullModbusSnapshotBlocking(long timeoutMs) {
        if (!ModbusManagerRtu.get().isCanSendData()) {
            Log.w(TAG, "readFullModbusSnapshotBlocking: modbus not ready");
            return new ModbusSnapshot(null, null, false);
        }
        if (ModbusOtaExclusiveSession.checkBlocked(ModbusTraffic.READ) != null) {
            Log.w(TAG, "readFullModbusSnapshotBlocking: deferred — OTA exclusive session active");
            return new ModbusSnapshot(null, null, false);
        }
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<DeviceStatus> statusRef = new AtomicReference<>();
        AtomicReference<DeviceData> dataRef = new AtomicReference<>();

        ModbusManagerRtu.get().readInputRegistersSort(
                ModbusFiledBuilder.createDeviceStatus(),
                new RxModbusCallBack() {
                    @Override
                    public void onSuccess(List<ModbusReadFiled> modbusReadFields) {
                        statusRef.set(ModbusFiledConvert.mergeDeviceStatusFromPoll(
                                modbusReadFields, new DeviceStatus()));
                        ModbusManagerRtu.get().readInputRegistersSort(
                                ModbusFiledBuilder.createDeviceData(),
                                new RxModbusCallBack() {
                                    @Override
                                    public void onSuccess(List<ModbusReadFiled> dataFields) {
                                        dataRef.set(ModbusFiledConvert.mergeDeviceDataFromPoll(
                                                dataFields, new DeviceData()));
                                        latch.countDown();
                                    }

                                    @Override
                                    public void onFailure(Throwable throwable) {
                                        Log.w(TAG, "readFullModbusSnapshotBlocking data failed", throwable);
                                        latch.countDown();
                                    }
                                });
                    }

                    @Override
                    public void onFailure(Throwable throwable) {
                        Log.w(TAG, "readFullModbusSnapshotBlocking status failed", throwable);
                        latch.countDown();
                    }
                });

        awaitLatch(latch, timeoutMs);
        DeviceStatus status = statusRef.get();
        DeviceData data = dataRef.get();
        boolean controllerReady = isValidDeviceStatus(status);
        return new ModbusSnapshot(status, data, controllerReady);
    }

    public static boolean evaluateControllerReady(@Nullable DeviceStatus status) {
        return isValidDeviceStatus(status);
    }

    public static BootSelfCheckStatus evaluateItem(
            BootSelfCheckItem item,
            @Nullable ModbusSnapshot snapshot,
            boolean controllerReady) {
        if (item == BootSelfCheckItem.CAMERA_COMM) {
            if (!isCameraSelfCheckApplicable()) {
                return BootSelfCheckStatus.SKIPPED;
            }
            return CameraUtils.checkCameraBlocking() ? BootSelfCheckStatus.PASS : BootSelfCheckStatus.FAIL;
        }
        if (!isModbusSelfCheckAvailable()) {
            return BootSelfCheckStatus.SKIPPED;
        }
        if (!controllerReady) {
            return BootSelfCheckStatus.SKIPPED;
        }
        if (snapshot == null || !snapshot.controllerReady) {
            return BootSelfCheckStatus.FAIL;
        }
        DeviceStatus status = snapshot.status;
        DeviceData data = snapshot.data;
        if (status == null) {
            return BootSelfCheckStatus.FAIL;
        }
        switch (item) {
            case CONTROLLER_COMM:
                return BootSelfCheckStatus.PASS;
            case PUMP_COMM:
                return commPass(!status.isLaserCommunicationAlarm());
            case GUN_COMM:
                return commPass(!status.isGunCommunicationAlarm());
            case WIRE_FEEDER_COMM:
                return commPass(!status.isWireFeederCommunicationAlarm());
            case MOTOR_DRIVER_TEMP:
                return temperaturePass(status, data, !status.isDriverTemperatureAlarm(), data != null && data.hasGunDriverBoardTempValue());
            case GUN_MOTOR_TEMP:
                return temperaturePass(status, data, !status.isGunMotorOverTemperatureAlarm(), data != null && data.hasGunMotorTempValue());
            case PROTECTION_MIRROR_TEMP:
                return temperaturePass(status, data, !status.isProtectionBoardTemperatureAlarm(), data != null && data.hasProtectionBoardTempValue());
            case COLLIMATOR_TEMP:
                return temperaturePass(status, data, !status.isStraightTrackTemperatureAlarm(), data != null && data.hasCollimatorTempValue());
            default:
                return BootSelfCheckStatus.FAIL;
        }
    }

    private static BootSelfCheckStatus commPass(boolean healthy) {
        return healthy ? BootSelfCheckStatus.PASS : BootSelfCheckStatus.FAIL;
    }

    private static BootSelfCheckStatus temperaturePass(
            DeviceStatus status,
            @Nullable DeviceData data,
            boolean healthy,
            boolean hasValue) {
        if (data == null || !isValidDeviceStatus(status) || !hasValue) {
            return BootSelfCheckStatus.FAIL;
        }
        return healthy ? BootSelfCheckStatus.PASS : BootSelfCheckStatus.FAIL;
    }

    /**
     * Same validity rule as {@link com.lasercyber.lws.ui.activitys.device.monitor.fragment.WarnInfoFragment}.
     */
    static boolean isValidDeviceStatus(@Nullable DeviceStatus status) {
        return status != null && status.getDeviceType() != null && status.getDeviceType() > 0;
    }

    private static void awaitLatch(CountDownLatch latch, long timeoutMs) {
        try {
            latch.await(timeoutMs, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            Log.w(TAG, "modbus read interrupted");
        }
    }

    /** Visible for unit tests. */
    static void resetForTest() {
        emulatorOverrideForTest = null;
        modbusAvailableOverrideForTest = null;
        cameraHostConfiguredOverrideForTest = null;
    }

    /** Visible for unit tests. */
    static void setEmulatorForTest(boolean emulator) {
        emulatorOverrideForTest = emulator;
    }

    /** Visible for unit tests. */
    static void setModbusAvailableForTest(boolean available) {
        modbusAvailableOverrideForTest = available;
    }

    /** Visible for unit tests. */
    static void setCameraHostConfiguredForTest(boolean configured) {
        cameraHostConfiguredOverrideForTest = configured;
    }
}
