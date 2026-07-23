package com.lasercyber.lws.ui.common.network;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.config.CameraConfig;

/**
 * Chooses {@link CameraRoutePolicy} from wlan0 and camera IPv4.
 */
public final class CameraRoutePolicyResolver {

    private CameraRoutePolicyResolver() {
    }

    @NonNull
    public static CameraRoutePolicy resolve(
            @Nullable String wlanIp,
            @Nullable String cameraHost) {
        if (wlanIp == null || wlanIp.isEmpty()) {
            return CameraRoutePolicy.CAMERA_SUBNET_ROUTE;
        }
        String camera = cameraHost != null ? cameraHost : CameraConfig.getCameraIp();
        CameraEth0AddressPlanner.Ipv4 wlan =
                CameraEth0AddressPlanner.parseIpv4(wlanIp);
        CameraEth0AddressPlanner.Ipv4 cam =
                CameraEth0AddressPlanner.parseIpv4(camera);
        if (wlan != null && cam != null
                && CameraEth0AddressPlanner.sameSubnet24(wlan, cam)) {
            return CameraRoutePolicy.CAMERA_HOST_ROUTE;
        }
        return CameraRoutePolicy.CAMERA_SUBNET_ROUTE;
    }
}
