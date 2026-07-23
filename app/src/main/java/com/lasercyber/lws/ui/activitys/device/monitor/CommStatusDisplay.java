package com.lasercyber.lws.ui.activitys.device.monitor;

/**
 * Platform-aware display state for Alarm Information Comm Status indicators.
 */
public enum CommStatusDisplay {
    HEALTHY,
    FAULT,
    NEUTRAL;

    /**
     * @param emulator    running on Android emulator (no peripherals expected)
     * @param statusReady valid lower-controller status received
     * @param commAlarm   communication alarm bit set (missing comm when ready)
     */
    public static CommStatusDisplay resolve(boolean emulator, boolean statusReady, boolean commAlarm) {
        if (statusReady && !commAlarm) {
            return HEALTHY;
        }
        if (emulator) {
            return NEUTRAL;
        }
        return FAULT;
    }

    /**
     * Camera comm on emulator: when {@code camera_ip} is set in ROM (e.g. {@code CAMERA_IP} via
     * {@code make emulator}), reflect HTTP probe results (green/red) instead of neutral gray.
     */
    public static CommStatusDisplay resolveCameraComm(
            boolean emulator,
            boolean statusReady,
            boolean commAlarm,
            boolean cameraHostConfigured) {
        if (emulator && cameraHostConfigured) {
            return commAlarm ? FAULT : HEALTHY;
        }
        return resolve(emulator, statusReady, commAlarm);
    }

    /**
     * Temperature / metric tiles: gray when offline or no reading, red on alarm, green otherwise.
     */
    public static CommStatusDisplay resolveMetric(boolean ready, boolean hasValue, boolean fault) {
        if (!ready || !hasValue) {
            return NEUTRAL;
        }
        return fault ? FAULT : HEALTHY;
    }
}
