package com.lasercyber.lws.ui.common.network;

/**
 * eth0 route strategy when wlan0 shares the camera /24.
 */
public enum CameraRoutePolicy {
    /** Route entire camera /24 via eth0. */
    CAMERA_SUBNET_ROUTE,
    /** Route only camera host /32 via eth0 to avoid hijacking customer Wi-Fi LAN. */
    CAMERA_HOST_ROUTE
}
