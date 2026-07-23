package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.component.CameraController;

import java.lang.ref.WeakReference;

/**
 * Weak registration of the visible {@link CameraController} (Quick / Engineer Record Working)
 * for HTTP record UI sync.
 */
public final class CameraRecordUiBridge {
    @Nullable
    private static WeakReference<CameraController> active;

    private CameraRecordUiBridge() {
    }

    public static void register(@Nullable CameraController controller) {
        if (controller == null) {
            return;
        }
        active = new WeakReference<>(controller);
    }

    public static void unregister(@Nullable CameraController controller) {
        if (controller == null || active == null) {
            return;
        }
        CameraController current = active.get();
        if (current == controller) {
            active = null;
        }
    }

    @Nullable
    public static CameraController get() {
        return active != null ? active.get() : null;
    }

    /**
     * After HTTP record start/stop succeeds, mirror state on the attached controller if any.
     */
    public static void syncUiIfPresent(boolean recordingOn) {
        CameraController controller = get();
        if (controller == null) {
            return;
        }
        if (recordingOn) {
            controller.applyExternalRecordOn();
        } else {
            controller.applyExternalRecordOff();
        }
    }
}
