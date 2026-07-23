package com.lasercyber.lws.ui.common.camera;

import android.os.Handler;
import android.os.Looper;

import androidx.annotation.VisibleForTesting;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Global PR0 process-video recording flag for status bar and other surfaces outside
 * Fast / Engineer camera float.
 */
public final class CameraRecordStateStore {

    public interface Listener {
        void onRecordingChanged(boolean recording);
    }

    private static final Handler MAIN_HANDLER = new Handler(Looper.getMainLooper());
    private static final AtomicBoolean RECORDING = new AtomicBoolean(false);
    private static final List<Listener> LISTENERS = new CopyOnWriteArrayList<>();

    private CameraRecordStateStore() {
    }

    public static boolean isRecording() {
        return RECORDING.get();
    }

    public static void setRecording(boolean recording) {
        boolean previous = RECORDING.getAndSet(recording);
        if (previous == recording) {
            return;
        }
        notifyListeners(recording);
    }

    public static void addListener(Listener listener) {
        if (listener == null) {
            return;
        }
        LISTENERS.add(listener);
        listener.onRecordingChanged(RECORDING.get());
    }

    public static void removeListener(Listener listener) {
        if (listener != null) {
            LISTENERS.remove(listener);
        }
    }

    @VisibleForTesting
    static void resetForTest() {
        RECORDING.set(false);
        LISTENERS.clear();
    }

    private static void notifyListeners(boolean recording) {
        MAIN_HANDLER.post(() -> {
            for (Listener listener : LISTENERS) {
                listener.onRecordingChanged(recording);
            }
        });
    }
}
