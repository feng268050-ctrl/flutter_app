package com.lasercyber.lws.ui.common.weld;

import android.app.Activity;

import androidx.annotation.Nullable;

import com.blankj.utilcode.util.ActivityUtils;
import com.lasercyber.lws.ui.common.constant.ModelConstant;

/**
 * Lens dirty and zero-point offset deferred alerts apply only in weld modes.
 */
public final class WeldAlertScope {

    private WeldAlertScope() {
    }

    public static boolean isWeldModelType(int modelType) {
        return modelType == ModelConstant.CONTINUOUS_WELDING
                || modelType == ModelConstant.POINT_WELDING;
    }

    public static boolean isEligible(@Nullable WeldModeHost host) {
        return host != null && isWeldModelType(host.getActiveWeldModelType());
    }

    public static boolean isEligibleFromTopActivity() {
        Activity top = ActivityUtils.getTopActivity();
        if (top instanceof WeldModeHost host) {
            return isEligible(host);
        }
        return false;
    }
}
