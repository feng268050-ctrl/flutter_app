package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import static org.junit.Assert.assertEquals;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.ModelConstant;

import org.junit.Test;

public class LaserEnableReminderCopyTest {

    @Test
    public void weldModes_useWeldingNozzleCopy() {
        assertEquals(R.string.laser_reminder_welding_nozzle,
                LaserEnableReminderCopy.nozzleTipResId(ModelConstant.CONTINUOUS_WELDING));
        assertEquals(R.string.laser_reminder_welding_nozzle,
                LaserEnableReminderCopy.nozzleTipResId(ModelConstant.POINT_WELDING));
    }

    @Test
    public void cutModes_useCuttingNozzleCopy() {
        assertEquals(R.string.laser_reminder_cutting_nozzle,
                LaserEnableReminderCopy.nozzleTipResId(ModelConstant.HAND_CUT));
        assertEquals(R.string.laser_reminder_cutting_nozzle,
                LaserEnableReminderCopy.nozzleTipResId(ModelConstant.CNC_CUT));
    }

    @Test
    public void cleanModes_useRemovalCopy() {
        assertEquals(R.string.laser_reminder_clean_nozzle_removed,
                LaserEnableReminderCopy.nozzleTipResId(ModelConstant.WELD_CLEAN));
        assertEquals(R.string.laser_reminder_clean_nozzle_removed,
                LaserEnableReminderCopy.nozzleTipResId(ModelConstant.WIDTH_CLEAN));
    }

    @Test
    public void unknownMode_fallsBackToWeldingCopy() {
        assertEquals(R.string.laser_reminder_welding_nozzle,
                LaserEnableReminderCopy.nozzleTipResId(-1));
    }
}
