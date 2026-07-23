package com.lasercyber.lws.ui.common.device;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Persisted remote lock flag (server {@code command.lock} / {@code command.unlock} only).
 */
public final class DeviceRemoteLockStore {

    private static final String PREF = "lws_device_remote_lock";
    private static final String KEY_REMOTE_LOCKED = "remote_locked";

    @Nullable
    private static volatile Context appContext;

    @Nullable
    /** Package-visible for unit tests in {@code com.lasercyber.lws.ui.common.device} and {@code ...ws}. */
    public static volatile SharedPreferences testPrefsOverride;

    private static final Handler MAIN_HANDLER = new Handler(Looper.getMainLooper());
    private static final List<Listener> LISTENERS = new CopyOnWriteArrayList<>();

    public interface Listener {
        void onRemoteLockChanged(boolean locked);
    }

    private DeviceRemoteLockStore() {
    }

    public static void init(@Nullable Context context) {
        if (context != null) {
            appContext = context.getApplicationContext();
        }
    }

    public static boolean isLocked() {
        SharedPreferences prefs = prefsOrNull();
        return prefs != null && prefs.getBoolean(KEY_REMOTE_LOCKED, false);
    }

    public static void setLocked(boolean locked) {
        SharedPreferences prefs = prefsOrNull();
        if (prefs == null) {
            return;
        }
        boolean previous = prefs.getBoolean(KEY_REMOTE_LOCKED, false);
        if (previous == locked) {
            return;
        }
        prefs.edit().putBoolean(KEY_REMOTE_LOCKED, locked).apply();
        notifyListeners(locked);
    }

    public static void addListener(Listener listener) {
        if (listener != null) {
            LISTENERS.add(listener);
        }
    }

    public static void removeListener(Listener listener) {
        LISTENERS.remove(listener);
    }

    @VisibleForTesting
    static void resetForTest(@Nullable Context context, boolean locked) {
        init(context);
        SharedPreferences prefs = prefsOrNull();
        if (prefs != null) {
            prefs.edit().putBoolean(KEY_REMOTE_LOCKED, locked).commit();
        }
        notifyListeners(locked);
    }

    @Nullable
    private static SharedPreferences prefsOrNull() {
        if (testPrefsOverride != null) {
            return testPrefsOverride;
        }
        Context ctx = appContext;
        if (ctx == null) {
            return null;
        }
        return ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE);
    }

    private static void notifyListeners(boolean locked) {
        MAIN_HANDLER.post(() -> {
            for (Listener listener : LISTENERS) {
                try {
                    listener.onRemoteLockChanged(locked);
                } catch (Exception ignored) {
                    // keep other listeners running
                }
            }
        });
    }
}
