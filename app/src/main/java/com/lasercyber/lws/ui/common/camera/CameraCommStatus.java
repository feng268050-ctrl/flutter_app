package com.lasercyber.lws.ui.common.camera;

/**
 * Camera communication health derived from {@link CameraPingHealth} ICMP reachability.
 */
public final class CameraCommStatus {

    private CameraCommStatus() {
    }

    public static boolean isFault() {
        return !CameraPingHealth.getInstance().isReachable();
    }

    public static boolean isHealthy() {
        return CameraPingHealth.getInstance().isReachable();
    }
}
