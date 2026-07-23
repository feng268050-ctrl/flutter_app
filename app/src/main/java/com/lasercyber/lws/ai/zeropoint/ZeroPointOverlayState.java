package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.zeropoint.ZeroPointOverlaySnapshot;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Latest zero-point overlay for UI layers (AI Vision preview, debug).
 */
public final class ZeroPointOverlayState {

    public interface Listener {
        void onZeroPointOverlayChanged(@Nullable ZeroPointOverlaySnapshot snapshot);
    }

    private static final ZeroPointOverlayState INSTANCE = new ZeroPointOverlayState();

    private final CopyOnWriteArrayList<Listener> listeners = new CopyOnWriteArrayList<>();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    @Nullable
    private volatile ZeroPointOverlaySnapshot snapshot;

    @NonNull
    public static ZeroPointOverlayState getInstance() {
        return INSTANCE;
    }

    public void addListener(@NonNull Listener listener) {
        listeners.addIfAbsent(listener);
        ZeroPointOverlaySnapshot current = snapshot;
        if (current != null) {
            listener.onZeroPointOverlayChanged(current);
        }
    }

    public void removeListener(@NonNull Listener listener) {
        listeners.remove(listener);
    }

    public void update(@Nullable ZeroPointOverlaySnapshot next) {
        snapshot = next;
        if (listeners.isEmpty()) {
            return;
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            dispatch(next);
        } else {
            mainHandler.post(() -> dispatch(next));
        }
    }

    public void clear() {
        update(null);
    }

    @Nullable
    public ZeroPointOverlaySnapshot getSnapshot() {
        return snapshot;
    }

    private void dispatch(@Nullable ZeroPointOverlaySnapshot next) {
        for (Listener listener : listeners) {
            listener.onZeroPointOverlayChanged(next);
        }
    }
}
