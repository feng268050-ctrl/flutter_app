package com.lasercyber.lws.ui.common.camera;

/**
 * Resolves floating {@link com.lasercyber.lws.ui.component.CameraController} record button visuals
 * from recording flag and camera ICMP comm health.
 */
public final class CameraRecordButtonVisualState {

    public enum State {
        AVAILABLE,
        UNAVAILABLE,
        RECORDING
    }

    private CameraRecordButtonVisualState() {
    }

    public static State resolve(boolean recording, boolean cameraCommHealthy) {
        if (recording) {
            return State.RECORDING;
        }
        if (!cameraCommHealthy) {
            return State.UNAVAILABLE;
        }
        return State.AVAILABLE;
    }

    /** Visual-only mute on idle icon; recording ignores comm fault. */
    public static boolean commUnavailableVisual(boolean recording, boolean cameraCommHealthy) {
        return resolve(recording, cameraCommHealthy) == State.UNAVAILABLE;
    }

    public static boolean shouldStartPreflightOnTap(boolean recording, boolean cameraCommHealthy) {
        return resolve(recording, cameraCommHealthy) == State.AVAILABLE;
    }

    public static boolean shouldShowCameraUnavailableToast(boolean recording, boolean cameraCommHealthy) {
        return resolve(recording, cameraCommHealthy) == State.UNAVAILABLE;
    }
}
