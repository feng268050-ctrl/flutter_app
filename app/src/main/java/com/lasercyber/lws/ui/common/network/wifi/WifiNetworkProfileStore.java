package com.lasercyber.lws.ui.common.network.wifi;

import android.content.Context;
import android.content.SharedPreferences;
import android.text.TextUtils;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * Persists {@link WifiNetworkProfile} keyed by SSID + security type.
 */
public final class WifiNetworkProfileStore {

    private static final String PREFS = "wifi_network_profiles";
    private static final String KEY_PREFIX = "profile_";

    private final SharedPreferences prefs;

    public WifiNetworkProfileStore(@NonNull Context context) {
        this.prefs = context.getApplicationContext()
                .getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    @NonNull
    public WifiIpConfig getIpConfigOrDhcp(@NonNull String ssid, @NonNull String securityType) {
        WifiNetworkProfile profile = get(ssid, securityType);
        return profile == null ? WifiIpConfig.dhcp() : profile.ipConfig;
    }

    @Nullable
    public WifiNetworkProfile get(@NonNull String ssid, @NonNull String securityType) {
        String raw = prefs.getString(storageKey(ssid, securityType), null);
        if (TextUtils.isEmpty(raw)) {
            return null;
        }
        return decode(raw, ssid, securityType);
    }

    public void put(@NonNull WifiNetworkProfile profile) {
        prefs.edit()
                .putString(storageKey(profile.ssid, profile.securityType), encode(profile.ipConfig))
                .apply();
    }

    public void remove(@NonNull String ssid, @NonNull String securityType) {
        prefs.edit().remove(storageKey(ssid, securityType)).apply();
    }

    @NonNull
    private static String storageKey(@NonNull String ssid, @NonNull String securityType) {
        return KEY_PREFIX + WifiNetworkProfile.profileKey(ssid, securityType);
    }

    @NonNull
    public static String encodeIpConfig(@NonNull WifiIpConfig config) {
        return encode(config);
    }

    @NonNull
    public static WifiIpConfig decodeIpConfig(@NonNull String raw) {
        WifiNetworkProfile profile = decode(raw, "", "");
        return profile == null ? WifiIpConfig.dhcp() : profile.ipConfig;
    }

    @NonNull
    static String encode(@NonNull WifiIpConfig config) {
        if (config.mode == WifiIpConfig.Mode.DHCP) {
            return "dhcp";
        }
        return "static|"
                + nullToEmpty(config.ip) + '|'
                + config.prefixLength + '|'
                + nullToEmpty(config.gateway) + '|'
                + nullToEmpty(config.dns1) + '|'
                + nullToEmpty(config.dns2);
    }

    @Nullable
    static WifiNetworkProfile decode(
            @NonNull String raw,
            @NonNull String ssid,
            @NonNull String securityType) {
        if ("dhcp".equals(raw)) {
            return new WifiNetworkProfile(ssid, securityType, WifiIpConfig.dhcp());
        }
        if (!raw.startsWith("static|")) {
            return null;
        }
        String[] parts = raw.split("\\|", -1);
        if (parts.length < 6) {
            return null;
        }
        try {
            int prefix = Integer.parseInt(parts[2]);
            return new WifiNetworkProfile(
                    ssid,
                    securityType,
                    WifiIpConfig.staticIp(
                            emptyToNull(parts[1]),
                            prefix,
                            emptyToNull(parts[3]),
                            emptyToNull(parts[4]),
                            emptyToNull(parts[5])));
        } catch (NumberFormatException e) {
            return null;
        }
    }

    @NonNull
    private static String nullToEmpty(@Nullable String value) {
        return value == null ? "" : value;
    }

    @Nullable
    private static String emptyToNull(@NonNull String value) {
        return value.isEmpty() ? null : value;
    }
}
