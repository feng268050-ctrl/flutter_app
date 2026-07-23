package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.camera.CameraCommStatus;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.state.ProcessParametersSnapshotStore;

import java.util.Objects;

/**
 * Best-effort {@code deviceStatus}/{@code deviceData}/{@code processParameters} snapshot for monitor SSE.
 */
public final class MonitorStatSnapshot {

    @Nullable
    private final DeviceStatus deviceStatus;
    @Nullable
    private final DeviceData deviceData;
    @Nullable
    private final ProcessParametersData processParameters;

    private MonitorStatSnapshot(@Nullable DeviceStatus deviceStatus,
                                @Nullable DeviceData deviceData,
                                @Nullable ProcessParametersData processParameters) {
        this.deviceStatus = deviceStatus;
        this.deviceData = deviceData;
        this.processParameters = processParameters;
    }

    @NonNull
    public static MonitorStatSnapshot fromCache() {
        DeviceStatus rawStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        DeviceData rawData = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_DATA_KEY);
        int cameraStatus = CameraCommStatus.isFault() ? 0 : 1;
        return fromRaw(rawStatus, rawData, cameraStatus, ProcessParametersSnapshotStore.getSnapshot());
    }

    @VisibleForTesting
    @NonNull
    static MonitorStatSnapshot fromRaw(@Nullable DeviceStatus rawStatus,
                                       @Nullable DeviceData rawData,
                                       int cameraStatus) {
        return fromRaw(rawStatus, rawData, cameraStatus, null);
    }

    @VisibleForTesting
    @NonNull
    static MonitorStatSnapshot fromRaw(@Nullable DeviceStatus rawStatus,
                                       @Nullable DeviceData rawData,
                                       int cameraStatus,
                                       @Nullable ProcessParametersData processParameters) {
        DeviceStatus statusOut = rawStatus != null ? rawStatus.clone() : null;
        if (statusOut != null) {
            statusOut.setCameraStatus(cameraStatus);
        }
        DeviceData dataOut = rawData != null ? rawData.clone() : null;
        ProcessParametersData paramsOut = processParameters != null ? processParameters.clone() : null;
        return new MonitorStatSnapshot(statusOut, dataOut, paramsOut);
    }

    @Nullable
    public DeviceStatus getDeviceStatus() {
        return deviceStatus;
    }

    @Nullable
    public DeviceData getDeviceData() {
        return deviceData;
    }

    @Nullable
    public ProcessParametersData getProcessParameters() {
        return processParameters;
    }

    public boolean changedSince(@Nullable MonitorStatSnapshot previous) {
        if (previous == null) {
            return deviceStatus != null || deviceData != null || processParameters != null;
        }
        return fieldChanged(previous.deviceStatus, deviceStatus)
                || fieldChanged(previous.deviceData, deviceData)
                || processParametersChanged(previous.processParameters, processParameters);
    }

  private static <T extends com.lasercyber.lws.ui.bean.ui.DataEquals<T>> boolean fieldChanged(
            @Nullable T previous,
            @Nullable T current) {
        if (previous == null && current == null) {
            return false;
        }
        if (previous == null || current == null) {
            return true;
        }
        return previous.dataChange(current);
    }

    private static boolean processParametersChanged(@Nullable ProcessParametersData previous,
                                                    @Nullable ProcessParametersData current) {
        if (previous == null && current == null) {
            return false;
        }
        return !Objects.equals(previous, current);
    }

    @NonNull
    MonitorStatSnapshot copy() {
        DeviceStatus statusCopy = deviceStatus != null ? deviceStatus.clone() : null;
        DeviceData dataCopy = deviceData != null ? deviceData.clone() : null;
        ProcessParametersData paramsCopy = processParameters != null ? processParameters.clone() : null;
        return new MonitorStatSnapshot(statusCopy, dataCopy, paramsCopy);
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        if (!(other instanceof MonitorStatSnapshot)) {
            return false;
        }
        MonitorStatSnapshot that = (MonitorStatSnapshot) other;
        return Objects.equals(deviceStatus, that.deviceStatus)
                && Objects.equals(deviceData, that.deviceData)
                && Objects.equals(processParameters, that.processParameters);
    }

    @Override
    public int hashCode() {
        return Objects.hash(deviceStatus, deviceData, processParameters);
    }
}
