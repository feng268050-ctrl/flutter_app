package com.lasercyber.lws.ui.common.network.wifi;

import android.content.Context;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.common.network.CameraEth0Configurator;
import com.lasercyber.lws.ui.common.utils.SystemWifiManagerUtils;

/**
 * Orchestrates Wi‑Fi connect: validate, persist profile, apply IP config, connect.
 */
public final class WifiConnectionCoordinator {

    public static final class ConnectResult {
        public final boolean success;
        @NonNull
        public final String reason;

        public ConnectResult(boolean success, @NonNull String reason) {
            this.success = success;
            this.reason = reason;
        }
    }

    private final Context appContext;
    private final WifiNetworkProfileStore profileStore;
    private final SystemWifiManagerUtils wifiManagerUtils;

    public WifiConnectionCoordinator(@NonNull Context context) {
        this.appContext = context.getApplicationContext();
        this.profileStore = new WifiNetworkProfileStore(appContext);
        this.wifiManagerUtils = new SystemWifiManagerUtils(appContext);
    }

    @NonNull
    public WifiNetworkProfileStore profiles() {
        return profileStore;
    }

    @NonNull
    public ConnectResult connect(@NonNull WifiConnectRequest request) {
        String eth0Host = CameraEth0Configurator.currentEth0Ipv4Host();
        WifiIpConfigValidator.Result validation =
                WifiIpConfigValidator.validate(request.ipConfig, eth0Host);
        if (!validation.valid) {
            return new ConnectResult(false,
                    validation.reason != null ? validation.reason : "invalid_ip_config");
        }

        profileStore.put(new WifiNetworkProfile(
                request.ssid,
                request.securityType,
                request.ipConfig));

        SystemWifiManagerUtils.OperationResult result =
                wifiManagerUtils.connectOrUpdateNetwork(request);
        return new ConnectResult(result.success, result.reason);
    }

    public void removeProfile(@NonNull String ssid, @NonNull String securityType) {
        profileStore.remove(ssid, securityType);
    }
}
