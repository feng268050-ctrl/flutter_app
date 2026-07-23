package com.lasercyber.lws.ui.activitys.device.monitor.fragment;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.enums.UnitSystem;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.rx.modbus.task.RxTaskManager;
import com.lasercyber.lws.ui.common.camera.CameraCommStatus;
import com.lasercyber.lws.ui.common.config.DeviceModelConfig;
import com.lasercyber.lws.ui.common.utils.AndroidEmulatorUtils;
import com.lasercyber.lws.ui.databinding.FragmentWarnInfoBinding;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

/**
 * A simple {@link Fragment} subclass.
 * create an instance of this fragment.
 * 告警信息
 */
public class WarnInfoFragment extends BaseFragment<FragmentWarnInfoBinding> implements MemoryCacheManager.OnCacheChangedListener {
    private static final String TAG = LogTAGConstant.WarnInfoFragment;

    private final List<String> taskIdList = new ArrayList<>();
    private DeviceStatus deviceStatus;
    private DeviceData deviceData = new DeviceData();
    private boolean deviceStatusReady;
    private boolean deviceDataReady;
    private String temperatureDisplayUnit = UnitSystem.METRIC.getWireValue();

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_warn_info;
    }

    @Override
    protected void initView() {
        getChildFragmentManager().beginTransaction()
                .add(R.id.warn_log, new WarnLogFragment())
                .commitNow();
    }

    @Override
    protected void initData() {
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_STATUS_KEY, this);
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_DATA_KEY, this);
        MemoryCacheManager.getInstance().addListener(CacheKey.CAMERA_PING_REACHABLE, this);
        RxTaskManager.getInstance().batchCancelTask(taskIdList);
        observeCommonSettingsUnit();
        applyDeviceDataWithDisplayUnit(this.deviceData);
        binding.setEmulator(AndroidEmulatorUtils.isLikelyEmulator());
        binding.setCameraHostConfigured(DeviceModelConfig.getCameraIp() != null);
        binding.setCameraCommFault(CameraCommStatus.isFault());
        updateData();
        updateDataStatus();
    }

    private void updateData() {
        if (binding == null) {
            return;
        }
        DeviceStatus cacheData = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        boolean ready = isValidDeviceStatus(cacheData);
        DeviceStatus nextStatus = ready ? cacheData.clone() : new DeviceStatus();
        if (deviceStatus != null
                && deviceStatusReady == ready
                && !alarmInfoPanelStatusChanged(deviceStatus, nextStatus)) {
            return;
        }
        deviceStatus = nextStatus;
        deviceStatusReady = ready;
        Log.d(TAG, "updateData: 告警面板状态变化:" + deviceStatus);
        binding.setDeviceStatus(deviceStatus);
        binding.setStatusReady(deviceStatusReady);
    }

    private void updateDataStatus() {
        if (binding == null) {
            return;
        }
        DeviceData cacheData = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_DATA_KEY);
        boolean ready = cacheData != null
                && isValidDeviceStatus(MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY));
        DeviceData nextData = ready ? cacheData.clone() : new DeviceData();
        nextData.setDisplayUnit(temperatureDisplayUnit);
        if (deviceData != null
                && deviceDataReady == ready
                && !alarmInfoPanelDataChanged(deviceData, nextData)) {
            return;
        }
        Log.d(TAG, "updateDataStatus: 告警面板数据变化:" + cacheData);
        deviceDataReady = ready;
        applyDeviceDataWithDisplayUnit(nextData);
        binding.setDataReady(deviceDataReady);
    }

    private boolean isValidDeviceStatus(DeviceStatus status) {
        return status != null && status.getDeviceType() != null && status.getDeviceType() > 0;
    }

    @Override
    public void onCacheChanged(String key) {
        handler.post(() -> {
            if (Objects.equals(key, CacheKey.DEVICE_STATUS_KEY)) {
                updateData();
            } else if (Objects.equals(key, CacheKey.DEVICE_DATA_KEY)) {
                updateDataStatus();
            } else if (Objects.equals(key, CacheKey.CAMERA_PING_REACHABLE)) {
                updateCameraCommStatus();
            }
        });
    }

    private void observeCommonSettingsUnit() {
        AppDatabase.getInstance(requireContext()).commonSettingsDao().selectOneLiveData()
                .observe(getViewLifecycleOwner(), this::applyTemperatureDisplayUnit);
    }

    private void applyTemperatureDisplayUnit(CommonSettings commonSettings) {
        String unit = commonSettings != null && commonSettings.getUnit() != null
                ? commonSettings.getUnit()
                : UnitSystem.METRIC.getWireValue();
        if (Objects.equals(temperatureDisplayUnit, unit)) {
            return;
        }
        temperatureDisplayUnit = unit;
        applyDeviceDataWithDisplayUnit(deviceData);
    }

    private void applyDeviceDataWithDisplayUnit(DeviceData data) {
        if (data == null) {
            data = new DeviceData();
        }
        data.setDisplayUnit(temperatureDisplayUnit);
        if (deviceData != null
                && Objects.equals(deviceData.getDisplayUnit(), data.getDisplayUnit())
                && !alarmInfoPanelDataChanged(deviceData, data)) {
            return;
        }
        this.deviceData = data;
        if (binding != null) {
            binding.setDeviceData(this.deviceData);
        }
    }

    private void updateCameraCommStatus() {
        if (binding == null) {
            return;
        }
        boolean fault = CameraCommStatus.isFault();
        if (binding.getCameraCommFault() == fault) {
            return;
        }
        binding.setCameraCommFault(fault);
    }

    private static boolean alarmInfoPanelStatusChanged(
            @NonNull DeviceStatus current,
            @NonNull DeviceStatus next) {
        return current.isLaserCommunicationAlarm() != next.isLaserCommunicationAlarm()
                || current.isGunCommunicationAlarm() != next.isGunCommunicationAlarm()
                || current.isWireFeederCommunicationAlarm() != next.isWireFeederCommunicationAlarm()
                || current.isGunMotorOverTemperatureAlarm() != next.isGunMotorOverTemperatureAlarm()
                || current.isDriverTemperatureAlarm() != next.isDriverTemperatureAlarm()
                || current.isProtectionBoardTemperatureAlarm() != next.isProtectionBoardTemperatureAlarm()
                || current.isStraightTrackTemperatureAlarm() != next.isStraightTrackTemperatureAlarm()
                || !Objects.equals(current.getDeviceType(), next.getDeviceType());
    }

    private static boolean alarmInfoPanelDataChanged(
            @NonNull DeviceData current,
            @NonNull DeviceData next) {
        return !Objects.equals(current.getGunMotorTempText(), next.getGunMotorTempText())
                || !Objects.equals(current.getGunDriverBoardTempText(), next.getGunDriverBoardTempText())
                || !Objects.equals(current.getProtectionBoardTempText(), next.getProtectionBoardTempText())
                || !Objects.equals(current.getCollimatorTempText(), next.getCollimatorTempText());
    }

    @Override
    public void onDestroyView() {
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_DATA_KEY, this);
        MemoryCacheManager.getInstance().removeListener(CacheKey.CAMERA_PING_REACHABLE, this);
        RxTaskManager.getInstance().batchCancelTask(taskIdList);
        super.onDestroyView();
    }
}
