package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import androidx.annotation.StringRes;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.ModelConstant;

/**
 * Important Reminder dialog copy keyed by active process model.
 */
public final class LaserEnableReminderCopy {

    private LaserEnableReminderCopy() {
    }

    @StringRes
    public static int nozzleTipResId(int processModel) {
        return switch (processModel) {
            case ModelConstant.HAND_CUT, ModelConstant.CNC_CUT -> R.string.laser_reminder_cutting_nozzle;
            case ModelConstant.WELD_CLEAN, ModelConstant.WIDTH_CLEAN ->
                    R.string.laser_reminder_clean_nozzle_removed;
            default -> R.string.laser_reminder_welding_nozzle;
        };
    }
}
