package com.lasercyber.lws.ui.common.network.wifi;

import androidx.annotation.Nullable;

import java.util.Objects;

public final class WifiIpConfig {

    public enum Mode {
        DHCP,
        STATIC
    }

    public final Mode mode;
    @Nullable
    public final String ip;
    public final int prefixLength;
    @Nullable
    public final String gateway;
    @Nullable
    public final String dns1;
    @Nullable
    public final String dns2;

    private WifiIpConfig(
            Mode mode,
            @Nullable String ip,
            int prefixLength,
            @Nullable String gateway,
            @Nullable String dns1,
            @Nullable String dns2) {
        this.mode = mode;
        this.ip = ip;
        this.prefixLength = prefixLength;
        this.gateway = gateway;
        this.dns1 = dns1;
        this.dns2 = dns2;
    }

    public static WifiIpConfig dhcp() {
        return new WifiIpConfig(Mode.DHCP, null, 0, null, null, null);
    }

    public static WifiIpConfig staticIp(
            @Nullable String ip,
            int prefixLength,
            @Nullable String gateway,
            @Nullable String dns1,
            @Nullable String dns2) {
        return new WifiIpConfig(Mode.STATIC, ip, prefixLength, gateway, dns1, dns2);
    }

    public boolean isStatic() {
        return mode == Mode.STATIC;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof WifiIpConfig)) {
            return false;
        }
        WifiIpConfig that = (WifiIpConfig) o;
        return prefixLength == that.prefixLength
                && mode == that.mode
                && Objects.equals(ip, that.ip)
                && Objects.equals(gateway, that.gateway)
                && Objects.equals(dns1, that.dns1)
                && Objects.equals(dns2, that.dns2);
    }

    @Override
    public int hashCode() {
        return Objects.hash(mode, ip, prefixLength, gateway, dns1, dns2);
    }
}
