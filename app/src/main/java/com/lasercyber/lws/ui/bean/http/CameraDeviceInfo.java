package com.lasercyber.lws.ui.bean.http;

import com.google.gson.annotations.SerializedName;

import java.io.Serializable;

import lombok.Data;

/**
 * Response body for camera {@code GET /System/deviceinfo}.
 */
@Data
public class CameraDeviceInfo implements Serializable {

    private String deviceName;

    private Integer deviceID;

    private String serialNumber;

    private String macAddress;

    private String appVersion;

    private String deviceType;

    private String deviceModel;

    private Integer runningTime;
}
