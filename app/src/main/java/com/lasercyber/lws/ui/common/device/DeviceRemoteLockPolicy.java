package com.lasercyber.lws.ui.common.device;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;

import androidx.annotation.Nullable;

import com.blankj.utilcode.util.ActivityUtils;
import com.lasercyber.lws.ui.MainActivity;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.device.monitor.DeviceMonitoringActivity;
import com.lasercyber.lws.ui.activitys.engineer.mode.EngineerModeActivity;
import com.lasercyber.lws.ui.activitys.quick.mode.QuickModeActivity;
import com.lasercyber.lws.ui.component.dialog.GlobalDialogUtil;

/**
 * Entry guards and session ejection when the device is remotely locked.
 * Settings remain available so the user can connect network for {@code command.unlock}.
 */
public final class DeviceRemoteLockPolicy {

    public static final int HOME_PAGE_QUICK = 1;
    public static final int HOME_PAGE_ENGINEER = 2;
    public static final int HOME_PAGE_MONITOR = 3;
    public static final int HOME_PAGE_SETTINGS = 4;
    public static final int HOME_PAGE_AI_VISION = 5;

    private static volatile boolean lockDialogShownThisResumeCycle;

    private DeviceRemoteLockPolicy() {
    }

    public static boolean isSettingsPage(int page) {
        return page == HOME_PAGE_SETTINGS;
    }

    public static boolean isWorkFeaturePage(int page) {
        return page == HOME_PAGE_QUICK
                || page == HOME_PAGE_ENGINEER
                || page == HOME_PAGE_MONITOR
                || page == HOME_PAGE_AI_VISION;
    }

    /**
     * @return {@code true} if navigation must not proceed (dialog shown when applicable)
     */
    public static boolean blockHomeNavigationIfLocked(@Nullable Context context, int page) {
        if (!DeviceRemoteLockStore.isLocked() || isSettingsPage(page)) {
            return false;
        }
        if (isWorkFeaturePage(page)) {
            showRemoteLockDialog(context);
            return true;
        }
        return false;
    }

    /**
     * If a blocked operating session is foreground, safe-stop and return to home.
     */
    public static void ejectIfLockedModeActive() {
        if (!DeviceRemoteLockStore.isLocked()) {
            return;
        }
        Activity top = ActivityUtils.getTopActivity();
        if (top instanceof QuickModeActivity quickModeActivity) {
            quickModeActivity.exitForRemoteLock();
        } else if (top instanceof EngineerModeActivity engineerModeActivity) {
            engineerModeActivity.exitForRemoteLock();
        } else if (top instanceof DeviceMonitoringActivity monitoringActivity) {
            monitoringActivity.exitForRemoteLock();
        }
    }

    public static void onRemoteLockAppliedFromServer() {
        ejectIfLockedModeActive();
        showRemoteLockDialogIfNeeded();
    }

    public static void onRemoteUnlockAppliedFromServer() {
        GlobalDialogUtil.dismissRemoteLockDialog();
        lockDialogShownThisResumeCycle = false;
    }

    /**
     * Call from {@link MainActivity#onResume()} when already locked at cold start.
     */
    public static void maybeShowLockDialogOnResume(Activity activity) {
        if (activity instanceof MainActivity main) {
            com.lasercyber.lws.ui.common.home.HomePromptQueue.get().requestRefresh(main);
            return;
        }
        if (!DeviceRemoteLockStore.isLocked()) {
            lockDialogShownThisResumeCycle = false;
            return;
        }
        if (lockDialogShownThisResumeCycle) {
            return;
        }
        if (activity == null || activity.isFinishing() || activity.isDestroyed()) {
            return;
        }
        if (showRemoteLockDialog(activity)) {
            lockDialogShownThisResumeCycle = true;
        }
    }

    public static void resetResumeDialogCycle() {
        lockDialogShownThisResumeCycle = false;
    }

    /**
     * Shows the remote-lock dialog (dismissible; does not clear lock state).
     *
     * @return whether the dialog was shown or is already visible
     */
    public static boolean showRemoteLockDialog(@Nullable Context context) {
        return showRemoteLockDialog(context, null);
    }

    public static boolean showRemoteLockDialog(
            @Nullable Context context,
            @Nullable Runnable onDismissed) {
        Context host = resolveDialogHost(context);
        if (host == null) {
            return false;
        }
        return GlobalDialogUtil.showRemoteLockDialog(
                host,
                host.getString(R.string.remote_lock_dialog_title),
                host.getString(R.string.remote_lock_dialog_message),
                onDismissed);
    }

    private static void showRemoteLockDialogIfNeeded() {
        Activity top = ActivityUtils.getTopActivity();
        if (top == null || top.isFinishing() || top.isDestroyed()) {
            return;
        }
        if (showRemoteLockDialog(top)) {
            lockDialogShownThisResumeCycle = true;
        }
    }

    @Nullable
    private static Context resolveDialogHost(@Nullable Context context) {
        if (context instanceof Activity activity) {
            if (!activity.isFinishing() && !activity.isDestroyed()) {
                return activity;
            }
        }
        Activity top = ActivityUtils.getTopActivity();
        if (top != null && !top.isFinishing() && !top.isDestroyed()) {
            return top;
        }
        return context != null ? context.getApplicationContext() : null;
    }

    public static void navigateToHome(Context context) {
        Context app = context.getApplicationContext();
        Intent intent = new Intent(app, MainActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        app.startActivity(intent);
    }
}
