package com.lasercyber.lws.ui.common.upgrade;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.blankj.utilcode.util.ActivityUtils;
import com.lasercyber.lws.ui.MainActivity;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.io.File;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Dev helper: {@code make sync-firmware} pushes a {@code .bin} and broadcasts here to start OTA.
 */
public final class SyncFirmwareTrigger {

    public static final String ACTION_SYNC_FIRMWARE =
            "com.lasercyber.lws.ui.action.SYNC_FIRMWARE";
    public static final String EXTRA_FIRMWARE_PATH = "firmware_path";

    /** Device-side directory used by {@code scripts/make/sync-firmware.sh}. */
    public static final String DEVICE_SYNC_DIR = "/sdcard/Download/lws-sync-firmware";

    private static final String TAG = LogTAGConstant.SyncFirmwareTrigger;
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static final AtomicReference<String> pendingPath = new AtomicReference<>();

    private SyncFirmwareTrigger() {
    }

    public static void schedule(@Nullable Context context, @Nullable String devicePath) {
        if (context == null || devicePath == null || devicePath.trim().isEmpty()) {
            Log.w(TAG, "ignored: empty path");
            return;
        }
        pendingPath.set(devicePath.trim());
        Context app = context.getApplicationContext();
        if (Looper.myLooper() == Looper.getMainLooper()) {
            deliverPending(app);
        } else {
            MAIN.post(() -> deliverPending(app));
        }
    }

    public static void deliverFromActivityIntent(@NonNull Activity activity, @Nullable Intent intent) {
        if (intent == null) {
            return;
        }
        String path = intent.getStringExtra(EXTRA_FIRMWARE_PATH);
        if (path == null || path.isEmpty()) {
            return;
        }
        intent.removeExtra(EXTRA_FIRMWARE_PATH);
        deliverToActivity(activity, path);
    }

    private static void deliverPending(@NonNull Context app) {
        String path = pendingPath.getAndSet(null);
        if (path == null) {
            return;
        }
        Activity top = ActivityUtils.getTopActivity();
        if (top != null && !top.isFinishing() && !top.isDestroyed()) {
            deliverToActivity(top, path);
            return;
        }
        Intent intent = new Intent(app, MainActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        intent.putExtra(EXTRA_FIRMWARE_PATH, path);
        app.startActivity(intent);
        Log.i(TAG, "started MainActivity for sync firmware path=" + path);
    }

    private static void deliverToActivity(@NonNull Activity activity, @NonNull String devicePath) {
        File file = new File(devicePath);
        if (!file.isFile()) {
            Log.w(TAG, "sync firmware file missing: " + devicePath);
            return;
        }
        Log.i(TAG, "start sync firmware on " + activity.getClass().getSimpleName()
                + " path=" + devicePath);
        BundledFirmwareBootstrap.startSyncFirmwareUpgrade(activity, file);
    }
}
