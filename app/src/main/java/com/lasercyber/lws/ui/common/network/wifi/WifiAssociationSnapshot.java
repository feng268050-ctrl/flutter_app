package com.lasercyber.lws.ui.common.network.wifi;

import androidx.annotation.Nullable;

/**
 * Layer-2 Wi‑Fi association snapshot (SSID known, may lack IPv4).
 */
public final class WifiAssociationSnapshot {

    @Nullable
    public final String ssid;
    @Nullable
    public final String bssid;
    @Nullable
    public final String securityType;
    @Nullable
    public final String capabilities;
    @Nullable
    public final Integer rssi;
    @Nullable
    public final Integer frequency;
    public final boolean associated;

    public WifiAssociationSnapshot(
            @Nullable String ssid,
            @Nullable String bssid,
            @Nullable String securityType,
            @Nullable String capabilities,
            @Nullable Integer rssi,
            @Nullable Integer frequency,
            boolean associated) {
        this.ssid = ssid;
        this.bssid = bssid;
        this.securityType = securityType;
        this.capabilities = capabilities;
        this.rssi = rssi;
        this.frequency = frequency;
        this.associated = associated;
    }
}
