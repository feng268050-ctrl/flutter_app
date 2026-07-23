package com.lasercyber.lws.ui.network.ws;

import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;

/**
 * Device WebSocket URL helpers. Host and HTTPS origins are defined in {@link DeviceApiOriginConfig}.
 */
public final class DeviceWebSocketConfig {
    private DeviceWebSocketConfig() {
    }

    public static String resolveApiHost() {
        return DeviceApiOriginConfig.resolveApiHost();
    }

    public static String buildDeviceWsUrl(String deviceSn) {
        return DeviceApiOriginConfig.buildDeviceWebSocketUrl(deviceSn);
    }

    static String buildDeviceWsUrl(String host, String deviceSn) {
        return DeviceApiOriginConfig.buildDeviceWebSocketUrl(host, deviceSn);
    }
}
