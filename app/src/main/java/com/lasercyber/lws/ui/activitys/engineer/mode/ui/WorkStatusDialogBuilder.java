package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.component.dialog.FrostDialog;
import com.lasercyber.lws.ui.component.dialog.MachineStatusOverlay;

public class WorkStatusDialogBuilder {
    private static volatile boolean isOpen = false;
    private static final Handler handler = new Handler(Looper.getMainLooper());
    /**
     * 延时时间ms
     */
    private static final int DELAY_MILLIS = 500;
    /** Ignore brief gun-off glitches before scheduling auto-close. */
    private static final long GUN_OFF_DEBOUNCE_MS = 500L;
    @Nullable
    private static Runnable closeTask;
    @Nullable
    private static Runnable gunOffDebounceTask;
    @Nullable
    private static volatile FrostDialog.Handle instance;

    /**
     * 创建不显示关闭按钮的弹窗
     */
    public static void createShowNoButtonDialog(Context context) {
        cancelPendingClose();
        synchronized (WorkStatusDialogBuilder.class) {
            if (isOpen && instance != null && instance.isShowing()) {
                return;
            }
            isOpen = false;
            instance = MachineStatusOverlay.show(context, false, () -> {
                isOpen = false;
                cancelPendingClose();
                instance = null;
            });
            isOpen = instance != null;
        }
    }

    /**
     * Gun switch turned off; debounce before the delayed auto-close starts.
     */
    public static void scheduleCloseOnGunOff(Context context) {
        cancelPendingClose();
        Context appContext = context.getApplicationContext();
        gunOffDebounceTask = () -> closeDialogDelayMillis(appContext);
        handler.postDelayed(gunOffDebounceTask, GUN_OFF_DEBOUNCE_MS);
    }

    private static void cancelPendingClose() {
        if (gunOffDebounceTask != null) {
            handler.removeCallbacks(gunOffDebounceTask);
            gunOffDebounceTask = null;
        }
        if (closeTask != null) {
            handler.removeCallbacks(closeTask);
            closeTask = null;
        }
    }

    /**
     * 延时关闭弹窗
     */
    public static void closeDialogDelayMillis(Context context) {
        cancelPendingClose();
        Context appContext = context.getApplicationContext();
        closeTask = () -> closeDialog(appContext);
        handler.postDelayed(closeTask, DELAY_MILLIS);
    }

    public static void closeDialog(Context context) {
        cancelPendingClose();
        // Dismiss only the machine-status overlay handle. Warn overlays stack independently;
        // skipping close while a warn is visible left Real-time Machine Status stuck on screen.
        FrostDialog.Handle handle = instance;
        if (handle != null && handle.isShowing()) {
            handle.dismiss();
        } else {
            MachineStatusOverlay.dismiss(null);
        }
        instance = null;
        isOpen = false;
    }

    /**
     * 清空实例
     */
    public static void clearInstance() {
        cancelPendingClose();
        instance = null;
        synchronized (WorkStatusDialogBuilder.class) {
            instance = null;
            isOpen = false;
        }
    }
}
