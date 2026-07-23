package com.lasercyber.lws.ui.common.network.wifi;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

public final class WifiConnectRequest {

    @NonNull
    public final String ssid;
    @Nullable
    public final String password;
    @NonNull
    public final String securityType;
    @NonNull
    public final WifiIpConfig ipConfig;
    public final boolean hiddenSsid;

    public WifiConnectRequest(
            @NonNull String ssid,
            @Nullable String password,
            @NonNull String securityType,
            @NonNull WifiIpConfig ipConfig) {
        this(ssid, password, securityType, ipConfig, false);
    }

    public WifiConnectRequest(
            @NonNull String ssid,
            @Nullable String password,
            @NonNull String securityType,
            @NonNull WifiIpConfig ipConfig,
            boolean hiddenSsid) {
        this.ssid = ssid;
        this.password = password;
        this.securityType = securityType;
        this.ipConfig = ipConfig;
        this.hiddenSsid = hiddenSsid;
    }

    public boolean isOpenNetwork() {
        return "Open".equals(securityType);
    }
}
