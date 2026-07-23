package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import android.app.Activity;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.camera.CameraFloatOverlayCoordinator;
import com.lasercyber.lws.ui.component.dialog.FrostDialog;
import com.lasercyber.lws.ui.component.dialog.FrostPromptDialog;

/**
 * 进入工程师模式前的首次提示弹窗（首页与快速模式「更多参数」共用）。
 */
public final class EngineerModeEntryTipsDialog {
    private static final String DIALOG_KEY = "show_engineer_tips";

    private EngineerModeEntryTipsDialog() {
    }

    /**
     * 若用户未勾选「不再提醒」，则显示提示弹窗；确认后执行 {@code onProceed}。
     */
    public static void showIfNeeded(@NonNull Activity activity, @NonNull Runnable onProceed) {
        Boolean dontRemind = MemoryCacheManager.getInstance().getSerializable(DIALOG_KEY);
        if (Boolean.TRUE.equals(dontRemind)) {
            onProceed.run();
            return;
        }
        show(activity, onProceed);
    }

    private static void show(@NonNull Activity activity, @NonNull Runnable onProceed) {
        CameraFloatOverlayCoordinator.onMachineStatusOverlayShowing();
        FrostDialog.Handle handle = FrostPromptDialog.builder(activity)
                .widthDimen(R.dimen.engineer_mode_entry_dialog_width)
                .confirmText(R.string.dialog_main_button_text)
                .body(FrostPromptDialog::bindEngineerModeEntryBody)
                .showDontShowAgain(true)
                .dontShowAgainCheckedByDefault(true)
                .onDontShowAgainConfirm(checked ->
                        MemoryCacheManager.getInstance().putSerializable(DIALOG_KEY, checked))
                .onConfirm(() -> {
                    FrostDialog.dismiss();
                    onProceed.run();
                })
                .onDismiss(CameraFloatOverlayCoordinator::onMachineStatusOverlayDismissed)
                .show();
        if (handle == null) {
            CameraFloatOverlayCoordinator.onMachineStatusOverlayDismissed();
        }
    }
}
