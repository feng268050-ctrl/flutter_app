package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.utils.InchMillimeterUtils;

/**
 * Formats engineer-mode numeric input descriptions and stepper bounds.
 */
final class EngineerInputRangeText {

    private EngineerInputRangeText() {
    }

    static int metricStepperMin(boolean useMMUnit, int minMm) {
        return useMMUnit ? minMm : 0;
    }

    static int metricStepperMax(boolean useMMUnit, int maxMm) {
        return useMMUnit ? maxMm : Integer.MAX_VALUE;
    }

    static String lengthRangeDesc(int descRes, boolean useMMUnit, int minMm, int maxMm) {
        String unit = Utils.getApp().getString(useMMUnit ? R.string.mm_unit : R.string.in_unit);
        String minStr = useMMUnit ? String.valueOf(minMm) : InchMillimeterUtils.mmToInStr(minMm);
        String maxStr = useMMUnit ? String.valueOf(maxMm) : InchMillimeterUtils.mmToInStr(maxMm);
        return Utils.getApp().getString(descRes, minStr, maxStr, unit);
    }

    static String speedRangeDesc(int descRes, boolean useMMUnit, int minMmPerS, int maxMmPerS) {
        String unit = Utils.getApp().getString(useMMUnit ? R.string.mm_s_unit : R.string.in_s_unit);
        String minStr = useMMUnit
                ? String.valueOf(minMmPerS)
                : String.valueOf(InchMillimeterUtils.mmToInPerSecond(minMmPerS));
        String maxStr = useMMUnit
                ? String.valueOf(maxMmPerS)
                : String.valueOf(InchMillimeterUtils.mmToInPerSecond(maxMmPerS));
        return Utils.getApp().getString(descRes, minStr, maxStr, unit);
    }

    static String frequencyRangeDesc(int minHz, int maxHz) {
        return Utils.getApp().getString(
                R.string.swing_frequency_desc,
                String.valueOf(minHz),
                String.valueOf(maxHz),
                Utils.getApp().getString(R.string.hz_unit));
    }
}
