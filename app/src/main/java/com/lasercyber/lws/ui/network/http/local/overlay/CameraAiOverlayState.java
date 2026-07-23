package com.lasercyber.lws.ui.network.http.local.overlay;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.view.DetectionOverlayView;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Thread-safe overlay snapshot for AI Vision UI and {@code GET /v1/camera/ai} compositor.
 */
public final class CameraAiOverlayState {

    public static final class Snapshot {
        public final String displayMessage;
        @NonNull
        public final List<DetectionOverlayView.Box> boxes;

        Snapshot(@Nullable String displayMessage, @Nullable List<DetectionOverlayView.Box> boxes) {
            this.displayMessage = displayMessage == null ? "" : displayMessage;
            this.boxes = boxes == null
                    ? Collections.emptyList()
                    : Collections.unmodifiableList(new ArrayList<>(boxes));
        }
    }

    private static final CameraAiOverlayState INSTANCE = new CameraAiOverlayState();

    private final Object lock = new Object();
    @NonNull
    private Snapshot snapshot = new Snapshot("", Collections.emptyList());

    @NonNull
    public static CameraAiOverlayState getInstance() {
        return INSTANCE;
    }

    public void updateFromCheckResult(@Nullable String rawMessage, @Nullable String status) {
        Snapshot next = AiVisionOverlayParser.buildSnapshot(rawMessage, status);
        synchronized (lock) {
            snapshot = next;
        }
    }

    public void clear() {
        synchronized (lock) {
            snapshot = new Snapshot("", Collections.emptyList());
        }
    }

    /** Updates overlay boxes for process-video AI sessions and HTTP compositor. */
    public void updateOverlay(@Nullable List<DetectionOverlayView.Box> boxes,
                              @Nullable String displayMessage) {
        synchronized (lock) {
            snapshot = new Snapshot(
                    displayMessage,
                    boxes == null ? Collections.emptyList() : boxes);
        }
    }

    @NonNull
    public Snapshot getSnapshot() {
        synchronized (lock) {
            return snapshot;
        }
    }
}
