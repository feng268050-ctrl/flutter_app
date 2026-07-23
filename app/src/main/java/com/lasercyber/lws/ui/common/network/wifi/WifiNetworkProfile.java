package com.lasercyber.lws.ui.common.network.wifi;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Objects;

public final class WifiNetworkProfile {

    @NonNull
    public final String ssid;
    @NonNull
    public final String securityType;
    @NonNull
    public final WifiIpConfig ipConfig;

    public WifiNetworkProfile(
            @NonNull String ssid,
            @NonNull String securityType,
            @NonNull WifiIpConfig ipConfig) {
        this.ssid = ssid;
        this.securityType = securityType;
        this.ipConfig = ipConfig;
    }

    public static String profileKey(@NonNull String ssid, @NonNull String securityType) {
        return ssid + '\u0000' + securityType;
    }

    @NonNull
    public String key() {
        return profileKey(ssid, securityType);
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof WifiNetworkProfile)) {
            return false;
        }
        WifiNetworkProfile that = (WifiNetworkProfile) o;
        return ssid.equals(that.ssid)
                && securityType.equals(that.securityType)
                && ipConfig.equals(that.ipConfig);
    }

    @Override
    public int hashCode() {
        return Objects.hash(ssid, securityType, ipConfig);
    }
}
