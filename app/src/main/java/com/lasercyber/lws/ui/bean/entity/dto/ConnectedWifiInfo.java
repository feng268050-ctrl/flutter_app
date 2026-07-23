package com.lasercyber.lws.ui.bean.entity.dto;

import java.io.Serializable;

import lombok.Data;

/**
 * Connected Wi-Fi metadata for remote snapshot {@code wifiInfo} and UI (Wi-Fi details screen).
 * Scalar fields use {@code null} when unavailable (not UI placeholder strings).
 */
@Data
public class ConnectedWifiInfo implements Serializable {
    private String ssid;
    private String bssid;
    private String capabilities;
    private String ipAddress;
    private String subnetMask;
    private String router;
    private String dns;
    private Integer rssi;
    private Integer linkSpeed;
    private Integer frequency;
    private String securityType;
    private String macAddress;
}
