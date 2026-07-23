package com.lasercyber.lws.ui.activitys.setting.model;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;

import com.blankj.utilcode.util.GsonUtils;
import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.activitys.BaseViewModel;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.camera.CameraDeviceInfoCache;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.config.DeviceModelConfig;
import com.lasercyber.lws.ui.common.version.LibraryVersionHelper;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.device.DeviceIdentity;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledConvert;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.network.http.remote.CameraRemote;

import java.util.Objects;

import cn.hutool.core.util.ObjectUtil;
import lombok.Data;
import lombok.EqualsAndHashCode;

/*切割；穿孔功率 、穿孔占空比， 就是激光功率\激光占空比
连续焊接： 激光频率、激光占空比、送丝延迟。
点焊接： 激光频率、激光占空比。*/

@EqualsAndHashCode(callSuper = true)
@Data
public class DeviceInfoViewModel extends BaseViewModel<DeviceInfo> implements MemoryCacheManager.OnCacheChangedListener {
    /** Placeholder when {@link DeviceStatus#getSoftwareVersion()} and DB have no firmware string yet (control-card style, not semver). */
    private static final String DEFAULT_FIRMWARE_VERSION = "1000";

    private AppDatabase instance;
    /** Installed APK {@code versionName} for Settings binding (not persisted as a duplicate Room column). */
    private final MutableLiveData<String> installedAppVersion = new MutableLiveData<>("");

    /** Camera {@code appVersion} from HTTP deviceinfo; not persisted in Room. */
    private final MutableLiveData<String> cameraVersionDisplay =
            new MutableLiveData<>(CameraRemote.CAMERA_VERSION_UNAVAILABLE);

    public LiveData<String> getCameraVersionDisplay() {
        return cameraVersionDisplay;
    }

    public void refreshCameraVersion(@NonNull Context context) {
        Log.d(TAG, "refreshCameraVersion: refreshing camera version cache");
        cameraVersionDisplay.postValue(CameraDeviceInfoCache.getDisplay());
        CameraDeviceInfoCache.clearAndRefresh(context);
    }

    private void syncCameraVersionFromCache() {
        cameraVersionDisplay.postValue(CameraDeviceInfoCache.getDisplay());
    }

    public void init( Context context ) {
        instance = AppDatabase.getInstance( context );
        LiveData<DeviceInfo> deviceInfoLiveData = instance.deviceInfoDto().queryLast();
        // 拉取数据
        requestData();
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_STATUS_KEY, this);
        MemoryCacheManager.getInstance().addListener(CacheKey.CAMERA_VERSION_DISPLAY, this);
        syncCameraVersionFromCache();
        deviceInfoLiveData.observeForever(info -> {
            if ( info == null ){
                info = new DeviceInfo();
            }
            try {
                PackageInfo packageInfo = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
                Log.d(TAG, "init: 获取包信息:" + GsonUtils.toJson(packageInfo));
                String versionName = packageInfo.versionName;
                installedAppVersion.postValue(versionName != null ? versionName : "");
            } catch (PackageManager.NameNotFoundException e) {
                Log.e(TAG, "init: 获取UI版本异常", e);
                installedAppVersion.postValue(BuildConfig.VERSION_NAME != null ? BuildConfig.VERSION_NAME : "");
            }
            info.setDeviceSn(getDeviceSnSafely());
            Log.d(TAG, "init: 加载的设备信息:"+info);
            mergeFirmwareFromDeviceStatus(info);
            applyEmptyDeviceInfoDefaults(info);

            super.postLiveData(info);
            MemoryCacheManager.getInstance().putSerializableNoNotice(CacheKey.DEVICE_INFO_KEY, info);
        });
    }

    /*更新或添加设备信息*/
    public void updateOrAddInfo( DeviceInfo info,Context context ){
        instance= AppDatabase.getInstance(context);
        ThreadPoolManager.getExecutor().execute(()-> {
            saveDeviceInfoSingleRow(info);
        });
    }

    public DeviceInfo getData(Context context) {
        instance= AppDatabase.getInstance(context);
        DeviceInfo info = instance.deviceInfoDto().getOneData();
        // 拉取数据
        requestData();
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_STATUS_KEY, this);
        MemoryCacheManager.getInstance().addListener(CacheKey.CAMERA_VERSION_DISPLAY, this);
        syncCameraVersionFromCache();
            if ( info == null ){
                info = new DeviceInfo();
            }
            info.setDeviceSn(getDeviceSnSafely());
            Log.d(TAG, "init: 加载的设备信息:"+info);
            mergeFirmwareFromDeviceStatus(info);
            applyEmptyDeviceInfoDefaults(info);
            try {
                PackageInfo packageInfo = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
                String versionName = packageInfo.versionName;
                installedAppVersion.postValue(versionName != null ? versionName : "");
            } catch (PackageManager.NameNotFoundException e) {
                installedAppVersion.postValue(BuildConfig.VERSION_NAME != null ? BuildConfig.VERSION_NAME : "");
            }
            super.postLiveData(info);
            MemoryCacheManager.getInstance().putSerializableNoNotice(CacheKey.DEVICE_INFO_KEY, info);
            return info;
    }

    /** Same empty-field fallbacks as {@link #init(Context)} (Settings display + cache / snapshot pack). */
    private static void applyEmptyDeviceInfoDefaults(DeviceInfo info) {
        if (info == null) {
            return;
        }
        info.setModel(DeviceModelConfig.getModel());
        info.setFocusScaleRef(DeviceModelConfig.getFocusScaleRef());
        ensureFirmwarePlaceholder(info);
        if (null == info.getGunSn() || ObjectUtil.equals(info.getGunSn(), "")) {
            info.setGunSn("WE16616");
        }
        if (null == info.getLaserVersion() || ObjectUtil.equals(info.getLaserVersion(), "")) {
            info.setLaserVersion("1.0");
        }
        if (LibraryVersionHelper.isUnset(info.getProcessLibVersion())) {
            info.setProcessLibVersion(LibraryVersionHelper.DISPLAY_PLACEHOLDER);
        }
        if (null == info.getWireFeederVersion() || ObjectUtil.equals(info.getWireFeederVersion(), "")) {
            info.setWireFeederVersion("1.0");
        }
    }

    /** Prefer {@link DeviceStatus#getSoftwareVersion()} over DB placeholder when available. */
    private static boolean mergeFirmwareFromDeviceStatus(DeviceInfo info) {
        if (info == null) {
            return false;
        }
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (deviceStatus == null) {
            return false;
        }
        Integer softwareVersion = deviceStatus.getSoftwareVersion();
        if (softwareVersion == null) {
            return false;
        }
        String fromStatus = String.valueOf(softwareVersion);
        if (Objects.equals(info.getFirmwareVersion(), fromStatus)) {
            return false;
        }
        info.setFirmwareVersion(fromStatus);
        return true;
    }

    private static void ensureFirmwarePlaceholder(DeviceInfo info) {
        if (info == null) {
            return;
        }
        if (ObjectUtil.isEmpty(info.getFirmwareVersion())) {
            info.setFirmwareVersion(DEFAULT_FIRMWARE_VERSION);
        }
    }

    /**
     * When {@link DeviceStatus} updates, mirror {@code softwareVersion} into {@link DeviceInfo#getFirmwareVersion()}.
     */
    public void readControllerCardVersion(){
        DeviceInfo deviceInfo = super.getData();
        if (deviceInfo == null) {
            deviceInfo = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_INFO_KEY);
        }
        if (deviceInfo == null) {
            return;
        }
        if (mergeFirmwareFromDeviceStatus(deviceInfo)) {
            super.postLiveData(deviceInfo);
            MemoryCacheManager.getInstance().putSerializableNoNotice(CacheKey.DEVICE_INFO_KEY, deviceInfo);
        }
    }
    /**
     * 主动和拉取设备上的数据
     */
    public void requestData(){
        Log.d(TAG, "requestData: 正在拉取设备信息");
        ModbusManagerRtu.get().readInputRegisters(ModbusFiledBuilder.createDeviceInfo(), modbusReadFields -> {
            ThreadPoolManager.getExecutor().execute(()->{
                // 成功读取到数据
                DeviceInfo base = super.getData();
                if (base == null) {
                    base = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_INFO_KEY);
                }
                if (base == null) {
                    base = new DeviceInfo();
                }
                DeviceInfo deviceInfo = ModbusFiledConvert.deviceInfoConvert(modbusReadFields, base);
                deviceInfo.setDeviceSn(getDeviceSnSafely());
                mergeFirmwareFromDeviceStatus(deviceInfo);
                applyEmptyDeviceInfoDefaults(deviceInfo);
                saveDeviceInfoSingleRow(deviceInfo);
                Log.d(TAG, "拉取到的设备信息:"+ GsonUtils.toJson(deviceInfo));
                DeviceInfoViewModel.super.postLiveData(deviceInfo);
            });
        });
    }

    @Override
    public void onCacheChanged(String key) {
        if (CacheKey.CAMERA_VERSION_DISPLAY.equals(key)) {
            syncCameraVersionFromCache();
            return;
        }
        readControllerCardVersion();
    }

    /**
     * 销毁
     */
    public void destroy(){
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);
        MemoryCacheManager.getInstance().removeListener(CacheKey.CAMERA_VERSION_DISPLAY, this);
    }

    private String getDeviceSnSafely() {
        return DeviceIdentity.getDeviceSnSafely();
    }

    private void saveDeviceInfoSingleRow(DeviceInfo incoming) {
        if (incoming == null) {
            return;
        }
        incoming.setProcessLibVersion(LibraryVersionHelper.normalizeForStorage(incoming.getProcessLibVersion()));
        DeviceInfo last = instance.deviceInfoDto().getOneData();
        DeviceInfo lastWithLibVer = instance.deviceInfoDto().getLastWithLibraryVersions();
        if (last != null) {
            if (LibraryVersionHelper.isUnset(incoming.getProcessLibVersion())) {
                if (!LibraryVersionHelper.isUnset(last.getProcessLibVersion())) {
                    incoming.setProcessLibVersion(last.getProcessLibVersion());
                } else if (lastWithLibVer != null
                        && !LibraryVersionHelper.isUnset(lastWithLibVer.getProcessLibVersion())) {
                    incoming.setProcessLibVersion(lastWithLibVer.getProcessLibVersion());
                }
            }
            incoming.setId(last.getId());
            instance.deviceInfoDto().update(incoming);
            instance.deviceInfoDto().deleteOthers(last.getId());
        } else {
            long insertId = instance.deviceInfoDto().insert(incoming);
            incoming.setId((int) insertId);
        }
    }
}
