package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import android.app.Activity;
import android.content.Context;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.settings.SafetyGroundLockAlarmSettings;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.dialog.FrostDialog;
import com.lasercyber.lws.ui.component.dialog.FrostPromptDialog;

/**
 * Informational prompt when laser enable is active, the gun switch is on,
 * but the safety ground lock is not connected. Not a logged alarm.
 * Auto-dismisses when laser enable turns off, the gun switch releases, or the safety ground lock connects.
 */
public final class SafetyGroundLockPrompt {

    private static volatile boolean promptedForCurrentGunPress;
    @Nullable
    private static volatile FrostDialog.Handle activeHandle;

    private SafetyGroundLockPrompt() {
    }

    public static void reset() {
        promptedForCurrentGunPress = false;
        dismissIfShowing();
    }

    private static void dismissIfShowing() {
        FrostDialog.Handle handle = activeHandle;
        activeHandle = null;
        if (handle != null && handle.isShowing()) {
            GlobalSoundManager.stopWarnSound();
            handle.dismiss();
        }
    }

    public static void maybeShow(
            @NonNull Context context,
            @Nullable DeviceStatus deviceStatus,
            boolean laserEnableActive) {
        if (!laserEnableActive) {
            reset();
            return;
        }
        if (deviceStatus == null) {
            return;
        }
        if (!deviceStatus.isGunSwitchOn()) {
            reset();
            return;
        }
        if (deviceStatus.isSafetyGroundLockLocked()) {
            reset();
            return;
        }
        if (!SafetyGroundLockAlarmSettings.isEnabled(context)) {
            return;
        }
        if (promptedForCurrentGunPress) {
            return;
        }
        promptedForCurrentGunPress = true;
        show(context);
    }

    private static void show(@NonNull Context context) {
        Activity activity = resolveActivity(context);
        if (activity == null) {
            promptedForCurrentGunPress = false;
            return;
        }
        String title = activity.getString(R.string.safety_ground_lock_not_connected_title);
        FrostDialog.Handle handle = FrostPromptDialog.builder(activity)
                .widthPx(FrostPromptDialog.resolveTitleBasedWidthPx(activity, title))
                .confirmText(R.string.confirm_text)
                .dismissOnScrimClick(true)
                .body(SafetyGroundLockPrompt::bindBody)
                .onConfirm(SafetyGroundLockPrompt::confirmDismiss)
                .onCancel(GlobalSoundManager::stopWarnSound)
                .onDismiss(() -> {
                    activeHandle = null;
                    GlobalSoundManager.stopWarnSound();
                    promptedForCurrentGunPress = false;
                })
                .show();
        if (handle == null) {
            promptedForCurrentGunPress = false;
            return;
        }
        activeHandle = handle;
        GlobalSoundManager.ensureInitialized(activity);
        GlobalSoundManager.warnSound();
    }

    private static void confirmDismiss() {
        GlobalSoundManager.stopWarnSound();
        FrostDialog.Handle handle = activeHandle;
        if (handle != null && handle.isShowing()) {
            handle.dismiss();
        }
    }

    private static void bindBody(@NonNull View body) {
        ImageView icon = body.findViewById(R.id.prompt_icon);
        if (icon != null) {
            icon.setImageResource(R.mipmap.alarm_warn_icon);
        }
        TextView title = body.findViewById(R.id.prompt_title);
        title.setText(R.string.safety_ground_lock_not_connected_title);
        title.setTextColor(body.getContext().getColor(R.color.text_black));

        TextView content = body.findViewById(R.id.prompt_content);
        content.setText(R.string.safety_ground_lock_not_connected_message);
    }

    @VisibleForTesting
    static boolean isEligibleForPrompt(
            @Nullable DeviceStatus deviceStatus,
            boolean laserEnableActive,
            boolean alarmEnabled) {
        if (!laserEnableActive || !alarmEnabled) {
            return false;
        }
        if (deviceStatus == null) {
            return false;
        }
        if (!deviceStatus.isGunSwitchOn()) {
            return false;
        }
        return !deviceStatus.isSafetyGroundLockLocked();
    }

    @Nullable
    private static Activity resolveActivity(@NonNull Context context) {
        if (!(context instanceof Activity activity)) {
            return null;
        }
        if (activity.isFinishing() || activity.isDestroyed()) {
            return null;
        }
        return activity;
    }
}
