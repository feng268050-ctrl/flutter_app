package com.lasercyber.lws.ui.common.handler;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;

import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.activitys.device.monitor.fragment.WarnInfoFragment;
import com.lasercyber.lws.ui.activitys.setting.model.DeviceInfoViewModel;
import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.StaticData;
import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.bean.entity.dto.DeviceInfoVo;
import com.lasercyber.lws.ui.bean.entity.dto.DeviceRemoteSnapshot;
import com.lasercyber.lws.ui.bean.entity.vo.WarnTableVo;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.device.DeviceIdentity;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockStore;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.camera.CameraCommStatus;
import com.lasercyber.lws.ui.common.state.ProcessParametersSnapshotStore;
import com.lasercyber.lws.ui.common.utils.CommonUseTextResolver;
import com.lasercyber.lws.ui.common.utils.WifiStatusUtils;
import com.lasercyber.lws.ui.common.camera.CameraDeviceInfoCache;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.config.DeviceModelConfig;
import com.lasercyber.lws.ui.repository.StaticDataDao;

import java.util.List;

import cn.hutool.core.util.ObjectUtil;

/*设备数据提交后台*/
public class DeviceStatusPut{

    /*封装设备上报的全部信息*/
    public DeviceInfoVo packVoData(Context context){
        DeviceInfoVo vo = new DeviceInfoVo();

        vo.setStaticData(getStaticData(context) );
        vo.setDeviceInfo(getDeviceInfo(context) );
        vo.setCommonSettings(getCommonSettings(context));
        vo.setDeviceStatus(getDeviceStatus(context) );
        vo.setDeviceData(getDeviceData(context) );
        vo.setWarns(getWarnList(context));

        return vo;
    }

    /**
     * Same field assembly as {@link #packVoData(Context)} but returns a transport-neutral snapshot
     * without a top-level {@code device} object (for WebSocket {@code command.stat_response}).
     */
    public DeviceRemoteSnapshot packRemoteSnapshot(Context context) {
        DeviceRemoteSnapshot snapshot = DeviceRemoteSnapshot.fromDeviceInfoVo(packVoData(context));
        if (snapshot != null && snapshot.getDeviceStatus() != null) {
            snapshot.getDeviceStatus().setCameraStatus(CameraCommStatus.isFault() ? 0 : 1);
        }
        snapshot.setProcessParameters(ProcessParametersSnapshotStore.getSnapshot());
        snapshot.setIsLocked(DeviceRemoteLockStore.isLocked());
        snapshot.setWifiInfo(WifiStatusUtils.getConnectedWifiInfo(context));
        return snapshot;
    }

    /*1、设备自定义布局内容*/
    private StaticData getStaticData(Context context){
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        StaticDataDao staticDataDao = appDataBase.staticDataDao();
        StaticData data = staticDataDao.getOneData();
        CommonUseTextResolver.fillForRemoteSnapshot(data);
        return data;
    }

    /*2、设备基础信息*/
    private DeviceInfo getDeviceInfo( Context context ){
        DeviceInfo deviceInfo= MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_INFO_KEY);
        if( ObjectUtil.isNull( deviceInfo ) ){
            //如果没有，则进行拉取
            DeviceInfoViewModel model = new DeviceInfoViewModel();
            deviceInfo = model.getData(context);
        }
        applyInstalledSystemVersionFromPackage(context, deviceInfo);
        if (deviceInfo != null) {
            // Canonical SN for protocol / cloud is always DeviceIdentity (never trust Room or Modbus copy).
            deviceInfo.setDeviceSn(DeviceIdentity.getDeviceSnSafely());
            deviceInfo.setCameraVersion(CameraDeviceInfoCache.getDisplay());
            deviceInfo.setCameraIp(CameraConfig.getCameraIp());
            String hostIp = DeviceModelConfig.getHostIp();
            deviceInfo.setHostIp(hostIp != null ? hostIp : "");
            deviceInfo.setFocusScaleRef(DeviceModelConfig.getFocusScaleRef());
        }
        return deviceInfo;
    }

    /** Fills transient {@link DeviceInfo#getSystemVersion()} from installed APK (not from Room). */
    public static void applyInstalledSystemVersionFromPackage(Context context, DeviceInfo deviceInfo) {
        if (deviceInfo == null || context == null) {
            return;
        }
        try {
            PackageInfo pi = context.getApplicationContext().getPackageManager()
                    .getPackageInfo(context.getPackageName(), 0);
            if (pi.versionName != null && !pi.versionName.trim().isEmpty()) {
                deviceInfo.setSystemVersion(pi.versionName.trim());
            } else {
                deviceInfo.setSystemVersion(BuildConfig.VERSION_NAME != null ? BuildConfig.VERSION_NAME : "");
            }
        } catch (PackageManager.NameNotFoundException e) {
            deviceInfo.setSystemVersion(BuildConfig.VERSION_NAME != null ? BuildConfig.VERSION_NAME : "");
        }
    }

    private CommonSettings getCommonSettings(Context context) {
        return AppDatabase.getInstance(context).commonSettingsDao().selectOne();
    }

    /*4、设备状态信息 不需要实时拉取*/
    private DeviceStatus getDeviceStatus(Context context){
        DeviceStatus deviceStatus= MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        return deviceStatus;
    }

    /*5、设备数据 需要实时拉取*/
    private DeviceData getDeviceData(Context context) {
        return MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_DATA_KEY);
    }

    /*6、告警列表*/
    private List<WarnTable> getWarnList(Context context) {
        return WarnListLoader.loadLocalizedWarnList(context);
    }


}
