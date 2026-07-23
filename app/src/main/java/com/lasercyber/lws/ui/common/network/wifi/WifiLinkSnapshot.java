package com.lasercyber.lws.ui.common.network.wifi;

import androidx.annotation.Nullable;

import java.util.Collections;
import java.util.List;

/**
 * Layer-3 link snapshot from {@link android.net.LinkProperties} or DHCP fallback.
 */
public final class WifiLinkSnapshot {

    @Nullable
    public final String ipv4Address;
    public final int prefixLength;
    @Nullable
    public final String subnetMask;
    @Nullable
    public final String gateway;
    public final List<String> dnsServers;
    public final boolean l3Ready;

    public WifiLinkSnapshot(
            @Nullable String ipv4Address,
            int prefixLength,
            @Nullable String subnetMask,
            @Nullable String gateway,
            @Nullable List<String> dnsServers,
            boolean l3Ready) {
        this.ipv4Address = ipv4Address;
        this.prefixLength = prefixLength;
        this.subnetMask = subnetMask;
        this.gateway = gateway;
        this.dnsServers = dnsServers == null
                ? Collections.emptyList()
                : Collections.unmodifiableList(dnsServers);
        this.l3Ready = l3Ready;
    }

    @Nullable
    public String dns1() {
        return dnsServers.isEmpty() ? null : dnsServers.get(0);
    }

    @Nullable
    public String dns2() {
        return dnsServers.size() < 2 ? null : dnsServers.get(1);
    }
}
