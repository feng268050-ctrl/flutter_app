package com.lasercyber.lws.ui.bean.entity;

import androidx.room.ColumnInfo;
import androidx.room.Entity;
import androidx.room.Ignore;
import androidx.room.PrimaryKey;

import com.google.gson.annotations.SerializedName;

import java.io.Serializable;

import lombok.Data;

@Data
@Entity(tableName = "t_device_info")
public class DeviceInfo implements Serializable {
    @PrimaryKey(autoGenerate = true)
    private Integer id;
    /**
     * 设备型号
     */
    private String model ="";
    /**
     * 固件版本
     */
    private String firmwareVersion ="";
    /**
     * 枪头Sn
     */
    private String gunSn ="";
    /**
     * 主控Sn
     */
    private String mainControlSn ="";
    /**
     * 激光固件版本
     */
    private String laserVersion ="";
    /**
     * 激光器硬件版本
     */
    private String laserHardwareVersion ="";
    /**
     * Not stored in Room. Installed APK {@code versionName} for remote payloads; matches Settings "System Version".
     */
    @Ignore
    private String systemVersion = "";
    /**
     * 工艺库版本
     */
    private String processLibVersion ="";
    /**
     * 送丝机固件版本
     */
    private String wireFeederVersion ="";
    /**
     * 送丝机硬件版本
     */
    private String wireFeederHardwareVersion ="";
    /**
     * 枪头硬件版本
     */
    private String gunHeadHardwareVersion ="";
    /**
     * 枪头软件版本
     */
    private String gunHeadSoftwareVersion ="";

    /**
     * Legacy DB column kept for migration compatibility; AI ships with the app APK and is not versioned separately.
     */
    @SerializedName("aiVersion")
    @ColumnInfo(name = "AIVersion")
    private String aiVersion = "";

    /**
     * Persisted column; for outbound API/WS payloads prefer {@link com.lasercyber.lws.ui.common.device.DeviceIdentity#getDeviceSnSafely()}.
     */
    private String deviceSn="";

    /**
     * Not stored in Room. Camera {@code appVersion} from {@link com.lasercyber.lws.ui.common.camera.CameraDeviceInfoCache}.
     */
    @Ignore
    private String cameraVersion = "";

    /**
     * Not stored in Room. Effective camera host IPv4 from {@link com.lasercyber.lws.ui.common.config.CameraConfig#getCameraIp()}.
     */
    @Ignore
    private String cameraIp = "";

    /**
     * Not stored in Room. Dev host LAN IPv4 from ROM {@code host_ip} ({@link com.lasercyber.lws.ui.common.config.DeviceModelConfig#getHostIp()}).
     */
    @Ignore
    private String hostIp = "";

    /**
     * Not stored in Room. Gun-head focus scale reference from ROM {@code focus_scale_ref}
     * ({@link com.lasercyber.lws.ui.common.config.DeviceModelConfig#getFocusScaleRef()}).
     */
    @Ignore
    private int focusScaleRef = 0;
}
