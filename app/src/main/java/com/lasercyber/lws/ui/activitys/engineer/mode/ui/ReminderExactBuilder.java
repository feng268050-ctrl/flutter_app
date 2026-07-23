package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import android.content.Context;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.camera.CameraFloatOverlayCoordinator;
import com.lasercyber.lws.ui.common.config.DeviceModelConfig;
import com.lasercyber.lws.ui.common.config.FocusScaleRefImageLoader;
import com.lasercyber.lws.ui.common.config.NozzleReminderImageLoader;
import com.lasercyber.lws.frostui.control.interop.FrostCheckboxView;
import com.lasercyber.lws.frostui.button.interop.FrostButtonView;
import com.lasercyber.lws.frostui.border.FrostTone;
import com.lasercyber.lws.ui.component.dialog.FrostDialog;

import java.util.HashMap;
import java.util.Objects;

/**
 * Important Reminder (laser enable) on {@link FrostDialog} with {@link FrostTone#LIGHT}.
 */
public final class ReminderExactBuilder {

    private static final HashMap<Integer, Boolean> remindersMap = new HashMap<>(3);

    private ReminderExactBuilder() {
    }

    public interface OnReminderBtnClickListener {
        void onConfirmClick();

        default void remember() {
        }
    }

    public static void openReminderExactDialog(
            @NonNull Context context,
            int sessionKey,
            int processModel,
            @NonNull OnReminderBtnClickListener listener) {
        Boolean reminders = remindersMap.get(sessionKey);
        if (Objects.equals(reminders, Boolean.TRUE)) {
            listener.onConfirmClick();
            return;
        }
        OnReminderBtnClickListener wrappedListener = new OnReminderBtnClickListener() {
            @Override
            public void onConfirmClick() {
                listener.onConfirmClick();
            }

            @Override
            public void remember() {
                remindersMap.put(sessionKey, Boolean.TRUE);
                listener.remember();
            }
        };
        CameraFloatOverlayCoordinator.onMachineStatusOverlayShowing();
        FrostDialog.Handle handle = FrostDialog.prompt(context)
                .tone(FrostTone.LIGHT)
                .title(R.string.laser_reminder_title)
                .widthFraction(0.9f)
                .showTitle(true)
                .showActionBar(true)
                .dismissOnScrimClick(false)
                .customBodyView(
                        R.layout.dialog_frost_body_laser_enable_reminder,
                        body -> bindReminderBody(body, processModel))
                .customActionBarView(
                        R.layout.dialog_frost_action_laser_enable_reminder,
                        action -> bindReminderAction(action, wrappedListener))
                .onDismiss(CameraFloatOverlayCoordinator::onMachineStatusOverlayDismissed)
                .show();
        if (handle == null) {
            CameraFloatOverlayCoordinator.onMachineStatusOverlayDismissed();
        }
    }

    private static void bindReminderBody(@NonNull View body, int processModel) {
        TextView nozzleTip = body.findViewById(R.id.tv_nozzle_tip);
        if (nozzleTip != null) {
            nozzleTip.setText(LaserEnableReminderCopy.nozzleTipResId(processModel));
        }
        ImageView nozzleIllustration = body.findViewById(R.id.iv_nozzle_reminder);
        if (nozzleIllustration != null) {
            nozzleIllustration.setScaleType(ImageView.ScaleType.CENTER_INSIDE);
            NozzleReminderImageLoader.bind(nozzleIllustration, processModel);
        }
        TextView focusTip = body.findViewById(R.id.tv_focus_scale_ref_tip);
        if (focusTip != null) {
            focusTip.setText(R.string.laser_reminder_focus_scale_ref);
        }
        ImageView focusIllustration = body.findViewById(R.id.iv_focus_scale_ref);
        if (focusIllustration != null) {
            focusIllustration.setScaleType(ImageView.ScaleType.CENTER_INSIDE);
            FocusScaleRefImageLoader.bind(focusIllustration, DeviceModelConfig.getFocusScaleRef());
        }
    }

    private static void bindReminderAction(
            @NonNull View action,
            @NonNull OnReminderBtnClickListener listener) {
        FrostCheckboxView checkBox = action.findViewById(R.id.important_reminder_check_box);
        FrostButtonView confirm = action.findViewById(R.id.btn_confirm);
        if (confirm != null) {
            confirm.setOnClickListener(v -> {
                if (checkBox != null && checkBox.isChecked()) {
                    listener.remember();
                }
                listener.onConfirmClick();
                FrostDialog.dismiss();
            });
        }
    }
}
