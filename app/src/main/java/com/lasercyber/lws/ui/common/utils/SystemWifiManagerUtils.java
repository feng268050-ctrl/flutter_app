package com.lasercyber.lws.ui.common.utils;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.net.wifi.WifiConfiguration;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Process;
import android.text.TextUtils;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import com.lasercyber.lws.ui.common.network.wifi.WifiConnectRequest;
import com.lasercyber.lws.ui.common.network.wifi.WifiIpConfig;
import com.lasercyber.lws.ui.common.network.wifi.WifiIpConfigApplier;

import java.lang.reflect.Field;
import java.util.List;

public class SystemWifiManagerUtils {
    private static final String PERMISSION_NETWORK_SETTINGS = "android.permission.NETWORK_SETTINGS";
    /** @see ApplicationInfo#PRIVATE_FLAG_PRIVILEGED (hidden); stable in AOSP. */
    private static final int PRIVATE_FLAG_PRIVILEGED = 1 << 3;

    public static class OperationResult {
        public final boolean success;
        public final String reason;

        public OperationResult(boolean success, String reason) {
            this.success = success;
            this.reason = reason;
        }
    }

    private final Context appContext;
    private final WifiManager wifiManager;

    public SystemWifiManagerUtils(Context context) {
        this.appContext = context.getApplicationContext();
        this.wifiManager = (WifiManager) this.appContext.getSystemService(Context.WIFI_SERVICE);
    }

    public boolean hasPrivilegedWifiControl() {
        if (ContextCompat.checkSelfPermission(
                appContext,
                PERMISSION_NETWORK_SETTINGS
        ) == PackageManager.PERMISSION_GRANTED) {
            return true;
        }
        return hasPrivilegedSystemAppBypass(appContext);
    }

    private boolean hasPrivilegedSystemAppBypass(Context context) {
        if (Process.myUid() < Process.FIRST_APPLICATION_UID) {
            return true;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                ApplicationInfo ai = context.getApplicationInfo();
                Field pf = ApplicationInfo.class.getField("privateFlags");
                int privateFlags = pf.getInt(ai);
                return (privateFlags & PRIVATE_FLAG_PRIVILEGED) != 0;
            } catch (ReflectiveOperationException ignored) {
                // Fall through to the explicit permission result above.
            }
        }
        return false;
    }

    @SuppressLint("MissingPermission")
    public OperationResult connectOrUpdateNetwork(String ssid, String password) {
        return connectOrUpdateNetwork(new WifiConnectRequest(
                ssid,
                password,
                TextUtils.isEmpty(password) ? "Open" : "WPA",
                WifiIpConfig.dhcp()));
    }

    @SuppressLint("MissingPermission")
    public OperationResult connectOrUpdateNetwork(@NonNull WifiConnectRequest request) {
        if (wifiManager == null) {
            return new OperationResult(false, "wifi_manager_unavailable");
        }
        if (TextUtils.isEmpty(request.ssid)) {
            return new OperationResult(false, "empty_ssid");
        }
        if (!hasPrivilegedWifiControl()) {
            return new OperationResult(false, "missing_network_settings_permission");
        }
        if (!wifiManager.isWifiEnabled()) {
            return new OperationResult(false, "wifi_disabled");
        }

        WifiConfiguration config = obtainOrCreateConfiguration(request.ssid);
        config.SSID = quoteSsid(request.ssid);
        config.hiddenSSID = request.hiddenSsid;
        applySecurity(config, request);

        WifiIpConfigApplier.ApplyResult ipResult = request.ipConfig.isStatic()
                ? WifiIpConfigApplier.applyStatic(config, request.ipConfig)
                : WifiIpConfigApplier.applyDhcp(config);
        if (!ipResult.success) {
            return new OperationResult(false, ipResult.reason);
        }

        int networkId = config.networkId;
        if (networkId >= 0) {
            networkId = wifiManager.updateNetwork(config);
        } else {
            networkId = wifiManager.addNetwork(config);
        }
        if (networkId < 0) {
            return new OperationResult(false, "add_or_update_network_failed");
        }

        boolean disconnectOk = wifiManager.disconnect();
        boolean enableOk = wifiManager.enableNetwork(networkId, true);
        boolean reconnectOk = wifiManager.reconnect();
        wifiManager.saveConfiguration();
        boolean success = enableOk && reconnectOk;
        return new OperationResult(success, success ? "ok" : "enable_or_reconnect_failed:" + disconnectOk);
    }

    @SuppressLint("MissingPermission")
    @NonNull
    private WifiConfiguration obtainOrCreateConfiguration(@NonNull String ssid) {
        int networkId = findNetworkIdBySsid(ssid);
        if (networkId >= 0) {
            List<WifiConfiguration> configs = wifiManager.getConfiguredNetworks();
            if (configs != null) {
                String quotedSsid = quoteSsid(ssid);
                for (WifiConfiguration existing : configs) {
                    if (existing != null
                            && existing.networkId == networkId
                            && TextUtils.equals(existing.SSID, quotedSsid)) {
                        return existing;
                    }
                }
            }
            WifiConfiguration reused = new WifiConfiguration();
            reused.networkId = networkId;
            return reused;
        }
        return new WifiConfiguration();
    }

    @SuppressLint("MissingPermission")
    public OperationResult forgetNetwork(String ssid, String bssid) {
        if (wifiManager == null) {
            return new OperationResult(false, "wifi_manager_unavailable");
        }
        if (!hasPrivilegedWifiControl()) {
            return new OperationResult(false, "missing_network_settings_permission");
        }

        int networkId = findNetworkIdBySsid(ssid);
        WifiInfo current = wifiManager.getConnectionInfo();
        if (networkId < 0 && current != null && !TextUtils.isEmpty(current.getSSID())) {
            String currentSsid = normalizeSsid(current.getSSID());
            if (TextUtils.equals(currentSsid, ssid)
                    || (!TextUtils.isEmpty(bssid) && TextUtils.equals(current.getBSSID(), bssid))) {
                networkId = current.getNetworkId();
            }
        }

        boolean disconnectOk = wifiManager.disconnect();
        boolean removed = false;
        if (networkId >= 0) {
            wifiManager.disableNetwork(networkId);
            removed = wifiManager.removeNetwork(networkId);
            wifiManager.saveConfiguration();
        }

        boolean success = disconnectOk && (removed || networkId < 0);
        return new OperationResult(success, success ? "ok" : "disconnect_or_remove_failed");
    }

    @SuppressLint("MissingPermission")
    private int findNetworkIdBySsid(String ssid) {
        if (TextUtils.isEmpty(ssid) || wifiManager == null) {
            return -1;
        }
        List<WifiConfiguration> configs = wifiManager.getConfiguredNetworks();
        if (configs == null || configs.isEmpty()) {
            return -1;
        }
        String quotedSsid = quoteSsid(ssid);
        for (WifiConfiguration config : configs) {
            if (config != null && TextUtils.equals(config.SSID, quotedSsid)) {
                return config.networkId;
            }
        }
        return -1;
    }

    private String quoteSsid(String value) {
        return "\"" + value + "\"";
    }

    private String normalizeSsid(String raw) {
        return raw == null ? "" : raw.replace("\"", "");
    }

    private void applySecurity(@NonNull WifiConfiguration config, @NonNull WifiConnectRequest request) {
        config.allowedKeyManagement.clear();
        config.preSharedKey = null;
        if (request.isOpenNetwork()) {
            config.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE);
            return;
        }
        if (TextUtils.isEmpty(request.password)) {
            return;
        }
        String password = quoteSsid(request.password);
        if ("WPA3".equals(request.securityType) && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            config.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.SAE);
            config.preSharedKey = password;
            return;
        }
        config.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK);
        config.preSharedKey = password;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            config.allowedProtocols.set(WifiConfiguration.Protocol.RSN);
            config.allowedProtocols.set(WifiConfiguration.Protocol.WPA);
            config.allowedPairwiseCiphers.set(WifiConfiguration.PairwiseCipher.CCMP);
            config.allowedPairwiseCiphers.set(WifiConfiguration.PairwiseCipher.TKIP);
            config.allowedGroupCiphers.set(WifiConfiguration.GroupCipher.CCMP);
            config.allowedGroupCiphers.set(WifiConfiguration.GroupCipher.TKIP);
        }
    }
}
